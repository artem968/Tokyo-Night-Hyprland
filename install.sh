#!/bin/bash

# This script automates the installation of Hyprland dotfiles.
# It uses the 'gum' TUI for interactive prompts.
#
# Before running:
# 1. This script will check for 'gum' and offer to install it if missing.
# 2. This script will ask if you want to use a custom dotfiles Git repository or the default.
# 3. Ensure your new config files are in a 'config' subdirectory within your Git repository.
#    Example: If your repository is 'my-dotfiles-repo' and your Hyprland config is inside
#    'my-dotfiles-repo/config/hypr', it will be copied to ~/.config/hypr.

# --- Configuration (can be overridden by user input) ---
# Default temporary directory for cloning the dotfiles repository
TEMP_DOTFILES_DIR="/tmp/hyprland_dotfiles_$(date +%s)"

# Default dotfiles repository URL
DEFAULT_DOTFILES_REPO="https://github.com/artem968/Tokyo-Night-Hyprland.git"

# List of packages to install via Pacman (space-separated)
# Add all your essential Hyprland, Wayland, terminal, editor, etc., packages here.
PACMAN_PACKAGES="
  hyprland wayland wayland-protocols xdg-desktop-portal xdg-desktop-portal-hyprland
  kitty neovim git pulseaudio pipewire pipewire-pulse
  brightnessctl playerctl polkit-kde-agent networkmanager
  ttf-font-awesome ttf-jetbrains-mono noto-fonts noto-fonts-emoji
  mako grim slurp wl-clipboard wofi dunst
  swaybg swaylock-effects grimblast-git pamixer
  zsh starship"

# List of packages to install via an AUR helper (space-separated)
# Add any AUR packages like icon themes, specific utilities, etc.
AUR_PACKAGES="
  hyprpicker-git sddm-git nwg-look-git wlr-randr-git
  xdg-desktop-portal-hyprland-git" # Often AUR for latest git version

# --- Script Start ---

echo "Welcome to the Hyprland Dotfiles Setup Script!"

# --- Initial Check for gum installation ---
if ! command -v gum &>/dev/null; then
  echo ""
  echo "---------------------------------------------------------"
  echo "  'gum' is not installed."
  echo "  This script heavily relies on 'gum' for interactive prompts."
  echo "  It makes the script much more user-friendly."
  echo "---------------------------------------------------------"
  echo ""
  read -p "Do you want to install 'gum' now? (y/N) " install_gum_choice
  case "$install_gum_choice" in
  y | Y)
    echo "Attempting to install 'gum'..."
    sudo pacman -S gum --noconfirm
    if [ $? -eq 0 ]; then
      echo "'gum' installed successfully! Restarting script with gum."
      # Re-execute the script, allowing it to proceed with gum
      exec bash "$0" "$@"
    else
      echo "Failed to install 'gum'. Please install it manually: sudo pacman -S gum"
      echo "Then re-run this script. Exiting."
      exit 1
    fi
    ;;
  *)
    echo "Installation of 'gum' skipped. This script requires 'gum'."
    echo "Please install it manually: sudo pacman -S gum"
    echo "Then re-run this script. Exiting."
    exit 1
    ;;
  esac
fi

# Now that gum is ensured to be installed, we can use it for styling
gum style \
  --foreground "#F8F8F2" --border-foreground "#F8F8F2" --border normal \
  --align center --width 50 --margin "1 2" --padding "1 2" \
  "$(gum style --foreground "#BD93F9" --bold "Hyprland Dotfiles Setup")"

# --- Step 0: Get Dotfiles Repository URL ---
if gum confirm "Do you want to specify a custom dotfiles GitHub repository?"; then
  DOTFILES_REPO_URL=$(gum input --placeholder "Enter your custom dotfiles Git repository URL (e.g., https://github.com/youruser/your-dotfiles.git)")
else
  DOTFILES_REPO_URL="$DEFAULT_DOTFILES_REPO"
  echo "Using default dotfiles repository: $(gum style --foreground "#6272A4" "$DEFAULT_DOTFILES_REPO")" | gum style --foreground "#8BE9FD"
