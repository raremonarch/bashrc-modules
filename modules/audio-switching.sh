#!/bin/bash
# Module: audio-switching
# Version: 0.1.1
# Description: Audio device switching utilities
# BashMod Dependencies: none
alias headset='pactl set-default-sink alsa_output.usb-Turtle_Beach_Corp_Stealth_600X_Gen_3_0000000000000001-00.analog-stereo'
alias speakers='pactl set-default-sink alsa_output.pci-0000_28_00.4.analog-stereo'
