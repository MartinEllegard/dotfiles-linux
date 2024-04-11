

LINK TO SOURCE = https://www.reddit.com/r/Gentoo/comments/150r74m/guide_hyprland_nvidia_extremely_minimal_gentoo/
Please check the comments too for additional information! This guide covers the parts after chrooting.

ALL OF THE LINKS ARE UPDATED WITH GITHUB GISTS. SO LINKS WON'T BE BROKEN AGAIN.

OpenRC package is updated. Enable sysvinit useflag. You can disable all others.

NOTHING IN THIS GUIDE IS A RECOMMENDATION! THIS IS FOR THE PEOPLE WHO ALREADY WANT TO DO THIS.
GUIDE

Since we are on a new environment, we need to source it and we need to know that we are in a chrooted environment just in case:

source /etc/profile && export PS1="(chroot) ${PS1}"

We need to mount our boot partition in order to put the Gentoo kernel in it. The disk should be GPT-Labeled and the partition label must be "EFI Partition" and the file system must be FAT32. This should be a very "minimal" Gentoo installation. So we won't use a bootloader. We'll use efistub instead that I'll explain later:

mount /dev/nvme0n1p1 /boot --> </dev/nvme0n1p1> should change with your boot partition.

We will use the below variables in order to configure our system easier.

PARTITION_ROOT=$(findmnt -n -o SOURCE /) 
PARTITION_BOOT=$(findmnt -n -o SOURCE /boot)  
UUID_ROOT=$(blkid -s UUID -o value $PARTITION_ROOT) 
UUID_BOOT=$(blkid -s UUID -o value $PARTITION_BOOT) 
PARTUUID_ROOT=$(blkid -s PARTUUID -o value $PARTITION_ROOT)
read -p "Enter the timezone (eg. Europe/Berlin): " time_zone

while true; do
    read -p "Enter the new username: " username
    if [[ "$username" =~ ^[a-zA-Z0-9_]+$ ]]; then
        break
    else
        echo "Invalid username. Only alphanumeric characters and underscores are allowed."
    fi
done

while true; do
    read -s -p "Enter the new password: " password
    echo
    read -s -p "Confirm the new password: " password2
    echo
    if [[ "$password" = "$password2" ]]; then
        if [[ "$password" =~ ^[a-zA-Z0-9_]+$ ]]; then
        break
        else
            echo "Invalid password. Only alphanumeric characters and underscores are allowed."
        fi
    else
        echo "Passwords do not match, please try again"
    fi
done

We need to sync the Gentoo repository:

emerge --sync --quiet

We will set our locale settings:

