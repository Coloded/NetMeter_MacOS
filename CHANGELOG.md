# Changelog

## 1.1.3

- Show the negotiated Ethernet link rate or Wi-Fi TX PHY rate beside the real interface name.
- Refresh connection rates every five seconds in graph headers, interface menus and hover details.
- Explicit unavailable state when macOS does not report a connection rate; no guessed hardware speed.
- Separate network scale maximum from the interface header to keep link details readable.
- Correct binary traffic-rate units to KiB/s, MiB/s and GiB/s.

## 1.1.2

- Compact two-row download/upload display in the menu bar with full speed units.
- Localized hover details: active interface, current rates, session and lifetime traffic totals.
- Native template rendering for light/dark menu bars and an accessible text label.

## 1.1.1

- Native macOS launch-at-login checkbox with actual system status and approval handling.
- Checked all four interface languages and unified grid-control wording.
- Signed release files now travel over SSH to a dedicated publication branch; GitHub Actions publishes Releases without a local API token or exporting the Sparkle private key.

## 1.1.0

- Per-graph line, value-label and heading colors with the native macOS color panel and eyedropper.
- Separate download/upload and read/write color controls; preferences survive restarts.
- Classic and system-adaptive macOS styles applied immediately to every graph, including CPU cores.
- Click a graph to open Activity Monitor; automatic category selection and GPU History require Accessibility permission.
- New controls translated into all four interface languages.

## 1.0.0

- Independent network, memory, CPU, GPU and system-disk graphs.
- Per-core CPU grid, resizable windows and saved layouts.
- Edge snapping, group movement and individual-window detachment.
- Menu-bar download/upload rates and primary-interface discovery.
- English, Russian, Arabic and Simplified Chinese interface catalogs.
- Signed Sparkle updates through GitHub Releases.
- Source layout, application icon and bilingual documentation.
