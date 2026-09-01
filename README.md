# NVIDIA Status
<img src="screenshot.png" width="500" alt="NVIDIA Status Screenshot">
<img src="screenshot2.png" width="250" alt="NVIDIA Status Screenshot 2">

KDE Plasma 6 widget for monitoring NVIDIA GPU power state (`Suspended / D3cold` vs `Active / D0`), hardware telemetry, and active processes.

## Features
- **GPU Status Monitor**: Real-time monitoring of `Suspended (D3cold)` and `Active (D0)` power states via sysfs.
- **Multi-GPU Support**: Configurable per-instance PCI address binding to independently monitor multiple NVIDIA cards on the same system.
- **GPU Model Detection**: Automatically detects and displays your clean GPU model name (e.g. `RTX 4060`, `RTX 5060 Ti`) with a toggle in settings.
- **Process Tracking**: Lists applications using the dGPU with GPU utilization (%) and VRAM memory consumption.
- **Process Icon Resolution**: Automatically resolves desktop icons for apps, games, tools, and system processes running on the dGPU (Flatpaks, native packages, and direct `.exe` icon extraction for Proton/Wine games).
- **Flexible Display Modes**: Use as a compact panel applet or place directly on your desktop / secondary monitor as a floating widget.
- **GPU Telemetry & VRAM Meter**: Visual progress bar for total dGPU VRAM allocation along with live temperature (°C) and power draw (Watts) telemetry.
- **Process Management**: Directly terminate (`SIGTERM`) or force kill (`SIGKILL`) user applications keeping the dGPU awake (with safe protection for system processes like `kwin_wayland` and a settings toggle to enable/disable).
- **Smart Power Guardian**: Automatically pauses polling when user applications close, allowing the dGPU to enter `D3cold` sleep state even while keeping the process list view open. Filters out background desktop compositor tasks (`kwin_wayland`, `plasmashell`).
- **Configurable Process Sorting**: Sort processes by GPU Usage (SM %), VRAM allocation, or Process Name with ascending/descending toggles.
- **Proton / DXVK Support**: Accurately tracks GPU percentage for Vulkan and Direct3D games.
- **Dynamic Discovery**: Automatically detects `nvidia-smi` across system and user binary paths.
- **Persistent Header**: Optional pinning to keep popups open and shortcut to settings.

## Requirements
- KDE Plasma 6
- NVIDIA Proprietary Driver
- `nvidia-smi` (optional — for process list & telemetry)

## Installation

### From KDE Store (Recommended)
You can install this applet directly through KDE Plasma:
1. Right-click your panel or desktop and select **Add Widgets...**
2. Click **Get New Widgets...** -> **Download New Plasma Widgets**
3. Search for **NVIDIA Status** and click **Install**

Alternatively, view or download it directly from the [KDE Store](https://store.kde.org/p/2354531/).

### From Source
1. Clone the repository:
   ```bash
   git clone https://github.com/UserCel/plasma-applet-nvidia-status.git
   ```
2. Install the widget:
   ```bash
   kpackagetool6 -t Plasma/Applet -i package/
   ```
   *To update an existing installation:*
   ```bash
   kpackagetool6 -t Plasma/Applet -u package/
   systemctl --user restart plasma-plasmashell
   ```

## Configuration
- **PCI Address**: Automatically detected, with support for multi-GPU setups.
- **GPU Model Display**: Toggle display of the GPU model name in header and tooltip.
- **Polling Interval**: Adjustable from settings (default: 3 seconds).
- **Appearance & Toggles**: Customizable colors for different power states, toggleable panel text, process termination toggle, and process icons toggle.
- **Process Sorting**: Click list column headers to sort by Process Name, GPU %, or VRAM.

## License
GPL-3.0-or-later
