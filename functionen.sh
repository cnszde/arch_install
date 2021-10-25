#!/bin/bash
# Check of the system is a (U)efi System
efi() {
    if ! [ -d "/sys/firmware/efi" ]; then
        echo "Das ist keine UEFI-System, Abbruch"
        exit
    else
        clear
    fi
}

# Check the Blockdevice are sdX or nvme0
blockdevice() {
    if ! [ -d "/sys/block/nvme0n1" ]; then

        hd="sda"
        hd1="sda1"
        hd2="sda2"
        hd3="sda3"
    else
        hd="nvme0n1"
        hd1="nvme0n1p1"
        hd2="nvme0n1p2"
        hd3="nvme0n1p3"

    fi
}

# Partition the disks
# create a gpt partition
# create a 512 MB boot partition
# The rest is for the encrypted system
partition_lvm() {
    sgdisk /dev/$hd -o
    sgdisk /dev/$hd -n 1::+512MiB -t 1:ef00
    sgdisk /dev/$hd -n 2
}
partition() {
    sgdisk /dev/$hd -o
    sgdisk /dev/$hd -n 1::+512MiB -t 1:ef00
    sgdisk /dev/$hd -n 2::+8096MiB
    sgdisk /dev/$hd -n 3

}

# Encrypt the hard disk
crypt() {

    echo "The password must be entered a total of 3 times after confirming with 'YES'."
    read -p "Continue with Enter"
    cryptsetup -c aes-xts-plain64 -y -s 512 luksFormat /dev/$hd2
    read -p "Continue with Enter"
    cryptsetup luksOpen /dev/$hd2 lvm
}

#lvm, swap and mount
lvm() {
    pvcreate /dev/mapper/lvm
    vgcreate main /dev/mapper/lvm
    lvcreate -L 8G -n swap main
    lvcreate -L 50G -n root main
    lvcreate -l 100%FREE -n home main
    #Swap
    mkswap /dev/mapper/main-swap
    swapon /dev/mapper/main-swap
    # Formatieren und mounten
    mkfs.vfat /dev/$hd1
    mkfs.ext4 /dev/mapper/main-root
    mkfs.ext4 /dev/mapper/main-home
    mount /dev/mapper/main-root /mnt
    mkdir /mnt/boot
    mkdir /mnt/home
    mount /dev/$hd1 /mnt/boot
    mount /dev/mapper/main-home /mnt/home
}

no_lvm() {
    mkfs.vfat /dev/$hd1
    mkfs.ext4 /dev/$hd3
    mkswap /dev/$hd2
    swapon /dev/$hd2
    mount /dev/$hd3 /mnt
    mkdir /mnt/boot
    mount /dev/$hd1 /mnt/boot

}

# Grundsytem installieren
grundsystem() {
    pacstrap /mnt base base-devel linux linux-firmware networkmanager intel-ucode dhclient lvm2 iwd vim zsh git grml-zsh-config
}

#fstab erstellen und locale einrichten
fstab() {
    genfstab -p /mnt >/mnt/etc/fstab
}
locale() {
    echo $hostname >/mnt/etc/hostname
    echo "LANG=de_DE.UTF-8" >/mnt/etc/locale.conf
    echo "KEYMAP=de-latin1" >/mnt/etc/vconsole.conf
    echo "FONT=lat9w-16" >>/mnt/etc/vconsole.conf
    echo "de_DE.UTF-8 UTF-8" >/mnt/etc/locale.gen
    echo "de_DE ISO-8859-1" >>/mnt/etc/locale.gen
    echo "de_DE@euro ISO-8859-15" >>/mnt/etc/locale.gen
    arch-chroot /mnt /bin/bash locale-gen
    arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
EOF
}

# mkinitcpio anpassen (verbesserungswürdig!)
mkinitcpio() {
    sed -i "s/.*MODULES=().*/MODULES=(ext4 vmd )/g" /mnt/etc/mkinitcpio.conf
    sed -i "s/HOOKS=(.*)/HOOKS=(base udev block autodetect modconf keyboard keymap encrypt lvm2 filesystems fsck shutdown)/g" /mnt/etc/mkinitcpio.conf
}

