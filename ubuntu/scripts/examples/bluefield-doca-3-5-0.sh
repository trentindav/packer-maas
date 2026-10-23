#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

BASE_URL="https://linux.mellanox.com/public/repo/doca"
DPU_ARCH="arm64-dpu"
DOCA_VERSION="3.5.0"
KERNEL="6.8.0"
KSUBVER="1030"
KVER_DASH="$KERNEL-$KSUBVER"
KREVISION="35"
BF_KERNEL_VERSION="$KERNEL.$KSUBVER.32"
BSP_VERSION="4.16.0-14075"
BOOTIMAGE_DEB="/tmp/mlxbf-bootimages-signed_${BSP_VERSION}_arm64.deb"

echo "deb [trusted=yes] $BASE_URL/$DOCA_VERSION/ubuntu24.04/$DPU_ARCH ./" | tee /etc/apt/sources.list.d/doca.list

wget -O "$BOOTIMAGE_DEB" "${BASE_URL}/${DOCA_VERSION}/ubuntu24.04/${DPU_ARCH}/mlxbf-bootimages-signed_${BSP_VERSION}_arm64.deb"
dpkg -i "$BOOTIMAGE_DEB"
rm -f "$BOOTIMAGE_DEB"

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
    bridge-utils \
    conntrack \
    dmidecode \
    ebtables \
    edac-utils \
    iptables-persistent \
    iputils-arping \
    iputils-ping \
    iputils-tracepath \
    irqbalance \
    jq \
    curl \
    kexec-tools \
    lldpd \
    lm-sensors \
    mstflint \
    net-tools \
    nftables \
    tcpdump \
    vim \
    mlnx-ofed-kernel-modules \
    doca-runtime \
    doca-devel \
    libxlio \
    libxlio-dev \
    libxlio-utils \
    strongswan \
    mlnx-fw-updater-signed \
    bf3-bmc-fw-signed \
    bf3-bmc-gi-signed \
    bf3-cec-fw-signed

# Set versions for OVS conflicts and dependencies to allow installation of
# a dummy openvswitch-switch package without --force-conflicts.
apt download doca-openvswitch-common
apt download doca-openvswitch-switch
dpkg-deb -R doca-openvswitch-common*.deb /tmp/doca-openvswitch-common
dpkg-deb -R doca-openvswitch-switch*.deb /tmp/doca-openvswitch-switch
sed -i 's/^Conflicts: openvswitch-common$/Conflicts: openvswitch-common (<< 2.17~)/' /tmp/doca-openvswitch-common/DEBIAN/control
sed -i 's/^Conflicts: openvswitch-switch$/Conflicts: openvswitch-switch (<< 2.17~)/' /tmp/doca-openvswitch-switch/DEBIAN/control
dpkg-deb -b /tmp/doca-openvswitch-common /tmp/doca-openvswitch-common_workaround_all.deb
dpkg-deb -b /tmp/doca-openvswitch-switch /tmp/doca-openvswitch-switch_workaround_all.deb
dpkg -i /tmp/doca-openvswitch-common_workaround_all.deb
dpkg -i /tmp/doca-openvswitch-switch_workaround_all.deb

apt-mark hold linux-bluefield linux-headers-bluefield linux-image-bluefield \
    linux-tools-bluefield \
    mlnx-ofed-kernel-modules doca-runtime doca-devel mlnx-fw-updater-signed

apt-mark hold linux-image-$KVER_DASH-bluefield linux-modules-$KVER_DASH-bluefield \
    linux-modules-extra-$KVER_DASH-bluefield linux-headers-$KVER_DASH-bluefield

rm /etc/apt/sources.list.d/doca.list
sed -i -E "s/(_unsigned|_prod|_dev)/_packer_maas/;" /etc/mlnx-release
sed -i -e "s/FORCE_MODE=.*/FORCE_MODE=yes/" /etc/infiniband/openib.conf

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

mkdir -p /curtin
echo -n "linux-bluefield=$BF_KERNEL_VERSION" > /curtin/CUSTOM_KERNEL
