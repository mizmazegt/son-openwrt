


wget -qO- https://raw.githubusercontent.com/mizmazegt/son-openwrt/refs/heads/main/install.sh | sh

# commands from the video
# Setup/Install OpenWRT On Hyper-V

# installs need apps
opkg update && opkg install lsblk resize2fs losetup parted
# version 25.12.0 +
apk update && apk add lsblk resize2fs losetup parted

# list partitions
lsblk

# make sure the drive path and partition selected are correct 
parted -f -s /dev/sda resizepart 2 100%
reboot

losetup /dev/loop0 /dev/sda2 2> /dev/null
resize2fs -f /dev/loop0
reboot
passwall2 không tự khởi động lại cấu hình
cách fix 
Bước 2: Kích hoạt autostart và nạp liên kết ucitrack cho rpcd
Do /etc/init.d/passwall2 không sử dụng USE_PROCD=1, tiến trình rpcd của LuCI chỉ chịu gọi reload khi bấm Save & Apply nếu thỏa mãn đồng thời hai điều kiện: dịch vụ đã được enable (có symlink trong /etc/rc.d/) và rpcd đã nạp mục passwall2 từ /etc/config/ucitrack.

Chạy cụm lệnh sau trong SSH:

Bash
/etc/init.d/passwall2 enable

uci -q get ucitrack.@passwall2[0] >/dev/null || {
    uci add ucitrack passwall2
    uci set ucitrack.@passwall2[-1].init='passwall2'
    uci commit ucitrack
}

[ -x /etc/init.d/ucitrack ] && /etc/init.d/ucitrack reload
/etc/init.d/rpcd restart

Kiểm tra: Chạy lệnh /etc/init.d/passwall2 enabled && echo "ENABLED OK". Màn hình phải in ra ENABLED OK (xác nhận đã tạo /etc/rc.d/S99passwall2).

ok done
