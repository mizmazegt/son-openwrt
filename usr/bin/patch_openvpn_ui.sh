#!/bin/sh

TARGET_FILE="/usr/lib/lua/luci/view/openvpn/cbi-select-input-add.htm"
PATCH_FILE="/usr/bin/openvpn_custom_ui.htm"

if [ -f "$TARGET_FILE" ] && [ -f "$PATCH_FILE" ]; then
    # Kiểm tra xem code đã được chèn chưa bằng một từ khóa đặc trưng
    if ! grep -q "exportRunningIPs" "$TARGET_FILE"; then
        # Cắt bỏ dòng </div> cuối cùng, chèn code của bạn, rồi đóng </div> lại
        sed -i '$d' "$TARGET_FILE"
        cat "$PATCH_FILE" >> "$TARGET_FILE"
        echo "</div>" >> "$TARGET_FILE"
        logger -t "OpenVPN-Patch" "Da chen thanh cong custom UI (Buttons + JS) vao OpenVPN"
    fi
fi