We basically remove the comment (#) before our locales with the below command.

sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen

Then generate and set locales:

locale-gen

eselect locale set en_US.utf8

This below is not directly needed but is a good practice to reinforce our locale settings in order to prevent problems later :

echo "LC_COLLATE=\"C.UTF-8\"" >> /etc/env.d/02locale

Now we update our environment again with:

env-update && source /etc/profile && export PS1="(chroot) ${PS1}"

Now we will set our Portage environment for:

We need to install a program in order to find our CPU flags.

emerge cpuid2cpuflags

The below code uses the above program to find flags then prepare it for make.conf file then add the related flags in proper form to the end of the file. ">>" is for adding at the end of the file while preserving the file's content. ">" on the other hand would have deleted the file's content and only added the below output in it.

cpuid2cpuflags | sed 's/:\s/="/; s/$/"/' >> /etc/portage/make.conf

We need to accept licenses in order to install software with various licenses. If you are a "license extremist" you can set this for each package one by one. For now we use a global setting to accept all licenses. Backslashes are needed for writing the actual quotes. This is called escaping. Otherwise the quotes are interpreted as a part of the echo command rather than actual quotes. We use escaping for special characters in general:

echo "ACCEPT_LICENSE=\"*\"" >> /etc/portage/make.conf

This below is self explanatory:

echo "VIDEO_CARDS=\"nvidia\"" >> /etc/portage/make.conf

Some portage settings:

With below variable, portage will use all cores and threads on our system. Threads are detected with the command "nproc".

echo "MAKEOPTS=\"-j$(nproc) -l$(nproc)\"" >> /etc/portage/make.conf

Portage niceness setting is not preferred anymore so we will add a scheduling priority. With this config, portage will have no priority and you can use your computer however you want while compiling stuff. You can check out: Portage Niceness:

echo "PORTAGE_SCHEDULING_POLICY=\"idle\"" >> /etc/portage/make.conf

These are good defaults for "emerge". So we don't have to write these every time we need to use emerge. We will only specify what we need such as --update (to update our software) or --depclean (to remove software) or nothing most of the time. Additionally, jobs and load average are important indicators. They show that we will compile multiple programs (as much as our thread count) at the same time when we can.

echo "EMERGE_DEFAULT_OPTS=\"--jobs=$(nproc) --load-average=$(nproc) --keep-going --verbose --quiet-build --with-bdeps=y --complete-graph=y --deep --ask\"" >> /etc/portage/make.conf

We will accept rolling release packages in order to compile Hyprland. If you don't like using rolling release packages you can set it for each package one by one just like licenses. But we will keep the guide shorter. We also indicate our targets. These targets are the newest ones that are supported by every package at the moment. So indicating these will prevent installing multiple versions of these targets. We don't want to use multiple versions of Python for example. EOF (probably short version of End Of File) is used for pasting multiple line strings easily. The arrows pointing to cat shows that we will see the content of the file we show (the things we write here) and the arrows pointing to the make.conf is used to put the content inside the file :

cat << EOF >> /etc/portage/make.conf
ACCEPT_KEYWORDS="~amd64"
RUBY_TARGETS="ruby31"
RUBY_SINGLE_TARGET="ruby31"
PYTHON_TARGETS="python3_11"
PYTHON_SINGLE_TARGET="python3_11"
LUA_TARGETS="lua5-4"
LUA_SINGLE_TARGET="lua5-4"
EOF

We will use some default Portage Features. You don't need to use any of these. You can look at the Portage manual for detailed description. They are mostly self explanatory:

echo "FEATURES=\"candy fixlafiles unmerge-orphans noman nodoc noinfo notitles parallel-install parallel-fetch clean-logs\" >> /etc/portage/make.conf

We will set our global use flags. "-*" means disabling every use flag, even default ones. We will just use the ones we need. "minimal" use flag is for packages that offer them. If we can use the minimal version, we will. If we need to disable this flag, portage will warn us like this: "In order to emerge the package A you need to disable "minimal" use flag for package B." so it's safe to use. Native-symlinks is a good flag if we compile Clang for example. lto pgo jit xs orc threads asm openmp: These are all performance related optimization flags. If a package offers them, we will use. system-* use flag is for using the packages we already have in our "system" instead of downloading extra ones. Hyprland comes with vulkan support by default and it's a good renderer when it's offered. We also use opengl when it's needed. Clang use flag is only offered when it's recommended so we enable if a package has clang use flag (such as libreoffice or firefox):

echo "USE=\"-* minimal wayland pipewire vulkan clang qt6 native-symlinks lto pgo jit xs orc threads asm openmp system-man system-libyaml system-lua system-bootstrap system-llvm system-lz4 system-sqlite system-ffmpeg system-icu system-av1 system-harfbuzz system-jpeg system-libevent system-librnp system-libvpx system-png system-python-libs system-webp system-ssl system-zlib system-boost\"" >> /etc/portage/make.conf

We will change our COMMON_FLAGS for compiling. We basically add "-march=native" here:

sed -i "s/COMMON_FLAGS=.*/COMMON_FLAGS=\"-march=native -O2 -pipe\"/g" make.conf

We will also add safe default LDFLAGS. We use "sed" command in order to put the LDFLAGS just below FFLAGS. "a\" means new line:

sed -i '/^FFLAGS/ a\LDFLAGS=\"-Wl,-O2 -Wl,--as-needed\"' /etc/portage/make.conf

We will add RUSTFLAGS. These are used for packages needing Rust such as Firefox. We simply add optimizations. Mostly self explanatory but you can look these up if you wonder about them:

sed -i '/^LDFLAGS/ a\RUSTFLAGS=\"-C debuginfo=0 -C codegen-units=1 -C target-cpu=native -C opt-level=3\"' /etc/portage/make.conf

First we remove the directory and instead use a text file for package.use

rm -rf /etc/portage/package.use

The below are the use flags that we need and flags I have thoroughly tested. I'll try to create a convenient use flags file for everyone. You can later modify small parts or arrange the structure of the file. Here are use flags and explanations: package.use These may seem a lot at first. But actually, Portage enables much more of them by default. Since we removed all flags; we added what we needed. Not all of these are enabled by the way. For some of them, you actually need to "emerge" them yourself. I just added some settings for convenience. You can try to disable some of them or enable more of them on your setup later:

curl -L https://gist.githubusercontent.com/emrakyz/0361625a94f5317345b8a7934dbb350b/raw/c28c982bf681436eaec846a80dce2890356584af/package.use -o /etc/portage/package.use

Make sure that no directory is present for package.accept_keywords

rm -rf /etc/portage/package.accept_keywords

Then we need to enable some packages' live versions because especially Hyprland develops fast and package maintainers can't keep up with updates. We also enable live for qbittorrent since it's the only version supporting Wayland (if you want to compile it later). You can later change versions for your liking, these packages are not critical:

curl -L https://gist.githubusercontent.com/emrakyz/7cd145c59e431046ecaea0666ce6d734/raw/894ab89518e6c33719c6208155b6de90c3c81ac5/package.accept_keywords -o /etc/portage/package.accept_keywords

We need to unmask qt6 use flag since it's needed:

echo "-qt6" > /etc/portage/profile/use.mask

Then unmask related packages along with use flags:

echo "dev-qt/qtgui
dev-qt/qtchooser
dev-qt/qtdbus
dev-qt/qtcore
dev-qt/qtbase
dev-qt/qtwayland
dev-qt/qtdeclarative
dev-qt/qtshadertools
dev-qt/qtsvg
dev-qt/qttools
dev-qt/qt5compat
dev-qt/qtimageformats
media-video/ffmpeg
virtual/rust
dev-lang/rust" > /etc/portage/profile/package.unmask

We can (optionally) create a compiler environment for Firefox. We basically create an environment inside "env" directory then we enable that environment for the firefox package. These flags are known to be safe for Firefox. Do not use them with other critical packages. It includes O3 and some additional flags that I had tested to confirm increased performance:

mkdir -p /etc/portage/env

curl -L https://gist.githubusercontent.com/emrakyz/23bf6fe9c30aa0b1eb88021889750ace/raw/832a0160ac0d0383c4f600da5cf8af4290019ff6/compiler-firefox -o /etc/portage/env/compiler-firefox

echo "www-client/firefox compiler-firefox" > /etc/portage/package.env

We would add one more variable for our CPU microcode but we need to update our system first. We only use update and newuse options since we showed others inside make.conf.

emerge --update --newuse @world

Now we check if some packages need to be compiled again for their preserved files:

emerge @preserved-rebuild

Now we remove old and unrelated packages

emerge --depclean

We have our timezone variable. Now we use it to set the time zone:

rm /etc/localtime

echo "$time_zone" > /etc/timezone

emerge --config sys-libs/timezone-data

Since we probably updated GCC, we will renew our environment again:

env-update && source /etc/profile && export PS1="(chroot) ${PS1}"

Now we need to learn our CPU microcode ID. So we need to install intel-microcode (amd users need to rely on the microcode page on Wiki):

This is temporal. We need -S option at first, after learning our signature, we'll change this.

echo "MICROCODE_SIGNATURES=\"-S\"" >> /etc/portage/make.conf

emerge intel-microcode

Now we need to learn our microcode signature:

SIGNATURE=$(iucode_tool -S 2>&1 | grep -o "0.*$")

Then we use that to change our related string:

sed -i "s/MICROCODE_SIGNATURES=\"-S\"/MICROCODE_SIGNATURES=\"-s $SIGNATURE\"/" /etc/portage/make.conf

Now we can emerge microcode again with our modified setting. This is important for efistub method:

emerge intel-microcode

Now let's install linux-firmware. We will temporarily disable a use flag because we don't have the kernel configuration yet.

USE="-compress-xz" emerge linux-firmware

Now we will find our GPU ID then we will keep GPU related firmware and delete the other ones.

pciutils is needed in order to find our GPU ID. Then we will strip the output of lspci command to get what we need (just the cpu ID such as tu104 for RTX 2080). Then we delete all other files inside linux-firmware (there are tons of). So basically, this goes into the savedconfig file that has the names of all installed firmware. Then it deletes everything except $GPU_CODE. For example it deletes every line that doesn't start with "nvidia/tu104". So when we recompile linux-firmware package, the files corresponding to the lines in the savedconfig stay and others are deleted.

emerge --oneshot pciutils
GPU_CODE=$(lspci | grep -i 'vga\|3d\|2d' | awk -F'[[]' '{print $1}' | awk '{print $NF}' | tr '[:upper:]' '[:lower:]')
sed -i "/^nvidia\/\($GPU_CODE\)/!d" /etc/portage/savedconfig/sys-kernel/linux-firmware-*

Now we will solve the dependency problems for freetype. Freetype needs to be compiled first without harfbuzz support because of the circular dependency. Then it should be compiled again with harfbuzz. The dependencies will install freetype with harfbuzz support later.

USE="-harfbuzz" emerge --oneshot freetype

emerge --oneshot freetype

Now we compile our kernel. You can check my kernel configuration and use it as a baseline. We'll just modify some parts. If the link for the kernel doesn't work, then please check the comments: My Minimal Kernel Config

My configuration does the following:

1) It's an extremely minimal kernel configuration. It only has what we need. Its binary size is 3mb.

