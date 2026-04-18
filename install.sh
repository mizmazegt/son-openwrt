#!/bin/sh

# Đổi URL này cho đúng repo của bạn
REPO_URL="https://raw.githubusercontent.com/mizmazegt/son-openwrt/main"

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

echo "Bắt đầu tải và thiết lập cấu hình bằng CURL..."

# Biến đếm số file thành công
SUCCESS_COUNT=0

for file in $FILES; do
    # Tạo thư mục nếu chưa có
    DIR_NAME=$(dirname "/$file")
    mkdir -p "$DIR_NAME"
    
    echo "- Đang xử lý: /$file"
    
    # Dùng curl thay cho wget:
    # -s: silent (không hiện thanh tiến trình tải)
    # -L: follow redirects (chuyển hướng link nếu có)
    # -f: fail silently on HTTP errors (trả về lỗi nếu file 404)
    # -o: output ra file đích
    curl -sLf -o "/$file" "$REPO_URL/$file"
    
    # Kiểm tra mã lỗi trả về của curl ($?)
    if [ $? -eq 0 ]; then
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
        echo "  -> [LỖI] Không thể tải file này! (Kiểm tra lại link hoặc file có tồn tại trên GitHub không)"
    fi
done

echo "========================================="
echo "Hoàn tất! Đã tải thành công: $SUCCESS_COUNT file."
echo "========================================="

# Kích hoạt các dịch vụ (init.d)
echo "Kích hoạt các dịch vụ tự chạy..."
/etc/init.d/vpn_watchdog enable 2>/dev/null
/etc/init.d/listen_api enable 2>/dev/null
/etc/init.d/passwall2 enable 2>/dev/null
