#!/bin/bash
set -x
export DEBIAN_FRONTEND=noninteractive

GPG_KEY="GPG-KEY-Mellanox.pub"
DPU_ARCH="aarch64"
DOCA_29_VERSION="2.9.3"
DOCA_30_VERSION="3.0.0"
TMP_KEYRING="/tmp/mellanox-keyring.gpg"
MELLANOX_GPG="/etc/apt/keyrings/mellanox.gpg"
BF_KERNEL_VERSION="5.15.0.1065.67"


export  BFVER=25.04.OFED.25.04.0.6.1.1-1.bf.kver.5.15.0-1065-bluefield
export MFTVER=4.32.0-120.kver.5.15.0-1065-bluefield
export    VER=25.04.OFED.25.04.0.6.1.1-1.kver.5.15.0-1065-bluefield
export UBKVER=5.15.0-1065

mkdir -p /etc/apt/keyrings
wget https://linux.mellanox.com/public/repo/doca/$DOCA_30_VERSION/ubuntu22.04/$DPU_ARCH/$GPG_KEY
gpg --no-default-keyring --keyring $TMP_KEYRING --import ./$GPG_KEY
gpg --no-default-keyring --keyring $TMP_KEYRING --export --output $MELLANOX_GPG
rm $TMP_KEYRING
echo "deb [signed-by=$MELLANOX_GPG] https://linux.mellanox.com/public/repo/doca/$DOCA_30_VERSION/ubuntu22.04/$DPU_ARCH ./" | tee /etc/apt/sources.list.d/doca.list

apt-get update
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -f \
    linux-bluefield=$BF_KERNEL_VERSION \
    linux-bluefield-headers-$UBKVER \
    linux-bluefield-tools-$UBKVER \
    linux-buildinfo-$UBKVER-bluefield \
    linux-headers-$UBKVER-bluefield \
    linux-image-$UBKVER-bluefield \
    linux-modules-$UBKVER-bluefield \
    linux-modules-extra-$UBKVER-bluefield \
    linux-tools-$UBKVER-bluefield \
    mlnx-ofed-kernel-modules=$BFVER \
    mlnx-ofed-kernel-utils=$BFVER \
    kernel-mft-modules=$MFTVER \
    fwctl-modules=$VER \
    iser-modules=$VER \
    isert-modules=$VER \
    mlnx-nfsrdma-modules=$VER \
    mlnx-nvme-modules=$VER \
    srp-modules=$VER

rm /etc/apt/sources.list.d/doca.list
wget https://linux.mellanox.com/public/repo/doca/$DOCA_29_VERSION/ubuntu22.04/$DPU_ARCH/$GPG_KEY
gpg --no-default-keyring --keyring $TMP_KEYRING --import ./$GPG_KEY
gpg --no-default-keyring --keyring $TMP_KEYRING --export --output $MELLANOX_GPG
rm $TMP_KEYRING
echo "deb [signed-by=$MELLANOX_GPG] https://linux.mellanox.com/public/repo/doca/$DOCA_29_VERSION/ubuntu22.04/$DPU_ARCH ./" | tee /etc/apt/sources.list.d/doca.list

apt-get update
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -f \
    doca-runtime-user \
    mlnx-fw-updater-signed

apt-mark hold linux-tools-bluefield linux-image-bluefield linux-bluefield \
        linux-headers-bluefield linux-image-bluefield \
        linux-tools-common mlnx-ofed-kernel-modules doca-runtime-user

sed -i -e "s/FORCE_MODE=.*/FORCE_MODE=yes/" /etc/infiniband/openib.conf

# Remove conflicting and unused configurations from bf-release
sed -i \
    -e 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="text debug console=hvc0 console=ttyAMA0 earlycon=pl011,0x13010000 fixrtc net.ifnames=0 biosdevname=0 iommu.passthrough=1 earlyprintk=efi,keep"/' \
    -e 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=""/' \
    /etc/default/grub
rm /etc/cloud/cloud.cfg.d/91-dib-cloud-init-datasources.cfg
rm /etc/netplan/60-mlnx.yaml

sed -i -E "s/(_unsigned|_prod|_dev)/_packer_maas/;" /etc/mlnx-release

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

# OpenVSwitch related configuration
echo vm.nr_hugepages = 1024 >> /etc/sysctl.conf
ovs-vsctl --no-wait set Open_vSwitch . other_config:doca-init=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:hw-offload=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:default-datapath-type=netdev

# Static configuration for tmfifo_net0 and OVS bridges (not configurable by MAAS)
cat > /etc/netplan/60-tmfifo-ovsbr.yaml <<EOF
network:
    version: 2
    ethernets:
        tmfifo_net0:
            addresses:
            - 192.168.100.2/30
            mtu: 1500
        pf0hpf:
            renderer: networkd
            dhcp4: false
            mtu: 9000
        pf1hpf:
            renderer: networkd
            dhcp4: false
            mtu: 9000
    bridges:
        ovsbr1:
            mtu: 9000
            interfaces:
            - eth1
            - pf0hpf
            parameters:
                forward-delay: "15"
                stp: false
            openvswitch: {}
        ovsbr2:
            mtu: 9000
            interfaces:
            - eth2
            - pf1hpf
            parameters:
                forward-delay: "15"
                stp: false
            openvswitch: {}
EOF

mkdir -p /curtin
echo -n "linux-bluefield=$BF_KERNEL_VERSION" > /curtin/CUSTOM_KERNEL
