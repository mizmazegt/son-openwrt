#!/bin/sh
# =================================================================
# CƠ CHẾ HUNTER - TRUY QUÉT VÀ TIÊU DIỆT TIẾN TRÌNH CŨ
# =================================================================
for pid in $(ps w | grep "[w]atch_ovpn.sh" | grep -v "$$" | awk '{print $1}'); do
    kill -9 "$pid" 2>/dev/null
done
killall -9 inotifywait 2>/dev/null
# =================================================================

inotifywait -m -e close_write -e moved_to /etc/openvpn |
while read -r directory events filename; do
    case "$filename" in
        *.ovpn)
            INSTANCE="${filename%.ovpn}"
            FILE_PATH="/etc/openvpn/$filename"
            [ ! -f "$FILE_PATH" ] && continue

            # Bước 1: Xử lý thay đổi "dev tun" trong file .ovpn
            if grep -E -q "^dev tun[[:space:]]*$" "$FILE_PATH"; then
                logger -t OpenVPN-Watchdog "Phat hien 'dev tun' goc trong $filename. Dang chuyen thanh 'dev $INSTANCE'..."
                sed -i "s/^dev tun[[:space:]]*$/dev $INSTANCE/" "$FILE_PATH"
            fi

            # Bước 1.5: Kiểm tra và chèn data-ciphers / route-nopull nếu thiếu
            NEED_CIPHERS=0
            NEED_NOPULL=0
            grep -qF "data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305:AES-128-CBC" "$FILE_PATH" || NEED_CIPHERS=1
            grep -qF "route-nopull" "$FILE_PATH" || NEED_NOPULL=1

            if [ "$NEED_CIPHERS" = "1" ] || [ "$NEED_NOPULL" = "1" ]; then
                # Xác định dòng neo (anchor) để chèn ngay sau nó
                if grep -qxF "cipher AES-128-CBC" "$FILE_PATH"; then
                    ANCHOR="cipher AES-128-CBC"
                elif grep -qxF "dev $INSTANCE" "$FILE_PATH"; then
                    ANCHOR="dev $INSTANCE"
                else
                    ANCHOR=""
                fi

                if [ -n "$ANCHOR" ]; then
                    logger -t OpenVPN-Watchdog "$filename thieu cau hinh can thiet. Dang chen sau dong '$ANCHOR'..."

                    INSERT_BLOCK=""
                    [ "$NEED_CIPHERS" = "1" ] && INSERT_BLOCK="${INSERT_BLOCK}data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305:AES-128-CBC
"
                    [ "$NEED_NOPULL" = "1" ] && INSERT_BLOCK="${INSERT_BLOCK}route-nopull
"

                    awk -v anchor="$ANCHOR" -v ins="$INSERT_BLOCK" '
                        {
                            print
                            if ($0 == anchor && !done) {
                                printf "%s", ins
                                done = 1
                            }
                        }
                    ' "$FILE_PATH" > "${FILE_PATH}.tmp" && mv "${FILE_PATH}.tmp" "$FILE_PATH"
                else
                    logger -t OpenVPN-Watchdog "$filename: khong tim thay dong 'cipher AES-128-CBC' hoac 'dev $INSTANCE' de chen. Bo qua."
                fi
            fi

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
            ;;
    esac
done