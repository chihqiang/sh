#!/usr/bin/env bash
set -e

# 永久修改主机名
# hostnamectl set-hostname k8s-master

# 禁用swap
# 临时修改，重启后恢复 swapoff -a
# 编辑配置文件/etc/fstab 将swap进行注释

# 安装docker
# apt install -y docker.io
# 修改运行时
# root@k8s-master:~# cat > /etc/docker/daemon.json << EOF
# {
#     "registry-mirrors":[
#         "https://docker.mirrors.ustc.edu.cn",
#         "https://hub-mirror.c.163.com"
#     ],
#     "exec-opts":[
#         "native.cgroupdriver=systemd"
#     ]
# }
# EOF
# systemctl daemon-reload
# systemctl restart docker

# 在线安装必要组建
# curl -sSL https://raw.githubusercontent.com/chihqiang/sh/main/k8s/kubeadm_install.sh | bash

# 启动
# kubeadm init --apiserver-advertise-address=0.0.0.0 --image-repository registry.aliyuncs.com/google_containers --kubernetes-version 1.23.0 --service-cidr=10.1.0.0/16 --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=all
#  curl -sSL "https://raw.githubusercontent.com/chihqiang/sh/main/k8s/kubeadm-init.yaml"  | sed "s/advertiseAddress:.*/advertiseAddress: $(ip addr show eth0 |grep "inet "|awk '{print $2}' | cut -d/ -f1)/" > kubeadm-init.yaml
# kubeadm init --config  kubeadm-init.yaml  

# 安装网络组建
# kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# 检查master节点是否安装成功
# kubectl get node 

# 可执行文件路径
LOCAL_BIN_PATH=/usr/local/bin
ARCH="amd64"

# 安装必要的组建
sudo apt update
sudo apt install -y conntrack ebtables ntpdate socat


# 允许 iptables 检查桥接流量
sudo cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

# 允许 iptables 检查桥接流量
sudo cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

# 时间同步
sudo ntpdate time.windows.com

# 安装CNI插件
CNI_VERSION="v0.8.2"
# cni可执行文件安装目录
CNI_BIN_DIR=/opt/cni/bin
sudo mkdir -p $CNI_BIN_DIR
sudo curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz" | sudo tar -C /opt/cni/bin -xz

#  安装crictl
CRICTL_VERSION="v1.22.0"
sudo curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" | sudo tar -C $LOCAL_BIN_PATH -xz

RELEASE="v1.23.9"
# ELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
cd  $LOCAL_BIN_PATH &&  sudo curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet,kubectl}

sudo chmod +x kubeadm kubectl kubelet

RELEASE_VERSION="v0.4.0"
sudo curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" | sed "s:/usr/bin:${LOCAL_BIN_PATH}:g" | sudo tee /etc/systemd/system/kubelet.service
sudo mkdir -p /etc/systemd/system/kubelet.service.d
sudo curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${LOCAL_BIN_PATH}:g" | sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# 设置kubelet开启自动自动
sudo systemctl enable --now kubelet