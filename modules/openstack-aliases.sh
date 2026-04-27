#!/bin/bash
# Module: openstack-aliases
# Version: 0.2.0
# Description: OpenStack cloud management utilities
# BashMod Dependencies: none

export OS_CLOUD=ebsco-novelist
export OS_REGION_NAME=SDCEDN

osr() {
  case "${1,,}" in
    sdc)
      export OS_CLOUD=ebsco-novelist-sdc
      export OS_REGION_NAME=SDC
      ;;
    sdcedn|edn)
      export OS_CLOUD=ebsco-novelist
      export OS_REGION_NAME=SDCEDN
      ;;
    "")
      printf 'Current region: %s\n' "$OS_REGION_NAME"
      return 0
      ;;
    *)
      printf 'Unknown region: %s\n' "$1"
      printf 'Use: osr sdc | osr sdcedn\n'
      return 1
      ;;
  esac

  printf 'Region set to %s\n' "$OS_REGION_NAME"
}

os() {
  openstack --os-cloud "$OS_CLOUD" --os-region-name "$OS_REGION_NAME" "$@"
}