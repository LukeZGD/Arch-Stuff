#!/bin/bash

pacman=(
base-devel
fish
intel-ucode
linux-firmware
linux-zen
linux-zen-headers
nano
usbutils

dialog
git
neofetch
rsync
pacman-contrib
wget

alsa-utils
pavucontrol
pulseaudio
pulseaudio-alsa
pulseaudio-bluetooth

lightdm
lightdm-gtk-greeter
lightdm-gtk-greeter-settings
xfce4
xfce4-goodies
xorg-server
xorg-xinit
xorg-xrandr
xsecurelock

networkmanager
network-manager-applet

bluez
bluez-plugins
bluez-utils
blueman

exfat-utils
gnome-disk-utility
gparted
gvfs
gvfs-afc
gvfs-gphoto2
ntfs-3g

ark
p7zip
zip
unzip
unrar

papirus-icon-theme

cups-pdf
foomatic-db-gutenprint-ppds
gutenprint
hplip
simple-scan
system-config-printer

audacious
audacity
ffmpeg
ffmpegthumbnailer
fluidsynth
handbrake
kdenlive
kolourpaint
lame
mcomix
mpv
nemo
notepadqq
obs-studio
okteta
openshot
pinta

gnome-keyring
seahorse

galculator
gsmartcontrol
htop
ifuse
jre8-openjdk
love
openssh
noto-fonts-cjk
noto-fonts-emoji
qbittorrent
samba
testdisk
xfburn
)

function grubinstall {
  pacman -S --noconfirm grub
  lsblk
  echo "[Input] Disk? (/dev/sdX)"
  read part
  echo "[Input] Please enter encrypted partition (/dev/sdaX)"
  read rootpart
  rootuuid=$(blkid -o value -s UUID $rootpart)
  echo "[Log] Got UUID of $rootpart: $rootuuid"
  echo "[Log] Run grub-install"
  grub-install $part --target=i386-pc
  echo "[Log] Edit /etc/default/grub"
  sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /etc/default/grub
  sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet resume=/dev/mapper/vg0-swap\"|g" /etc/default/grub
  sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$rootuuid:lvm:allow-discards\"/" /etc/default/grub
  echo "[Log] Run grub-mkconfig"
  grub-mkconfig -o /boot/grub/grub.cfg
}

function grubinstallia32 {
  pacman -S --noconfirm grub
  lsblk
  echo "[Input] Disk? (/dev/sdX)"
  read part
  echo "[Input] Please enter swap partition (/dev/sdaX)"
  read swappart
  swapuuid=$(blkid -o value -s UUID $swappart)
  echo "[Log] Got UUID of $swappart: $swapuuid"
  echo "[Log] Run grub-install"
  grub-install $part --target=i386-efi
  sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet resume=UUID=$swapuuid\"|g" /etc/default/grub
  sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/" /etc/default/grub
  grub-mkconfig -o /boot/grub/grub.cfg
}

function systemdinstall {
  echo "[Log] run bootctl install"
  bootctl install
  lsblk
  echo "[Input] Please enter encrypted partition (/dev/sdaX)"
  read rootpart
  rootuuid=$(blkid -o value -s UUID $rootpart)
  echo "[Log] Got UUID of $rootpart: $rootuuid"
  echo "[Log] Creating arch.conf entry"
  echo "title Arch Linux
linux /vmlinuz-linux-zen
initrd /intel-ucode.img
initrd /initramfs-linux-zen.img
options cryptdevice=UUID=$rootuuid:lvm:allow-discards resume=/dev/mapper/vg0-swap root=/dev/mapper/vg0-root rw quiet" > /boot/loader/entries/arch.conf
	echo "timeout 0
default arch
editor 0" > /boot/loader/loader.conf
}

echo "[Log] Installing packages"
pacman -S --noconfirm ${pacman[*]}
echo "[Log] Setting locale"
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "[Log] Time stuff"
ln -sf /usr/share/zoneinfo/Hongkong /etc/localtime
hwclock --systohc
echo "[Log] hosts file"
echo "127.0.0.1 localhost" >> /etc/hosts
echo "[Log] Running passwd"
passwd

if [ -f /ia32 ]; then
  echo "[Log] Installing grub"
  grubinstallia32
  rm /ia32
