#!/bin/sh

# =================================================================
# CƠ CHẾ LOCK FILE - CHỈ 1 TIẾN TRÌNH, TIẾN TRÌNH MỚI SẼ KILL TIẾN TRÌNH CŨ
# =================================================================
LOCK_FILE="/var/run/listen_api.pid"
TMP_MSG="/tmp/listen_api.msg"
WGET_PID=""

# Kill các tiến trình con của một PID (wget, sleep đang chạy dở)
kill_children() {
    for p in /proc/[0-9]*; do
        pid=${p#/proc/}
        ppid=$(grep '^PPid:' "$p/status" 2>/dev/null | awk '{print $2}')
        [ "$ppid" = "$1" ] && kill -9 "$pid" 2>/dev/null
    done
}

kill_old_process() {
    OLD="$1"

    # Không tự kill chính mình
    [ "$OLD" = "$$" ] && return

    logger -t ListenAPI "Phat hien tien trinh cu PID $OLD. Dang kill..."

    kill -TERM "$OLD" 2>/dev/null
    kill_children "$OLD"

    # Chờ tối đa 5 giây cho nó tự thoát
    i=0
    while kill -0 "$OLD" 2>/dev/null && [ $i -lt 5 ]; do
        sleep 1
        i=$((i + 1))
    done

    # Vẫn còn sống thì kill cứng
    if kill -0 "$OLD" 2>/dev/null; then
        kill -9 "$OLD" 2>/dev/null
        kill_children "$OLD"
        sleep 1
    fi

    logger -t ListenAPI "Da kill xong tien trinh cu PID $OLD."
}

if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        # Chỉ kill nếu đúng là tiến trình của script này (tránh PID bị tái sử dụng)
        if tr '\0' ' ' < /proc/$OLD_PID/cmdline 2>/dev/null | grep -q "listen_api"; then
            kill_old_process "$OLD_PID"
        else
            logger -t ListenAPI "PID $OLD_PID khong phai listen_api (PID bi tai su dung). Bo qua."
        fi
    else
        logger -t ListenAPI "Lock file cu tu tien trinh $OLD_PID da chet. Dang don dep..."
    fi
fi

# Ghi PID của tiến trình hiện tại vào lock file
echo $$ > "$LOCK_FILE"

# Chỉ xóa lock file nếu nó vẫn thuộc về MÌNH
# (tránh tiến trình cũ lúc chết xóa nhầm lock file của tiến trình mới)
cleanup() {
    [ "$(cat "$LOCK_FILE" 2>/dev/null)" = "$$" ] && rm -f "$LOCK_FILE"
    rm -f "$TMP_MSG"
}
trap 'cleanup' EXIT
# Khi nhận SIGTERM/SIGINT: kill wget đang chờ rồi thoát ngay
trap '[ -n "$WGET_PID" ] && kill "$WGET_PID" 2>/dev/null; exit 1' INT TERM
# =================================================================

SERVER_URL="https://sonbuitcc.io.vn/router/wait_command"

# Tìm thiết bị WAN thực tế
WAN_DEV=$(uci -q get network.wan.device)
[ -z "$WAN_DEV" ] && WAN_DEV=$(uci -q get network.wan.ifname)

# Lấy địa chỉ MAC gốc và dọn sạch ký tự ẩn
MAC_ADDR=$(cat /sys/class/net/$WAN_DEV/address | tr 'a-z' 'A-Z' | tr -d '\n' | tr -d '\r')

# --- BẮT ĐẦU ĐỌC DẤU VÂN TAY PHẦN CỨNG ---
# 1. Thử đọc số Serial của CPU và dọn sạch ký tự ẩn
HARDWARE_ID=$(cat /proc/cpuinfo 2>/dev/null | grep -i 'Serial' | awk '{print $3}' | tr 'a-z' 'A-Z' | tr -d '\n' | tr -d '\r')

# 2. Nếu CPU không có Serial (bị ẩn), lấy MAC gốc của chip mạng băm ra 6 ký tự
if [ -z "$HARDWARE_ID" ]; then
    HARDWARE_ID=$(cat /sys/class/net/eth0/address 2>/dev/null | md5sum | cut -c 1-6 | tr 'a-z' 'A-Z' | tr -d '\n' | tr -d '\r')
fi

# Chốt danh tính: MAC Mạng + Dấu vân tay vật lý (Đảm bảo chuỗi này liền mạch 100%)
UNIQUE_MAC="${MAC_ADDR}-${HARDWARE_ID}"
# --- KẾT THÚC ĐỌC DẤU VÂN TAY ---

logger -t ListenAPI "Bat dau chay voi Danh tinh = [$UNIQUE_MAC]"

while true; do
    # Gọi server ở nền rồi dùng 'wait' để trap SIGTERM được xử lý ngay lập tức
    rm -f "$TMP_MSG"
    wget -T 60 -qO "$TMP_MSG" "$SERVER_URL?mac=$UNIQUE_MAC" &
    WGET_PID=$!
    wait $WGET_PID
    MSG=$(cat "$TMP_MSG" 2>/dev/null)
    WGET_PID=""

    # Kiểm tra nếu server có gửi lệnh (khác rỗng và khác KEEP_ALIVE)
    if [ -n "$MSG" ] && [ "$MSG" != "KEEP_ALIVE" ]; then

        # Cắt chuỗi để lấy riêng 2 lệnh (VD: MSG="ACTIVE,EXPIRED")
        LAN_CMD=$(echo "$MSG" | cut -d',' -f1)
        PW_CMD=$(echo "$MSG" | cut -d',' -f2)

        # ---------------- 0. LỆNH ĐẶC BIỆT: RESET OPENVPN & PASSWALL2 ----------------
        if [ "$LAN_CMD" = "RESET_VPN_PW" ]; then
            logger -t ListenAPI "Nhan lenh XOA config OpenVPN va Passwall2 tu Server!"

            # Xử lý OpenVPN
            if [ -f /rom/etc/config/openvpn ]; then
                cp /rom/etc/config/openvpn /etc/config/openvpn
            else
                > /etc/config/openvpn
            fi

            # Xử lý Passwall2
            if [ -f /rom/etc/config/passwall2 ]; then
                cp /rom/etc/config/passwall2 /etc/config/passwall2
            else
                > /etc/config/passwall2
            fi

            # Khởi động lại dịch vụ để áp dụng file rỗng/file gốc
            /etc/init.d/openvpn restart 2>/dev/null
            /etc/init.d/passwall2 restart 2>/dev/null

            logger -t ListenAPI "Da xoa va khoi phuc xong OpenVPN, Passwall2!"
            continue # Xử lý xong quay lại vòng lặp chờ, bỏ qua các lệnh dưới
        fi

        # ---------------- 1. XỬ LÝ MẠNG LAN ----------------
        if [ "$LAN_CMD" = "ACTIVE" ]; then
            # Mở mạng: Điền 'wan' vào đích đến (dest) của Forwards
            uci set firewall.@forwarding[0].dest='wan'
        elif [ "$LAN_CMD" = "EXPIRED" ]; then
            # Khóa mạng: Xóa 'wan' (xóa hoàn toàn option dest) khỏi Forwards
            uci -q delete firewall.@forwarding[0].dest
        fi
        uci commit firewall
        /etc/init.d/firewall reload

        # -------------- 2. XỬ LÝ PASSWALL 2 --------------
        if [ "$PW_CMD" = "ACTIVE" ]; then
            uci set passwall2.@acl_rule[0].enabled='1'
        elif [ "$PW_CMD" = "EXPIRED" ]; then
            uci set passwall2.@acl_rule[0].enabled='0'
        fi
        uci commit passwall2
        /etc/init.d/passwall2 restart

        logger -t ListenAPI "LongPolling: Cap nhat LAN=$LAN_CMD, Passwall2=$PW_CMD cho MAC=$UNIQUE_MAC"
    fi

    sleep 1
done