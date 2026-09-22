# Documentation Index

This directory contains the public operator, status, and maintenance documentation for Forgejo-iOS. The v1.0.0 release is frozen to Forgejo `15.0.9`, `go1.26.7-a7`, and the qualified `iPad4,4` Apple A7 target.

## Project status and planning

- [`STATUS.md`](STATUS.md) separates implemented, tested/verified, device-gated, and planned work.
- [`COMPATIBILITY.md`](COMPATIBILITY.md) records qualified, CI-only, device-gated, and unverified combinations.
- [`../ROADMAP.md`](../ROADMAP.md) tracks realistic next steps without expanding support claims.
- [`SSH-TUNNELING.md`](SSH-TUNNELING.md) documents remote access while keeping Forgejo on loopback.

## Core documents

- [`INSTALL.md`](INSTALL.md) explains requirements, jailbreak assumptions, installation, verification, and first startup.
- [`DEVELOPMENT.md`](DEVELOPMENT.md) summarizes repository structure, build flow, the iOS toolchain, and validation expectations.
- [`BACKUP.md`](BACKUP.md) documents stopped-files backup and restore operations.
- [`SECURITY.md`](SECURITY.md) defines permissions, signing, network posture, and unsupported exposure paths.
- [`MAINTENANCE.md`](MAINTENANCE.md) defines the frozen release matrix and update policy.

## Evidence documents

- [`PERFORMANCE.md`](PERFORMANCE.md) records resource and performance evidence.
- [`DIAGNOSTICS.md`](DIAGNOSTICS.md) documents the read-only RAM/CPU and storage diagnostic scripts.
- [`P9-WORKLOAD.md`](P9-WORKLOAD.md) records workload validation evidence.
- [`../PORTING_IOS.md`](../PORTING_IOS.md) is the chronological porting and device-validation log.
- [`../RELEASE.md`](../RELEASE.md) is the v1.0.0 release metadata and limitation summary.

## Reading order

1. Read [`STATUS.md`](STATUS.md) and [`../README.md`](../README.md) for scope.
2. Read [`COMPATIBILITY.md`](COMPATIBILITY.md) before selecting a device.
3. Read [`INSTALL.md`](INSTALL.md) before installing an artifact.
4. Read [`DIAGNOSTICS.md`](DIAGNOSTICS.md) when collecting resource or storage observations.
5. Read [`SECURITY.md`](SECURITY.md) and [`SSH-TUNNELING.md`](SSH-TUNNELING.md) before remote access.
6. Read [`BACKUP.md`](BACKUP.md), [`MAINTENANCE.md`](MAINTENANCE.md), and [`DEVELOPMENT.md`](DEVELOPMENT.md) before changing the deployment.

Do not commit runtime directories, databases, repositories, logs, private keys, credentials, cookies, or backup archives as documentation evidence.