2) It has all performance related options for network and computer hardware.

3) It has some INTEL related options. AMD users need to use "make menuconfig" inside the kernel source directory and make related changes. Since there aren't many options enabled, you can easily find and change them.

4) It has everything that we need to boot with UEFI environment using Wayland and Nvidia.

5) USB Audio devices (even wireless ones except bluetooth), external HDDs, USB mouses and keyboards, ethernet connection work. If you have other sophisticated hardware you need to enable them yourself.

6) You need to change the ethernet or network driver with your driver.

7) This kernel can be compiled in seconds with modern hardware since it's very minimal.

Let's start:

emerge gentoo-sources

We'll go to the kernel directory:

cd /usr/src/linux

We'll install my kernel configuration as a "base" then we modify it:

curl -L https://gist.githubusercontent.com/emrakyz/0ff8674792bd844fcab6afb2063ffa94/raw/e91e60ae2f74ccee8fcd7b7b93db942ba60277ce/.config -o .config

Now we will use one of the variables we had at first. We need PARTUUID of our root partition. We will add it inside the kernel directory in order to boot directly from the kernel using efistub. This command will change my PARTUUID with yours:

sed -i -e '/^CONFIG_CMDLINE="root=PARTUUID=.*/c\' -e "CONFIG_CMDLINE=\"root=PARTUUID=$PARTUUID_ROOT\"" /usr/src/linux/.config

