#!/bin/sh

# Đặt biến đường dẫn Raw của GitHub (thay bằng link repo của bạn sau khi upload)
REPO_URL="https://raw.githubusercontent.com/TenCuaBan/my-openwrt-config/main"

echo "======================================"
echo "Bắt đầu thiết lập OpenWrt/ImmortalWrt..."
echo "======================================"

# 1. (Tùy chọn) Cập nhật và cài đặt các package cần thiết
echo "[1/4] Cài đặt các gói phụ thuộc..."
apk update
apk add wget curl nano tmux libinotifytools # Thêm docker, mwan3, passwall... nếu cần

# 2. Tạo thư mục chứa script trên router
echo "[2/4] Tạo thư mục /root/scripts..."
mkdir -p /root/scripts

# 3. Tải các file từ GitHub về router
echo "[3/4] Đang tải các script..."
# Ví dụ tải file script vào /root/scripts
wget -qO /root/scripts/load_balance.sh "$REPO_URL/scripts/load_balance.sh"
wget -qO /root/scripts/docker_setup.sh "$REPO_URL/scripts/docker_setup.sh"

# Ví dụ tải file cấu hình đè vào hệ thống (Cẩn thận khi dùng)
# wget -qO /etc/firewall.user "$REPO_URL/configs/custom_firewall.user"

# 4. Phân quyền thực thi (chmod +x) cho các script
echo "[4/4] Cấp quyền thực thi..."
chmod +x /root/scripts/*.sh

echo "======================================"
echo "Hoàn tất cài đặt! Hãy kiểm tra lại trong /root/scripts"
echo "======================================"