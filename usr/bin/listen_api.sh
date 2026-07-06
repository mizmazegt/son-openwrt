#!/bin/sh

SERVER_URL="https://sonbui8386.online/router/wait_command"

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

logger "ListenAPI: Bat dau chay voi Danh tinh = [$UNIQUE_MAC]"

while true; do
    # Gọi lên Server bằng danh tính mới
    MSG=$(wget -T 60 -qO- "$SERVER_URL?mac=$UNIQUE_MAC")

    # Kiểm tra nếu server có gửi lệnh (khác rỗng và khác KEEP_ALIVE)
    if [ -n "$MSG" ] && [ "$MSG" != "KEEP_ALIVE" ]; then
        
        # Cắt chuỗi để lấy riêng 2 lệnh (VD: MSG="ACTIVE,EXPIRED")
        LAN_CMD=$(echo "$MSG" | cut -d',' -f1)
        PW_CMD=$(echo "$MSG" | cut -d',' -f2)

        # ---------------- 0. LỆNH ĐẶC BIỆT: RESET OPENVPN & PASSWALL2 ----------------
        if [ "$LAN_CMD" = "RESET_VPN_PW" ]; then
            logger "ListenAPI: Nhan lenh XOA config OpenVPN va Passwall2 tu Server!"
            
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
            
            logger "ListenAPI: Da xoa va khoi phuc xong OpenVPN, Passwall2!"
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

        logger "LongPolling: Cap nhat LAN=$LAN_CMD, Passwall2=$PW_CMD cho MAC=$UNIQUE_MAC"
    fi
    
    sleep 1
done