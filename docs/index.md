# Bliss OS Codespaces Guide

This site explains how to run Bliss OS in a GitHub Codespace using this repository.

## What this repository provides

- A launcher script (`run-bliss-novnc.sh`) that prepares dependencies automatically
- QEMU-based Bliss OS virtualization
- noVNC browser access to the running VM
- Persistent VM state in the workspace via `.bliss-state`

## Quick start

1. Open this repository in GitHub Codespaces.
2. In the terminal, run:

   ```bash
   chmod +x run-bliss-novnc.sh
   ./run-bliss-novnc.sh
   ```

3. Open the printed noVNC URL, or open forwarded port `6080`.

## First boot installation checklist

When the installer opens:

1. Create a partition table (`dos`)
2. Create one primary partition
3. Mark it bootable
4. Write changes and quit partitioning
5. Format as `ext4`
6. Install GRUB when prompted

Later boots reuse the same virtual disk.

## Useful configuration options

The launcher accepts options such as:

- `--memory` (default `4G`)
- `--cpus` (default `2`)
- `--disk-size` (default `32G`)
- `--novnc-port` (default `6080`)
- `--no-browser`

Run help for the full list:

```bash
./run-bliss-novnc.sh --help
```

## Notes

- If dependencies are missing, the script installs them with `apt` automatically.
- In Codespaces, the script prints a public forwarded noVNC URL.
