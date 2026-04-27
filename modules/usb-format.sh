#!/bin/bash
# Module: usb-format
# Version: 0.2.0
# Description: USB device formatting utilities
# BashMod Dependencies: none

function format-usb() {
  if [ -z "$1" ]; then
    echo "Usage: format-usb /dev/sdX"
    return 1
  fi
  if [ ! -b "$1" ]; then
    echo "Error: $1 is not a valid block device."
    return 1
  fi
  echo "Device info for $1:"
  echo "---------------------"
  lsblk -o Fare -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,MODEL "$1" | awk 'NR>1 {print "NAME: "$1"\nSIZE: "$2"\nFSTYPE: "$3"\nLABEL: "($4 ? $4 : "None")"\nMOUNTPOINT: "($5 ? $5 : "Not mounted")"\nMODEL: "$6}'
  echo "---------------------"
  echo "WARNING: Formatting $1 will erase all data. Confirm? (y/n)"
  read -r confirm
  if [ "$confirm" != "y" ]; then
    echo "Aborted."
    return 1
  fi
  sudo umount "$1"* 2>/dev/null
  sudo parted "$1" --script mklabel msdos
  sudo mkfs.vfat -F 32 "$1"
  echo "Formatted $1 as FAT32."
}
