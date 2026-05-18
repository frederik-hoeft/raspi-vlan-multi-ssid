# Raspberry Pi Multi-SSID Wireless Access Point with VLAN Isolation

Turn a Raspberry Pi into a multi-SSID wireless access point that separates client traffic into VLANs using a single physical wireless interface (e.g., a USB Wi-Fi adapter supporting AP mode and multiple virtual interfaces). Each SSID is mapped to its own VLAN in Cisco-style **access mode** where clients remain completely unaware of the underlying VLAN infrastructure and tagging / untagging is handled transparently by the WAP itself.

## Overview

This repository provides a complete, production-oriented reference configuration for running multiple SSIDs with Debian on a Raspberry Pi 3B+ with per-SSID VLAN segmentation, although the same principles can be applied to any Linux-based system with a compatible wireless adapter. This proof-of-concept uses:

- **hostapd** with multiple virtual AP (VAP) interfaces on a single physical radio, in this case a Ralink RT5572-based USB adapter (`radio0`)
- A **VLAN-aware Linux bridge** (`br_trunk`) that aggregates the wired trunk and all wireless interfaces
- **ifupdown2** `bridge-access` port semantics for zero-config VLAN classification
- **systemd** units to orchestrate interface creation and service startup

Traffic from each SSID is tagged into its own VLAN before reaching the upstream trunk port, enabling full layer-2 isolation with no client-side configuration.

## Network Architecture

This example use case defines four SSIDs, each mapped to a unique VLAN for different device classes (trusted IoT, trusted mobile, untrusted IoT, guest). The Raspberry Pi connects to an upstream VLAN aware switch via the onboard Ethernet port configured as an 802.1Q trunk carrying all VLANs plus a native management VLAN.

```
 Upstream switch (802.1Q trunk)
        │
   ┌────┴────┐
   │  trunk0 │  ← tagged VLANs 100/200/300/400 + native VLAN 1 (management)
   └────┬────┘
        │
 ┌──────┴──────────────────────────────────────────┐
 │               br_trunk (VLAN-aware)             │
 │  PVID 1 · VIDs 1, 100, 200, 300, 400            │
 ├────────┬────────┬────────┬────────┬─────────────┤
 │ trunk0 │ radio0 │ radio1 │ radio2 │ radio3      │
 │  trunk │ access │ access │ access │ access      │
 │        │ VID100 │ VID200 │ VID300 │ VID400      │
 └────────┴────────┴────────┴────────┴─────────────┘
```

### VLAN / SSID Mapping

| Interface | VLAN | SSID | Purpose |
|-----------|------|------|---------|
| `radio0` | 100 | `ap.iot.home.arpa` | Trusted IoT: internet and access to internal services |
| `radio1` | 200 | `ap.mobile.home.arpa` | Trusted mobile: full access, no inbound |
| `radio2` | 300 | `ap.external.home.arpa` | Untrusted IoT: accessible from trusted subnets, no internet |
| `radio3` | 400 | `ap.guest.home.arpa` | Guest: internet only |

### Device Classification

- **Trusted IoT** (VLAN 100): Devices you own/control (e.g. open-source firmware, known security profile). Allowed internet and internal service access; reachable from other trusted subnets.
- **Trusted Mobile** (VLAN 200): Personal computers, phones, tablets. Full network access but not reachable by other hosts.
- **External IoT** (VLAN 300): Proprietary smart-home devices, printers, appliances you don't fully trust. No internet, no internal services, reachable only from trusted subnets.
- **Guest** (VLAN 400): Visitors' devices. Internet access only; fully isolated from all internal resources.

Where the WAP in this setup provides layer-2 isolation and VLAN tagging, and the exact access semantics are enforced by upstream firewall rules on the router or switch.

## Prerequisites

- Raspberry Pi (or any Linux SBC) with a wireless adapter supporting AP mode and multiple virtual interfaces (`iw list` → "valid interface combinations")
- Debian/Raspbian with:
  - `hostapd`
  - `ifupdown2` (VLAN-aware bridge support)
  - `iw`
  - `systemd`
- An upstream switch or router configured with an 802.1Q trunk port

## Repository Structure

```
etc/
├── hostapd/
│   ├── radio0.conf          # hostapd config: IoT SSID
│   ├── radio1.conf          # hostapd config: Mobile SSID
│   ├── radio2.conf          # hostapd config: External IoT SSID
│   └── radio3.conf          # hostapd config: Guest SSID
├── network/
│   ├── interfaces.conf      # Network config template (with variable substitution)
│   ├── interfaces           # Generated output (do not edit directly)
│   ├── interfaces-conf.py   # Template preprocessor (Python)
│   └── interfaces-conf.cs   # Template preprocessor (C# / .NET)
└── systemd/
    ├── network/
    │   ├── 10-radio.link    # udev/systemd-networkd: rename Wi-Fi adapter → radio0
    │   └── 10-trunk.link    # udev/systemd-networkd: rename Ethernet adapter → trunk0
    └── system/
        ├── hostapd.service              # Multi-instance hostapd unit
        ├── wap-radio-vifs.service       # Creates virtual AP interfaces before networking
        └── networking.service.d/
            └── 10-wap-radio-vifs.conf   # Drop-in: networking.service depends on wap-radio-vifs

usr/
└── local/
    └── sbin/
        └── wap-radio-vifs   # Shell script to create/configure virtual AP interfaces
```

