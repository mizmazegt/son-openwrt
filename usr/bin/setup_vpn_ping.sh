#!/bin/sh

CONFIG_FILE="/etc/config/openvpn"

# 1. Kiểm tra xem file cấu hình có tồn tại không
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Lỗi: File $CONFIG_FILE không tồn tại."
    exit 1
fi

# 2. Đếm số lượng cấu hình OpenVPN
TUN_COUNT=$(grep -E -c "config[[:space:]]+openvpn" "$CONFIG_FILE")

if [ "$TUN_COUNT" -eq 0 ]; then
    echo "Không tìm thấy cấu hình OpenVPN nào trong $CONFIG_FILE."
    exit 1
fi

echo "Tìm thấy $TUN_COUNT cấu hình OpenVPN."

# 3. Tính số thứ tự tun lớn nhất
MAX_TUN=$((TUN_COUNT - 1))

# 4. Tạo nội dung lệnh cron
CRON_CMD="* * * * * i=0; while [ \$i -le $MAX_TUN ]; do ping -I \"tun\$i\" -c 1 -W 1 8.8.8.8 >/dev/null 2>&1 & i=\$((i+1)); done"

# 5. Ghi vào crontab
(crontab -l 2>/dev/null | grep -v "ping -I \"tun"; echo "$CRON_CMD") | crontab -

# 6. Khởi động lại service cron (Trên Router OpenWrt/ImmortalWrt)
if [ -f "/etc/init.d/cron" ]; then
    /etc/init.d/cron restart >/dev/null 2>&1
fi

echo "Đã thêm thành công lệnh sau vào crontab:"
echo "$CRON_CMD"

# 7. Dừng và kill tiến trình của script ngay lập tức
exit 0