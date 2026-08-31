# omarchy-sysmon

A bar widget plugin for [Omarchy](https://omarchy.org/) showing live CPU
usage in the bar, with a popup panel for CPU/GPU/RAM/storage usage and
temperature.

![bar pill](https://img.shields.io/badge/omarchy-plugin-blue)

## Features

- Bar pill: current CPU usage %, turns red when any sensor runs hot
- Popup panel:
  - **CPU** — usage, model name, temperature
  - **GPU** — usage, temperature, VRAM (NVIDIA only, via `nvidia-smi`)
  - **Memory** — RAM and swap usage
  - **Storage** — per-disk usage and temperature (via UDisks2/`busctl`, no
    root or `smartmontools` required)

All sampling comes from `/proc`, `lsblk`, `sensors -j`, and unprivileged
UDisks2 D-Bus calls. The collector script is bundled with this plugin
(`bin/omarchy-sysmon-stats`) — nothing to install separately.

## Requirements

- `python3` (stdlib only, no extra packages)
- `lm_sensors` for CPU temperature (optional — falls back to `—` if absent)
- `nvidia-smi` for the GPU section (optional — GPU section is hidden without it)
- `util-linux` (`lsblk`) and `systemd` (`busctl`) — present by default on Omarchy

## Install

```bash
omarchy plugin add https://github.com/santiagoalmeida/omarchy-sysmon.git --enable --yes
```

Or interactively:

```bash
omarchy plugin add https://github.com/santiagoalmeida/omarchy-sysmon.git
```

This clones the plugin into `~/.config/omarchy/plugins/santyalmeida.sysmon/`.
Review the code, then enable it:

```bash
omarchy plugin enable santyalmeida.sysmon
```

Move it around the bar like any other widget:

```bash
omarchy bar move santyalmeida.sysmon --section right
```

## Update / remove

```bash
omarchy plugin update santyalmeida.sysmon
omarchy plugin remove santyalmeida.sysmon
```

## License

MIT
