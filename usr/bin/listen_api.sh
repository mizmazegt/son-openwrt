#!/bin/sh

SERVER_URL="https://sonbui8386.online/router/wait_command"

# Tìm thi?t b? WAN th?c t?
WAN_DEV=$(uci -q get network.wan.device)
[ -z "$WAN_DEV" ] && WAN_DEV=$(uci -q get network.wan.ifname)

# L?y d?a ch? MAC g?c và d?n s?ch ký t? ?n
MAC_ADDR=$(cat /sys/class/net/$WAN_DEV/address | tr 'a-z' 'A-Z' | tr -d '\n' | tr -d '\r')

# --- B?T Ð?U Ð?C D?U VÂN TAY PH?N C?NG ---
# 1. Th? d?c s? Serial c?a CPU và d?n s?ch ký t? ?n
HARDWARE_ID=$(cat /proc/cpuinfo 2>/dev/null | grep -i 'Serial' | awk '{print $3}' | tr 'a-z' 'A-Z' | tr -d '\n' | tr -d '\r')

# 2. N?u CPU không có Serial (b? ?n), l?y MAC g?c c?a chip m?ng bam ra 6 ký t?
if [ -z "$HARDWARE_ID" ]; then
    HARDWARE_ID=$(cat /sys/class/net/eth0/address 2>/dev/null | md5sum | cut -c 1-6 | tr 'a-z' 'A-Z' | tr -d '\n' | tr -d '\r')
fi

# Ch?t danh tính: MAC M?ng + D?u vân tay v?t lý (Ð?m b?o chu?i này li?n m?ch 100%)
UNIQUE_MAC="${MAC_ADDR}-${HARDWARE_ID}"
# --- K?T THÚC Ð?C D?U VÂN TAY ---

logger "ListenAPI: Bat dau chay voi Danh tinh = [$UNIQUE_MAC]"

while true; do
    # G?i lên Server b?ng danh tính m?i
    MSG=$(wget -T 60 -qO- "$SERVER_URL?mac=$UNIQUE_MAC")

    # Ki?m tra n?u server có g?i l?nh (khác r?ng và khác KEEP_ALIVE)
    if [ -n "$MSG" ] && [ "$MSG" != "KEEP_ALIVE" ]; then
        
        # C?t chu?i d? l?y riêng 2 l?nh (VD: MSG="ACTIVE,EXPIRED")
        LAN_CMD=$(echo "$MSG" | cut -d',' -f1)
        PW_CMD=$(echo "$MSG" | cut -d',' -f2)

        # ---------------- 1. X? LÝ M?NG LAN ----------------
        if [ "$LAN_CMD" = "ACTIVE" ]; then
            # M? m?ng: Ði?n 'wan' vào dích d?n (dest) c?a Forwards
            uci set firewall.@forwarding[0].dest='wan'
        elif [ "$LAN_CMD" = "EXPIRED" ]; then
            # Khóa m?ng: Xóa 'wan' (xóa hoàn toàn option dest) kh?i Forwards
            uci -q delete firewall.@forwarding[0].dest
        fi
        uci commit firewall
        /etc/init.d/firewall reload

        # -------------- 2. X? LÝ PASSWALL 2 --------------
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