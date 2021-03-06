#!/bin/bash

pacmanpkgs=(
amd-ucode
base-devel
dialog
fish
git
intel-ucode
linux-firmware
linux-lts
linux-lts-headers
nano
pacman-contrib
reflector
rsync
terminus-font
usbutils
vim
wget

alsa-utils
pavucontrol-qt
pulseaudio
pulseaudio-alsa
pulseaudio-bluetooth

intel-media-driver
intel-gpu-tools
libva-intel-driver
libva-mesa-driver
libva-utils
libvdpau-va-gl
mesa-demos
vulkan-icd-loader
vulkan-intel
vulkan-radeon
xorg-server
xorg-xinit
xorg-xrandr

bluez
bluez-plugins
bluez-utils
networkmanager
networkmanager-openvpn
network-manager-applet
openvpn
systemd-resolvconf

exfatprogs
ntfs-3g

p7zip
unzip
unrar
zip

cups-pdf
foomatic-db-gutenprint-ppds
gutenprint
hplip

plasma
ark
dolphin
k3b
kamera
kate
kdegraphics-thumbnailers
kdesdk-kioslaves
kdesdk-thumbnailers
kfind
kimageformats
kio
kio-extras
kio-fuse
kmix
konsole
kwalletmanager
qt5-imageformats
spectacle
taglib

breeze-gtk
ccache
gnome-disk-utility
gparted
kdialog
nano-syntax-highlighting
neofetch
plasma-browser-integration
print-manager
simple-scan
system-config-printer
ttf-dejavu

audacious
digikam
ffmpeg
ffmpegthumbs
ffmpegthumbnailer
fluidsynth
fuseiso
gimp
kamoso
kate
kdenlive
kolourpaint
lame
mpv
obs-studio
okteta

aria2
firefox
gnome-calculator
gnome-keyring
gsmartcontrol
htop
jre11-openjdk
jsoncpp
krdc
libreoffice-fresh
love
okular
openssh
maxcso
noto-fonts-cjk
noto-fonts-emoji
persepolis
qbittorrent
freerdp
samba
seahorse
testdisk
v4l2loopback-dkms
xdelta3
xdg-desktop-portal
xdg-desktop-portal-kde
youtube-dl
zsync
)

