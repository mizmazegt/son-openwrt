#!/bin/sh

echo "========================================="
echo "1. Đang chuẩn bị môi trường..."
echo "========================================="



# Đường dẫn URL trực tiếp tới file nén trên GitHub
TAR_URL="https://raw.githubusercontent.com/mizmazegt/son-openwrt/refs/heads/main/update.tar.gz"
TMP_TAR="/tmp/update.tar.gz"

echo "========================================="
echo "2. Đang tải gói cập nhật update.tar.gz..."
echo "========================================="
wget -q -O "$TMP_TAR" "$TAR_URL"

# Kiểm tra file tải về thành công và không trống
if [ $? -eq 0 ] && [ -s "$TMP_TAR" ]; then
    echo "  -> Tải thành công! Đang giải nén hệ thống..."
    
    # Giải nén cấu trúc đè thẳng vào thư mục gốc /
    # Tham số -C / chỉ định giải nén từ gốc hệ thống
    tar -xzvf "$TMP_TAR" -C /
    
    echo "  -> Giải nén hoàn tất. Đang thiết lập quyền thực thi..."
    # Phân quyền cho các file thực thi quan trọng
    chmod +x /etc/rc.local
    chmod +x /etc/init.d/watch_ovpn
    chmod +x /etc/init.d/listen_api
	chmod +x /etc/init.d/extend_session
    chmod +x /usr/bin/listen_api.sh
    chmod +x /usr/bin/watch_ovpn.sh
	chmod +x /www/cgi-bin/vpn-manager

    # Xóa file nén tạm để giải phóng bộ nhớ RAM của router
    rm -f "$TMP_TAR"
    echo "  -> Đồng bộ dữ liệu thành công!"
else
    echo "  -> [LỖI] Không thể tải gói update.tar.gz. Vui lòng kiểm tra lại đường dẫn GitHub!"
    rm -f "$TMP_TAR"
    exit 1
fi

echo "========================================="
echo "3. Kích hoạt và khởi động lại dịch vụ..."
echo "========================================="
/etc/init.d/vpn_watchdog enable
/etc/init.d/listen_api enable
/etc/init.d/extend_session enable
/etc/init.d/watch_ovpn start
/etc/init.d/listen_api start
/etc/init.d/extend_session start


echo "========================================="
echo "Hoàn tất cấu hình hệ thống!"
echo "========================================="