# Forgejo iOS

Máy chủ Forgejo chất lượng sản xuất cho các thiết bị iOS jailbreak với quản lý vòng đời hoàn chỉnh: cài đặt, cập nhật, xác minh, chẩn đoán, sửa chữa và gỡ cài đặt.

## Tính năng

- **Cài đặt một lệnh**: `curl -fsSL https://raw.githubusercontent.com/forgejo/forgejo/ios/install.sh | sudo sh`
- **Cập nhật tự động** với hỗ trợ khôi phục
- **Bảo tồn dữ liệu**: Kho lưu trữ và cấu hình của bạn tồn tại qua các bản cập nhật
- **Chẩn đoán**: Kiểm tra sức khỏe hệ thống toàn diện
- **Gỡ cài đặt an toàn**: Xóa Forgejo trong khi giữ dữ liệu của bạn
- **Quản lý trạng thái**: Theo dõi phiên bản cài đặt và tính toàn vẹn
- **Tương thích POSIX**: Không có phụ thuộc bash hoặc zsh
- **An toàn từ pipe**: Xử lý `stdin` một cách an toàn khi chạy từ curl pipe

## Bắt đầu nhanh

### Cài đặt

```bash
curl -fsSL https://raw.githubusercontent.com/forgejo/forgejo/ios/install.sh | sudo sh
```

Trình cài đặt sẽ:
1. Kiểm tra yêu cầu trước tiên của thiết bị (kiến trúc, jailbreak, công cụ cần thiết)
2. Tải xuống bản phát hành Forgejo iOS mới nhất
3. Xác minh tổng kiểm tra SHA256
4. Bảo tồn bất kỳ dữ liệu hiện có nào
5. Di chuyển tệp nhị phân đến `/var/lib/forgejo-ios/bin/forgejo`
6. Tạo tệp trạng thái cài đặt

### Chạy trình đơn trình cài đặt

Nếu bạn muốn chạy lại trình cài đặt mà không cần piping:

```bash
sudo sh install.sh
```

Điều này sẽ hiển thị menu tương tác:

```
1. Cài đặt Forgejo
2. Cập nhật Forgejo
3. Xác minh cài đặt
4. Hiển thị chẩn đoán
5. Sửa chữa cài đặt
6. Gỡ cài đặt Forgejo
7. Thoát
```

## Yêu cầu trước tiên

- **Phiên bản iOS**: Bất kỳ phiên bản nào có quyền truy cập jailbreak
- **Kiến trúc**: ARM64 (A9+) hoặc ARMv7 (thiết bị 32-bit)
- **Quyền root**: Jailbreak với quyền truy cập SSH/shell
- **Công cụ**: `curl`, `sha256sum`, `tar`, `gzip`
- **Tùy chọn**: `ldid` để ký nhị phân trên iOS

## Tương thích

### Kiến trúc được hỗ trợ

| Kiến trúc | Thiết bị | Trạng thái |
|---|---|---|
| ARM64 | iPhone 6s+, iPad Air 2+, iPad Pro | Được hỗ trợ đầy đủ |
| ARMv7 | iPhone 5s, iPad Air trước đó, iPad mini 2-3 | Được hỗ trợ đầy đủ |

### Phiên bản iOS

Forgejo iOS chạy trên bất kỳ phiên bản iOS jailbreak nào có đủ dung lượng trống (tối thiểu 200 MB cho tệp nhị phân, thư mục dữ liệu).

### Yêu cầu thiết bị

- Tối thiểu 512 MB RAM có sẵn
- 200 MB dung lượng trống (tệp nhị phân)
- 1 GB+ được khuyến nghị cho dữ liệu và kho lưu trữ

## Cài đặt

### Cài đặt tiêu chuẩn (tương tác)

```bash
sudo sh install.sh
```

Chọn tùy chọn `1` từ menu.

### Cài đặt tự động (từ curl pipe)

```bash
curl -fsSL https://raw.githubusercontent.com/forgejo/forgejo/ios/install.sh | sudo sh
```

Điều này mặc định ở chế độ cài đặt khi `stdin` không phải là terminal.

### Thư mục cài đặt tùy chỉnh

Thư mục cài đặt mặc định là `/var/lib/forgejo-ios`. Để sử dụng một vị trí khác:

```bash
FORGEJO_BASE_DIR=/custom/path sudo sh install.sh
```

### Cấu trúc thư mục sau khi cài đặt

