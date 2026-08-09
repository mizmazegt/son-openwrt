#!/bin/sh

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
                # Lệnh sed lưu file sẽ kích hoạt lại vòng lặp để xuống nhánh else
            else
                # Bước 2: Kiểm tra và bật enable trong /etc/config/openvpn
                # Dùng uci để lấy giá trị của "option enabled"
                IS_ENABLED=$(uci -q get openvpn.$INSTANCE.enabled)
                
                if [ "$IS_ENABLED" = "0" ]; then
                    logger -t OpenVPN-Watchdog "$INSTANCE dang bi tat (enabled='0'). Dang doi thanh '1'..."
                    # Thay đổi thành 1
                    uci set openvpn.$INSTANCE.enabled='1'
                    # Lưu lại cấu hình (commit) vào file /etc/config/openvpn
                    uci commit openvpn
                elif [ -z "$IS_ENABLED" ]; then
                    # Tuỳ chọn thêm: Nếu chưa từng có cấu hình của tun này, hệ thống cũng ghi nhận vào log
                    logger -t OpenVPN-Watchdog "Luu y: $INSTANCE chua duoc cau hinh trong /etc/config/openvpn."
                fi
                
                # Bước 3: Restart dịch vụ
                logger -t OpenVPN-Watchdog "Ghi nhan file $filename san sang. Dang restart $INSTANCE..."
                /etc/init.d/openvpn restart "$INSTANCE"
            fi
            ;;
    esac
done