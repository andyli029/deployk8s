#!/bin/sh
set -e
#================================ user set ==========================
#TODO begin with "k8s-", can't set other role name at master node.
role=k8s-master
#kubeadm token create --print-join-command
join_master="kubeadm join 192.168.0.3:6443 --token 380vf8.lr9fieh3mrmdk818 --discovery-token-ca-cert-hash sha256:11b28d592b75e47100a5a8dec24deae9333ef9ef93376e8b3b9c1e0386dfb5fa "


private_hub_webui=1 # 0 or 1, set 1 to use the webui, http://${private_hub_ip}:8090, you should install ubuntu-desktop: 1. reboot, 2. apt-get install ubuntu-desktop, 3. reboot
helm_hub=1 # 0 or 1 #port 8091, http:${private_hub_ip}:8091
user=ubuntu
private_hub_user=qingcloud
private_hub_password=qingcloud1234
k8s_version=v1.18.5
kube_flannel=kube-flannel.yml
helm=helm-v3.3.0-rc.1-linux-amd64.tar.gz
#==== reference document ====
#https://www.cnblogs.com/alamisu/p/10751418.html
#================================ deploy code ================
log()
{
# bash echo -e
	if [ "$1" = 'GREEN' ]; then
		echo  "\033[32m $2 \033[0m" 
	elif [ "$1" = 'RED' ]; then
		echo  "\033[31m $2 \033[0m" 
	elif [ "$1" = 'EXIT' ]; then
		echo  "\033[31m $2 \033[0m" 
		exit 1
	elif [ "$1" = 'YELLOW' ]; then
		echo  "\033[33m $2 \033[0m" 
	elif [ "$1" = 'BLUE' ]; then
		echo  "\033[34m $2 \033[0m"
	else
		echo  "\033[32m $1 \033[0m" 
	fi
}

#====  check params ====
# check role
log "role is $role"

if [ $role = 'k8s-master' ]; then
	if [ -f $kube_flannel ]; then
		log "flannel file $kube_flannel"
	else
		log EXIT "flan file $kube_flannel not exist"
	fi

	if [ -f $helm ]; then
		log "helm $helm"
	else
		log EXIT "helm $helm not exist"
	fi
fi

#==== system set ====
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
log "swapoff "

#==== set mirrors ====
cat >> /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse
#deb http://apt.kubernetes.io/ kubernetes-xenial main #we use aliyun mirror
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF

#==== install package ====
log "update mirrors"
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 
apt-get update
log "update mirrors over"

log "install docker k8s"
rm -rf /var/lib/dpkg/lock
apt-get install -y docker.io  kubectl kubelet kubeadm conntrack ntpdate ntp ipvsadm ipset jq sysstat net-tools git apache2-utils # ubuntu-desktop

if [ $role = 'k8s-master' ]; then
	private_hub_ip=`ifconfig | grep -A 1 eth0: | tail -n 1 | awk '{print $2}'`
else
	private_hub_ip=`echo $join_master | awk '{print $3'} | cut -d ':' -f 1`
fi

cat >> /etc/docker/daemon.json  << EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "insecure-registries": ["${private_hub_ip}:5000"],
    "registry-mirrors": ["http://hub-mirror.c.163.com"]
}
EOF

systemctl enable docker
systemctl start docker
systemctl enable kubelet.service
systemctl start kubelet.service
log "install docker k8s over"

hostnamectl set-hostname $role
log "set hostname over"

