#!/bin/bash

if [[ $(playerctl -l | grep spotify) ]]; then
    song=$(playerctl metadata -f '{{title}} - {{artist}}')
fi

echo "${song}"