grubinstall() {
    pacman -S --noconfirm --needed grub
    lsblk
    read -p "[Input] Disk? (/dev/sdX) " part
    read -p "[Input] Please enter encrypted partition (/dev/sdaX) " rootpart
    rootuuid=$(blkid -o value -s UUID $rootpart)
    swapuuid=$(findmnt -no UUID -T /swapfile)
    swapoffset=$(filefrag -v /swapfile | awk '{ if($1=="0:"){print $4} }')
    swapoffset=$(echo ${swapoffset//./})
    echo "[Log] Got UUID of root $rootpart: $rootuuid"
    echo "[Log] Got UUID of swap $swappart: $swapuuid"
    echo "[Log] Got resume offset: $swapoffset"
    echo "[Log] Run grub-install"
    grub-install $part --target=i386-pc
    echo "[Log] Edit /etc/default/grub"
    sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /etc/default/grub
    sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 splash nowatchdog rd.udev.log_priority=3 resume=UUID=$swapuuid resume_offset=$swapoffset\"|g" /etc/default/grub
    sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$rootuuid:lvm:allow-discards\"/" /etc/default/grub
    echo "[Log] Run grub-mkconfig"
    grub-mkconfig -o /boot/grub/grub.cfg
}

grubinstallia32() {
    pacman -S --noconfirm --needed grub efibootmgr
    lsblk
    read -p "[Input] Disk? (/dev/sdX) " read part
    read -p "[Input] Please enter swap partition (/dev/sdaX) " swappart
    swapuuid=$(blkid -o value -s UUID $swappart)
    echo "[Log] Got UUID of $swappart: $swapuuid"
    echo "[Log] Run grub-install"
    grub-install $part --target=i386-efi
    sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 splash nowatchdog rd.udev.log_priority=3 resume=UUID=$swapuuid\"|g" /etc/default/grub
    sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg
}

systemdinstall() {
    pacman -S --noconfirm --needed efibootmgr
    echo "[Log] run bootctl install"
    bootctl install
    lsblk
    read -p "[Input] Please enter encrypted partition (/dev/sdaX) " rootpart
    rootuuid=$(blkid -o value -s UUID $rootpart)
    swapuuid=$(findmnt -no UUID -T /swapfile)
    swapoffset=$(sudo filefrag -v /swapfile | awk '{ if($1=="0:"){print $4} }')
    swapoffset=$(echo ${swapoffset//./})
    echo "[Log] Got UUID of root $rootpart: $rootuuid"
    echo "[Log] Got UUID of swap $swappart: $swapuuid"
    echo "[Log] Got resume offset: $swapoffset"
    echo "[Log] Creating arch.conf entry"
    echo "title Arch Linux
    linux /vmlinuz-linux-lts
    initrd /amd-ucode.img
    initrd /intel-ucode.img
    initrd /initramfs-linux-lts.img
    options cryptdevice=UUID=$rootuuid:lvm:allow-discards resume=UUID=$swapuuid resume_offset=$swapoffset root=/dev/mapper/vg0-root rw loglevel=3 splash nowatchdog rd.udev.log_priority=3" > /boot/loader/entries/arch.conf
    echo "timeout 0
    default arch
    editor 0" > /boot/loader/loader.conf
}

setupstuff() {
    echo "[Log] nanorc"
    echo 'include "/usr/share/nano/*.nanorc"
    include "/usr/share/nano-syntax-highlighting/*.nanorc"' | tee /etc/nanorc

    echo "[Log] makepkg.conf"
    sed -i "s|BUILDENV=(!distcc color !ccache check !sign)|BUILDENV=(!distcc color ccache check !sign)|g" /etc/makepkg.conf
    sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j"$(nproc)"\"/" /etc/makepkg.conf
    sed -i "s|          'ftp::/usr/bin/curl -gqfC - --ftp-pasv --retry 3 --retry-delay 3 -o %o %u'|          'ftp::/usr/bin/aria2c -UWget -s4 %u -o %o'|g" /etc/makepkg.conf
    sed -i "s|          'http::/usr/bin/curl -gqb \"\" -fLC - --retry 3 --retry-delay 3 -o %o %u'|          'http::/usr/bin/aria2c -UWget -s4 %u -o %o'|g" /etc/makepkg.conf
    sed -i "s|          'https::/usr/bin/curl -gqb \"\" -fLC - --retry 3 --retry-delay 3 -o %o %u'|          'https::/usr/bin/aria2c -UWget -s4 %u -o %o'|g" /etc/makepkg.conf
    
    echo 'ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
    ACTION=="add|change", KERNEL=="sd[a-z]|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"' | tee /etc/udev/rules.d/60-ioschedulers.rules
    echo "vm.swappiness=10" | tee /etc/sysctl.d/99-swappiness.conf
    
    sed -i "s|ExecStart=/usr/lib/bluetooth/bluetoothd|ExecStart=/usr/lib/bluetooth/bluetoothd --noplugin=avrcp|g" /etc/systemd/system/bluetooth.service
}

# ----------------

echo "[Log] pacman.conf"
sed -i "s/#Color/Color/" /etc/pacman.conf
sed -i "s/#TotalDownload/TotalDownload\nILoveCandy/" /etc/pacman.conf
echo "[Log] Installing packages"
pacman -S --noconfirm --needed ${pacmanpkgs[*]}
echo "[Log] Setting locale"
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
locale-gen
echo "[Log] Time stuff"
ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
hwclock --systohc
echo "[Log] Running passwd"
passwd

if [[ ! -z /ia32 ]]; then
    echo "[Log] Setup grub ia32"
    grubinstallia32
    rm /ia32
else
    if [[ ! -z /fdisk ]]; then
        echo "[Log] Setup grub"
        grubinstall
        rm /fdisk
    else
        echo "[Log] Setup systemd-boot"
        systemdinstall
    fi
fi

echo "[Log] Edit mkinitcpio.conf"
sed -i "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block keyboard encrypt lvm2 resume filesystems fsck)/" /etc/mkinitcpio.conf
sed -i "s/MODULES=()/MODULES=(i915 ext4)/" /etc/mkinitcpio.conf
echo "options i915 enable_guc=2" | tee /etc/modprobe.d/i915.conf
echo "[Log] Run mkinitcpio"
mkinitcpio -p linux-lts

read -p "[Input] Enter hostname: " hostname
echo "[Log] Creating /etc/hostname"
echo $hostname > /etc/hostname
echo "[Log] hosts file"
echo -e "127.0.0.1 localhost.localdomain localhost
::1       localhost.localdomain localhost
127.0.1.1 localhost.localdomain $hostname" >> /etc/hosts
read -p "[Input] Enter username: " username
echo "[Log] Creating user $username"
useradd -m -g users -G audio,optical,storage,wheel -s /bin/bash $username
echo "[Log] Running passwd $username"
passwd $username
echo "[Log] Running visudo"
echo "%wheel ALL=(ALL) ALL" | EDITOR="tee -a" visudo
echo "[Log] Enabling services"
systemctl enable NetworkManager bluetooth cups fstrim.timer sddm

echo "[Log] Power management and lock"
echo 'HandlePowerKey=suspend
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=suspend
IdleAction=suspend
IdleActionSec=15min' | tee -a /etc/systemd/logind.conf

echo "[Log] Terminus font"
echo 'FONT=ter-p32n
FONT_MAP=8859-2' | tee /etc/vconsole.conf

read -p "[Input] Create /etc/X11/xorg.conf.d/30-touchpad.conf? (for laptop touchpads) (y/N) " touchpad
if [ $touchpad == y ] || [ $touchpad == Y ]; then
    echo "[Log] Creating /etc/X11/xorg.conf.d/30-touchpad.conf"
    echo 'Section "InputClass"
        Identifier "touchpad"
        Driver "libinput"
        MatchIsTouchpad "on"
        Option "Tapping" "on"
        Option "TappingButtonMap" "lrm"
        Option "NaturalScrolling" "true"
    EndSection' > /etc/X11/xorg.conf.d/30-touchpad.conf
fi

#echo "[Log] unmountonlogout"
#cat > /usr/bin/unmountonlogout << 'EOF'
cat > /dev/null << 'EOF'
#!/bin/bash
for device in /sys/block/*
do
    if udevadm info --query=property --path=$device | grep -q ^ID_BUS=usb
    then
        echo Found $device to unmount
        DEVTO=`echo $device|awk -F"/" 'NF>1{print $NF}'`
        echo `df -h|grep "$(ls /dev/$DEVTO*)"|awk '{print $1}'` is the exact device
        UM=`df -h|grep "$(ls /dev/$DEVTO*)"|awk '{print $1}'`
        if sudo umount $UM
        then echo Done umounting
        fi
    fi
done
EOF
#chmod +x /usr/bin/unmountonlogout
#sed -i "s/#session-cleanup-script=/session-cleanup-script=\/usr\/bin\/unmountonlogout/" /etc/lightdm/lightdm.conf
cat > /dev/null << 'EOF'
echo "[Log] reflector service"
echo '[Unit]
Description=Pacman mirrorlist update
Wants=network-online.target
After=network-online.target nss-lookup.target

[Service]
Type=oneshot
ExecStart=/usr/bin/reflector --verbose --country "Singapore" -l 5 --sort rate --save /etc/pacman.d/mirrorlist

[Install]
WantedBy=multi-user.target' | tee /etc/systemd/system/reflector.service
echo '[Unit]
Description=Run reflector weekly

[Timer]
OnCalendar=Mon *-*-* 7:00:00
RandomizedDelaySec=15h
Persistent=true

[Install]
WantedBy=timers.target' | tee /etc/systemd/system/reflector.timer
systemctl enable reflector.timer
EOF

setupstuff
echo "[Log] chroot script done"
