#!/bin/sh

# Đặt biến đường dẫn Raw của GitHub (thay bằng link repo của bạn sau khi upload)
REPO_URL="https://raw.githubusercontent.com/mizmazegt/son-openwrt/refs/heads/main/"
# Danh sách file (viết đường dẫn tính từ thư mục gốc /)
FILES="
etc/rc.local
etc/init.d/passwall2
etc/init.d/vpn_watchdog
etc/init.d/listen_api
root/watch_ovpn.sh
usr/lib/lua/luci/view/openvpn/cbi-select-input-add.htm
usr/lib/lua/luci/view/passwall2/node_list/node_list.htm
usr/share/passwall2/app.sh
usr/share/rpcd/acl.d/luci-openvpn-read.json
usr/bin/listen_api.sh
"

echo "Bắt đầu tải và thiết lập cấu hình..."

for file in $FILES; do
    # 1. Lấy tên thư mục chứa file và tự động tạo nếu chưa có
    DIR_NAME=$(dirname "/$file")
    mkdir -p "$DIR_NAME"
    
    # 2. Tải file và ghi đè
    echo "- Đang tải: /$file"
    wget -qO "/$file" "$REPO_URL/$file"
    
    # 3. Phân quyền thông minh (Bỏ qua file .htm và .json)
    case "$file" in
        *.htm|*.json)
            # Không làm gì với file giao diện và cấu hình
            ;;
        *)
            # Cấp quyền thực thi cho các file còn lại
            chmod +x "/$file"
            ;;
    esac
done

echo "Tải file và phân quyền hoàn tất!"

# Khởi động và kích hoạt các dịch vụ tự chạy cùng hệ thống (Tùy chọn)
echo "Kích hoạt các dịch vụ (init.d)..."
/etc/init.d/vpn_watchdog enable
/etc/init.d/listen_api enable
/etc/init.d/passwall2 enable

echo "Mọi thứ đã xong!"