```
/var/lib/forgejo-ios/
├── bin/
│   └── forgejo              # Tệp nhị phân Forgejo
├── data/                    # Dữ liệu người dùng (được bảo tồn khi cập nhật)
├── repositories/            # Kho lưu trữ Git (được bảo tồn khi cập nhật)
├── custom/
│   └── conf/
│       └── app.ini         # Cấu hình Forgejo (được bảo tồn)
├── logs/                    # Nhật ký ứng dụng
├── backup/                  # Sao lưu tự động trong quá trình cập nhật
└── install-state            # Theo dõi phiên bản và tổng kiểm tra
```

## Khởi động lần đầu

Sau khi cài đặt, hãy khởi động Forgejo:

```bash
/var/lib/forgejo-ios/bin/forgejo web
```

Hoặc sử dụng trình quản lý dịch vụ của jailbreak (ví dụ: `launchd` trên iOS):

```bash
# Tạo plist LaunchDaemon cho khởi động tự động
sudo tee /Library/LaunchDaemons/com.forgejo.plist > /dev/null << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.forgejo</string>
    <key>ProgramArguments</key>
    <array>
        <string>/var/lib/forgejo-ios/bin/forgejo</string>
        <string>web</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/lib/forgejo-ios/logs/forgejo.log</string>
    <key>StandardErrorPath</key>
    <string>/var/lib/forgejo-ios/logs/forgejo-error.log</string>
</dict>
</plist>
EOF
```

Sau đó tải dịch vụ:

```bash
sudo launchctl load /Library/LaunchDaemons/com.forgejo.plist
```

## Cập nhật

### Kiểm tra bản cập nhật

```bash
sudo sh install.sh
```

Chọn tùy chọn `2` từ menu. Trình cài đặt tự động:

1. Tải xuống phiên bản mới nhất
2. Xác minh tổng kiểm tra
3. Sao lưu tệp nhị phân hiện tại
4. Thay thế tệp nhị phân một cách nguyên tử
5. Cập nhật tệp trạng thái

Nếu có sự cố xảy ra trong quá trình khởi động, trình cài đặt sẽ tự động khôi phục phiên bản trước đó.

### Cập nhật tự động

Để giữ Forgejo luôn cập nhật, hãy thêm tác vụ cron:

```bash
sudo crontab -e
# Thêm: 0 2 * * * sh /var/lib/forgejo-ios/install.sh 2 >> /var/lib/forgejo-ios/logs/update.log
```

Hoặc sử dụng LaunchDaemon để cập nhật định kỳ (khuyến nghị trên iOS).

## Xác minh

### Xác minh tính toàn vẹn cài đặt

```bash
sudo sh install.sh
```

Chọn tùy chọn `3`. Điều này kiểm tra:

- Tệp nhị phân tồn tại và có thể thực thi
- Tệp trạng thái có mặt
- Các thư mục cần thiết được tạo
- Quyền tệp chính xác

### Hiển thị chẩn đoán

```bash
sudo sh install.sh
```

Chọn tùy chọn `4`. Đầu ra bao gồm:

- Kiến trúc thiết bị và phiên bản hệ điều hành
- Vị trí tệp nhị phân, kích thước, phiên bản và tổng kiểm tra
- Trạng thái cài đặt (phiên bản, thời gian cài đặt)
- Sử dụng lưu trữ (dữ liệu, kho lưu trữ, sao lưu, dung lượng trống)

## Sửa chữa

Nếu có sự cố, hãy chạy lệnh sửa chữa:

```bash
sudo sh install.sh
```

Chọn tùy chọn `5`. Điều này một cách an toàn:

- Tạo lại các thư mục bị thiếu
- Sửa quyền tệp
- Không sửa đổi dữ liệu hoặc cấu hình
- Không đặt lại cơ sở dữ liệu

## Sao lưu và khôi phục

### Sao lưu thủ công

```bash
sudo tar czf /tmp/forgejo-backup-$(date +%s).tar.gz \
    /var/lib/forgejo-ios/data/ \
    /var/lib/forgejo-ios/repositories/ \
    /var/lib/forgejo-ios/custom/conf/
```

### Khôi phục thủ công

```bash
sudo tar xzf /tmp/forgejo-backup-1234567890.tar.gz -C /
```

Các bản sao lưu cũng được tạo tự động khi cập nhật.

## Gỡ cài đặt

### Xóa Forgejo (giữ dữ liệu)

```bash
sudo sh install.sh
```

Chọn tùy chọn `6`. Khi được nhắc, nhấn `Enter` (KHÔNG nhập cụm từ xác nhận).

Điều này xóa:
- Tệp nhị phân Forgejo
- Tệp khởi động và dịch vụ
- Trạng thái cài đặt
- Tệp nhật ký

Dữ liệu và kho lưu trữ của bạn được bảo tồn tại `/var/lib/forgejo-ios/data/` và `/var/lib/forgejo-ios/repositories/`.

