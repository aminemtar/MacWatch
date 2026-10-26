# MacWatch 0.1
Native SwiftUI monitoring utility for macOS 13+, Intel and Apple Silicon.

## Run on your Mac
1. Install Apple Command Line Tools if needed: `xcode-select --install`.
2. Open Terminal inside the extracted MacWatch folder.
3. Run `bash build.command`.

The script runs unit tests, compiles for your current Mac, builds and ad-hoc signs dist/MacWatch.app, then opens it. Move that app to Applications if you want. No external packages or administrator privileges required. This is source code, not a precompiled or notarized installer.

## Included
- Process list with CPU estimate and resident memory, searchable by name or PID; refreshed about every five seconds.
- macOS thermal state: Normal, Warm, Hot, Critical.
- In-app sustained CPU alerts after six qualifying samples: >=80% normally, >=25% when input has been idle for at least 60 seconds. One alert per continuous episode, maximum 500 retained. No notifications outside the app yet.
- Read-only TCP/UDP socket snapshot, refreshed manually.
- Third-party launch agent/daemon file inventory; modern login items require System Settings inspection.
- Sampled foreground application time excluding idle and long sleep gaps; battery charge/source via pmset.
- Menu bar status and local JSON history, saved about every 30 seconds and on menu-bar Quit. Delete history in Usage & battery.

## Honest limitations
CPU/GPU temperature in degrees and fan RPM are NOT implemented. Apple's public thermalState reports heat pressure, not degrees. Hardware-specific SMC/HID sensor integration needs validation on the actual Mac before use. This version must not be described as a working temperature sensor monitor.

CPU is the ps estimate rather than an instantaneous sample; 100% means one core. Summed RSS includes shared pages and is not system memory pressure. No disk throughput, network bandwidth, GPU utilization, battery health, process start history or malware scanning in this version. Network and startup inventories are incomplete without additional privileges and APIs. An open socket is not proof of traffic or malicious behavior.

Activity time is approximate and cumulative, not a daily report. App names, process paths, alert messages and usage durations remain local in ~/Library/Application Support/MacWatch. Nothing is uploaded. No screenshots, content capture, keys, automatic termination, fan control, root helper or auto-start installation. Monitoring stops when the app quits.

## Validation
This project was authored on Linux, without Swift or a macOS SDK; native build, XCTest and GUI behavior have NOT been executed here. `bash build.command` runs the included meaningful parser and sustained-alert tests on your Mac before building. If a native build fails, send the compiler output.

Manual checks: verify process names and CPU estimates against Activity Monitor; confirm foreground app minutes advance while active and stop after idle; refresh Connections during network use; confirm launch agents against Finder; relaunch to check retained history; use Delete history and relaunch to confirm deletion. Thermal state should be compared with the OS, not inferred from CPU use.

API references:
- https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.property
- https://developer.apple.com/documentation/coregraphics/cgeventsource