fi

if [ -z "$DOTFILES_REPO_URL" ]; then
  echo "Dotfiles repository URL cannot be empty. Exiting." | gum style --foreground "#FF5555" --bold
  exit 1
fi

# --- Step 1: Check and Install AUR Helper ---
AUR_HELPER=""
if command -v yay &>/dev/null; then
  AUR_HELPER="yay"
elif command -v paru &>/dev/null; then
  AUR_HELPER="paru"
fi

if [ -z "$AUR_HELPER" ]; then
  echo "No AUR helper (yay or paru) found on your system." | gum style --foreground "#F1FA8C"
  if gum confirm "Do you want to install one?"; then
    SELECTED_HELPER=$(gum choose "yay" "paru")
    echo "Installing $SELECTED_HELPER..." | gum style --foreground "#8BE9FD"
    gum spin --spinner dot --title "Installing build dependencies..." -- sudo pacman -S --needed git base-devel --noconfirm

    # Clean up existing temporary build directory before attempting to clone
    if [ -d "/tmp/$SELECTED_HELPER" ]; then
      gum spin --spinner dot --title "Cleaning up old /tmp/$SELECTED_HELPER directory..." -- rm -rf "/tmp/$SELECTED_HELPER"
    fi

    if [ "$SELECTED_HELPER" == "yay" ]; then
      gum spin --spinner dot --title "Cloning and building yay..." -- \
        bash -c "git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si --noconfirm"
    elif [ "$SELECTED_HELPER" == "paru" ]; then
      gum spin --spinner dot --title "Cloning and building paru..." -- \
        bash -c "git clone https://aur.archlinux.org/paru.git /tmp/paru && cd /tmp/paru && makepkg -si --noconfirm"
    fi

    if [ $? -eq 0 ]; then
      AUR_HELPER="$SELECTED_HELPER"
      echo "$AUR_HELPER installed successfully!" | gum style --foreground "#50FA7B" --bold
    else
      echo "Failed to install $SELECTED_HELPER. Please install it manually and re-run the script." | gum style --foreground "#FF5555" --bold
      exit 1
    fi
  else
    echo "An AUR helper is required to install some packages. Exiting." | gum style --foreground "#FF5555" --bold
    exit 1
  fi
else
  echo "Detected AUR helper: $(gum style --foreground "#50FA7B" --bold "$AUR_HELPER")"
fi

# --- Step 2: Clone Dotfiles Repository ---
echo "Cloning your dotfiles repository: $(gum style --foreground "#6272A4" "$DOTFILES_REPO_URL")" | gum style --foreground "#8BE9FD" --bold
gum spin --spinner dot --title "Cloning dotfiles to $TEMP_DOTFILES_DIR..." -- git clone "$DOTFILES_REPO_URL" "$TEMP_DOTFILES_DIR"
if [ $? -eq 0 ]; then
  echo "Dotfiles cloned successfully!" | gum style --foreground "#50FA7B" --bold
  DOTFILES_CONFIG_SOURCE_DIR="$TEMP_DOTFILES_DIR/config"
  if [ ! -d "$DOTFILES_CONFIG_SOURCE_DIR" ]; then
    echo "Error: 'config' directory not found inside the cloned repository ($DOTFILES_CONFIG_SOURCE_DIR)." | gum style --foreground "#FF5555" --bold
    echo "Please ensure your dotfiles repo has a 'config' directory containing your configuration files." | gum style --foreground "#FF5555" --bold
    echo "Cleaning up temporary files and exiting." | gum style --foreground "#FF5555"
    rm -rf "$TEMP_DOTFILES_DIR"
    exit 1
  fi
else
  echo "Failed to clone dotfiles repository. Please check the URL and your network connection." | gum style --foreground "#FF5555" --bold
  exit 1
fi

