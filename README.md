<p align="center">
  <img src="Resources/Branding/icon.png" width="112" alt="NetMeter icon">
</p>

# NetMeter for macOS

[English](README.md) · [Русский](README.ru.md)

A native macOS monitor with separate, always-on-top graphs for network traffic,
memory, CPU, GPU and system disk activity. Arrange the windows around your work,
snap them together, or keep only the graphs you need.

## Features

- **Network:** live download/upload rates in a floating graph and the menu bar.
- **Automatic interface discovery:** finds the current Mac's primary connection;
  follows network changes and supports a manual interface selection.
- **CPU:** overall usage or a responsive grid with a graph for every logical core.
- **Memory:** used memory, total capacity and a usage history.
- **GPU:** enabled only when macOS exposes a readable utilization sensor.
- **System disk:** detects the physical disk backing the startup volume and shows
  its read/write rates.
- **Independent windows:** separate controls, saved sizes and positions, opacity
  and always-on-top behavior.
- **Window groups:** snap any side to another window and move the group together.
- **Four interface languages:** English, Russian, Arabic and Simplified Chinese.
- **Signed updates:** Sparkle 2.9.2, signed appcasts and signed update archives.

## Graphs

Real application screenshots, cropped from the supplied Russian-interface capture.
Each graph has its own context menu; other graphs are managed from the menu bar.

### Network

<img src="docs/screenshots/network-ru.png" width="420" alt="Network graph with download and upload speeds">

Red shows download, green shows upload. The primary physical connection is detected
on the current Mac and follows network changes; a VPN or another interface can be
selected manually. The graph includes traffic passing through that interface.

![Download and upload speeds in the macOS menu bar](docs/screenshots/menu-bar.png)

The same live rates are always available in the menu bar, even with the graph hidden.

### CPU

<img src="docs/screenshots/cpu-ru.png" width="420" alt="CPU utilization history and processor count">

Shows overall processor usage. Right-click → **Show all cores** to display a separate
history for each logical core in one responsive window. Resize it to enlarge the
individual charts; disabling the per-core mode restores the standard window size.

### Memory

<img src="docs/screenshots/memory-ru.png" width="420" alt="Memory graph with used capacity and percentage">

Shows used memory, total physical capacity and the percentage in use. The purple
history makes sustained memory consumption and changes over time easy to see.

### GPU

<img src="docs/screenshots/gpu-ru.png" width="420" alt="GPU utilization history">

Shows device utilization when a readable sensor is available. The GPU graph is not
enabled on Macs that do not expose the required statistics.

### System disk

<img src="docs/screenshots/disk-ru.png" width="420" alt="System disk read and write rates">

Detects the physical disk backing the startup volume. Cyan shows reads and orange
shows writes in bytes per second; other attached drives are not added to this graph.

<details>
<summary>Example: all five windows snapped into a vertical group</summary>
<p><img src="docs/screenshots/graph-stack-ru.png" width="330" alt="Five graph windows in a vertical group"></p>
</details>

## Requirements and installation

- macOS 13 Ventura or later.
- Apple Silicon or Intel. The default build produces a Universal application.

To install a release, download `NetMeter-stable.dmg` from this repository's
[**Releases**](https://github.com/Coloded/NetMeter_MacOS/releases/latest), open it and drag **NetMeter.app** to **Applications**.

The app lives in the menu bar. Use **Graphs** to show or hide each window.
GPU monitoring is unavailable when the system does not provide the required data.

## Using the graphs

Right-click a graph → **Color → Graph / Label** to open the native macOS color panel with its eyedropper. Network and disk have separate controls for both lines and their labels; heading colors are configurable too. Colors are saved between launches.

In **General → Application style**, choose **Classic** (dark charts) or **macOS** (follows system light/dark appearance). The change applies immediately to all graphs, including individual CPU cores.

Click the chart area to open Activity Monitor. Selecting its matching category or GPU History requires granting NetMeter **Accessibility** access in System Settings. Without that permission, Activity Monitor opens in its current view. Drag graph windows by their title bars.

| Action | Control |
|---|---|
| Show or hide a graph | Menu bar → **Graphs** |
| Configure one graph | Right-click that graph |
| Show individual CPU cores | Right-click CPU → **Show all cores** |
| Increase graph size | Drag a window edge or choose **Enlarge this window** |
| Restore the compact CPU window | Turn off **Show all cores** |
| Join windows | Enable **Snap**, then drag a window near another edge |
| Move a group | Drag any attached window |
| Rearrange one member | **Option-drag**, or right-click → **Detach this window** |
| Choose a language | Menu bar → **Language** |

Window layouts, visibility and language preferences are saved. Changing the
language updates the app's menus, window titles, settings and graph labels.
Arabic menus and settings use right-to-left layout.

Automatic network mode selects the primary physical connection where it can be
identified. Traffic includes LAN activity and VPN transport on that connection.
Select the VPN interface manually to inspect traffic inside its tunnel. If no
route is available, the app reports no connection instead of assuming `en0`.

## Build from source

Install Apple Command Line Tools and Python 3.9 or later:

```bash
xcode-select --install
bash build.sh
open NetMeter.app
```

The build discovers the installed SDK, downloads the pinned Sparkle distribution,
verifies its SHA-256, generates the icon and signs the local app ad hoc.
Build products and downloaded dependencies are excluded from Git.

For a single architecture:

```bash
NETMETER_ARCH=arm64 bash build.sh
# or NETMETER_ARCH=x86_64 bash build.sh
```

## Project layout

```text
Sources/NetMeter/
  App/             Application lifecycle
  Monitoring/      Network discovery and system measurements
  Models/          Samples and formatting
  Graphs/          Network, resource and per-core rendering
  Windows/         Floating windows, persistence and snapping
  Menus/           Menu-bar and graph-specific actions
  Settings/        Preferences and About window
  Localization/    Language selection and layout direction
  Updates/         Sparkle integration
Resources/
  Localization/    en, ru, ar and zh-Hans .lproj catalogs
  Branding/        Vector logo and PNG icon
  AppIcon.icns     macOS application icon
scripts/           Build and signed-release tools
Tests/             Routing, localization and update checks
updates/           Public update configuration and release notes
docs/              Update guide and screenshots
```

## Checks and updates

```bash
python3 Tests/test_localization.py
bash build.sh --probe
python3 Tests/test_updates.py --dmg
```

The probe checks interface-selection fixtures, local sensors and graph snapping.
The update test uses temporary local files and confirms that modified appcasts
and archives are rejected. It requires this app's signing key in the local Keychain.

Updates use signed appcasts hosted in [GitHub Releases](https://github.com/Coloded/NetMeter_MacOS/releases).
See [the update guide](docs/updates.md) for configuration,
key storage and release preparation. Nothing is published by the build scripts.

The app currently uses an ad-hoc signature. Developer ID signing and notarization
are separate release configuration steps.

The implementation has been exercised on the development Apple Silicon Mac.
Intel is included in the Universal build; physical testing on another Mac is
still needed before describing it as verified on that hardware.

## Third-party software

[Sparkle](https://sparkle-project.org/) is distributed under its
[included license](Resources/ThirdParty/Sparkle-LICENSE.txt).
