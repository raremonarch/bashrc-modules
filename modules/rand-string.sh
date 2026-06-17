#!/bin/bash
# Module: rand-string
# Version: 0.1.0
# Description: Random string generators for alphabet, numeric, and alphanumeric output
# BashMod Dependencies: none

rand_alphabet() {
  local length="${1:-16}"

  [[ "$length" =~ ^[0-9]+$ ]] || {
    echo "Usage: rand_alphabet [length]" >&2
    return 1
  }

  LC_ALL=C tr -dc 'a-hj-km-np-z' < /dev/urandom | head -c "$length"
  printf '\n'
}

rand_number() {
  local length="${1:-16}"

  [[ "$length" =~ ^[0-9]+$ ]] || {
    echo "Usage: rand_number [length]" >&2
    return 1
  }

  LC_ALL=C tr -dc '0-9' < /dev/urandom | head -c "$length"
  printf '\n'
}

rand_alphanumeric() {
  local length="${1:-16}"

  [[ "$length" =~ ^[0-9]+$ ]] || {
    echo "Usage: rand_alphanumeric [length]" >&2
    return 1
  }

  LC_ALL=C tr -dc 'a-hj-km-np-z2-9' < /dev/urandom | head -c "$length"
  printf '\n'
}