### Gỡ cài đặt hoàn toàn (xóa mọi thứ)

Khi được nhắc trong quá trình gỡ cài đặt, hãy nhập chính xác:

```
DELETE FORGEJO DATA
```

Điều này xóa:
- Tất cả các tệp Forgejo
- Tệp nhị phân, trạng thái, nhật ký
- **Cũng xóa**: Dữ liệu, kho lưu trữ và cấu hình

## Khắc phục sự cố

### "Checksum verification failed"

Tệp nhị phân được tải xuống không khớp với tệp SHA256SUMS được xuất bản. Điều này thường có nghĩa là:

- Sự tham nhũng mạng (thử lại)
- Tệp cũ được lưu trong bộ nhớ cache (xóa bộ nhớ cache và thử lại)
- Giới hạn tỷ lệ API GitHub (đợi và thử lại)

**Giải pháp**: Chạy trình cài đặt lại.

### "Forgejo binary is not executable"

Tệp nhị phân mất quyền thực thi, có thể do các tùy chọn gắn kết hoặc các vấn đề về hệ thống tệp.

**Giải pháp**: Chạy `repair installation` (tùy chọn 5).

### "Required tool not found"

Trình cài đặt phụ thuộc vào các công cụ Unix tiêu chuẩn. Lỗi này có nghĩa là một trong số chúng bị thiếu hoặc không có trong `$PATH`.

**Giải pháp**: Cài đặt công cụ bị thiếu:
- Debian/Ubuntu: `sudo apt-get install curl gzip tar`
- Alpine: `sudo apk add curl gzip tar`
- macOS: `brew install curl gzip tar`

### "This script must be run as root"

Trình cài đặt yêu cầu quyền root/sudo để tạo thư mục và cài đặt tệp trong `/var/lib/`.

**Giải pháp**: Chạy với `sudo`:

```bash
sudo sh install.sh
```

### Forgejo không khởi động

Kiểm tra nhật ký:

```bash
tail -f /var/lib/forgejo-ios/logs/forgejo*.log
```

Vấn đề phổ biến:

- Cổng đã được sử dụng (cấu hình cổng khác trong `app.ini`)
- Cơ sở dữ liệu bị khóa (kiểm tra các phiên bản khác)
- Vấn đề quyền (chạy sửa chữa)

### Cập nhật đã khôi phục tự động

Quy trình cập nhật phát hiện rằng Forgejo không khởi động được với tệp nhị phân mới và đã khôi phục phiên bản trước đó.

**Giải pháp**: Kiểm tra nhật ký để chẩn đoán vấn đề, sau đó thử cập nhật lại sau khi khắc phục sự cố.

## Hạn chế

- **Không quản lý dịch vụ tự động**: Forgejo không tự động khởi động lại sau khi khởi động lại. Sử dụng LaunchDaemon hoặc trình quản lý dịch vụ jailbreak khác.
- **Sandbox hạn chế**: Chạy dưới dạng root có nghĩa là Forgejo có quyền truy cập toàn bộ hệ thống. Hãy cẩn thận với Git hooks và plugin.
- **Ràng buộc hệ thống tệp iOS**: Một số công cụ Linux phổ biến có thể hoạt động khác nhau hoặc không có sẵn trên iOS.
- **Không có cập nhật bảo mật tự động**: Kiểm tra dự án Forgejo để biết các thông báo bảo mật.
- **Phụ thuộc jailbreak**: Forgejo yêu cầu jailbreak hoạt động với quyền truy cập SSH/shell.

## Nâng cao

### Cấu hình

Chỉnh sửa `/var/lib/forgejo-ios/custom/conf/app.ini` để tùy chỉnh:

```ini
[server]
HTTP_PORT = 3000
```

Sau đó khởi động lại Forgejo.

### Đường dẫn cài đặt tùy chỉnh

```bash
FORGEJO_BASE_DIR=/custom/path sudo sh install.sh
```

### Tải xuống tệp nhị phân thủ công

Nếu tải xuống tự động không thành công:

1. Tải xuống từ [Forgejo releases](https://github.com/forgejo/forgejo/releases)
2. Đặt trong `/var/lib/forgejo-ios/bin/forgejo`
3. Làm cho thực thi: `chmod 755 /var/lib/forgejo-ios/bin/forgejo`
4. Chạy xác minh: `sudo sh install.sh` → tùy chọn 3

## Hỗ trợ

Để báo cáo các vấn đề hoặc yêu cầu tính năng:

- [Forgejo GitHub Issues](https://github.com/forgejo/forgejo/issues)
- [Tài liệu Forgejo](https://forgejo.org/docs/)

## Giấy phép

Forgejo iOS theo sau giấy phép dự án Forgejo (MIT).
