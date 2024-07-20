#!/bin/bash

# Function to check Bluetooth status
bluetooth_status() {
  if [[ $(bluetoothctl show | grep Powered) ]]; then
    echo "on"
  else
    echo "off"
  fi
}

# Get initial Bluetooth status
status=$(bluetooth_status)

# Function to toggle Bluetooth
toggle_bluetooth() {
  if [[ $status == "on" ]]; then
    sudo bluetoothctl power off
    status="off"
  else
    sudo bluetoothctl power on
    status="on"
  fi
}

# Handle left click (turn on)
if [[ $1 == "left" ]]; then
  toggle_bluetooth
fi

# Handle right click (turn off)
if [[ $1 == "right" ]]; then
  toggle_bluetooth
fi

# Get icon based on status
if [[ $status == "off" ]]; then
  icon="󰂲"
else
  icon=""
fi

# Print JSON output for Waybar
echo '{ "full_text": "'"$icon"' }'