crypt_bootloader() {
    # Bootloader
    arch-chroot /mnt /bin/bash <<EOF

    mkinitcpio -p linux

    bootctl install
    echo -e "
    title    Arch Linux
    linux    /vmlinuz-linux
    initrd   /intel-ucode.img
    initrd   /initramfs-linux.img
    options  cryptdevice=/dev/$hd2:main root=/dev/mapper/main-root rw lang=de init=/usr/lib/systemd/systemd locale=de_DE.UTF-8" > /boot/loader/entries/arch.conf

    echo -e "
    timeout 5
    default arch.conf "  > /boot/loader/loader.conf

EOF
}
grub_crypt () {
	arch-chroot /mnt /bin/bash <<EOF
pacman -S install grub-efi-x86_64 efibootmgr 
grub-install
echo "GRUB_CMDLINE_LINUX to GRUB_CMDLINE_LINUX="cryptdevice=/dev/$hd2:luks:allow-discards" >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
EOF
}


bootloader() {
    # Bootloader
    arch-chroot /mnt /bin/bash <<EOF

    mkinitcpio -p linux

    bootctl install
    echo -e "
    title    Arch Linux
    linux    /vmlinuz-linux
    initrd   /intel-ucode.img
    initrd   /initramfs-linux.img
    options  root=/dev/$hd3 rw lang=de init=/usr/lib/systemd/systemd locale=de_DE.UTF-8" > /boot/loader/entries/arch.conf

    echo -e "
    timeout 5
    default arch.conf "  > /boot/loader/loader.conf

EOF
}
# Dienste installieren und aktivieren
service() {
    curl -o /mnt/root/.zshrc https://raw.githubusercontent.com/grml/grml-etc-core/master/etc/zsh/zshrc
    arch-chroot /mnt /bin/bash <<EOF
    pacman -S  --noconfirm acpid dbus avahi cups
    systemctl enable acpid
    systemctl enable avahi-daemon
    systemctl enable NetworkManager.service
    systemctl enable --now systemd-timesyncd.service
    systemctl enable --now fstrim.timer
    systemctl enable cups.service
    ln -s /usr/bin/vim /usr/bin/vi
    chsh -s /usr/bin/zsh
EOF
}

# Keyboard einrichten
keyboard() {
    arch-chroot /mnt /bin/bash <<EOF
     echo -e "
     Section \"InputClass\"
     Identifier \"keyboard\"
     MatchIsKeyboard \"yes\"
     Option \"XkbLayout\" \"de\"
     Option \"XkbModel\" \"pc105\"
     Option \"XkbVariant\" \"deadgraveacute\"
     EndSection " > /etc/X11/xorg.conf.d/00-keyboard.conf
EOF
}
pw_root() {
    echo "Passwort für root eingeben"
    arch-chroot /mnt passwd root
    curl -o /mnt/root/.zshrc https://raw.githubusercontent.com/grml/grml-etc-core/master/etc/zsh/zshrc
}

user() {
    arch-chroot /mnt useradd -m -g users -s /usr/bin/zsh "$username"
    arch-chroot /mnt usermod -a -G video,audio,games,power,wheel $username
    echo "Passwort für $username vergeben"
    arch-chroot /mnt passwd $username
}

chaotic() {
    #chaotic-Aur hinzufügen
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

    echo "[multilib]" >>/etc/pacman.conf
    echo "Include = /etc/pacman.d/mirrorlist" >>/etc/pacman.conf
    echo "[chaotic-aur]" >>/etc/pacman.conf
    echo "Include = /etc/pacman.d/chaotic-mirrorlist" >>/etc/pacman.conf
    pacman -Syy
}

chaotic_sys() {
    arch-chroot /mnt pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    arch-chroot /mnt pacman-key --lsign-key 3056513887B78AEB
    arch-chroot /mnt pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

    echo "[multilib]" >>/mnt/etc/pacman.conf
    echo "Include = /etc/pacman.d/mirrorlist" >>/mnt/etc/pacman.conf
    echo "[chaotic-aur]" >>/mnt/etc/pacman.conf
    echo "Include = /etc/pacman.d/chaotic-mirrorlist" >>/mnt/etc/pacman.conf
}

gnome() {
    arch-chroot /mnt pacman -Sy --noconfirm xorg-server xorg-xinit alsa-utils \
        xf86-video-intel xf86-video-ati xf86-video-nouveau firefox firefox-i18n-de \
        ttf-bitstream-vera ttf-dejavu alsa-utils pulseaudio openssh aspell \
        aspell-de hunspell hunspell-de bluez bluez-utils bluez-hid2hci sof-firmware noto-fonts \
        pulseaudio-bluetooth mc yay pavucontrol gnome

    arch-chroot /mnt systemctl enable gdm.service

    arch-chroot /mnt /bin/bash <<EOF
     echo -e "
     Section \"InputClass\"
     Identifier \"keyboard\"
     MatchIsKeyboard \"yes\"
     Option \"XkbLayout\" \"de\"
     Option \"XkbModel\" \"pc105\"
     Option \"XkbVariant\" \"deadgraveacute\"
     EndSection " > /etc/X11/xorg.conf.d/00-keyboard.conf
EOF

}

