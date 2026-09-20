# Forgejo iOS

[![iOS Forgejo production build](https://github.com/nghianguyen150612/forgejo-ios/actions/workflows/ios-forgejo-production.yml/badge.svg?branch=ios)](https://github.com/nghianguyen150612/forgejo-ios/actions/workflows/ios-forgejo-production.yml)
[![iOS A7 runtime build](https://github.com/nghianguyen150612/forgejo-ios/actions/workflows/ios-forgejo-a7-runtime.yml/badge.svg?branch=ios)](https://github.com/nghianguyen150612/forgejo-ios/actions/workflows/ios-forgejo-a7-runtime.yml)
[![Release](https://img.shields.io/github/v/tag/nghianguyen150612/forgejo-ios?filter=v1.0.0-ios&label=release)](https://github.com/nghianguyen150612/forgejo-ios/releases/tag/v1.0.0-ios)
[![License](https://img.shields.io/github/license/nghianguyen150612/forgejo-ios)](LICENSE)

Forgejo iOS là bản port được thẩm định hẹp của [Forgejo](https://forgejo.org/) chạy native trên iPad đã jailbreak.

[English](README.md)

## Overview

Forgejo iOS đóng gói Forgejo `15.0.9` thành binary iOS vật lý `arm64`, kèm Go runtime tương thích Apple A7, service launcher thủ công, và tài liệu về backup cũng như ranh giới bảo mật.

Dự án dành cho người vận hành và nhà phát triển muốn chạy Git server tự host nhỏ gọn trên mục tiêu iOS đã được xác thực. Dự án giữ lại Forgejo web interface, Git repository workflow, và mô hình triển khai SQLite-backed, đồng thời tài liệu hóa runtime, signing, và jailbreak boundaries bổ sung cần thiết trên iOS.

Đây không phải tuyên bố hỗ trợ chính thức từ upstream Forgejo và không mở rộng support matrix chung của Forgejo.

## Features

- ✓ Native iOS `arm64` build cho thiết bị vật lý.
- ✓ Forgejo web interface phục vụ trực tiếp từ iPad.
- ✓ Git repository hosting thông qua workflow HTTP của Forgejo.
- ✓ SQLite backend cho triển khai một thiết bị đã được xác thực.
- ✓ Backup and restore workflow với integrity checks.
- ✓ Manual service launcher cho start, status, restart, và stop.
- ✓ Apple A7 runtime compatibility thông qua `go1.26.7-a7`.
- ✓ Release metadata, checksum, provenance, và tài liệu security boundary.

## Supported Device

Bản phát hành v1.0.0 chỉ được xác thực cho nền tảng sau:

```text
Device:    iPad4,4
CPU:       Apple A7
OS:        iOS 12.5.7
Jailbreak: Rootful Amethyst
Forgejo:   15.0.9
Runtime:   go1.26.7-a7
```

Các thiết bị iOS khác, phiên bản iOS khác, layout jailbreak khác, CPU khác, và mô hình background service khác đều cần validation riêng trước khi sử dụng.

## Quick Start

1. Lấy release artifact `v1.0.0-ios` và metadata đi kèm.
2. Xác minh `SHA256SUMS`, sau đó chuyển executable sang iPad đã jailbreak.
3. Cấu hình runtime tree owner-only với loopback HTTP và SQLite paths.
4. Khởi động Forgejo bằng `scripts/ios/run-forgejo.sh` và truy cập qua loopback URL đã cấu hình.

## Installation

Bắt đầu với release bundle được mô tả trong [`RELEASE.md`](RELEASE.md). Bundle chứa executable iOS, `build-info.txt`, và `SHA256SUMS`.

1. Lấy release artifact `v1.0.0-ios`.
2. Xác minh artifact trước khi chuyển sang thiết bị:

   ```sh
   sha256sum -c SHA256SUMS
   ```

3. Sao chép executable và support scripts vào thư mục owner-only trên iPad đã jailbreak.
4. Ký device-side working copy bằng `ldid` và no-container entitlement đã được tài liệu hóa.
5. Tạo `custom/conf/app.ini`, `data/`, `repositories/`, và `logs/` trong runtime root riêng.
6. Giữ configuration, database files, launcher state, và logs ở chế độ owner-only.

Xem [`docs/INSTALL.md`](docs/INSTALL.md) để có hướng dẫn cài đặt đầy đủ cho người vận hành.

## Usage

Khởi động Forgejo bằng launcher và đường dẫn cấu hình rõ ràng:

```sh
export FORGEJO_IOS_BINARY=/var/nghianguyen/forgejo-ios/<release>/bin/forgejo-ios
export FORGEJO_IOS_SERVICE_DIR=/var/nghianguyen/forgejo-ios/<release>/runtime
export FORGEJO_IOS_DEVICE_MODEL=iPad4,4
export FORGEJO_IOS_DARWIN_RELEASE=18.7.0

scripts/ios/run-forgejo.sh start "$FORGEJO_IOS_BINARY" \
  --config "$FORGEJO_IOS_SERVICE_DIR/custom/conf/app.ini"
```

Sau đó xác minh service cục bộ trên iPad:

```sh
scripts/ios/run-forgejo.sh status "$FORGEJO_IOS_BINARY"
curl --fail http://127.0.0.1:<port>/
sqlite3 "$FORGEJO_IOS_SERVICE_DIR/data/forgejo.db" 'PRAGMA integrity_check;'
```

Dừng service trước khi backup, restore, thử nghiệm upgrade, hoặc bảo trì filesystem:

```sh
scripts/ios/run-forgejo.sh stop "$FORGEJO_IOS_BINARY"
```

## Architecture

Forgejo iOS giữ nguyên mô hình ứng dụng upstream Forgejo và bổ sung một lớp triển khai iOS nhỏ quanh build, runtime, launcher, và quy trình validation.

```text
Forgejo
   |
Go runtime
   |
A7 compatibility layer
   |
iOS launcher
   |
Jailbroken iPad
```

Runtime đã được xác thực được build từ Go `1.26.7` với patch tương thích A7 hẹp cho iOS `arm64` tại `runtime.procyieldAsm`. Release sử dụng `GOOS=ios`, `GOARCH=arm64`, `CGO_ENABLED=1`, physical iOS Mach-O output, SQLite build tags, và device-side signing rõ ràng.

Bằng chứng porting chi tiết được ghi trong [`PORTING_IOS.md`](PORTING_IOS.md). Chính sách maintenance nằm trong [`docs/MAINTENANCE.md`](docs/MAINTENANCE.md).

## Backup

Sử dụng stopped-files backup flow đã được tài liệu hóa trước khi di chuyển dữ liệu, restore instance, hoặc kiểm thử release mới. Quy trình backup xác minh SQLite integrity và repository object health, nhưng không phải công cụ mã hóa.

Đọc [`docs/BACKUP.md`](docs/BACKUP.md) trước khi thao tác với persistent data.

## Security

Triển khai đã được xác thực mặc định dùng loopback HTTP và runtime files owner-only. Không công bố private keys, credentials, runtime directories, databases, logs, cookies, hoặc backup archives.

Đọc [`docs/SECURITY.md`](docs/SECURITY.md) để biết security boundary, network posture được hỗ trợ, signing notes, permission expectations, và các exposure paths không được hỗ trợ.

## Limitations

- Chỉ hỗ trợ manual launcher; không bảo đảm automatic boot.
- Chỉ hỗ trợ rootful jailbreak target.
- Loopback HTTP là mặc định và là listener posture duy nhất đã được xác thực.
- Thiết bị, phiên bản iOS, jailbreak, và CPU khác cần testing mới.
- Bằng chứng A7 runtime là bounded validation, không phải qualification về thermal, battery, capacity, hoặc indefinite-soak.
- Optional Forgejo services và external renderers vẫn phụ thuộc từng deployment.

## Development

Công việc development cần giữ nguyên release boundary trừ khi một maintenance hoặc upgrade cycle mới được mở rõ ràng.

- Tài liệu public bắt đầu tại [`docs/README.md`](docs/README.md).
- Chi tiết cài đặt nằm trong [`docs/INSTALL.md`](docs/INSTALL.md).
- Ghi chú build và validation nằm trong [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).
- Release metadata đã đóng băng của v1.0.0 nằm trong [`CHANGELOG.md`](CHANGELOG.md) và [`RELEASE.md`](RELEASE.md).

Contributions không được chứa runtime data, logs, backups, secrets, private keys, hoặc device-local databases.

## License

Forgejo được phân phối theo [GNU General Public License version 3.0](LICENSE) hoặc bất kỳ phiên bản mới hơn nào. Các phiên bản Forgejo trước v9.0 được phân phối theo MIT license.

Để xem hướng dẫn đóng góp upstream, đọc [`CONTRIBUTING.md`](CONTRIBUTING.md).
