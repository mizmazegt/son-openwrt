#!/bin/sh

TARGET_FILE="/usr/lib/lua/luci/view/openvpn/cbi-select-input-add.htm"
PATCH_FILE="/usr/bin/openvpn_custom_ui.htm"

echo "Bắt đầu chạy script patch OpenVPN..."

# Kiểm tra xem file patch có tồn tại không
if [ ! -f "$PATCH_FILE" ]; then
    echo "LỖI: Không tìm thấy file patch tại $PATCH_FILE"
    exit 1
fi

# Kiểm tra xem file gốc có tồn tại không
if [ ! -f "$TARGET_FILE" ]; then
    echo "LỖI: Không tìm thấy file gốc tại $TARGET_FILE"
    exit 1
fi

# Kiểm tra xem code đã được chèn chưa
if grep -q "restartVpnInstance" "$TARGET_FILE"; then
    echo "THÔNG BÁO: Code patch đã tồn tại, không cần chèn thêm."
else
    echo "Đang tiến hành chèn code..."
    # Cắt bỏ dòng cuối cùng
    sed -i '$d' "$TARGET_FILE"
    # Chèn code từ file patch
    cat "$PATCH_FILE" >> "$TARGET_FILE"
    # Đóng thẻ div
    echo "</div>" >> "$TARGET_FILE"
    
    logger -t "OpenVPN-Patch" "Da chen thanh cong custom UI (Buttons + JS) vao OpenVPN"
    echo "THÀNH CÔNG: Đã chèn patch vào file đích."
fi