


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