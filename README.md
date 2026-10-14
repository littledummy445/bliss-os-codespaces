# Bliss OS in GitHub Codespaces 🚀

A automated development environment configuration designed to run a fully hardware-accelerated **Bliss OS (Android 11/14)** virtual machine directly inside a cloud-hosted GitHub Codespace using QEMU and noVNC.

[![Open in GitHub Codespaces](https://github.com/codespaces/new)](https://github.com/codespaces/new)

## Features

- **⚡ Hardware Acceleration:** Fully leverages Kernel-based Virtual Machine (`/dev/kvm`) architecture passed down through the underlying Azure cloud layer.
- **🎨 Color-Correct Display:** Pre-configured with specific video device flags (`-vga std`) to eliminate common color-inversion channel glitches (swapped BGR/RGB channels).
- **🌐 Browser-Based Graphical UI:** Combines a background `websockify` network layer with `noVNC` to stream the active emulator interface directly inside a secure forward browser port.
- **💾 Persistent OS Installation:** Binds local workspace drive volumes (`.img`) into the virtualization engine, ensuring system states and partitioned configurations survive container stops.

---

## Quick Start Guide

### 1. Launch the Cloud Workspace
Click the **Open in GitHub Codespaces** badge at the top of this document or initialize a fresh instance manually from the repository management panel.

### 2. Deploy the Installation Pipeline
Execute the main automation shell script inside your open environment terminal window to dynamically install dependencies, format the virtual disk buffers, and pull the latest production system blocks:

```bash
chmod +x run-bliss-novnc.sh
./run-bliss-novnc.sh
```

### 3. Access the Graphical Screen
1. Locate the **Ports** dashboard tray at the bottom edge of your editor interface.
2. Ensure network port **`6080`** (noVNC interface) is forwarded.
3. Open the URL printed by the script to access Bliss OS in your browser.

---

## Advanced Technical Reference

### Operating System Disk Partitioning
When executing the initial setup sequence within the `cfdisk` installation menu utility interface, use these configurations to guarantee a successful deployment:
1. Select the **`dos`** MBR partition label layout profile.
2. Select **`[ New ]`** -> **`[ Primary ]`**, accepting the default maximum space configuration metrics.
3. Highlight **`[ Bootable ]`** to activate the boot sequence flag on the volume partition `/dev/vda1`.
4. Select **`[ Write ]`**, type out `yes` completely, and finalize with **`[ Quit ]`**.
5. Choose **`ext4`** as your file system layout format type, agreeing to install the **GRUB Bootloader** and mounting the `/system` architecture layer as **Read-Write**.

### Underlying QEMU Runtime Configurations
The container initialization script triggers the emulator loop utilizing the following architectural flags:
- `-enable-kvm` Enables near-bare-metal cloud operational processing speeds.
- `-smp 2 -m 2G` Allocates a baseline 2-core CPU model configuration paired with 2GB RAM.
- `-vga std` Fixes BGR byte alignments to stop the display from rendering inverted orange/blue hues.
- `-netdev user,...,hostfwd=tcp::5555-:5555` Exposes the standard Android Debug Bridge (`adb`) socket endpoint mapping parameters.

---

## Custom Maintenance Framework
To execute manual system diagnostics or override configurations without utilizing standard user text interfaces, read or update the workspace profile properties by leveraging raw terminal pipelines:

```bash
# Verify KVM device module privilege layouts inside the active shell
ls -l /dev/kvm

# Manually verify internal binary image byte sizes
stat -c%s bliss-os-14.iso
```