if [ $role = 'k8s-master' ]; then
	log "kubeadm init"
	kubeadm init --image-repository gcr.azk8s.cn/google_containers --kubernetes-version $k8s_version --pod-network-cidr=10.244.0.0/16
	log "kubeadm init over"

	log "set kube/config"
	mkdir -p $HOME/.kube
	cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
	chown $(id -u):$(id -g) $HOME/.kube/config

	mkdir -p /home/$user/.kube
	cp -i /etc/kubernetes/admin.conf /home/$user/.kube/config
	chown -R $user:$user /home/$user/.kube

	echo "source <(kubectl completion bash)" >> /home/$user/.bashrc
	chown -R $user:$user /home/$user/.bashrc

	cp -rf /home/$user/.bashrc /root

	# log "get kube-flannel.yml"
	# kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml #FGW. can't donwload it.
	# wget https://api.anybox.qingcloud.com/v1/downloads/8fFFIbYavjsT0Ldu3Gqpzk5iOKw7Y8VYx2Oq3UI3NFAkbhF4bLrdEFFbsCT630uUGzlvZMbebRwaxKFu62V3kF74V6FlrBBJLsK2fBzYsdbfki2BBqkC2J2dYmWWEsii/kube-flannel.yml
	log "apply $kube_flannel"

	kubectl apply -f $kube_flannel
	log "apply $kube_flannel over"

	log RED "waiting until master node is ready(command: kubectl get node -w), then join other node!!! "

	log "get $helm"
	# wget https://api.anybox.qingcloud.com/v1/downloads/1Yyy8hFyjMP9ogpQrIfgQiK2OzN5jWa85GRcOtEFVLKGChsayCU0nqsNUj9PkETcF6SuMTsA5It8O3s34Bz70Xf7sIRy2NDTT4GB3vnyJR0jcEPVXJhZ295tRop5wW6Z/helm-v3.3.0-rc.1-linux-amd64.tar.gz
	tar xzvf $helm
	cp linux-amd64/helm /usr/local/bin/
	log "add stable repo"
	helm repo add stable https://kubernetes-charts.storage.googleapis.com/
	helm repo update
	#helm install stable/postgresql --generate-name #generate-name is necessary
	echo "source <(helm completion bash)" >> /home/$user/.bashrc
	log "helm install over"

	log "create private imagehub"
	docker pull registry # hyper/docker-registry-web # https://blog.csdn.net/c13891506947/article/details/107105418/ # https://blog.csdn.net/vbaspdelphi/article/details/53389952
	#openssl req -newkey rsa:4096 -nodes -sha256 -keyout certs/qingcloud.key -x509 -days 3650 -out certs/qingcloud.crt
	#docker run -d -p 5000:5000 --restart=always --name registry  -v /root/imagehub/auth/:/auth -e "REGISTRY_AUTH=htpasswd"   -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm"   -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd   -v /root/imagehub/certs:/certs   -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/qingcloud.crt   -e REGISTRY_HTTP_TLS_KEY=/certs/qingcloud.key  -v /root/imagehub:/var/lib/registry/ registry   
	mkdir -p /root/imagehub/auth/
	htpasswd -Bbn $private_hub_user $private_hub_password > /root/imagehub/auth/htpasswd

	docker run -d -p 5000:5000 --restart=always --name registry  -v /root/imagehub/auth/:/auth -e "REGISTRY_AUTH=htpasswd"   -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm"   -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd  -v /root/imagehub:/var/lib/registry/ registry 
	sleep 20 #waitting for startup
	docker login -u $private_hub_user -p $private_hub_password ${private_hub_ip}:5000
	log "login private hub user $private_hub_user  password $private_hub_password port 5000"

	log "usage example:"
	log "    docker login -u $private_hub_user -p $private_hub_password ${private_hub_ip}:5000"
	log "    curl -u '$private_hub_user:$private_hub_password' -XGET http://${private_hub_ip}:5000/v2/_catalog "
	log "    curl -u '$private_hub_user:$private_hub_password' -XGET http://${private_hub_ip}:5000/v2/lzz_alpine/tags/list "

	if [ $private_hub_webui = '1' ]; then
		log "pull docker webui"
		docker pull hyper/docker-registry-web
		webuiuser=`echo -n "$private_hub_user:$private_hub_password" | base64 `
		docker run -d  --restart=always -p 8090:8080 --name registry-web --link registry -e REGISTRY_URL=http://${private_hub_ip}:5000/v2 -e REGISTRY_TRUST_ANY_SSL=true -e REGISTRY_BASIC_AUTH="$webuiuser" -e REGISTRY_NAME=private_hub hyper/docker-registry-web
		log RED "browser: http://${private_hub_ip}:8090"
	fi

	if [ $helm_hub = '1' ]; then
		mkdir /root/helmhub
		chmod 777 /root/helmhub
		docker run -d  --restart=always -p 8091:8080 --name helm-hub -e DEBUG=true -e STORAGE=local -e STORAGE_LOCAL_ROOTDIR=/charts -v /root/helmhub:/charts chartmuseum/chartmuseum
		helm repo add localhub http://localhost:8091
		# helm create zlz
		# helm package zlz
		# mkdir package_zlz
		# cp zlz-* package_zlz/
		# helm repo index package_zlz --url http:/localhost:8091 #--merge helmhub/index.yaml. merge already exists index.yaml
		# mv package_zlz/* helmhub/
		# helm repo update
		# helm search repo zlz
	fi
else
	docker login -u $private_hub_user -p $private_hub_password ${private_hub_ip}:5000
	log "login private hub user $private_hub_user  password $private_hub_password port 5000"
	$join_master
	log "join master over"
fi

log "finish"