else
  echo "[Input] Select boot manager (grub for legacy, systemd-boot for UEFI)"
  select opt in "grub" "systemd-boot"; do
  case $opt in
    "grub" ) grubinstall; break;;
    "systemd-boot" ) systemdinstall; break;;
  esac
  done
fi

echo "[Log] Edit mkinitcpio.conf"
sed -i "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block keyboard encrypt lvm2 resume filesystems fsck)/" /etc/mkinitcpio.conf
sed -i "s/MODULES=()/MODULES=(ext4)/" /etc/mkinitcpio.conf
echo "[Log] Run mkinitcpio"
mkinitcpio -p linux-zen

echo "[Input] Enter hostname"
read hostname
echo "[Log] Creating /etc/hostname"
echo $hostname > /etc/hostname
echo "[Input] Enter username"
read username
echo "[Log] Creating user $username"
useradd -m -g users -G wheel,audio -s /usr/bin/fish $username
echo "[Log] Running passwd $username"
passwd $username
echo "[Input] Create 2nd user account? (with no wheel/sudo) (y/n)"
read userc2
if [ $userc2 == y ] || [ $userc2 == Y ]; then
  echo "[Input] Enter username"
  read username2
  echo "[Log] Creating user $username2"
  useradd -m -g users -G audio -s /usr/bin/fish $username2
  echo "[Log] Running passwd $username2"
  passwd $username2
fi
echo "[Log] Running visudo"
echo "%wheel ALL=(ALL) ALL" | EDITOR="tee -a" visudo
echo "[Log] Enabling services"
systemctl enable lightdm NetworkManager bluetooth org.cups.cupsd

echo "[Input] Create /etc/X11/xorg.conf.d/30-touchpad.conf? (for laptop touchpads) (y/N)"
read touchpad
if [ $touchpad == y ] || [ $touchpad == Y ]; then
  echo "[Log] Creating /etc/X11/xorg.conf.d/30-touchpad.conf"
  echo 'Section "InputClass"
  Identifier "touchpad"
  Driver "libinput"
  MatchIsTouchpad "on"
  Option "Tapping" "on"
  Option "TappingButtonMap" "lmr"
EndSection' > /etc/X11/xorg.conf.d/30-touchpad.conf
fi

echo "[Log] Configuring unmountonlogout"
cat > /usr/bin/unmountonlogout << 'EOF'
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
chmod +x /usr/bin/unmountonlogout
sed -i "s/#session-cleanup-script=/session-cleanup-script=\/usr\/bin\/unmountonlogout/" /etc/lightdm/lightdm.conf

echo "[Log] Configuring rc-local"
echo '[Unit]
Description=/etc/rc.local compatibility

[Service]
Type=oneshot
ExecStart=/etc/rc.local
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target' | tee /usr/lib/systemd/system/rc-local.service
echo '#!/bin/bash
echo 0,0,345,345 | sudo tee /sys/module/veikk/parameters/bounds_map
exit 0' | tee /etc/rc.local
chmod +x /etc/rc.local

echo "[Log] Configuring power management and lock"
pacman -R --noconfirm xfce4-screensaver
echo 'HandlePowerKey=suspend
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
IdleAction=suspend
IdleActionSec=30min' | tee -a /etc/systemd/logind.conf
echo "[Unit]
Description=Lock the screen on resume from suspend

[Service]
User=$username
Environment=DISPLAY=:0
Environment=\"XSECURELOCK_SWITCH_USER_COMMAND='dm-tool switch-to-greeter'\"
Environment=\"XSECURELOCK_SHOW_DATETIME=1\"
ExecStart=/usr/bin/xsecurelock

[Install]
WantedBy=suspend.target" | tee /etc/systemd/system/lock.service

echo "[Log] lightdm-gtk-greeter.conf"
echo '[greeter]
theme-name = Adwaita-dark
icon-theme-name = Papirus-Dark
font-name = Cantarell 20
background = /usr/share/backgrounds/adapta/tealized.jpg
user-background = false' > /etc/lightdm/lightdm-gtk-greeter.conf

echo "[Log] Enabling new services"
systemctl enable rc-local lock
echo "[Log] Removing chroot.sh"
rm /chroot.sh