# BlueField Packer Templates for MAAS

## Introduction

The Packer template in this directory creates BlueField images for use with MAAS.

This template is based on the `ubuntu` cloudimg template, with a customization
script executed to install the bluefield kernel, the related modules, utils,
and the NVIDIA DOCA software stack.

## Prerequisites (to create the image)

* An arm64 machine running Ubuntu 18.04+ with the ability to run KVM virtual machines.
* qemu-utils, libnbd-bin, nbdkit and fuse2fs
* qemu-system
* ovmf
* cloud-image-utils
* parted
* [Packer](https://www.packer.io/intro/getting-started/install.html), v1.7.0 or newer

## Requirements (to deploy the image)

* [MAAS](https://maas.io) 3.7+
* [Curtin](https://launchpad.net/curtin) 21.0+

## Building the image

The Makefile provides the `ubuntu-bluefield-2-9-lts.tar.gz` target to prepare the
environment and build the image using `packer`. This target is executed by
default and it is consequently sufficient to invoke `make` to build the
BlueField image.

```shell
make
```

Despite supporting the same configuration variables as the
`ubuntu-cloudimg.tar.gz` template, BlueField images (as of DOCA 2.9 LTS) must be
built using the `jammy` series as base and `arm64` architecture.
Note that this template has been tested only building images from arm64 hosts.


#### Accessing external files from you script

If you want to put or use some files in the image, you can put those in the `http` directory.

Whatever file you put there, you can access from within your script like this:

```shell
wget http://${PACKER_HTTP_IP}:${PACKER_HTTP_PORT}:/my-file
```

### BlueField kernel

The customization script takes care of installing the optimized bluefield
kernel. If a different kernel is desired, the customization script must be
modified to install it and to specify what kernel must be used in the
`/curtin/CUSTOM_KERNEL` file in the image.

### Customizing the Image

The `scripts/customize-bluefield.sh` script is used by the template to install
all software required by BlueField DPUs. The focus of this script is to install
all NVIDIA software that can enable the DPU functionalities, to create an image
that resembles the one installed by BFB bundles generated with the
(bfb-build)[https://github.com/Mellanox/bfb-build/blob/lts-2.9.x/ubuntu/22.04/Dockerfile] tool.

### Building the image using a proxy

The Packer template downloads the Ubuntu net installer from the Internet. To tell Packer to use a proxy set the HTTP_PROXY environment variable to your proxy server. Alternatively you may redefine iso_url to a local file, set iso_checksum_type to none to disable checksuming, and remove iso_checksum_url.

### Makefile Parameters

#### PACKER_LOG

Enable (1) or Disable (0) verbose packer logs. The default value is set to 0.

#### SUMS

The file name for the checksums file. The default value is set to SHA256SUMS.

#### TIMEOUT

The timeout to apply when building the image. The default value is set to 1h.

## Uploading images to MAAS

TGZ image

```shell
maas admin boot-resources create \
    name='custom/ubuntu-bluefield-2-9-lts' \
    title='Ubuntu for BlueField, DOCA 2.9' \
    architecture='amd64/generic' \
    filetype='tgz' \
    content@=ubuntu-bluefield-2-9-lts.tar.gz
```