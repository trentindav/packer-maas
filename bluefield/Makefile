#!/usr/bin/make -f

include ../scripts/check.mk

PACKER ?= packer
PACKER_LOG ?= 0
export PACKER_LOG

SERIES ?= jammy
ARCH ?= arm64
SUMS ?= SHA256SUMS
TIMEOUT ?= 1h
OVMF ?= OVMF

define PACKER_BUILD
	${PACKER} init . && ${PACKER} build \
		-var ubuntu_series=${SERIES} \
		-var architecture=${ARCH} \
		-var host_is_arm=${HOST_IS_ARM} \
		-var ovmf_suffix=${OVMF_SFX} \
		-var timeout=${TIMEOUT} \
		-var customize_script=$(1) \
		-var filename=$(2) \
		.
endef

# Detect if running on ARM host
ifeq ($(shell uname -m),aarch64)
	HOST_IS_ARM = true
	OVMF = AAVMF
else
	HOST_IS_ARM = false
endif

ifeq ($(wildcard /usr/share/$(OVMF)/$(OVMF)_CODE.fd),)
	OVMF_SFX ?= _4M
else
	OVMF_SFX ?=
endif

.PHONY: all clean

all: ubuntu-bluefield-2-9-lts.tar.gz

$(eval $(call check_packages_deps,cloud-image-utils ovmf parted,cloud-image-utils ovmf parted))

lint:
	packer validate .
	packer fmt -check -diff .

format:
	packer fmt .

OVMF_VARS.fd:
ifeq ($(strip $(ARCH)),arm64)
	truncate -s 64m OVMF_VARS.fd
else
	truncate -s 2m OVMF_VARS.fd
endif

OVMF_CODE.fd: /usr/share/${OVMF}/${OVMF}_CODE${OVMF_SFX}.fd
	cp -v $< OVMF_CODE.fd

SIZE_VARS.fd:
ifeq ($(strip $(ARCH)),arm64)
	truncate -s 64m OVMF_VARS.fd
endif

SIZE_CODE.fd:
ifeq ($(strip $(ARCH)),arm64)
	truncate -s 64m OVMF_CODE.fd
endif

ubuntu-bluefield-2-9-lts.tar.gz: check-deps clean OVMF_CODE.fd OVMF_VARS.fd SIZE_CODE.fd SIZE_VARS.fd
	$(call PACKER_BUILD,scripts/customize-bluefield/doca-2-9-lts.sh,ubuntu-bluefield-2-9-lts.tar.gz)

clean:
	${RM} -rf output-* ubuntu-bluefield-*.gz \
		seeds-cloudimg.iso \
		OVMF_VARS.fd \
		OVMF_CODE.fd

CUSTOM_PKGS:=${wildcard packages/*.deb}

packages/custom-packages.tar.gz: ${CUSTOM_PKGS}
ifeq ($(strip $(CUSTOM_PKGS)),)
	tar czf $@ -C packages -T /dev/null
else
	tar czf $@ -C packages ${notdir $^}
endif

.INTERMEDIATE: packages/custom-packages.tar.gz \
	seeds-cloudimg.iso
