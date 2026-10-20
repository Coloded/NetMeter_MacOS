# Application screenshots

These are real captures supplied during development, with Russian UI labels.
The individual graph files are exact crops, with no regenerated text or values.

| File | Contents |
|---|---|
| `network-ru.png` | Download and upload graph |
| `cpu-ru.png` | Overall processor usage |
| `memory-ru.png` | Used memory and percentage |
| `gpu-ru.png` | GPU device utilization |
| `disk-ru.png` | System disk reads and writes |
| `menu-bar.png` | Live rates in the macOS menu bar |
| `graph-stack-ru.png` | Original five-window stack |

Reproduce the crops from the original image:

```bash
swiftc -module-cache-path .build/module-cache scripts/prepare_screenshots.swift -o .build/prepare_screenshots
.build/prepare_screenshots
```