kde() {
    arch-chroot /mnt pacman -Sy --noconfirm xorg-server xorg-xinit alsa-utils \
        xf86-video-intel xf86-video-ati xf86-video-nouveau firefox firefox-i18n-de \
        ttf-bitstream-vera ttf-dejavu alsa-utils pulseaudio openssh aspell \
        aspell-de hunspell hunspell-de bluez bluez-utils bluez-hid2hci sof-firmware noto-fonts \
        pulseaudio-bluetooth pavucontrol mc yay plasma-meta plasma konsole sddm

    arch-chroot /mnt systemctl enable sddm.service

    arch-chroot /mnt /bin/bash <<EOF
     echo -e "
     Section \"InputClass\"
     Identifier \"keyboard\"
     MatchIsKeyboard \"yes\"
     Option \"XkbLayout\" \"de\"
     Option \"XkbModel\" \"pc105\"
     Option \"XkbVariant\" \"deadgraveacute\"
     EndSection " > /etc/X11/xorg.conf.d/00-keyboard.conf
EOF
}

xfce() {
    arch-chroot /mnt pacman -Sy --noconfirm xorg-server xorg-xinit alsa-utils \
        xf86-video-intel xf86-video-ati xf86-video-nouveau firefox firefox-i18n-de \
        ttf-bitstream-vera ttf-dejavu alsa-utils pulseaudio openssh aspell \
        aspell-de hunspell hunspell-de bluez bluez-utils bluez-hid2hci sof-firmware noto-fonts \
        pulseaudio-bluetooth pavucontrol mc yay xfce4 xfce4-goodies sddm

    arch-chroot /mnt systemctl enable sddm.service

    arch-chroot /mnt /bin/bash <<EOF
     echo -e "
     Section \"InputClass\"
     Identifier \"keyboard\"
     MatchIsKeyboard \"yes\"
     Option \"XkbLayout\" \"de\"
     Option \"XkbModel\" \"pc105\"
     Option \"XkbVariant\" \"deadgraveacute\"
     EndSection " > /etc/X11/xorg.conf.d/00-keyboard.conf
EOF
}

deepin() {
    arch-chroot /mnt pacman -Sy --noconfirm xorg-server xorg-xinit alsa-utils \
        xf86-video-intel xf86-video-ati xf86-video-nouveau firefox firefox-i18n-de \
        ttf-bitstream-vera ttf-dejavu alsa-utils pulseaudio openssh aspell \
        aspell-de hunspell hunspell-de bluez bluez-utils bluez-hid2hci sof-firmware noto-fonts \
        pulseaudio-bluetooth mc yay pavucontrol deepin deepin-extra sddm

    arch-chroot /mnt systemctl enable sddm.service
    arch-chroot /mnt /bin/bash <<EOF
     echo -e "
     Section \"InputClass\"
     Identifier \"keyboard\"
     MatchIsKeyboard \"yes\"
     Option \"XkbLayout\" \"de\"
     Option \"XkbModel\" \"pc105\"
     Option \"XkbVariant\" \"deadgraveacute\"
     EndSection " > /etc/X11/xorg.conf.d/00-keyboard.conf
EOF
}

sway() {
    arch-chroot /mnt pacman -Sy --noconfirm xorg-server xorg-xinit alsa-utils \
        xf86-video-intel xf86-video-ati xf86-video-nouveau firefox firefox-i18n-de \
        ttf-bitstream-vera ttf-dejavu alsa-utils pulseaudio openssh aspell \
        aspell-de hunspell hunspell-de bluez bluez-utils bluez-hid2hci sof-firmware noto-fonts \
        pulseaudio-bluetooth mc yay sway waybar opendesktop-fonts nwg-launchers \
        mpd ncmpc elinks swayidle swaylock alacritty gnome-keyring grim otf-font-awesome \
        p7zip unrar pavucontrol pamixer light clipman autotiling mutt elinks blueman gksu \
        wofi dmenu playerctl mako clipman kanshi blueman

    cp -r config /mnt/home/$username/.config

    arch-chroot /mnt chown -R $username:users /home/$username/.config/
}
