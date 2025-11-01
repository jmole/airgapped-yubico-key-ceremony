#!/bin/sh
set -eu

# Usage: ./print.sh FILE
# Sends FILE to the detected printer device. Initializes ESC/P to 10 CPI, Draft quality, and an 8-column left margin.
# Designed for busybox systems (uses sed/printf only).

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 FILE" >&2
  exit 2
fi

INPUT_FILE=$1
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: file not found: $INPUT_FILE" >&2
  exit 1
fi

# Allow override via PRN_DEV, else auto-detect
PRN_DEV=${PRN_DEV:-}
if [ -z "$PRN_DEV" ]; then
  if [ -e /dev/usb/lp0 ]; then
    PRN_DEV=/dev/usb/lp0
  elif [ -e /dev/lp0 ]; then
    PRN_DEV=/dev/lp0
  else
    echo "Error: no printer device found (/dev/usb/lp0 or /dev/lp0). Set PRN_DEV to override." >&2
    exit 1
  fi
fi

# Initialize printer (ESC @), set 10 CPI (ESC P), set Draft quality (ESC x 0),
# set left margin to 8 columns (ESC l 0x08), then send file with CRLF line endings
# and finish with a form feed.
(
  printf '\x1B@\x1BP\x1Bx\x00\x1Bl\x08'
  sed 's/$/\r/' "$INPUT_FILE"
  printf '\f'
) > "$PRN_DEV"

echo "Printed: $INPUT_FILE -> $PRN_DEV"

