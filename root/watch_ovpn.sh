#!/bin/sh

# Dùng inotifywait để giám sát liên tục (-m) thư mục, chỉ bắt sự kiện ghi xong file (-e close_write)
inotifywait -m -e close_write /etc/openvpn |
while read -r directory events filename; do
    # Kiểm tra xem file có đuôi .ovpn hay không
    case "$filename" in
        *.ovpn)
            # Lấy tên instance
            INSTANCE="${filename%.ovpn}"
            
            logger -t OpenVPN-Watchdog "Phat hien thay doi tai $filename. Dang restart $INSTANCE..."
            /etc/init.d/openvpn restart "$INSTANCE"
            ;;
    esac
done