# Reliability QA report

Environment: macOS 27.0.1, arm64. Local checkout; no publication, installation, app restart, real preference changes, login-item changes or private signing-key access. Tests use temporary files and isolated UserDefaults suites.

## Results and reproduction history

| Requirement | Command / evidence | Result |
|---|---|---|
| P0-NET-01 model | `bash Tests/run_core_regressions.sh` | PASS, 82 assertions combined with settings: 4 GiB crossing, near UInt64 maximum, independent direction resets/availability, missing/idle, interface switch, negative/zero dt and next interval, NaN, long gaps |
| P0-NET-01 live counters | `python3 Tests/test_network_counters.py --interface en0` | PASS: read-only netstat bracketing, RX 607760797077 and TX 1639032082990 bytes; both exceed 2^32. This validates current host counters, not sustained traffic generation |
| P0-SET-01 | core command above | PASS isolated-suite migration, global/property/graph independence, network legacy fallback freeze, reopen persistence and unrelated settings preservation |
| P1-MET-01 subprocess | `bash Tests/run_command_regressions.sh` | PASS, 10 assertions: continuous-output cap/deadline, stdout, exit failure, missing executable, output larger than pipe capacity, deadline, inherited stdout and descendant cleanup |
| P1-LOG-01 model | `python3 Tests/run_diagnostic_regressions.py` | PASS, 17 assertions including bare-token/IP redaction and rejected arbitrary sensor/category. No save panel or production export invoked |
| P1-BLD-01 bundle copying | `python3 Tests/test_copy_bundle.py` | PASS, 7 fixtures: stale files/directories, symlink type replacement and external-target isolation, executable permissions, AppleDouble |
| P1-BLD-01 build locking | `python3 Tests/test_build_lock.py` | PASS, 3 fixtures: overlap rejected, failed command status preserved and lock reusable, killed runner keeps live child locked |
| P2-UI-01 localization | `python3 Tests/test_localization.py` | PASS, 123 keys across en/ru/ar/zh-Hans, duplicate/missing keys, format placeholders and grid wording. Linguistic quality/RTL visuals not certified |

Reproduced failures retained for audit:

1. P0-NET: NET_RT_IFLIST2 implementation returned 2163106816 RX while independent netstat reported ~607753495118 bytes. Replaced with IFMIB_IFDATA/IFDATA_GENERAL; live retest PASS above.
2. P0-NET: nonpositive dt replaced baseline and lost valid next-interval bytes. Fixed by retaining valid baseline; regression retest PASS.
3. P1-MET: descendant retaining stdout outlived exited parent and leaked blocking read. Replaced runner with process-group deadline cleanup/nonblocking reads; retest PASS.
4. P1-BLD: old bundle copier baseline PASS 1, FAIL 4, ERROR 2 on stale/type/symlink fixtures. After parent fixes all 7 PASS.

## Additional final verification

- `bash Tests/run_collector_regressions.sh`: PASS 14 assertions against the actual MetricsCollector and simulated discovery/sensors. Providers run off main, completion on main, overlapping calls coalesce, auto interface resolves, absent GPU later recovers, wake marks a gap and rebases without adding bytes. This is not physical GPU removal/reconnection or actual sleep.
- `bash Tests/run_layout_regressions.sh`: PASS 60 assertions against actual GraphTextLayout fittedFont, four writing scripts, 6/12/48 pt, width and height fitting, disabled fitting and documented 6 pt truncation policy. Draw-only dependencies stubbed; no visual certification.
- `python3 Tests/test_updates.py`: PASS 8 checks using actual pinned Sparkle sign_update and disposable random 32-byte seed file. Valid signed feed/archive accepted; modified feed, same-size archive corruption, wrong version/build/immutable URL, wrong length and missing signing source rejected. Archive payload deliberately simulated bytes; this does not certify DMG installation. No Keychain access.
- Fresh `.build/staging/NetMeter.app`: `codesign --verify --deep --strict` PASS; lipo arm64+x86_64; vtool minimum macOS 13.0 in both slices; embedded Sparkle 2.10.1; exact four localization catalogs. Executable timestamp newer than all source files and nm contains new MetricsCollector, NetworkRateTracker, fittedFont and DiagnosticCenter symbols. No application launch/install.
- Final live netstat bracket retest PASS: RX 607816888756 ≤ 607816893296 ≤ 607816893296; TX 1639090218725 ≤ 1639090219397 ≤ 1639090219611. Initial sandbox denied netstat sysctl; authorized read-only unsandboxed run supplied the evidence. Generic CI must not assume en0 or hardware/sysctl availability.
- `python3 Tests/test_memory_live.py`: PASS 4 read-only live assertions using unchanged extracted production memory()/memoryDetails(): finite 0–100%, GiB, separate swap availability and kernel pressure independently read as normal. No inferred pressure from RAM utilization.
- `git diff --check -- Tests docs/qa/TEST_REPORT.md`: PASS.

## Pending / limits