# --- Step 3: Backup existing ~/.config folder ---
if gum confirm "Do you want to create a backup of your existing ~/.config folder?"; then
  BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
  echo "Creating backup in $BACKUP_DIR..." | gum style --foreground "#8BE9FD"
  gum spin --spinner dot --title "Backing up ~/.config..." -- rsync -av --exclude '**/cache' --exclude '**/npm' --exclude '**/yarn' --exclude '**/node_modules' "$HOME/.config/" "$BACKUP_DIR/"
  if [ $? -eq 0 ]; then
    echo "Backup created successfully!" | gum style --foreground "#50FA7B" --bold
  else
    echo "Backup failed. Continuing without backup." | gum style --foreground "#FFB86C"
  fi
else
  echo "Skipping backup of ~/.config." | gum style --foreground "#BD93F9"
fi

# --- Step 4: Install Pacman packages ---
echo "Installing Pacman packages..." | gum style --foreground "#8BE9FD" --bold
gum spin --spinner dot --title "Running sudo pacman -S --needed..." -- sudo pacman -S --needed $PACMAN_PACKAGES --noconfirm
if [ $? -eq 0 ]; then
  echo "Pacman packages installed successfully!" | gum style --foreground "#50FA7B" --bold
else
  echo "Failed to install all Pacman packages. Please check the output above." | gum style --foreground "#FF5555" --bold
  if ! gum confirm "Do you want to continue despite Pacman errors?"; then
    # Clean up temporary dotfiles directory before exiting
    rm -rf "$TEMP_DOTFILES_DIR"
    exit 1
  fi
fi

# --- Step 5: Install AUR packages ---
if [ -n "$AUR_HELPER" ]; then
  echo "Installing AUR packages using $AUR_HELPER..." | gum style --foreground "#8BE9FD" --bold
  gum spin --spinner dot --title "Running $AUR_HELPER -S --needed..." -- $AUR_HELPER -S --needed $AUR_PACKAGES --noconfirm
  if [ $? -eq 0 ]; then
    echo "AUR packages installed successfully!" | gum style --foreground "#50FA7B" --bold
  else
    echo "Failed to install all AUR packages. Please check the output above." | gum style --foreground "#FF5555" --bold
    if ! gum confirm "Do you want to continue despite AUR errors?"; then
      # Clean up temporary dotfiles directory before exiting
      rm -rf "$TEMP_DOTFILES_DIR"
      exit 1
    fi
  fi
else
  echo "No AUR helper found or installed. Skipping AUR package installation." | gum style --foreground "#FFB86C"
fi

# --- Step 6: Copy new config files ---
echo "Copying new configuration files from cloned repository to ~/.config..." | gum style --foreground "#8BE9FD" --bold
gum spin --spinner dot --title "Copying $DOTFILES_CONFIG_SOURCE_DIR to ~/.config..." -- rsync -av --delete "$DOTFILES_CONFIG_SOURCE_DIR/" "$HOME/.config/"
if [ $? -eq 0 ]; then
  echo "Configuration files copied successfully! Existing files were overridden." | gum style --foreground "#50FA7B" --bold
else
  echo "Failed to copy configuration files. Please check permissions and paths, or if the 'config' folder exists in your repository." | gum style --foreground "#FF5555" --bold
  # Clean up temporary dotfiles directory before exiting
  rm -rf "$TEMP_DOTFILES_DIR"
  exit 1
fi

# --- Step 7: Clean up temporary dotfiles ---
echo "Cleaning up temporary dotfiles directory: $(gum style --foreground "#6272A4" "$TEMP_DOTFILES_DIR")" | gum style --foreground "#8BE9FD"
rm -rf "$TEMP_DOTFILES_DIR"
if [ $? -eq 0 ]; then
  echo "Temporary files cleaned up successfully!" | gum style --foreground "#50FA7B"
else
  echo "Failed to clean up temporary files. You may need to remove '$TEMP_DOTFILES_DIR' manually." | gum style --foreground "#FFB86C"
fi

echo ""
echo "Setup complete! Please reboot or log out and log back in to apply changes." | gum style --foreground "#50FA7B" --bold
echo "You might need to enable/start sddm.service if you installed it: sudo systemctl enable sddm.service" | gum style --foreground "#8BE9FD"
echo "Thank you for using the Hyprland Dotfiles Setup Script!" | gum style --foreground "#8BE9FD" --bold

exit 0
