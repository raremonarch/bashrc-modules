alias lsp="ls -lahp"
alias calc='galculator'
alias pwdsize='du -sh .'
alias tstamp='~/Scripts/timestamp-to-clipboard.sh'
alias fproc='ps aux | grep -i'
alias psg='ps aux | grep -i'
alias llama='ollama run llama3'
alias kit='~/Downloads/kitbash/kit-start.sh'

function confi3() {
  vim ~/.config/i3/config
}

# custom package add/rm (fedora)
mypackages_file=~/packages.txt
function addpack() {
  local appname=$1
  echo "$appname" >> "$mypackages_file" && sudo dnf install "$appname" -y
}
function rmpack() {
  local appname=$1
  if grep -q "$appname" "$mypackages_file"; then 
    echo "package '$appname' found in $mypackages_file; removing"
    sed -i "/$appname/d" "$mypackages_file"
    sudo dnf remove "$appname" -y
  else 
    echo "package '$appname' NOT found in $mypackages_file, exiting"
  fi 
}
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

function aliases() {
  echo "=== Aliases and Functions in ~/.bashrc.d/ ==="
  echo ""
  
  for script in ~/.bashrc.d/*.sh; do
    if [ -f "$script" ]; then
      filename=$(basename "$script")
      echo "📁 $filename"
      echo "$(printf '%.0s─' {1..40})"
      
      # Find aliases and extract names
      grep "^alias " "$script" 2>/dev/null | sed 's/^alias \([^=]*\)=.*/\1/' | while read -r name; do
        case "$name" in
          calc) echo "  $name - Launch calculator" ;;
          pwdsize) echo "  $name - Show current directory size" ;;
          tstamp) echo "  $name - Copy timestamp to clipboard" ;;
          fproc|psg) echo "  $name - Search running processes" ;;
          llama) echo "  $name - Run Llama3 AI model" ;;
          gitaddcommit) echo "  $name - Git add all and commit with message" ;;
          *) echo "  $name - Custom alias" ;;
        esac
      done
      
      # Find functions (both syntaxes) and extract names
      {
        grep "^function " "$script" 2>/dev/null | sed 's/^function \([^(]*\).*/\1/'
        grep "^[a-zA-Z_][a-zA-Z0-9_-]*() {" "$script" 2>/dev/null | sed 's/() {.*//'
      } | while read -r name; do
        case "$name" in
          confi3) echo "  $name - Edit i3 config file" ;;
          addpack) echo "  $name - Add package to list and install" ;;
          rmpack) echo "  $name - Remove package from list and system" ;;
          format-usb) echo "  $name - Format USB drive as FAT32" ;;
          aliases) echo "  $name - Show all aliases and functions" ;;
          clone-eis) echo "  $name - Clone EIS repository" ;;
          clone-daev) echo "  $name - Clone personal repository" ;;
          git-del-branch) echo "  $name - Delete branch locally and remotely" ;;
          docker-nukec) echo "  $name - Stop and remove all containers" ;;
          docker-purge-all) echo "  $name - Remove all Docker data" ;;
          cdpydev) echo "  $name - Change to Python development directory" ;;
          poetryreq) echo "  $name - Export Poetry requirements" ;;
          pycov) echo "  $name - Run pytest with coverage (skip covered)" ;;
          pycov-all) echo "  $name - Run pytest with full coverage report" ;;
          coverage-check) echo "  $name - Check coverage meets 80% threshold" ;;
          *) echo "  $name - Custom function" ;;
        esac
      done
      
      echo ""
    fi
  done
}
