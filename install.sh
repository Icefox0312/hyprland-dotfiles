#!/usr/bin/env bash

set -e

# --- Colors for Output ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==>${NC} Starting Hyprland Dotfiles Installation..."

# --- Dependency Lists ---
CORE_PKGS=(
    hyprland
    waybar
    kitty
    swaync
    awww
    hyprlock
    hypridle
    wl-clipboard
    grim
    slurp
    brightnessctl
    playerctl
    polkit-gnome
    xdg-desktop-portal-hyprland
    ttf-jetbrains-mono-nerd
    noto-fonts-emoji
    mpirs
)

AUR_PKGS=(
    wlogout
)

# --- 1. Check & Install AUR Helper (yay) ---
if ! command -v yay &> /dev/null; then
    echo -e "${YELLOW}==>${NC} AUR helper 'yay' not found. Installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    (cd /tmp/yay-bin && makepkg -si --noconfirm)
    rm -rf /tmp/yay-bin
fi

# --- 2. Install Packages ---
echo -e "${BLUE}==>${NC} Installing official packages..."
sudo pacman -S --needed --noconfirm "${CORE_PKGS[@]}"

echo -e "${BLUE}==>${NC} Installing AUR packages..."
yay -S --needed --noconfirm "${AUR_PKGS[@]}"

# --- 3. Backup & Copy Configurations ---
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.config/cfg_backups_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$CONFIG_DIR"

CONFIGS_TO_COPY=("hypr" "waybar" "rofi" "kitty" "swaync")

# Check if any target exists before creating backup directory
needs_backup=false
for cfg in "${CONFIGS_TO_COPY[@]}"; do
    if [ -d "$CONFIG_DIR/$cfg" ] || [ -f "$CONFIG_DIR/$cfg" ]; then
        needs_backup=true
        break
    fi
done

if [ "$needs_backup" = true ]; then
    echo -e "${YELLOW}==>${NC} Existing configurations found. Backing up to ${BACKUP_DIR}..."
    mkdir -p "$BACKUP_DIR"
    
    for cfg in "${CONFIGS_TO_COPY[@]}"; do
        if [ -d "$CONFIG_DIR/$cfg" ] || [ -f "$CONFIG_DIR/$cfg" ]; then
            echo -e "${YELLOW}==>${NC} Backing up: $cfg"
            mv "$CONFIG_DIR/$cfg" "$BACKUP_DIR/"
        fi
    done
fi

# --- 4. Copying the config files ---
  rm -rf ~/.config/hypr && cp -r ~/hyprland-dotfiles/.config/hypr ~/.config/
  rm -rf ~/.config/kitty cp -r  ~/hyprland-dotfiles/.config/kitty ~/.config/kitty
  rm -rf ~/.config/quickshell && -r  ~/hyprland-dotfiles/.config/quickshell ~/.config/
  rm -rf ~/.config/swaync && cp -r  ~/hyprland-dotfiles/.config/swaync ~/.config/
  rm -rf ~/.config/waybar && cp -r  ~/hyprland-dotfiles/.config/waybar ~/.config/
  rm -rf ~/.config/waybar && cp -r  ~/hyprland-dotfiles/.config/wlogout ~/.config/
  cp -r  ~/hyprland-dotfiles/.local/apply_wallpaper.sh ~/.local/bin

# --- 4. Finish ---
echo -e "${GREEN}==>${NC} Installation and setup complete! Log out and start Hyprland."
