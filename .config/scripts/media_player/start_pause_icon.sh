#!/bin/bash

if [[ $(playerctl status | grep Playing) ]]; then
    echo "󰏤"
elif [[ $(playerctl status | grep Pause) ]]; then
    echo "󰐊" 
fi
