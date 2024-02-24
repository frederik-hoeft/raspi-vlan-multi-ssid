# Raspberry Pi Multi-SSID Wireless Access Point Configuration + VLAN support

This repository contains a proof of concept for setting up your Raspberry Pi as a multi-SSID wireless access point in Cisco-style VLAN "access mode". 
So traffic from different SSIDs can be separated using VLANs, allowing clients to remain unaware of the whole VLAN shenanigans.

## Purpose

The purpose of this repository is to provide a reference for setting up a multi-SSID WAP with various subnets and access levels. This example includes configurations for trusted IoT devices, trusted mobile devices, untrusted (propriatary) IoT devices, and guest devices. Each type of device is assigned to a specific VLAN for security and management purposes.

## Network Setup

The network setup is based on a hypothetical scenario where there are multiple types of devices that need to connect to the network, each with different access requirements.

- **Trusted IoT devices** have access to internal services and the internet and can be accessed by trusted local subnets. These may be devices that you own or control, such as IoT devices running open-source software with a known security profile, or devices that you trust to have internet access.
- **Trusted mobile devices** have access to internal services and the internet, but shouldn't be accessed from other hosts themselves. These may include your personal computer, phone, or other devices that you trust to have access to the internet and the internal network.
- **External IoT devices** are restricted from accessing the internet and internal services, but can be accessed by trusted local subnets. These may include proprietary "smart home" devices, printers, or devices that you don't trust to have internet access. You probably don't want to allow your WiFi-lightbulbs to call home to _*<insert name of country or company you don't trust>_*.
- **Guest devices** have internet access but no access to internal services. These may include devices from your friends, customers, or other people who visit your home or office and need temporary access to the internet.

The network interfaces are configured using the [`interfaces.conf`](/etc/network/interfaces.conf) file in the `etc/network/` directory. This file uses the [`interfaces-conf.py`](/etc/network/interfaces-conf.py) pre-processor script for basic variable substitution and easier configuration management.

The network setup includes both ethernet and wireless interfaces. The ethernet interfaces are configured as a main trunk interface (to communicate with upstream components) and VLAN interfaces for each type of device. The wireless interfaces are configured with virtual interfaces per subnet, with automatic VLAN tagging and translation handled by the [`vlan-access-mode-up.sh`](/etc/network/tc/vlan-access-mode-up.sh) script, with [`vlan-access-mode-down.sh`](/etc/network/tc/vlan-access-mode-down.sh) scripts reverting the interface back to its default configuration. These scripts are located in the `etc/network/tc/` directory.

The [`wlx-create-virtual.sh`](/etc/network/wlx-create-virtual.sh) script in `etc/network/` is used to create the virtual wireless interfaces.

Files
- [`README.md`](/README.md): This file.
- [`etc/hostapd/hostapd.conf`](/etc/hostapd/hostapd.conf): Configuration file for the hostapd package.
- [`etc/network/interfaces.conf`](/etc/network/interfaces.conf): Main network interfaces configuration file.
- [`etc/network/interfaces-conf.py`](/etc/network/interfaces-conf.py): Pre-processor script for the interfaces.conf file.
- [`etc/network/interfaces`](/etc/network/interfaces): The generated network interfaces configuration file.
- [`etc/network/tc/vlan-access-mode-down.sh`](/etc/network/tc/vlan-access-mode-down.sh): Script to disable VLAN tagging and translation for down events.
- [`etc/network/tc/vlan-access-mode-up.sh`](/etc/network/tc/vlan-access-mode-up.sh): Script to enable VLAN tagging and translation for up events.
- [`etc/network/wlx-create-virtual.sh`](/etc/network/wlx-create-virtual.sh): Script to create virtual wireless interfaces.

Please refer to the individual files for more detailed information about their purpose and usage.
