#!/bin/bash

if [[ $(playerctl status | grep Playing) ]]; then
    $(playerctl pause)
elif [[ $(playerctl status | grep Pause) ]]; then
    $(playerctl play)
fi