Now we also need to change the intel-microcode directory with yours (AMD users need to follow the microcode page on Gentoo Wiki):

First we learn our microcode path. It is like this: "intel-ucode/06-9e-0c". It can give an unrelated output. Just ignore it. Kernel needs the directory path and this command will get the correct path inside the variable, then we use that variable for the kernel configuration file.

MICROCODE_PATH=$(iucode_tool -S -l /lib/firmware/intel-ucode/* 2>&1 | grep 'microcode bundle' | awk -F': ' '{print $2}' | cut -d'/' -f4-)

Then we change the related configuration with your microcode directory. We use # as a delimeter because our replacement string has a forward slash. If we use forward slash as a delimeter sed get confused with our replacement string:

sed -i "s#CONFIG_EXTRA_FIRMWARE=.*#CONFIG_EXTRA_FIRMWARE=\"$MICROCODE_PATH\"#g" /usr/src/linux/.config

Now we get our number of threads then we'll add it inside kernel configuration:

THREAD_NUM=$(nproc)

sed -i "s#CONFIG_NR_CPUS=.*#CONFIG_NR_CPUS=$THREAD_NUM#g" /usr/src/linux/.config

Now we have everything ready. You can make your small kernel modifications now:

make menuconfig

Important settings are:

All EFI settings are needed for UEFI motherboards, booting with Nvidia and efistub.

CONFIG_DRM is needed for booting with Wayland using Nvidia.

Simple Framebuffer Support is "indirectly" needed --AS A MODULE-- because we need DRM_KMS_HELPER (we can't directly enable this).

MTRR and x86 Pat is needed for Nvidia GPUs. Actually, only Pat is needed but MTRR is a dependency in the kernel.

MTRR Cleanup Support is DEPRECATED. Do not enable it.

If you use SATA Drive, you need to enable support for it. I currently only enable support for NVME SSDs and SCSI disks.

Keyboards and Mouse settings look like being disabled. They are not. USB and EVDEV drivers are enough for them to work. Those settings are for specific drivers and 99% people do not need it. If you still use optical keyboards or mouses in 2023, then you probably know what to enable yourself.

Now you can compile the kernel:

make -j$(nproc)

Install the nvidia drivers along with linux firmware because we change its settings. By the way, every time you install a new kernel you need to emerge nvidia-drivers again but not the linux-firmware:

emerge nvidia-drivers linux-firmware

If you see "* IMPORTANT: config file needs updating" you just need to enter dispatch-conf and then choose Zap New.

Now install the related kernel modules:

make modules_install

Create a directory in the boot partition for our motherboard to see then copy the compiled kernel binary into it. The below created directory is the safest one, other directories sometimes are not detected by all motherboards:

mkdir -p /boot/EFI/BOOT && cp /usr/src/linux/arch/x86/boot/bzImage /boot/EFI/BOOT/BOOTX64.EFI

We will now create the /etc/fstab file automatically.

echo "UUID=$UUID_BOOT /boot vfat defaults,noatime 0 2
UUID=$UUID_ROOT / ext4 defaults,noatime 0 1" > /etc/fstab

Modify the hostname:

sed -i "s/hostname=.*/hostname=\"$username\"/g" /etc/conf.d/hostname

Set up the internet and modify /etc/hosts:

emerge net-misc/dhcpcd 
rc-update add dhcpcd default 
rc-service dhcpcd start

echo -e "127.0.0.1\t$username\tlocalhost
::1\t\t$username\tlocalhost" > /etc/hosts

You can add a blacklist into /etc/hosts consisting from adware, malware, ads, fake news and gambling sites. So these sites won't open for you. It basically works like adblocking. Check out StevenBlack/Hosts on GitHub. Since the files' first 40 lines are not related we will only get the lines after them:

curl -s https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling/hosts | tail -n +40 >> /etc/hosts

Remove the hard pass requirement if you want:

sed -i 's/enforce=everyone/enforce=none/g' /etc/security/passwdqc.conf

Change the root password with the password you have given while starting this guide:

echo "root:$password" | chpasswd

Change the system clock to local clock.

sed -i 's/clock=.*/clock=\"local\"/g' /etc/conf.d/hwclock

(Optional) Change DNS server to Quad9.

echo "nameserver 9.9.9.9
nameserver 149.112.112.112" > /etc/resolv.conf

echo "nohook resolv.conf" >> /etc/dhcpcd.conf

We will use "doas" instead of sudo to have an easier and more minimal solution. You can change this with sudo if you want. The below configuration makes so that your user don't have to enter password when you use command doas. You can change this behaviour if you want by removing "nopass":

emerge doas

echo "permit :wheel
permit nopass keepenv :$username
permit nopass keepenv :root" > /etc/doas.conf

Now install the related packages:

We first need to install eselect-repository and git for syncing. Git sync is faster than rsync.

emerge app-eselect/eselect-repository dev-vcs/git

Then remove current repository that uses Rsync.:

eselect repository remove gentoo && rm -rf /var/db/repos/gentoo

Add git version of Gentoo repo:

eselect repository add gentoo git https://github.com/gentoo-mirror/gentoo.git

Add repositories that have good packages for Wayland:

eselect repository enable wayland-desktop guru pf4public

We will now create a local repository for our hyprland-9999 ebuild. It's basically the ebuild from the official repository that is modified to be able to use live versions. Create the local repo, create the needed directories, download hyprland ebuild, download nvidia patch, then give portage the ownership then validate the ebuild:

eselect repository create local
mkdir -p /var/db/repos/local/gui-wm/hyprland
mkdir -p /var/db/repos/local/gui-wm/hyprland/files
curl -L https://gist.githubusercontent.com/emrakyz/eeab3c83fb527bae2f52930e86ac3768/raw/66f5ef7c9f4e0480d46749018f6cccb60fecfa15/hyprland-9999.ebuild -o /var/db/repos/local/gui-wm/hyprland/hyprland-9999.ebuild
curl -L https://gist.githubusercontent.com/emrakyz/2c7c8da8295e0671f676cb0c2951b3e9/raw/67de071d1c08aecc995f7d0407038d537c4e2666/nvidia-9999.patch -o /var/db/repos/local/gui-wm/hyprland/files/nvidia-9999.patch
chown -R portage:portage /var/db/repos/local
ebuild /var/db/repos/local/gui-wm/hyprland/hyprland-9999.ebuild manifest

Then finally install the packages. Gsettings is needed on Hyprland. Otherwise some settings, especially GTK settings and mouse settings do not apply for most apps. Efibootmgr will be removed after creating the boot entry. You can also add whatever programs you want to install here. If a program you want to install needs you to enable a use flag, Portwage will warn you:

emerge gui-wm/hyprland::local kitty wofi dunst imv doas gnome-base/gsettings-desktop-schemas hyprpaper wl-clipboard xdg-desktop-portal-hyprland dhcpcd efibootmgr

We need to activate seatd. This manages logins on Wayland. This step is very important. Otherwise Hyprland won't start. We also installed dhcpcd with embedded use flag for a very minimal network configuration. It will automatically connect the internet without doing anything for ethernet connection. For wireless, you need to follow the wiki or do your thing:

rc-update add seatd default

rc-update add dhcpcd default

rc-service dhcpcd start

Now we create our user with the username we had given at the start. All of these groups are crucial. For example you can't have audio without pipewire or you can't run Hyprland without seat:

useradd -mG wheel,audio,video,usb,input,portage,pipewire,seat $username

We change our user's password with the password we had given (you can change this later if you want):

echo "$username:$password" | chpasswd

Create Hyprland config directory

mkdir -p /home/$username/.config/hypr

Download the reference config file from the Hyprland Github:

curl -L https://raw.githubusercontent.com/hyprwm/Hyprland/3229862dd4cbfa93638a4d16ed86ec2fda5d38a6/example/hyprland.conf -o /home/$username/.config/hypr/hyprland.conf

Related settings for hyprland.conf:

echo "exec-once=dbus-launch gentoo-pipewire-launcher & hyprpaper" >> /home/$username/.config/hypr/hyprland.conf

Enable portal at start:

echo "exec-once=/home/$username/.config/hypr/portalstart" >> /home/$username/.config/hypr/hyprland.conf

Add environment options:

echo "misc {
disable_hyprland_logo=1
disable_splash_rendering=1
}

