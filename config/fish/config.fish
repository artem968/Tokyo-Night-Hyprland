if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -Ux EDITOR /usr/bin/nvim

function fish_greeting
    # Do nothing
end

source ~/.config/fish/themes/tokyonight_night.theme

#starship init fish | source
