#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

GPG_KEY="GPG-KEY-Mellanox.pub"
DPU_ARCH="aarch64"
DOCA_VERSION="3.2.0"
TMP_KEYRING="/tmp/mellanox-keyring.gpg"
MELLANOX_GPG="/etc/apt/keyrings/mellanox.gpg"
KERNEL="6.8.0"
KSUBVER="1012"
KVER_DASH="$KERNEL-$KSUBVER"
KVER_DOT="$KERNEL.$KSUBVER"
KREVISION="16"
BF_KERNEL_VERSION="$KVER_DOT.13"

mkdir -p /etc/apt/keyrings
wget https://linux.mellanox.com/public/repo/doca/$DOCA_VERSION/ubuntu24.04/$DPU_ARCH/$GPG_KEY
gpg --no-default-keyring --keyring $TMP_KEYRING --import ./$GPG_KEY
gpg --no-default-keyring --keyring $TMP_KEYRING --export --output $MELLANOX_GPG
rm $TMP_KEYRING
echo "deb [signed-by=$MELLANOX_GPG] https://linux.mellanox.com/public/repo/doca/$DOCA_VERSION/ubuntu24.04/$DPU_ARCH ./" | tee /etc/apt/sources.list.d/doca.list

apt-get update
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -f \
    linux-bluefield=$BF_KERNEL_VERSION \
    linux-bluefield-headers-$KVER_DASH=$KVER_DASH.$KREVISION \
    linux-bluefield-tools-$KVER_DASH=$KVER_DASH.$KREVISION \
    linux-buildinfo-$KVER_DASH-bluefield=$KVER_DASH.$KREVISION \
    linux-headers-$KVER_DASH-bluefield=$KVER_DASH.$KREVISION \
    linux-headers-bluefield=$BF_KERNEL_VERSION \
    linux-image-$KVER_DASH-bluefield=$KVER_DASH.$KREVISION \
    linux-image-bluefield=$BF_KERNEL_VERSION \
    linux-modules-$KVER_DASH-bluefield=$KVER_DASH.$KREVISION \
    linux-modules-extra-$KVER_DASH-bluefield=$KVER_DASH.$KREVISION \
    linux-tools-$KVER_DASH-bluefield=$KVER_DASH.$KREVISION \
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

rm /etc/apt/sources.list.d/doca.list

sed -i -e "s/FORCE_MODE=.*/FORCE_MODE=yes/" /etc/infiniband/openib.conf


# Remove conflicting and unused configurations from bf-release
sed -i \
    -e 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="text debug console=hvc0 console=ttyAMA0 earlycon=pl011,0x13010000 fixrtc net.ifnames=0 biosdevname=0 iommu.passthrough=1 earlyprintk=efi,keep"/' \
    -e 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=""/' \
    /etc/default/grub
rm /etc/cloud/cloud.cfg.d/91-dib-cloud-init-datasources.cfg
rm /etc/netplan/60-mlnx.yaml

sed -i -E "s/(_unsigned|_prod|_dev)/_packer_maas/;" /etc/mlnx-release

# Use OVS_DOCA to use Bluefield provided tools to apply the suggested OVS and related configuration
# OVS bridges creation will be managed by MAAS and cloud-init
sed -i 's/OVS_DOCA="no"/OVS_DOCA="yes"/' /etc/mellanox/mlnx-ovs.conf
sed -i 's/CREATE_OVS_BRIDGES="yes"/CREATE_OVS_BRIDGES="no"/' /etc/mellanox/mlnx-ovs.conf

systemctl enable NetworkManager.service || true
systemctl enable NetworkManager-wait-online.service || true
systemctl enable acpid.service || true
systemctl enable mlx-openipmi.service || true
systemctl enable mlx_ipmid.service || true
systemctl enable set_emu_param.service || true
systemctl disable openvswitch-ipsec || true
systemctl disable srp_daemon.service || true
systemctl disable ibacm.service || true
systemctl disable opensmd.service || true
systemctl disable unattended-upgrades.service || true
systemctl disable apt-daily-upgrade.timer || true
systemctl disable ModemManager.service || true

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
EOF

mkdir -p /curtin
echo -n "linux-bluefield=$BF_KERNEL_VERSION" > /curtin/CUSTOM_KERNEL