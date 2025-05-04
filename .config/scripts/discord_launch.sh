#!/bin/bash

# Start the necessary portal services
systemctl --user unmask xdg-desktop-portal.service
systemctl --user unmask xdg-desktop-portal-hyprland.service
systemctl --user start xdg-desktop-portal.service
systemctl --user start xdg-desktop-portal-hyprland.service

# Run Discord
cd ~/manual_software/Vesktop && pnpm start

# Wait for Discord to exit
wait $!

# After Discord exits, stop the portal services
systemctl --user stop xdg-desktop-portal.service
systemctl --user stop xdg-desktop-portal-hyprland.service
systemctl --user mask xdg-desktop-portal.service
systemctl --user mask xdg-desktop-portal-hyprland.service
