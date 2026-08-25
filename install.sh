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
    rofi-wayland
    kitty
    swaync
    hyprpaper
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

# --- 3. Backup Existing Configurations ---
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.config/cfg_backups_$(date +%Y%m%d_%H%M%S)"

echo -e "${BLUE}==>${NC} Creating backup directory at${BACKUP_DIR}..."
mkdir -p "$BACKUP_DIR"

CONFIGS_TO_LINK=("hypr" "waybar" "rofi" "kitty" "swaync")

for cfg in "${CONFIGS_TO_LINK[@]}"; do
    if [ -d "$CONFIG_DIR/$cfg" ] || [ -f "$CONFIG_DIR/$cfg" ]; then
        echo -e "${YELLOW}==>${NC} Backing up existing config:$cfg"
        mv "$CONFIG_DIR/$cfg" "$BACKUP_DIR/"
    fi
done

# --- 4. Deploy Configurations ---
echo -e "${BLUE}==>${NC} Deploying dotfiles to ~/.config..."
for cfg in "${CONFIGS_TO_LINK[@]}"; do
    if [ -d "$DOTFILES_DIR/$cfg" ] || [ -f "$DOTFILES_DIR/$cfg" ]; then
        echo -e "${GREEN}==>${NC} Linking $cfg -> ~/.config/$cfg"
        ln -sf "$DOTFILES_DIR/$cfg" "$CONFIG_DIR/$cfg"
    fi
done

# --- 5. Finish ---
echo -e "${GREEN}==>${NC} Installation complete! Log out and start Hyprland."
