# Forgejo-iOS diagnostics

These small, read-only scripts are intended for later validation on a jailbroken iOS/iPadOS device. They do not start, stop, restart, kill, install, uninstall, or modify Forgejo, and they do not modify user data.

## Process RAM and CPU

Run the resource snapshot with an explicit Forgejo PID when possible:

```sh
sh scripts/ios/diagnose-forgejo-resources.sh 1234
```

With no argument, the script looks for the first process whose command name is `forgejo`:

```sh
sh scripts/ios/diagnose-forgejo-resources.sh
```

It reports the PID, resident set size (RSS) in KB, process-local CPU percentage, and command name. `ps` is the only required command. If `ps` or the process is unavailable, the script prints an `unavailable` result and exits without treating that as a measurement failure.

RSS and CPU are a single process snapshot. CPU is not whole-device CPU usage, and a single sample is not a workload profile. Repeat the command during idle and representative disposable workloads if a bounded profile is needed.

## Forgejo data and storage

Pass the actual Forgejo data directory used by the device:

```sh
sh scripts/ios/diagnose-forgejo-storage.sh /var/mobile/Library/Forgejo
```

The default is `$FORGEJO_IOS_DATA_DIR`, or `/var/mobile/Library/Forgejo` when that variable is unset. The script reports the total `du` size, sizes for common `data`, `custom`, `repositories`, `log`/`logs` subdirectories when present, and filesystem space available from `df`. It never creates, deletes, or changes files. `du` and `df` are optional; unavailable commands or paths are reported explicitly.

Storage totals can include SQLite database files, WAL/SHM files, repositories, indexes, uploads, attachments, and logs. `du` units and filesystem accounting vary by userspace and filesystem. The script does not check SQLite integrity, Git integrity, backup recoverability, or free-space safety thresholds.

## iOS limitations and interpretation

The scripts prefer POSIX shell, `ps`, `du`, and `df` forms that are practical on old iOS 12 jailbreak userspaces. Command output and process visibility can vary by jailbreak, privilege, process arguments, and installed utilities. Some iOS `ps` builds may not expose all columns, so a value can remain unavailable rather than being inferred. Run as the same privilege that can see the Forgejo process and data path, without granting broader access than necessary.

Run these diagnostics only when the service state and data path are already known; they are observations, not lifecycle controls. Record the device model, iOS version, jailbreak/layout, Forgejo version, PID, path, timestamp, workload state, and complete output alongside any measurement.

Running these scripts does **not** constitute physical-device qualification by itself. Qualification still requires the controlled build, signing, runtime, lifecycle, storage/integrity, networking, cleanup, and workload evidence described in [`STATUS.md`](STATUS.md), [`COMPATIBILITY.md`](COMPATIBILITY.md), and [`PERFORMANCE.md`](PERFORMANCE.md).
