#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

GPG_KEY="GPG-KEY-Mellanox.pub"
DPU_ARCH="aarch64"
DOCA_VERSION="latest-2.9-LTS"
TMP_KEYRING="/tmp/mellanox-keyring.gpg"
MELLANOX_GPG="/etc/apt/keyrings/mellanox.gpg"
BF_KERNEL_VERSION="5.15.0.1060.62"
BF_KERNEL_VERSION_DASH="5.15.0-1060.62"
mkdir -p /etc/apt/keyrings
wget https://linux.mellanox.com/public/repo/doca/$DOCA_VERSION/ubuntu22.04/$DPU_ARCH/$GPG_KEY
gpg --no-default-keyring --keyring $TMP_KEYRING --import ./$GPG_KEY
gpg --no-default-keyring --keyring $TMP_KEYRING --export --output $MELLANOX_GPG
rm $TMP_KEYRING
echo "deb [signed-by=$MELLANOX_GPG] https://linux.mellanox.com/public/repo/doca/$DOCA_VERSION/ubuntu22.04/$DPU_ARCH ./" | tee /etc/apt/sources.list.d/doca.list


apt-get update
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -f \
    linux-bluefield=$BF_KERNEL_VERSION \
    linux-bluefield-cloud-tools-common=$BF_KERNEL_VERSION_DASH \
    linux-bluefield-headers-5.15.0-1060=$BF_KERNEL_VERSION_DASH \
    linux-bluefield-tools-5.15.0-1060=$BF_KERNEL_VERSION_DASH \
    linux-buildinfo-5.15.0-1060-bluefield=$BF_KERNEL_VERSION_DASH \
    linux-headers-5.15.0-1060-bluefield=$BF_KERNEL_VERSION_DASH \
    linux-headers-bluefield=$BF_KERNEL_VERSION \
    linux-image-5.15.0-1060-bluefield=$BF_KERNEL_VERSION_DASH \
    linux-image-bluefield=$BF_KERNEL_VERSION \
    linux-modules-5.15.0-1060-bluefield=$BF_KERNEL_VERSION_DASH \
    linux-modules-extra-5.15.0-1060-bluefield=$BF_KERNEL_VERSION_DASH \
    linux-tools-5.15.0-1060-bluefield=$BF_KERNEL_VERSION_DASH \
    linux-tools-bluefield=$BF_KERNEL_VERSION \
    linux-libc-dev:arm64 \
    linux-tools-common \
    mlnx-ofed-kernel-modules \
    doca-runtime \
    doca-devel \
    mlnx-fw-updater-signed

apt-mark hold linux-tools-bluefield linux-image-bluefield linux-bluefield \
        linux-headers-bluefield linux-image-bluefield linux-libc-dev \
        linux-tools-common mlnx-ofed-kernel-modules doca-runtime doca-devel

sed -i -e "s/FORCE_MODE=.*/FORCE_MODE=yes/" /etc/infiniband/openib.conf

sed -i \
    -e 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="text debug console=hvc0 console=ttyAMA0 earlycon=pl011,0x13010000 fixrtc net.ifnames=0 biosdevname=0 iommu.passthrough=1 earlyprintk=efi,keep"/' \
    -e 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=""/' \
    /etc/default/grub

rm /etc/cloud/cloud.cfg.d/91-dib-cloud-init-datasources.cfg
rm /etc/netplan/60-mlnx.yaml

systemctl enable NetworkManager.service || true
systemctl enable NetworkManager-wait-online.service || true
systemctl enable acpid.service || true
systemctl enable mlx-openipmi.service || true
systemctl enable mlx_ipmid.service || true
systemctl enable set_emu_param.service || true
systemctl enable mst || true
systemctl disable openvswitch-ipsec || true
systemctl disable srp_daemon.service || true
systemctl disable ibacm.service || true
systemctl disable opensmd.service || true
systemctl disable unattended-upgrades.service || true
systemctl disable apt-daily-upgrade.timer || true
systemctl disable containerd.service || true
systemctl disable ModemManager.service || true

sed -i -E "s/(_unsigned|_prod|_dev)/_packer_maas/;" /etc/mlnx-release

# iptables rules from bf-relealse cloud-init user-data
mkdir -p /etc/iptables
cp /tmp/iptables-rules-v4 /etc/iptables/rules.v4
chmod 644 /etc/iptables/rules.v4

# OpenVSwitch related configuration
echo vm.nr_hugepages = 1024 >> /etc/sysctl.conf
ovs-vsctl --no-wait set Open_vSwitch . other_config:doca-init=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:hw-offload=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:default-datapath-type=netdev

mkdir -p /curtin
echo -n "linux-bluefield=$BF_KERNEL_VERSION" > /curtin/CUSTOM_KERNEL
