#!/bin/bash

node_name="master-end"
node_ip="172.23.228.4"

# 截取 eth0 的ip地址
# ip address | grep eth0 | sed -e "2s/^.*inet //" -e "2s/\/.*$//p" -n

# 设置主机名 和 域名解析
hostnamectl set-hostname  ${node_name}
cat >> /etc/hosts<<EOF
${node_ip} ${node_name}
EOF


# 关闭防火墙
systemctl stop firewalld
systemctl disable firewalld


# 关闭 swap
swapoff -a
free
sed -ri 's/.*swap.*/#&/' /etc/fstab



# 禁用 SELinux
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config


# 允许 iptables 检查桥接流量
sudo modprobe br_netfilter
lsmod | grep br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system


# 配置 yum 源
# wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
# yum -y install yum-utils
# yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo




# 安装docker
# yum install -y docker-ce
# 从本地rpm包安装docker
yum -y install ./docker_rpm/*.rpm

systemctl start docker
systemctl enable docker
docker --version
docker version



# Docker镜像源设置
cat >/etc/docker/daemon.json<<EOF
{
   "registry-mirrors": ["http://hub-mirror.c.163.com"]
}
EOF

systemctl reload docker
systemctl status docker containerd


# 配置k8s镜像源
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[k8s]
name=k8s
enabled=1
gpgcheck=0
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
EOF

containerd config default > /etc/containerd/config.toml
grep sandbox_image  /etc/containerd/config.toml
sed -i "s#k8s.gcr.io/pause#registry.aliyuncs.com/google_containers/pause#g"       /etc/containerd/config.toml
grep sandbox_image  /etc/containerd/config.toml

sed -i 's#SystemdCgroup = false#SystemdCgroup = true#g' /etc/containerd/config.toml
systemctl restart containerd


# 安装k8s 3大件

# yum install -y kubelet-1.24.1  kubeadm-1.24.1  kubectl-1.24.1 --disableexcludes=kubernetes
# yum install  --downloadonly --downloaddi=./k8s_rpm kubelet-1.24.1 --disableexcludes=kubernetes kubeadm-1.24.1  kubectl-1.24.1
yum -y install ./k8s_rpm/*.rpm


systemctl enable --now kubelet
systemctl status kubelet


# 提前下载好镜像
#docker pull registry.aliyuncs.com/google_containers/kube-apiserver:v1.24.1
#docker pull registry.aliyuncs.com/google_containers/kube-controller-manager:v1.24.1
#docker pull registry.aliyuncs.com/google_containers/kube-scheduler:v1.24.1
#docker pull registry.aliyuncs.com/google_containers/kube-proxy:v1.24.1
#docker pull registry.aliyuncs.com/google_containers/pause:3.7
#docker pull registry.aliyuncs.com/google_containers/etcd:3.5.3-0
#docker pull registry.aliyuncs.com/google_containers/coredns:v1.8.6

# 导入镜像
docker load -i ./images/kube-apiserver.tar
docker load -i ./images/kube-proxy.tar
docker load -i ./images/kube-controller-manager.tar
docker load -i ./images/kube-scheduler.tar
docker load -i ./images/etcd.tar
docker load -i ./images/pause.tar
docker load -i ./images/coredns.tar

docker load -i ./images/flannel.tar
docker load -i ./images/mirrored-flannelcni-flannel-cni-plugin.tar
docker load -i ./images/mirrored-flannelcni-flannel.tar







# kubeadm引导k8s集群
# kubeadm reset
# rm -fr ~/.kube/  /etc/kubernetes/* var/lib/etcd/*
kubeadm init \
  --apiserver-advertise-address=${node_ip} \
  --image-repository registry.aliyuncs.com/google_containers \
  --control-plane-endpoint=${node_name} \
  --kubernetes-version v1.24.1 \
  --service-cidr=10.1.0.0/16 \
  --pod-network-cidr=10.244.0.0/16 \
  --v=5


# 配置环境变量
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=/etc/kubernetes/admin.conf
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> ~/.bash_profile
source  ~/.bash_profile


# 安装网络插件
# docker pull quay.io/coreos/flannel:v0.14.0
# kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml


docker load -i ./images/flannel.tar
docker load -i ./images/mirrored-flannelcni-flannel-cni-plugin.tar
docker load -i ./images/mirrored-flannelcni-flannel.tar
kubectl apply -f kube-flannel.yml

echo "install complete!"



ip address | grep eth0 | sed "2s/^.*inet //" -n





 ifconfig eth0 | sed -e "2s/^.*inet //" -e "2s/ net.*$//p" -n
 
 ifconfig eth0 | sed -e "2s/^.*inet //" -e "2s/ netmask.*$//p" -n
 
 
 