Fresh Universal build/signature checks and model seams pass as above. Palette live synchronization, Activity Monitor AX selection, grouping/detach/screen geometry, actual provider failure/recovery, and real graphical rendering remain BLOCKED for live acceptance because no working app restart or production settings/permissions changes were authorized in QA. UI-refresh no-tick/totals mutation was inspected statically by spec controller; collector byte deltas are tested, full UI totals flow is not claimed live. Read-only swap/pressure probe passed above. Static or model checks will not be represented as live GUI/hardware E2E. Physical Intel/eGPU, actual login-start, actual sleep/wake, real Sparkle installation and user-authorized AX denial flows require separate acceptance.

## Final rebuilt artifact acceptance

Final build SHA-256: `24c111583a1b0388be5ecaf49fd1f02814db6db66ce206da5d1520bbaa3ab59c` for `.build/staging/NetMeter.app/Contents/MacOS/NetMeter` (2026-11-16 12:01:46 local). Independent final retest PASS: exact hash, executable newer than every Swift source, deep strict codesign, arm64+x86_64, both slices minimum 13.0, embedded Sparkle 2.10.1. Collector regression retest PASS 14 after final one-line startup change.

Startup semantics inspected in source: `applicationDidFinishLaunching` passes nil to updateStatusRates; absent sample and unavailable directions render em dash. First baseline nil is exercised by collector and core runtime tests. Presentation refresh contains no tick/totals mutation. These UI wiring checks are static inspection; no working app was launched or replaced.

QA disposition: available automated regression scope PASS; remaining live GUI/device acceptance explicitly untested above. No publication performed.

## Interactive installation follow-up: executable inode replacement

After user authorization for interactive testing, root reported live launch failure after replacing an existing app: macOS terminated it with CODESIGNING despite successful codesign verification. Implementation independently inspected the crash as Taskgated `Code Signature Invalid` before application frames. QA did not perform this launch; the live failure is evidence supplied by root/implementation.

The copier was observed using `shutil.copyfile` on an existing regular file, which overwrites its inode. Root changed it to a temporary sibling and atomic `os.replace`. QA added `test_executable_replacement_preserves_held_open_old_inode`: retain an open descriptor to the old executable, copy the new file, assert the descriptor still returns old bytes, the path returns new bytes with a distinct inode, executable mode persists and no temporary sibling remains.

`python3 Tests/test_copy_bundle.py`: PASS 8/8 after fix (the fix landed before QA ran the new fixture; no independent pre-fix test result claimed). Live reinstall/relaunch retest pending root observation. No GitHub publication performed by QA.

Additional interrupted-copy regression PASS: injected copy failure after writing partial temporary bytes preserves the existing target contents/inode and removes the temporary sibling. Current bundle synchronization suite: 9/9 PASS.

## Release 1.1.5 build 7 and interactive retest

Independent release QA PASS for `dist/release-v1.1.5-build7`:

- SHA256SUMS verified against both files: DMG `630410b2ef5f17b15eaeae464b41e45593dd174a40605d211eb20d19a572e8de`; appcast `d42700bc11aaffbe5e4c0ac273dc846e45f7d32a3ba2c7be6ce438b403e657b3`.
- Feed has one release, version 1.1.5/build 7, correct immutable v1.1.5 URL, archive size and signature attribute.
- `python3 scripts/verify_update.py dist/release-v1.1.5-build7`: PASS actual feed/archive cryptographic verification using the existing approved Keychain account; no key export or mutation.
- `hdiutil verify dist/release-v1.1.5-build7/NetMeter-stable.dmg`: VALID.
- Mounted DMG readonly and detached in finally. All 173 payload entries match staging (file hashes, modes and symlink destinations); packaged app passes deep strict codesign; Applications symlink correct. First literal comparison flagged only 173 stage AppleDouble metadata files absent from DMG. Excluding filesystem AppleDouble yields exact payload equality; DMG has zero AppleDouble files.
- Staging metadata 1.1.5/build 7, arm64+x86_64, minimum macOS 13.0 in both slices and deep strict signature: PASS.

Root-reported interactive results (QA did not operate these GUI checks): atomic replacement followed by launch PASS, PID 53358, subsequent restarts and sensors normal; no repeated CODESIGNING failure. GPU line yellow-only palette change and native eyedropper present; GPU 20 cores; CPU 14-core grid, expand and compact restoration PASS. macOS style applied to CPU/memory. Arabic RTL screenshot and Chinese/English/Russian accessibility inspection PASS. Activity Monitor selection was unavailable with existing AX permission and used honest fallback. Native CUA drag failed `windowNotFoundAtPosition`; real drag/grouping E2E remains limited.

Root also found stale General network summary when created before first snapshot. Implementation retained the label and refreshes it after accepted snapshots, presentation changes and settings creation/show. QA static inspection confirms these call paths, latest snapshot interface usage, full tooltip and no sampling tick in summary refresh. Release DMG contains this fix, matching staging as verified above. No independent GUI replay of this label update was performed.

No publication performed by QA. Earlier sections retain historical staged 1.1.4 checks; this section is the current 1.1.5/build 7 release acceptance.