env = QT_SCREEN_SCALE_FACTORS,1;1
env = WLR_NO_HARDWARE_CURSORS,1
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = _JAVA_AWT_WM_NONREPARENTING,1
env = ANV_QUEUE_THREAD_DISABLE,1
env = QT_QPA_PLATFORM,wayland
env = CLUTTER_BACKEND,wayland
env = SDL_VIDEODRIVER,wayland
env = XDG_SESSION_TYPE,wayland
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_DESKTOP,Hyprland
env = MOZ_ENABLE_WAYLAND,1
env = MOZ_DBUS_REMOTE,1" >> /home/$username/.config/hypr/hyprland.conf

Create portal starting script:

echo "#\!/bin/bash
sleep 1
killall xdg-desktop-portal-hyprland
killall xdg-desktop-portal-wlr
killall xdg-desktop-portal
/usr/libexec/xdg-desktop-portal-hyprland &
sleep 2
/usr/libexec/xdg-desktop-portal &" > /home/$username/.config/hypr/portalstart

Create Hyprland starting script:

echo "#\!/bin/sh
cd ~
export XDG_RUNTIME_DIR=\"/tmp/hyprland\"
mkdir -p \$XDG_RUNTIME_DIR
chmod 0700 \$XDG_RUNTIME_DIR
exec dbus-launch --exit-with-session Hyprland" >> /home/$username/.config/hypr/start.sh

