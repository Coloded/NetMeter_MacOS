# NetMeter 1.1.5 / build 7 — publication receipt

Date: 2026-11-16. Publication and local restart were explicitly authorized by the user after the local-only audit.

## Published artifacts

- Release: https://github.com/Coloded/NetMeter_MacOS/releases/tag/v1.1.5
- Source tag commit: `20c4ede16aa4be48996ed93461e93c8c3b52c613`.
- Source CI: https://github.com/Coloded/NetMeter_MacOS/actions/runs/43842144938 — all steps passed on macos-15. The verification commit changes only CI configuration and the QA report relative to the release tag; Sources, Resources and updater configuration are identical.
- Publication workflow: https://github.com/Coloded/NetMeter_MacOS/actions/runs/43842525934 — success. Files were sent via SSH to release-assets; Actions uploaded the already signed files without rebuilding them. No private key was exported or uploaded.
- Downloaded the public version-specific DMG, latest appcast and SHA256SUMS after publication: all three match the local signed originals byte for byte.

| File | SHA-256 |
|---|---|
| NetMeter-stable.dmg | 630410b2ef5f17b15eaeae464b41e45593dd174a40605d211eb20d19a572e8de |
| appcast.xml | d42700bc11aaffbe5e4c0ac273dc846e45f7d32a3ba2c7be6ce438b403e657b3 |
| SHA256SUMS.txt | 6243773aff04f8b2952df4c8f7c226ac35c1e4d8b9ce15b10069927eb0242b95 |

## Local application

Installed and restarted the final app. Confirmed version 1.1.5/build 7 and normal network/CPU/memory/GPU/disk sampling. Repeated launch after the atomic-copy correction succeeded. Existing preference backup and prior app bundle were kept locally, outside Git.

Temporary test language, style, GPU line color, geometry and graph visibility were restored to their original values; accumulated traffic and updater state were retained. The native launch-at-login setting and macOS permissions were not changed. Other computers were not updated.

A real manual Sparkle check displayed: “В настоящий момент NetMeter 1.1.5 является новейшей версией.” This verifies the published feed through the running app. It does not certify the complete old-version download/install/relaunch path on another computer.

A minor diagnostic naming issue was observed: Sparkle SUNoUpdateError (1001, as defined by the pinned framework headers) is currently recorded as `cycle_failed`, although the user-facing result correctly says the app is up to date. This is a future diagnostic wording correction, not a failed feed check.

## Interactive scope and remaining limits

Passed by direct UI observation: native graph palette and eyedropper availability; independent GPU line/label colors; 20 GPU cores; 14 CPU core graphs with expansion and compact restoration; macOS style on CPU/memory/network; live disk0 and GiB/swap/pressure labels; single-line network heading; language switching including Arabic RTL; saved language/style after restart; refreshed General network summary.

Automatic Activity Monitor section selection remains unverified because NetMeter lacks Accessibility authorization; the app opened Activity Monitor and recorded the fallback honestly. No new permission was granted. Native coordinate dragging failed with the computer-use provider error `windowNotFoundAtPosition`, so real drag/grouping/Option-detach was not certified. Physical Intel/eGPU, real sleep, monitor reconnection and actual login startup remain separate hardware/session checks.

The first hosted CI run was cancelled before tests because GitHub retired macos-14 runners. It is not represented as a passing run. Reference: https://github.com/actions/runner-images/blob/main/README.md . The successful retry uses macos-15.
