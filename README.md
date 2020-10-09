# K8S 自动部署

## 宿主机

操作系统 Ubuntu 18.04 并建立一个 用户，例如ubuntu（普通用户可以使用K8S）

部署需要在root用户deployk8s.sh  helm-v3.3.0-rc.1-linux-amd64.tar.gz  kube-flannel.yml 放到 /root 目录。



## Master 节点

直接执行 deployk8s.sh 即可，记录下 join node 的字符串 `kubeadm join 192.168.0.3:6443 --token xxxxx  `



## Node 节点

当Master 节点的节点为 Ready 状态后，即可以在node下执行

配置 deployk8s.sh 的 role=k8s-node(x) 保障每个节点的role都不同
配置 deployk8s.sh 的 join_master="master 的join node 字符串”



## docker 私有仓库

地址： 本机IP: 5000

用户：private_hub_user的设置值，默认qingcloud

密码：private_hub_password的设置值，默认qingcloud1234



## docker 私有仓库Web浏览

地址：本机IP:8090

服务器版本没有安装桌面，安装桌面方法：1. 部署完K8S后（所有节点Ready）reboot， 2. apt-get install ubuntu-desktop 3. reboot



## Helm 管理工具

配置了stable的项目， `helm search repo postgresql`



## Helm Hub 仓库

helmhub：本机IP( or localhost):8091


## 仪表板


1. 进入webui的步骤

```
helm get notes -n kube-system dashboard
```

2. 登录webui的密码

```
kubectl describe secret -n kube-system dashboard-admin
```

