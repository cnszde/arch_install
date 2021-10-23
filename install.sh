#!/bin/bash
#    version         ${arch_install.sh} (https://github.com/cnszde/arch_install.git) 0.0.2
#    author          Christian Schnitz <cs@cschnitz.eu>
#    copyright       Copyright (c) Christian Schnitz
#    license         MIT License

source ./functionen.sh

# UEFI or BIOS? If the System a BIOS-System then break this scriptS
efi

# Detect the hard disks
blockdevice

# Ein paar Sachen Abragen
echo "Dieses Script installiert Archlinux entweder verschlüsselt (Empfohlen) oder unverschlüsselt!"
echo ""
echo "Es wird nicht mit Dualboot (anderes Linux / Windows) funktionieren, da die gesamte"
echo "Festplatte benutzt werden wird."
echo "Ein paar kleinigkeiten werden vorher abgefragt."
while true; do
    read -r -p "Fortfahren? [Y/n] " input
    case $input in
    [yY][eE][sS] | [yY])
        break
        ;;
    [nN][oO] | [nN])
        echo "Programm abgebrochen"
        exit
        ;;
    *)
        echo "Falsche Eingabe!"
        ;;
    esac
done

while true; do
    read -r -p "Festplatte verschlüsseln? [Y/n] " input
    case $input in
    [yY][eE][sS] | [yY])
        crypt="yes"
        break
        ;;
    [nN][oO] | [nN])
        crypt="no"
        break
        ;;
    *)
        echo "Falsche Eingabe!"
        ;;
    esac
done
read -p "Wie soll der Hostname lauten? " hostname
read -p "Wie soll der Benutzer heißen? " username
PS3="Welcher Desktop soll installiert werden? "
select desktop in KDE Gnome Xfce Deepin Sway Keiner; do
    case $desktop in
    "KDE")
        break
        ;;
    "Gnome")
        break
        ;;
    "Xfce")
        break
        ;;
    "Deepin")
        break
        ;;
    "Sway")
        break
        ;;
    "Keiner")
        break
        ;;
    *) echo "Auswahl nicht möglich $REPLAY" ;;
    esac

done
clear
echo "Zusammenfassung: "
if [ $crypt == "yes" ]; then
    echo "Archlinux wird verschlüsselt auf $hd installiert"
    echo "Der Hostname lautet: $hostname"
    echo "Der Benutzername lautet: $username"
    echo "und es soll $desktop installiert werden"
    while true; do
        read -r -p "Fortfahren? [Y/n] " input

        case $input in
        [yY][eE][sS] | [yY])
            # Dieses Zeug wird aus der functionen.sh geholt
            partition_lvm
            crypt
            lvm
            grundsystem
            fstab
            locale
            mkinitcpio
            crypt_bootloader
            service
            pw_root
            user
            chaotic
            chaotic_sys
            if [ $desktop = KDE ]; then kde; fi
            if [ $desktop = Gnome ]; then gnome; fi
            if [ $desktop = Xfce ]; then xfce; fi
            if [ $desktop = Deepin ]; then deepin; fi
            if [ $desktop = Sway ]; then sway; fi
            if [ $desktop = Keiner ]; then echo ""; fi
            break
            ;;
        [nN][oO] | [nN])
            echo "Programm abgebrochen"
            break
            ;;
        *)
            echo "Falsche Eingabe!"
            ;;
        esac
    done
else
    echo "Archlinux wird unverschlüsselt auf $hd installiert"
    echo "Der Hostname lautet: $hostname"
    echo "Der Benutzername lautet: $username"
    echo "und es soll $desktop installiert werden"
    while true; do
        read -r -p "Fortfahren? [Y/n] " input

        case $input in
        [yY][eE][sS] | [yY])
            partition
            no_lvm
            grundsystem
            fstab
            locale
            bootloader
            service
            pw_root
            user
            chaotic
            chaotic_sys
            if [ $desktop = KDE ]; then kde; fi
            if [ $desktop = Gnome ]; then gnome; fi
            if [ $desktop = Xfce ]; then xfce; fi
            if [ $desktop = Deepin ]; then deepin; fi
            if [ $desktop = Sway ]; then sway; fi
            if [ $desktop = Keiner ]; then echo ""; fi
            break
            ;;
        [nN][oO] | [nN])
            echo "Programm abgebrochen"
            break
            ;;
        *)
            echo "Falsche Eingabe!"
            ;;
        esac
    done
fi
clear

echo "Die Installation ist nun abgeschlossen."
while true; do
    read -r -p "Soll der Computer neu gestartet werden? [Y/n] " input
    case $input in
    [yY][eE][sS] | [yY])
        reboot
        break
        ;;
    [nN][oO] | [nN])
        echo "Programm abgebrochen"
        exit
        ;;
    *)
        echo "Falsche Eingabe!"
        ;;
    esac
done


