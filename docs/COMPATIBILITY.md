# Compatibility matrix

This matrix distinguishes what is known from what is merely plausible. A row is not qualified until the repository contains evidence for the complete build, signing, runtime, and deployment scope.

## Known and tested

| Device / CPU | OS | Jailbreak / layout | Forgejo / runtime | Scope and status |
| --- | --- | --- | --- | --- |
| iPad mini 2 / `iPad4,4` / Apple A7 / arm64 | iOS 12.5.7 / Darwin 18.7.0 | Rootful Amethyst | Forgejo 15.0.9 / `go1.26.7-a7` | **Primary target.** Build artifacts, signing path, runtime probes, manual lifecycle, SQLite/HTTP release evidence, and bounded workload evidence are recorded. |
| iPad mini 2 / `iPad4,4` / Apple A7 / arm64 | iOS 12.5.7 | Rootful Amethyst | Native C and Go 1.26.7 probes | **Tested.** Probes execute after device-side `ldid` signing with the demonstrated no-container entitlement. This does not by itself qualify every Forgejo feature. |
| macOS arm64 GitHub Actions runner | iPhoneOS SDK 18.5, deployment target iOS 12.0 | CI toolchain | Go 1.26.7, physical `ios/arm64`, CGO | **CI verified.** Produces and inspects physical-iOS Mach-O artifacts; CI is not a device substitute. |
| Linux amd64 host | Host Linux | N/A | Forgejo 15.0.9 / stock Go control build | **Control build only.** Useful for regression and tooling checks, not iOS qualification. |

## Implemented but not yet device-qualified

| Combination / feature | Status |
| --- | --- |
| `iPad4,4` / A7 / iOS 12.5.7 with managed rootful LaunchDaemon | **Awaiting physical-device verification.** Host fixtures validate plist generation and lifecycle logic; reboot persistence and crash recovery are not claimed. |
| `iPad4,4` / A7 / iOS 12.5.7 with arbitrary launchd hooks or tweaks | **Unverified.** The managed plist is the only intended service boundary. |
| `iPad4,4` / A7 / iOS 12.5.7 with public or wildcard HTTP exposure | **Not qualified.** Use loopback plus an SSH tunnel or a separately reviewed private proxy path. |
| `iPad4,4` / A7 / iOS 12.5.7 with optional PAM, systemd, sendmail, or external renderers | **Unverified / deployment-specific.** These have Linux or external-command assumptions. |

## Unverified combinations

The following are not supported claims and require a new evidence record:

- Rootless jailbreak layouts, including `/var/jb` deployments.
- Stock/non-jailbroken iOS, App Store deployment, and iOS Simulator.
- Devices other than `iPad4,4`, including other A7 and non-A7 arm64 devices.
- iOS/iPadOS versions other than 12.5.7, including newer releases.
- Forgejo versions other than 15.0.9 or Go runtimes other than `go1.26.7-a7`.
- Wildcard listeners, direct Internet exposure, or an assumed public TLS boundary.
- Indefinite uptime, reboot persistence, crash recovery, thermal, battery, or capacity behavior.

For the evidence behind each classification, see [`STATUS.md`](STATUS.md), [`PORTING_IOS.md`](../PORTING_IOS.md), and [`RELEASE.md`](../RELEASE.md).
