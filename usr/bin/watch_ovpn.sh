#!/bin/sh

# =================================================================
# CƠ CHẾ HUNTER - TRUY QUÉT VÀ TIÊU DIỆT TIẾN TRÌNH CŨ
# =================================================================
# Tìm mọi tiến trình watch_ovpn.sh đang chạy (ngoại trừ chính nó là $$) và diệt tận gốc
for pid in $(ps w | grep "[w]atch_ovpn.sh" | grep -v "$$" | awk '{print $1}'); do
    kill -9 "$pid" 2>/dev/null
done

# Dọn dẹp sạch sẽ inotifywait bị kẹt từ phiên cũ
killall -9 inotifywait 2>/dev/null
# =================================================================

inotifywait -m -e close_write -e moved_to /etc/openvpn |
while read -r directory events filename; do
    case "$filename" in
        *.ovpn)
            INSTANCE="${filename%.ovpn}"
            FILE_PATH="/etc/openvpn/$filename"

            # Bỏ qua nếu file bị xoá
            [ ! -f "$FILE_PATH" ] && continue

            # Bước 1: Xử lý thay đổi "dev tun" trong file .ovpn
            if grep -E -q "^dev tun[[:space:]]*$" "$FILE_PATH"; then
                logger -t OpenVPN-Watchdog "Phat hien 'dev tun' goc trong $filename. Dang chuyen thanh 'dev $INSTANCE'..."
                sed -i "s/^dev tun[[:space:]]*$/dev $INSTANCE/" "$FILE_PATH"
            else
                # Bước 2: Kiểm tra và bật enable trong /etc/config/openvpn
                IS_ENABLED=$(uci -q get openvpn.$INSTANCE.enabled)
                
                if [ "$IS_ENABLED" = "0" ]; then
                    logger -t OpenVPN-Watchdog "$INSTANCE dang bi tat. Dang doi thanh '1'..."
                    uci set openvpn.$INSTANCE.enabled='1'
                    uci commit openvpn
                elif [ -z "$IS_ENABLED" ]; then
                    logger -t OpenVPN-Watchdog "Luu y: $INSTANCE chua duoc cau hinh."
                fi
                
                # Bước 3: Restart dịch vụ
                logger -t OpenVPN-Watchdog "Ghi nhan file $filename san sang. Dang restart $INSTANCE..."
                /etc/init.d/openvpn restart "$INSTANCE"
            fi
            ;;
    esac
done