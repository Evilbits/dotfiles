#!/bin/bash

subinc=1
subchange=$(echo "1 / $subinc" | bc -l)
delay=0.001
opt=""


getIcon() {
    if [ "$1" -eq 0 ]; then
        echo "/usr/share/icons/kora/status/symbolic/display-brightness-off-symbolic.svg"
    elif [ "$1" -lt 33 ]; then
        echo "/usr/share/icons/kora/status/symbolic/display-brightness-low-symbolic.svg"
    elif [ "$1" -lt 66 ]; then
        echo "/usr/share/icons/kora/status/symbolic/display-brightness-medium-symbolic.svg"
    else
        echo "/usr/share/icons/kora/status/symbolic/display-brightness-high-symbolic.svg"
    fi

}


if [ "$1" == "inc" ]; then
    opt="-inc"
else
    opt="-dec"
fi


current=$(xbacklight)
truncated=$(echo "$current" | cut -d '.' -f1)

if (( $(echo "$current==0" | bc -l) )) && [ "$opt" == "-dec" ]; then
    exit 0;
elif (( $(echo "$current==100" | bc -l) )) && [ "$opt" == "-inc"  ]; then
    exit 0;
fi

xbacklight $opt "$2"
    
current=$(xbacklight)
truncated=$(echo "$current" | cut -d '.' -f1)

dunstify "" "Brightness at ${truncated}%" -i $(getIcon "$truncated") -a "Backlight" -u normal -h "int:value:$current" -h string:x-dunst-stack-tag:backlight
