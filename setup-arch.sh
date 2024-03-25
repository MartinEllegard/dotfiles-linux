# Vars
dotcore_dir=~/dotfiles-core
dotlinux_dir=~/dotfiles-linux
aur_dir=~/git/aur

# Setup directories
mkdir -p $aur_dir

# Update system
sudo pacman -Syu

# Install base dependencies
sudo pacman -S stow
sudo pacman -S --needed base-devel
sudo pacman -S fish
sudo chsh $USER /usr/bin/fish

# Setup dotfiles-core
cd $dotcore_dir
stow .
cd $dotlinux_dir
stow .

# Setup paru
cd $aur_dir
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si

# Install pacman packages
cd $dotlinux_dir
cat pacman.pkglist | xargs pacman-S --needed --noconfirm
