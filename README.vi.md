# Forgejo-iOS

[![Installer lifecycle](https://github.com/nghianguyen150612/Forgejo-iOS/actions/workflows/ios-installer.yml/badge.svg?branch=ios)](https://github.com/nghianguyen150612/Forgejo-iOS/actions/workflows/ios-installer.yml)
[![A7 runtime build](https://github.com/nghianguyen150612/Forgejo-iOS/actions/workflows/ios-forgejo-a7-runtime.yml/badge.svg?branch=ios)](https://github.com/nghianguyen150612/Forgejo-iOS/actions/workflows/ios-forgejo-a7-runtime.yml)

Chạy [Forgejo](https://forgejo.org/), dịch vụ Git tự quản lý, trực tiếp trên iPad đã jailbreak thuộc cấu hình được kiểm chứng. Bản port cộng đồng này đóng gói Forgejo **15.0.9**, SQLite và runtime **go1.26.7-a7**, kèm trình quản lý vòng đời luôn giữ dữ liệu người dùng theo mặc định. Đây không phải cam kết hỗ trợ iOS từ dự án Forgejo upstream.

[English](README.md) · [Hướng dẫn cài đặt](docs/INSTALL.md) · [Bảo trì](docs/MAINTENANCE.md)

## Tính năng

- Binary arm64 cho thiết bị iOS thật, dùng bản vá runtime Apple A7 đã được kiểm chứng.
- Giao diện web Forgejo, lưu trữ Git qua HTTP và cơ sở dữ liệu SQLite.
- Một công cụ cho cài đặt, cập nhật, xác minh, chẩn đoán, sửa chữa và gỡ cài đặt.
- Kiểm tra SHA-256 trước khi ký trên thiết bị hoặc thay binary; thay thế nguyên tử trên cùng hệ thống tệp.
- Lưu bản sao binary/launcher và tự hoàn tác nếu bản cập nhật không khởi động được hoặc kiểm tra HTTP thất bại.
- Chạy dịch vụ bằng tài khoản không phải root, giới hạn quyền truy cập dữ liệu/cấu hình và chỉ lắng nghe HTTP trên loopback.
- Gỡ cài đặt thông thường giữ lại cấu hình, cơ sở dữ liệu, repository và các bản sao phục hồi.

## Bắt đầu nhanh

Chạy trong terminal trên iPad được hỗ trợ:

```sh
curl -fsSL https://raw.githubusercontent.com/nghianguyen150612/Forgejo-iOS/ios/install.sh | sudo sh
```

Chọn **1. Install Forgejo**. Menu đọc từ `/dev/tty`, nên vẫn hoạt động khi stdin nhận script qua pipe. Tài khoản chạy dịch vụ mặc định là người gọi sudo; nếu gọi trực tiếp bằng root thì dùng `mobile`. Tiến trình Forgejo không chạy bằng root.

Sau khi cài, mở **http://127.0.0.1:3000/** trên iPad để hoàn tất thiết lập lần đầu và tạo tài khoản quản trị. Giữ SQLite và các đường dẫn do trình cài đặt cung cấp. Đây là cấu hình loopback, không phải triển khai công khai trên Internet.

```sh
sudo forgejo-ios verify
sudo forgejo-ios diagnostics
```

Trước khi hoàn tất thiết lập, cơ sở dữ liệu có thể chưa tồn tại. Lúc này công cụ báo SQLite chưa được khởi tạo; kiểm tra HTTP chỉ xác nhận máy chủ trang thiết lập đã sẵn sàng.

## Điều kiện tiên quyết

- Jailbreak rootful Amethyst, có quyền root/sudo. Không hỗ trợ iOS nguyên bản hoặc jailbreak rootless.
- POSIX `/bin/sh`; trình cài đặt và lệnh quản lý không cần Bash hay Zsh.
- `curl` hỗ trợ HTTPS, `sha256sum`, `ldid`, `git`, `sqlite3`, `sudo`, `nohup`, `ps`, `stat` và các công cụ tệp Unix thông thường.
- Một tài khoản không phải root đã tồn tại và đủ dung lượng cho tệp tải về, binary đang dùng cùng các bản sao phục hồi. Mỗi binary khoảng 100 MB; mỗi lần cập nhật giữ thêm bản sao.
- Kết nối tới GitHub và máy chủ tải release, hoặc một bộ tệp release ngoại tuyến được chỉ định rõ.

## Khả năng tương thích

| Thành phần | Cấu hình đã kiểm chứng |
| --- | --- |
| Thiết bị | iPad mini 2, `iPad4,4` |
| CPU / hệ điều hành | Apple A7 / iOS 12.5.7 |
| Jailbreak | Rootful Amethyst |
| Forgejo / runtime | 15.0.9 / go1.26.7-a7 |
| Lưu trữ / truy cập | SQLite / HTTP loopback |
| Khởi động | Lệnh thủ công; LaunchDaemon rootful cần kiểm chứng P18 trên thiết bị |

Trình cài đặt kiểm tra loại CPU, model thiết bị, phiên bản iOS, quyền root và công cụ cần thiết. Chỉ dựa vào các công cụ hiện có thì không thể khẳng định tên bản jailbreak. Những nền tảng khác cần được kiểm chứng riêng.

## Cài đặt

Thư mục mặc định là `/var/lib/forgejo-ios/`, chứa `bin/`, `custom/conf/`, `data/`, `repositories/`, `logs/`, `backup/` và `install-state`. Thư mục nội bộ `run/` giữ PID dịch vụ. Lệnh quản lý được liên kết tại `/usr/local/bin/forgejo-ios`.

Bootstrap kiểm tra SHA-256 đã cố định của script quản lý POSIX. Script tải release `v1.0.0-ios`, đối chiếu binary với `SHA256SUMS` và checksum A7 đã kiểm chứng, ký bản tạm bằng `ldid`, rồi chạy bằng tài khoản dịch vụ. Chỉ tạo `app.ini` khi tệp chưa tồn tại.

Có thể tải bootstrap về tệp để đọc trước khi chạy. Xem [docs/INSTALL.md](docs/INSTALL.md) về cài ngoại tuyến, đường dẫn tùy chỉnh, tài khoản dịch vụ, phân quyền và phục hồi. Bản cài thủ công cũ cần được kiểm tra đường dẫn/quyền sở hữu; công cụ không tự chuyển đổi bố cục.

## Cập nhật

```sh
sudo forgejo-ios update
sudo forgejo-ios verify
```

Hoặc chọn **2. Update Forgejo** trong menu. Nếu khởi động hoặc kiểm tra HTTP thất bại, công cụ khôi phục binary, launcher, trạng thái cài đặt, quyền truy cập và trạng thái đang chạy/đã dừng trước đó. PID thay đổi khi dịch vụ được khởi động lại.

Dòng release hiện tại được cố định: cập nhật sẽ cài lại an toàn binary `15.0.9` đã kiểm chứng. Công cụ không tự chọn phiên bản upstream bất kỳ. Release mới cần được kiểm chứng và cập nhật checksum trong installer. Hoàn tác binary không thể đảo ngược migration cơ sở dữ liệu; cập nhật khác phiên bản bị từ chối. Hãy sao lưu dữ liệu khi dịch vụ đã dừng trước khi bảo trì.

## Quản lý dịch vụ và gỡ cài đặt

```sh
sudo forgejo-ios start
sudo forgejo-ios stop
sudo forgejo-ios restart
sudo forgejo-ios service install
sudo forgejo-ios service status
sudo forgejo-ios service stop
sudo forgejo-ios service start
sudo forgejo-ios service restart
sudo forgejo-ios service uninstall
sudo forgejo-ios repair
sudo forgejo-ios uninstall
```

`service install` tạo nguyên tử và kiểm tra
`/Library/LaunchDaemons/com.forgejo.ios.plist`, sau đó nạp bằng `launchctl`.
Dịch vụ chạy bằng tài khoản không phải root đã cấu hình, tự khởi động sau boot
và được launchd khởi động lại khi bị crash. Trước khi chạm vào thư mục hệ
thống này, `sudo -n id` phải thành công. Lệnh stop gỡ daemon và xóa PID cũ;
uninstall chỉ xóa plist, giữ nguyên cấu hình, SQLite, repository, log và backup.
Các fixture trên host đã kiểm tra đường đi này; việc bật trên iPad vẫn cần vượt
qua cổng kiểm chứng reboot và crash recovery của P18.

Repair có thể tạo lại thư mục bị thiếu, khôi phục quyền của các mục do công cụ quản lý, khởi động lại dịch vụ và phục hồi binary bị mất từ bản sao có checksum phù hợp. Công cụ không đặt lại cấu hình, sửa nội dung cơ sở dữ liệu hay xóa dữ liệu.

Gỡ thông thường dừng Forgejo rồi xóa binary, launcher, log và trạng thái cài đặt. Các thư mục `data/`, `repositories/`, `custom/conf/` và bản sao phục hồi được giữ nguyên. Cài lại có thể dùng tiếp dữ liệu này.

Để xóa cả dữ liệu và bản sao phục hồi:

```sh
sudo forgejo-ios uninstall --purge
```

Phải nhập chính xác **`DELETE FORGEJO DATA`** qua `/dev/tty`. Không có cờ xác nhận tự động. Muốn phục hồi dữ liệu đã xóa cần bản sao lưu bên ngoài.

## Sao lưu

Snapshot của installer bảo vệ binary và launcher, **không phải bản sao lưu dữ liệu người dùng**. Xem [docs/BACKUP.md](docs/BACKUP.md) để sao lưu SQLite, repository và cấu hình khi đã dừng dịch vụ; dùng lệnh quản lý ở trên để dừng/chạy bản cài mới. Cần đọc kỹ giao diện launcher cũ của công cụ backup trước khi kết hợp với bố cục này. Mã hóa bản sao riêng và lưu ít nhất một bản ngoài thiết bị.

## Khắc phục sự cố

Chạy `sudo forgejo-ios diagnostics` để xem thiết bị, checksum, runtime, trạng thái cấu hình, kiểm tra SQLite, PID đã xác minh, cổng, mã HTTP, kích thước dữ liệu/repository và dung lượng trống. Công cụ không in nội dung cấu hình, log, bản ghi database, mật khẩu, token hoặc khóa.

- **Lỗi tải/checksum:** binary đang cài chưa bị thay thế. Kiểm tra release rồi thử lại; không bỏ qua xác minh.
- **Lỗi ký/khởi động:** xem riêng `logs/service.log` trên thiết bị; không công khai log chưa loại bỏ thông tin nhạy cảm.
- **Cổng bị chiếm:** dừng dịch vụ xung đột hoặc chọn cổng loopback không đặc quyền khác trong `app.ini`, rồi khởi động lại.
- **Mất binary:** chạy repair; checksum bản sao phải khớp trạng thái đã cài. Nếu không khớp thì cần phục hồi thủ công.
- **Thao tác bị gián đoạn:** giữ snapshot và kiểm tra `.installer-lock` trước khi xóa khóa cũ. Xem [hướng dẫn bảo trì](docs/MAINTENANCE.md).

## Giới hạn đã biết

- Chỉ hỗ trợ cấu hình đã nêu; không có App Store, iOS nguyên bản, simulator hoặc LaunchDaemon rootless.
- LaunchDaemon P18 đã được kiểm tra bằng fixture trên host, nhưng persistence
  sau reboot, crash recovery, SQLite và HTTP trên iPad chưa được xác nhận nếu
  `sudo -n id` chưa thành công trên thiết bị.
- Công cụ kiểm tra loopback HTTP và SSH bị tắt trong cấu hình. Truy cập công khai cần thiết kế bảo mật riêng.
- Cập nhật dừng dịch vụ trong thời gian ngắn, kiểm tra hai lần HTTP 200 từ `/api/healthz` và quyền sở hữu tiến trình; không bảo đảm không gián đoạn.
- `SIGKILL`, mất nguồn, hết dung lượng trong lúc phục hồi hoặc tiến trình không phản hồi có thể cần xử lý thủ công. Công cụ không ép tắt Forgejo bằng SIGKILL.
- Repair chỉ sửa quyền các thư mục và tệp quản lý, không sửa đệ quy toàn bộ repository/database.
- Checksum bảo đảm tính toàn vẹn theo nguồn installer/release được tin cậy; không thay thế chữ ký nhà phát hành độc lập.
- Kiểm chứng runtime không bảo đảm thời gian chạy vô hạn, pin, nhiệt độ hoặc sức chứa.

Bằng chứng port: [PORTING_IOS.md](PORTING_IOS.md). Artifact: [RELEASE.md](RELEASE.md). Bảo mật: [docs/SECURITY.md](docs/SECURITY.md). Mục lục: [docs/README.md](docs/README.md).

## Giấy phép

Forgejo dùng [GNU GPL v3.0 hoặc mới hơn](LICENSE). Các phiên bản trước v9.0 dùng MIT. Xem [CONTRIBUTING.md](CONTRIBUTING.md) về đóng góp upstream.
