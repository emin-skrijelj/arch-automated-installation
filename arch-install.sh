echo "Made by L3G4CY emin-skrijelj on github with a help of a friend Elf :)"
echo "\n"
echo "========================================"
echo "              Your username             "
echo "========================================"
read user
echo "========================================"
echo "            Password for user           "
echo "========================================"
read userpass
echo "========================================"
echo "              Root password             "
echo "========================================"
read rootpass
echo "========================================"
echo "                Hostname                "
echo "========================================"
read hostn
echo "========================================"
echo "            Select your device          "
echo "========================================"
lsblk
read devicename
echo "[+]Selected $devicename"

function make_efi()
{
    printf "g\nn\n\n\n+100MB\nyes\nt\n1\nn\n\n\n\n\nyes\nw\n" | fdisk $devicename
    export first_part="$devicename"1
    export second_part="$devicename"2
    mkfs.fat -F32 $first_part
    mkfs.ext4 $second_part
    mount $second_part /mnt
}

function make_mbr()
{
    printf "o\nn\np\n\n\n\nyes\na\nw\n" | fdisk $devicename
    export first_part="$devicename"1
    mkfs.ext4 $first_part
    mount $first_part /mnt
}

function configure_grub_bios()
{
    chroot /mnt /bin/bash -c "pacman -S grub --noconfirm"
    chroot /mnt /bin/bash -c "grub-install --target=i386-pc $devicename"
    chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
}

function configure_grub_efi()
{
    chroot /mnt /bin/bash -c "pacman -S efibootmgr grub --noconfirm"
    chroot /mnt /bin/bash -c "mkdir /boot/efi"
    chroot /mnt /bin/bash -c "mount $first_part /boot/efi"
    chroot /mnt /bin/bash -c "grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable"
    chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
}

[ -d /sys/firmware/efi ] && make_efi || make_mbr 

# give base 
pacstrap /mnt base linux linux-firmware vim nano 
genfstab -U /mnt >> /mnt/etc/fstab
cp /etc/resolv.conf /mnt/etc/resolv.conf

# mount chroot preps
mount --types proc /proc /mnt/proc
mount --rbind /sys /mnt/sys
mount --make-rslave /mnt/sys # rslave for systemd bind
mount --rbind /dev /mnt/dev
mount --make-rslave /mnt/dev # rslave for systemd bind

# Generate locales
echo 'en_US.UTF-8 UTF-8' >> /mnt/etc/locale.gen
chroot /mnt /bin/bash -c "locale-gen"

# Hostname
echo "Hostname"
echo "$hostn" > /mnt/etc/hostname 
cat >> /mnt/etc/hosts << EOF
127.0.0.1	localhost
::1	$hostn
127.0.1.1	$hostn
EOF

# Install sudo
chroot /mnt /bin/bash -c "pacman -S sudo --noconfirm"

# root password
chroot /mnt /bin/bash -c 'printf "$rootpass\n$rootpass\n" | passwd'

# Username
chroot /mnt /bin/bash -c "useradd -m -g users -G wheel $user"
chroot /mnt /bin/bash -c 'printf "$userpass\n$userpass\n" | passwd $user'
echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers

[ -d /sys/firmware/efi ] && configure_grub_efi || configure_grub_bios

# install tools
chroot /mnt /bin/bash -c "pacman -S xorg xorg-xinit pulseaudio pavucontrol git base-devel --noconfirm"
chroot /mnt /bin/bash -c "pacman -S feh firefox discord wireshark-qt metasploit python-pip code flameshot obs-studio nasm neofetch linux-headers ghidra noto-fonts-emoji --noconfirm"

# install xfce4
chroot /mnt /bin/bash -c "pacman -S xfce4 xfce4-goodies --noconfirm"

# Display manager
chroot /mnt /bin/bash -c "pacman -S lightdm-gtk-greeter --noconfirm"
chroot /mnt /bin/bash -c "systemctl enable lightdm.service"

# enable NetworkManager
chroot /mnt /bin/bash -c "pacman -S networkmanager network-manager-applet --noconfirm"
chroot /mnt /bin/bash -c "systemctl enable NetworkManager.service"

reboot