## How It Works

### 1. Interface Naming (`systemd-networkd` `.link` files)

The physical Wi-Fi and Ethernet adapters are matched by permanent MAC address and renamed to stable, predictable names (`radio0`, `trunk0`) via [etc/systemd/network/10-radio.link](etc/systemd/network/10-radio.link) and [etc/systemd/network/10-trunk.link](etc/systemd/network/10-trunk.link).

### 2. Virtual Interface Creation (`wap-radio-vifs`)

The [usr/local/sbin/wap-radio-vifs](usr/local/sbin/wap-radio-vifs) script runs early in the boot sequence (before `networking.service`) and uses `iw` to create the virtual AP interfaces (`radio1`–`radio3`) on the same physical radio as `radio0`. Each interface receives a unique MAC address within the same BSSID block.

### 3. VLAN-Aware Bridge (`ifupdown2`)

The [etc/network/interfaces.conf](etc/network/interfaces.conf) template defines:

- `trunk0` as a trunk port carrying all VLANs
- `radio[0..3]` as **access ports**, each assigned a single VLAN via `bridge-access`
- `br_trunk` as a VLAN-aware bridge aggregating all ports, with DHCP on the native/management VLAN (PVID 1)

The template uses `$define` variables for DRY configuration. Generate the final `interfaces` file with the included preprocessor:

```sh
# Python
python3 etc/network/interfaces-conf.py etc/network/interfaces.conf etc/network/interfaces

# C# (.NET 10+)
dotnet run etc/network/interfaces-conf.cs etc/network/interfaces.conf etc/network/interfaces
```

### 4. hostapd (Multi-SSID)

A single `hostapd` process manages all four BSSes, launched with one config file per interface. See [etc/hostapd/](etc/hostapd/) for per-radio configurations.

### 5. Service Orchestration

The systemd units ensure correct startup ordering:

```
wap-radio-vifs.service  →  networking.service  →  hostapd.service
```

## Installation

1. **Copy files** (or symlink) to their corresponding system paths:

   ```sh
   sudo cp usr/local/sbin/wap-radio-vifs /usr/local/sbin/
   sudo chmod +x /usr/local/sbin/wap-radio-vifs
   sudo cp etc/systemd/network/*.link /etc/systemd/network/
   sudo cp etc/systemd/system/hostapd.service /etc/systemd/system/
   sudo cp etc/systemd/system/wap-radio-vifs.service /etc/systemd/system/
   sudo mkdir -p /etc/systemd/system/networking.service.d
   sudo cp etc/systemd/system/networking.service.d/10-wap-radio-vifs.conf \
        /etc/systemd/system/networking.service.d/
   sudo cp etc/hostapd/radio*.conf /etc/hostapd/
   ```

2. **Edit MAC addresses** in `10-radio.link` and `wap-radio-vifs` to match your hardware.

3. **Edit hostapd configs** set your SSIDs, passphrases, country code, channels, and capabilities as needed.

4. **Generate the interfaces file** and copy it into place:

   ```sh
   python3 etc/network/interfaces-conf.py etc/network/interfaces.conf /etc/network/interfaces
   ```

5. **Enable and start services:**

   ```sh
   sudo systemctl daemon-reload
   sudo systemctl enable wap-radio-vifs.service hostapd.service
   sudo systemctl restart networking.service
   ```

## Customization

- **Add/remove SSIDs**: Create or remove `radioN.conf` files, adjust the `wap-radio-vifs` script, and update `interfaces.conf` accordingly.
- **Change VLAN IDs**: Edit the `$define` variables at the top of `interfaces.conf` and regenerate.
- **5 GHz / dual-band**: Change `hw_mode`, `channel`, and `ht_capab`/`vht_capab` in the hostapd configs. If using a second physical radio, add another `.link` file and extend `wap-radio-vifs`.
- **Static IP / no DHCP**: Replace the `inet dhcp` line on `br_trunk` with `inet static` and add address/gateway/dns directives.

## Security Considerations

- VLAN isolation is enforced at the bridge level. Upstream firewall rules are still required to control inter-VLAN routing.
- `ap_isolate=1` is enabled in all hostapd configs to prevent intra-SSID client-to-client traffic.
- Replace all `YOUR_SECRET_PASSWORD` placeholders with strong, unique passphrases before deployment.
- Consider upgrading to WPA3-SAE (`wpa_key_mgmt=SAE`) where client support permits.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
