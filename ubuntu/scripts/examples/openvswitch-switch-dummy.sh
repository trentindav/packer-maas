#!/bin/bash
set -x
dpkg -i /tmp/openvswitch-switch_9999_all.deb
apt-mark manual openvswitch-switch
dpkg -l | grep openvswitch-switch
apt-mark hold openvswitch-switch