Give these scripts execute permissions:

chmod +x /home/$username/.config/hypr/portalstart
chmod +x /home/$username/.config/hypr/start.sh

VERY IMPORTANT: You need to start 4 NVIDIA Modules automatically at boot:

mkdir -p /etc/modules-load.d
echo "nvidia
nvidia_modeset
nvidia_uvm
nvidia_drm" > /etc/modules-load.d/video.conf

You don't need a login manager. You can directly start Hyprland from the TTY by running the starting script. I add a line to my "zsh" profile file in order to start Hyprland starting script automatically when I log in as a user. You can also use this line on other shell configuration files. You just enter your username and pass in the tty and Hyprland starts. This line checks if you are currently on the TTY1, if you are at tty1 then it checks if Hyprland already runs, if not it starts it with the starting script. This is the last line of the profile file. Remember to change your username:

[ "$(tty)" = "/dev/tty1" ] && ! pidof -s Hyprland >/dev/null 2>&1 && exec "/home/your-username/.config/hypr/start.sh"

Here are some font rendering settings for convenience (they are beneficial for most people) :

eselect fontconfig disable 10-hinting-slight.conf
eselect fontconfig disable 10-no-antialias.conf
eselect fontconfig disable 10-sub-pixel-none.conf
eselect fontconfig enable 10-hinting-full.conf
eselect fontconfig enable 10-sub-pixel-rgb.conf
eselect fontconfig enable 10-yes-antialias.conf
eselect fontconfig enable 11-lcdfilter-default.conf

