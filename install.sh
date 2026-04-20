#!/bin/sh

echo "========================================="
echo "1. Đang chuẩn bị môi trường..."
echo "========================================="
# Cập nhật danh sách gói và cài đặt wget-ssl + chứng chỉ bảo mật
apk update
apk add wget-ssl ca-certificates

# Đổi URL này cho đúng repo của bạn
REPO_URL="https://raw.githubusercontent.com/mizmazegt/son-openwrt/refs/heads/main"

FILES="
etc/rc.local
etc/init.d/passwall2
etc/init.d/vpn_watchdog
etc/init.d/listen_api
root/watch_ovpn.sh
usr/lib/lua/luci/view/openvpn/cbi-select-input-add.htm
usr/lib/lua/luci/view/passwall2/node_list/node_list.htm
usr/share/passwall2/app.sh
usr/share/passwall2/test.sh
usr/share/rpcd/acl.d/luci-openvpn-read.json
usr/bin/listen_api.sh
"

echo "Bắt đầu tải và thiết lập cấu hình bằng WGET..."

# Biến đếm số file thành công
SUCCESS_COUNT=0

for file in $FILES; do
    # Tạo thư mục nếu chưa có
    DIR_NAME=$(dirname "/$file")
    mkdir -p "$DIR_NAME"
    
    echo "- Đang xử lý: /$file"
    
    # Dùng wget (đã hỗ trợ SSL):
    # -q: im lặng, không in log rác
    # -O: xuất ra file đích
    wget -q -O "/$file" "$REPO_URL/$file"
    
    # Kiểm tra wget chạy thành công (mã 0) VÀ file không bị rỗng (-s)
    if [ $? -eq 0 ] && [ -s "/$file" ]; then
        echo "  -> Tải thành công!"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        
        # Phân quyền thông minh (Bỏ qua file .htm và .json)
        case "$file" in
            *.htm|*.json)
                ;;
            *)
                chmod +x "/$file"
                ;;
        esac
    else
        echo "  -> [LỖI] Không thể tải file này! (Xóa file lỗi nếu có)"
        # Xóa file trắng/lỗi do wget lỡ tạo ra để tránh rác hệ thống
        rm -f "/$file"
    fi
done

echo "========================================="
echo "Hoàn tất! Đã tải thành công: $SUCCESS_COUNT file."
echo "========================================="

# Kích hoạt các dịch vụ (init.d)
echo "Kích hoạt các dịch vụ tự chạy..."
/etc/init.d/vpn_watchdog enable
/etc/init.d/listen_api enable