Clean-up by removing temporary portage files:

rm -rf /var/tmp/portage/*
rm -rf /var/cache/distfiles/*
rm -rf /var/cache/binpkgs/*

Now create the boot entry for your motherboard. I won't scriptize this part. It could be done but it would make it more complex for you to understand. DO NOT COPY AND PASTE THIS COMMAND:

Example: efibootmgr -c -d /dev/nvme0n1 -p 1 -L "GENTOO" -l '\EFI\BOOT\BOOTX64.EFI'

Explanation

efibootmgr calls the command

-c means create

-d means disk

/dev/nvme0n1 is the disk we use (NOT PARTITION)

-p 1 means the partition number 1

So if we mount /dev/nvme0n1p1 mount we issue the above parts. Or change accordingly.

-L means label. The name of the boot entry we see on our motherboard's bios.

-l means location. We show our kernel location here.

'\EFI\BOOT\BOOTX64.EFI' is the location of our kernel binary. BE CAREFUL: We use BACK SLASHES here instead of forward slashes.

Everything is same for you EXCEPT the disk and the partition.

Now you can remove efibootmgr and its dependencies if it was successful:

emerge --depclean efibootmgr && emerge --depclean

Now you can reboot your pc. If you have more than one distro or OS installed on your disk then you may go to your BIOS pressing the related key while starting your computer. The boot entry can be seen there. You can choose and boot into it OR you can change your BIOS settings for Boot Priority and you can boot into it without needing to choose every time.

Here are additional "example" settings for gsettings. This is needed for example to change cursor theme on Firefox. These commands can only be used after starting Hyprland since they need a running display:

gsettings

Here are my "mpv" video player settings that I use for Wayland, Pipewire, Opengl setup using gpu-next (the latest rendering method) and hardware acceleration:

~/.config/mpv/mpv.conf

