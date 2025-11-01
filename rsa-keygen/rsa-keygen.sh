#!/bin/sh
set -eu

INI="./rsa-keygen.ini"
[ -f "$INI" ] && . "$INI"

KEY_BITS=${KEY_BITS:-2048}
SLOT=${SLOT:-9c}
TITLE=${TITLE:-"RSA-PIV PAPER BACKUP (ENCRYPTED, PKCS#8/AES-256)"}
OUT_DIR=${OUT_DIR:-.}
PRN_DEV=${PRN_DEV:-}

# Certificate validity (days). Default to 1000 years.
CERT_DAYS=${CERT_DAYS:-365000}

# Certificate subject defaults (can be overridden in rsa-keygen.ini)
SUBJECT_CN=${SUBJECT_CN:-"Code Signing Certificate"}
SUBJECT_O=${SUBJECT_O:-}
SUBJECT_OU=${SUBJECT_OU:-}
SUBJECT_C=${SUBJECT_C:-}
SUBJECT_ST=${SUBJECT_ST:-}
SUBJECT_L=${SUBJECT_L:-}
# SUBJECT_EMAIL may be empty by default
SUBJECT_EMAIL=${SUBJECT_EMAIL:-}

# Assemble OpenSSL subject string (omit empty components)
SUBJECT="/CN=$SUBJECT_CN"
[ -n "${SUBJECT_O:-}" ] && SUBJECT="$SUBJECT/O=$SUBJECT_O"
[ -n "${SUBJECT_OU:-}" ] && SUBJECT="$SUBJECT/OU=$SUBJECT_OU"
[ -n "${SUBJECT_C:-}" ] && SUBJECT="$SUBJECT/C=$SUBJECT_C"
[ -n "${SUBJECT_ST:-}" ] && SUBJECT="$SUBJECT/ST=$SUBJECT_ST"
[ -n "${SUBJECT_L:-}" ] && SUBJECT="$SUBJECT/L=$SUBJECT_L"
[ -n "${SUBJECT_EMAIL:-}" ] && SUBJECT="$SUBJECT/emailAddress=$SUBJECT_EMAIL"

timestamp=$(date -u +"%Y-%m-%d-%H%M%S")
RUN_DIR="$OUT_DIR/output-$timestamp"
OUT_KEY="$RUN_DIR/encrypted-rsa-private-key.enc.pem"
OUT_TXT="$RUN_DIR/printable-backup.txt"
KEY_IMPORTED=0
PIV_RESET_DONE=0

CERT_PATH="$RUN_DIR/self-signed-certificate.pem"
CERT_CREATED=0
PRINT_DONE=0
FILES_SHREDDED=0

# --- UI helpers -------------------------------------------------------------
if [ -t 1 ]; then
  STYLE_RESET="$(printf '\033[0m')"
  STYLE_BOLD="$(printf '\033[1m')"
  STYLE_DIM="$(printf '\033[2m')"
  STYLE_CYAN="$(printf '\033[36m')"
  STYLE_GREEN="$(printf '\033[32m')"
  STYLE_YELLOW="$(printf '\033[33m')"
  STYLE_RED="$(printf '\033[31m')"
  STYLE_BLUE="$(printf '\033[34m')"
  STYLE_MAGENTA="$(printf '\033[35m')"
  STYLE_WHITE="$(printf '\033[37m')"
  STYLE_PROMPT="$(printf '\033[32m')"
  STYLE_RED_BOLD="$STYLE_BOLD$STYLE_RED"
  STYLE_BLUE_BOLD="$STYLE_BOLD$STYLE_BLUE"
  STYLE_GREEN_BOLD="$STYLE_BOLD$STYLE_GREEN"
  STYLE_WHITE_BOLD="$STYLE_BOLD$STYLE_WHITE"
  STYLE_MAGENTA_BOLD="$STYLE_BOLD$STYLE_MAGENTA"
else
  STYLE_RESET=
  STYLE_BOLD=
  STYLE_DIM=
  STYLE_CYAN=
  STYLE_GREEN=
  STYLE_YELLOW=
  STYLE_RED=
  STYLE_BLUE=
  STYLE_MAGENTA=
  STYLE_WHITE=
  STYLE_PROMPT=
  STYLE_RED_BOLD=
  STYLE_BLUE_BOLD=
  STYLE_GREEN_BOLD=
  STYLE_WHITE_BOLD=
  STYLE_MAGENTA_BOLD=
fi

PROGRESS_KEYS=
PROGRESS_CURRENT=

progress_define() {
  key=$1
  label=$2
  status=${3:-waiting}
  PROGRESS_KEYS="${PROGRESS_KEYS:+$PROGRESS_KEYS }$key"
  eval "PROGRESS_${key}_LABEL=\"$label\""
  eval "PROGRESS_${key}_STATUS=\"$status\""
}

progress_set() {
  key=$1
  status=$2
  eval "PROGRESS_${key}_STATUS=\"$status\""
  progress_render
}

progress_current() {
  PROGRESS_CURRENT=$1
}

progress_render() {
  printf "%sProgress overview:%s\n" "$STYLE_BOLD" "$STYLE_RESET"
  for key in $PROGRESS_KEYS; do
    [ -z "$key" ] && continue
    label=$(eval "printf '%s' \"\${PROGRESS_${key}_LABEL}\"")
    status=$(eval "printf '%s' \"\${PROGRESS_${key}_STATUS}\"")
    prefix="    "
    [ "$key" = "${PROGRESS_CURRENT:-}" ] && prefix="  > "
    case "$status" in
      done)
        color=$STYLE_GREEN
        badge="DONE"
        note="completed"
        ;;
      skipped)
        color=$STYLE_DIM
        badge="SKIP"
        note="skipped"
        ;;
      *)
        color=$STYLE_RED
        badge="TODO"
        note="pending"
        ;;
    esac
    printf "%s%s[%s]%s %s %s(%s)%s\n" "$prefix" "$color" "$badge" "$STYLE_RESET" "$label" "$STYLE_DIM" "$note" "$STYLE_RESET"
  done
  printf "\n"
}

print_next_steps() {
  printf "\n%sNext steps (recommended):%s\n" "$STYLE_BOLD" "$STYLE_RESET"
  if [ "$FILES_SHREDDED" -eq 1 ]; then
    printf "    - %sNo local copies remain; rely on your printed or offline backups.%s\n" "$STYLE_DIM" "$STYLE_RESET"
    printf "    - Verify the YubiKey reports the loaded key: ykman piv info\n"
    printf "    - Record where the passphrase and encrypted backup now live.\n"
    return
  fi

  key_name=$(basename "$OUT_KEY")

  printf "    - Backup folder created at: %s\n" "$RUN_DIR"
  printf "    - Review the printable instructions: less \"%s\"\n" "$OUT_TXT"
  printf "    - Confirm the encrypted key checksum: (cd \"%s\" && echo \"%s  %s\" | sha256sum -c -)\n" "$RUN_DIR" "$HASH" "$key_name"
  if [ "$PRINT_DONE" -eq 0 ]; then
    printf "    - Print a paper copy if needed: lp \"%s\"\n" "$OUT_TXT"
  fi
  printf "    - Mount removable storage for offline copies: ./mount-usb.sh\n"
  printf "      %sNote the mount path reported (for example, /mnt/usb001).%s\n" "$STYLE_DIM" "$STYLE_RESET"
  printf "    - Copy the entire backup folder to offline media: cp -a \"%s\" /mnt/usb001/\n" "$RUN_DIR"
  if [ "$CERT_CREATED" -eq 1 ]; then
    printf "      %sThis includes self-signed-certificate.pem for clients that expect it.%s\n" "$STYLE_DIM" "$STYLE_RESET"
  fi
  printf "    - Safely unmount the removable media when finished: umount /mnt/usb001\n"
  printf "    - Verify the YubiKey still reports the imported key: ykman piv info\n"
  printf "    - Record where the passphrase is stored; keep offline media and notes together.\n"
}

STEP=0
draw_rule() { printf "%s------------------------------------------------------------%s\n" "$STYLE_DIM" "$STYLE_RESET"; }

banner() {
  draw_rule
  printf "%s%sRSA Key Generation and Backup Assistant%s\n" "$STYLE_BOLD" "$STYLE_CYAN" "$STYLE_RESET"
  printf "%sGuides you through generating an encrypted RSA backup key,\nloading it onto a YubiKey, as well as an optional paper backup.%s\n" "$STYLE_DIM" "$STYLE_RESET"
  draw_rule
}

section() {
  STEP=$((STEP + 1))
  printf "\n%sStep %d:%s %s\n" "$STYLE_CYAN" "$STEP" "$STYLE_RESET" "$1"
  [ -n "${2:-}" ] && printf "  %s%s%s\n" "$STYLE_DIM" "$2" "$STYLE_RESET"
}

info() { printf "  %s[i]%s %s\n" "$STYLE_DIM" "$STYLE_RESET" "$1"; }
success() { printf "  %s[OK]%s %s\n" "$STYLE_GREEN" "$STYLE_RESET" "$1"; }
warn() { printf "  %s[!]%s %s\n" "$STYLE_YELLOW" "$STYLE_RESET" "$1"; }
critical() { printf "  %s[!!!]%s %s%s%s\n" "$STYLE_RED$STYLE_BOLD" "$STYLE_RESET" "$STYLE_RED$STYLE_BOLD" "$1" "$STYLE_RESET"; }

critical_block() {
  border="@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
  printf "  %s%s%s\n" "$STYLE_RED_BOLD" "$border" "$STYLE_RESET"
  for line in "$@"; do
    printf "  %s@%s %s%s\n" "$STYLE_RED_BOLD" "$STYLE_RESET" "$line" "$STYLE_RESET"
  done
  printf "  %s%s%s\n" "$STYLE_RED_BOLD" "$border" "$STYLE_RESET"
}

acknowledge() {
  message=${1:-"Press Enter to continue..."}
  printf "\n%s> %s%s" "$STYLE_PROMPT" "$message" "$STYLE_RESET"
  read -r _ || true
  printf "\n"
}

prompt_yes_no() {
  question=$1
  guidance=${2:-}
  default_choice=${3:-N}

  [ -n "$guidance" ] && printf "  %s%s%s\n" "$STYLE_DIM" "$guidance" "$STYLE_RESET"

  case "$default_choice" in
    y|Y) default_display="Y/n" ;;
    *) default_display="y/N" ;;
  esac

  while true; do
    printf "\n%s> %s [%s]: %s" "$STYLE_PROMPT" "$question" "$default_display" "$STYLE_RESET"
    read -r answer || answer=
    [ -z "$answer" ] && answer=$default_choice
    case "$answer" in
      y|Y) return 0 ;;
      n|N) return 1 ;;
      *) warn "Please answer with y or n." ;;
    esac
  done
}

prompt_run() {
  printf "%s> %s %s %s;%s\n" "$STYLE_RED$STYLE_BOLD" "$STYLE_RESET$STYLE_BOLD" "$1" "$STYLE_RED$STYLE_BOLD" "$STYLE_RESET"
  printf "\n"
  printf "%s> Press Enter to %sexecute ^%s   " "$STYLE_PROMPT" "$STYLE_RED$STYLE_BOLD" "$STYLE_RESET"
  read -r _ || true
  printf "\n"
}

run_with_retry() {
  cmd=$1
  if [ -z "${cmd:-}" ]; then
    warn "Internal error: no command provided for run_with_retry."
    return 1
  fi

  while true; do
    prompt_run "$cmd"
    if sh -c "$cmd"; then
      return 0
    fi
    status=$?
    if [ "$status" -eq 0 ]; then
      warn "Command reported an error but returned exit status 0."
    else
      warn "Command failed with exit status $status."
    fi
    if prompt_yes_no "Try this step again?" "" Y; then
      continue
    fi
    return 1
  done
}

ensure_dir() {
  if [ ! -d "$1" ]; then
    warn "Output directory $1 does not exist; creating it now."
    mkdir -p "$1"
  fi
}

# Track the high-level choices so users can see what has been completed.
progress_define "ENV_SETUP" "Smart card service ready" waiting
progress_define "PIV_RESET" "PIV applet reset" waiting
progress_define "PIN_CHANGE" "PIN rotated" waiting
progress_define "PUK_RESET" "PUK rotated" waiting
progress_define "MGMT_ROTATE" "Management key rotated" waiting
progress_define "KEY_CREATE" "Encrypted key generated" waiting
progress_define "KEY_VERIFY" "Passphrase re-tested" waiting
progress_define "BACKUP_PAGE" "Paper backup prepared" waiting
progress_define "KEY_IMPORT" "Private key loaded to YubiKey" waiting
progress_define "CERT_ATTACH" "Certificate attached to slot" waiting
progress_define "PRINT_BACKUP" "Printed backup page" waiting
progress_define "CLEANUP_DONE" "Local copies shredded" waiting

# --- Guided workflow --------------------------------------------------------
banner
info "Configuration file: $INI (override defaults by editing this file before running)."
info "Currently configured defaults:"
printf "    - RSA bits: %s\n" "$KEY_BITS"
printf "    - YubiKey slot: %s\n" "$SLOT"
printf "    - Output folder: %s\n" "$OUT_DIR"
printf "    - Run folder (per execution): %s\n" "$RUN_DIR"
printf "    - Certificate validity (days): %s\n" "$CERT_DAYS"
printf "    - Certificate subject: %s\n" "$SUBJECT"
info "During this guide you will enter three different secrets when prompted:"
printf "    - PIN: unlocks signing operations on the YubiKey (defaults to 123456).\n"
printf "    - PUK: unblocks the PIN after too many wrong attempts (defaults to 12345678).\n"
printf "    - Management key: permits administrative changes. This script prefers protected keys so you only need the PIN.\n"
info "Any time OpenSSL runs you will also create or confirm a passphrase that protects the offline backup file."
info "Commands displayed in bold red are about to run; press Enter to continue or Ctrl+C to abort safely."
info "The progress overview below updates after each decision so you always know what remains."
acknowledge "Press Enter to begin the guided setup."

ensure_dir "$OUT_DIR"
ensure_dir "$RUN_DIR"

progress_current "ENV_SETUP"
progress_render

section "Prepare your environment" "Confirm your YubiKey is inserted and that you know the current PIN, PUK, and management key."
info "This check starts the smart-card service so ykman can talk to the device. No credentials are required yet."
info "If your device is brand new, the defaults are PIN 123456, PUK 12345678, and management key 010203...0708."
info "If you are unsure of any credential, pause now and locate it before continuing."
acknowledge "Press Enter to verify the smart card service."
rc-service pcscd start >/dev/null 2>&1 || true
success "pcscd service checked."
progress_current "PIV_RESET"
progress_set "ENV_SETUP" done
section "Reset YubiKey PIV Storage" "Clean the PIV applet so the signing slot only contains the backup key you are about to import."
info "Slot $SLOT is a PIV signing slot (9c by default). Keys stored here never leave the device; the PIN unlocks them for signing."
info "Resetting the PIV applet deletes every private key, certificate, and cached credential on the YubiKey PIV interface."
info "After a reset the PIN becomes 123456, the PUK 12345678, and the management key 010203...0708."
info "ykman piv reset asks you to confirm by touching the YubiKey; no PIN is requested during the reset itself."
info "Take a moment to record any values you plan to set later in a secure location."
if prompt_yes_no "Show current PIV slots and certificates before deciding" "" Y; then
  if run_with_retry "ykman piv info"; then
    info "Review the output above; any listed certificate indicates an existing key."
  else
    warn "Unable to query current PIV state. Ensure the device is present and unlocked before continuing."
  fi
fi
info "Resetting is required only if you want a completely clean PIV state. Skip it if other slots contain keys you still need."
if prompt_yes_no "Reset the PIV storage now (erases all PIV keys/certs)" "" N; then
  if run_with_retry "ykman piv reset"; then
    success "PIV storage reset. Use the factory-default PIN/PUK/management key until you change them in the next steps."
    progress_current "PIN_CHANGE"
    progress_set "PIV_RESET" done
    PIV_RESET_DONE=1
  else
    warn "PIV reset skipped after errors."
    progress_current "PIN_CHANGE"
    progress_set "PIV_RESET" skipped
  fi
else
  info "Skipping PIV reset by request."
  progress_current "PIN_CHANGE"
  progress_set "PIV_RESET" skipped
fi

progress_current "PIN_CHANGE"
section "Optional: Change PIN" "Rotating the PIN limits access if the old code is known or has been shared."
info "You will need to provide the current PIN followed by the new PIN twice."
info "PINs are 6-8 digits. After three incorrect attempts the YubiKey requires the PUK to unblock."
info "Record the new PIN in your secure storage before moving on."
PIN_PROMPT_DEFAULT=$([ "$PIV_RESET_DONE" -eq 1 ] && printf 'Y' || printf 'N')
if [ "$PIV_RESET_DONE" -eq 1 ]; then
  info "Because the device was reset, changing the PIN now ensures you leave the factory default state."
fi
if prompt_yes_no "Change the PIV PIN now" "" "$PIN_PROMPT_DEFAULT"; then
  if run_with_retry "ykman piv access change-pin"; then
    success "PIN change completed."
    info "Verify the new PIN was saved somewhere safe; you will need it to use the private key."
    progress_current "PUK_RESET"
    progress_set "PIN_CHANGE" done
  else
    warn "PIN change skipped by request."
    progress_current "PUK_RESET"
    progress_set "PIN_CHANGE" skipped
  fi
else
  info "Skipping PIN change."
  progress_current "PUK_RESET"
  progress_set "PIN_CHANGE" skipped
fi

section "Optional: Reset PUK and management key" "Choose this if you want the device to have fresh credentials before importing the backup key."
info "Rotating these credentials now prevents older values from lingering."
info "The PUK restores access when the PIN locks; store it separately from the PIN."
info "The management key grants administrative control for tasks like key import. When protected, ykman unlocks it with the PIN."
info "Both actions below prompt for the current value first, then the new value (or create new material for you)."

PUK_PROMPT_DEFAULT=$([ "$PIV_RESET_DONE" -eq 1 ] && printf 'Y' || printf 'N')
if [ "$PIV_RESET_DONE" -eq 1 ]; then
  info "Because the device was reset, setting a new PUK now prevents leaving the factory default active."
fi
progress_current "PUK_RESET"
if prompt_yes_no "Reset the PIV PUK now" "" "$PUK_PROMPT_DEFAULT"; then
  if run_with_retry "ykman piv access change-puk"; then
    success "PUK reset completed."
    info "Write down the new PUK immediately. Without it, a locked PIN forces a full device reset."
    progress_current "MGMT_ROTATE"
    progress_set "PUK_RESET" done
  else
    warn "PUK reset skipped after errors."
    progress_current "MGMT_ROTATE"
    progress_set "PUK_RESET" skipped
  fi
else
  info "Skipping PUK reset."
  progress_current "MGMT_ROTATE"
  progress_set "PUK_RESET" skipped
fi

info "Next, decide whether to rotate the management key. Generating a protected key stores it encrypted on the device and prints recovery instructions."
MGMT_PROMPT_DEFAULT=$([ "$PIV_RESET_DONE" -eq 1 ] && printf 'Y' || printf 'N')
if [ "$PIV_RESET_DONE" -eq 1 ]; then
  info "Because the device was reset, rotating the management key now replaces the published factory value."
fi
progress_current "MGMT_ROTATE"
if prompt_yes_no "Generate a new protected management key now" "" "$MGMT_PROMPT_DEFAULT"; then
  if run_with_retry "ykman piv access change-management-key --protect --generate"; then
    success "Management key rotation completed."
    info "ykman prints the wrapping key reference; follow the on-screen instructions to capture it before continuing."
    progress_current "KEY_CREATE"
    progress_set "MGMT_ROTATE" done
  else
    warn "Management key reset skipped after errors."
    progress_current "KEY_CREATE"
    progress_set "MGMT_ROTATE" skipped
  fi
else
  info "Leaving the existing management key in place. Ensure you have it recorded before proceeding."
  progress_current "KEY_CREATE"
  progress_set "MGMT_ROTATE" skipped
fi

progress_current "KEY_CREATE"
section "Generate encrypted RSA key" "OpenSSL will prompt for a strong passphrase that protects the offline backup."
info "Output key file: $OUT_KEY"
info "OpenSSL will ask for the passphrase twice (set and confirm)."
info "Choose a passphrase you can store offline; this passphrase is required any time you restore the backup."
critical_block \
  "" \
  "${STYLE_WHITE_BOLD}It's now time to create your ${STYLE_BLUE_BOLD}SIGNING KEY${STYLE_WHITE_BOLD}." \
  "This is the private key that will be used to sign your code, and is generated randomly by OpenSSL." \
  "" \
  "${STYLE_WHITE_BOLD}You will be prompted for a ${STYLE_RED_BOLD}PEM PASS PHRASE${STYLE_WHITE_BOLD}" \
  "This passphrase will be used to create an ${STYLE_GREEN}encrypted backup${STYLE_RESET} of your ${STYLE_BLUE_BOLD}SIGNING KEY${STYLE_WHITE_BOLD}." \
  ""\
  "${STYLE_WHITE_BOLD}The ${STYLE_GREEN_BOLD}RSA BACKUP FILE${STYLE_WHITE_BOLD} can be decrypted with your ${STYLE_RED_BOLD}PEM PASS PHRASE${STYLE_WHITE_BOLD}." \
  ""\
  "${STYLE_WHITE_BOLD}Decrypting your ${STYLE_GREEN_BOLD}RSA BACKUP FILE${STYLE_WHITE_BOLD} will reveal your ${STYLE_BLUE_BOLD}SIGNING KEY${STYLE_WHITE_BOLD}." \
  "" \
  "${STYLE_WHITE_BOLD}This ${STYLE_BLUE_BOLD}SIGNING KEY${STYLE_WHITE_BOLD} can be loaded onto a new ${STYLE_YELLOW}YubiKey${STYLE_WHITE_BOLD} in the future."

if run_with_retry "openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:$KEY_BITS -aes-256-cbc -out \"$OUT_KEY\""; then
  success "Encrypted private key generated."
  progress_current "KEY_VERIFY"
  progress_set "KEY_CREATE" done
else
  warn "Key generation skipped; cannot continue."
  exit 1
fi

progress_current "KEY_VERIFY"
section "Verify the encrypted key" "We immediately re-open the key to ensure the passphrase works before proceeding."
info "Enter the same passphrase when prompted to confirm it was recorded correctly."
if run_with_retry "openssl pkey -in \"$OUT_KEY\" -noout -text > /dev/null"; then
  success "Decryption check succeeded."
  progress_current "BACKUP_PAGE"
  progress_set "KEY_VERIFY" done
else
  warn "Passphrase verification skipped; cannot continue."
  exit 1
fi

DATE_UTC=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
HOST=$(hostname 2>/dev/null || echo alpine-live)
HASH=$(sha256sum "$OUT_KEY" | awk '{print $1}')

progress_current "BACKUP_PAGE"
section "Create printable backup page" "This page records verification commands and embeds the encrypted key material."
info "Backup page: $OUT_TXT"
info "It includes restore commands, a checksum, and the encrypted PEM blob so you can re-create the key later."
acknowledge "Press Enter to generate the printable backup."
{
  echo "$TITLE"
  echo "Date: $DATE_UTC"
  echo "Host: $HOST"
  echo "Folder: $RUN_DIR"; echo
  echo "RESTORE (you will be prompted for the passphrase):"
  echo "  1) Recreate file as:"
  echo "       $(basename "$OUT_KEY")"
  echo "  2) Verify SHA256 checksum equals Expected below:"
  echo "       sha256sum $(basename \"$OUT_KEY\")"
  echo "       Expected: $HASH"
  echo "  3) Sanity-check parses:"
  echo "       openssl pkey -in $(basename \"$OUT_KEY\") -noout -text"
  echo "  4) CSR and self-sign certificate:"
  echo "       openssl req -new -key $(basename \"$OUT_KEY\")"
  echo "         -subj \"$SUBJECT\" -out csr.pem"
  echo "       openssl x509 -req -in csr.pem"
  echo "         -signkey $(basename \"$OUT_KEY\") -days $CERT_DAYS"
  echo "         -out self-signed-certificate.pem"
  echo "       rm -f csr.pem"
  echo "  5) Import to $SLOT (or chosen slot):"; echo "       ykman piv keys import $SLOT $(basename \"$OUT_KEY\")"; echo "       ykman piv certificates import $SLOT self-signed-certificate.pem"
  echo; echo "----- Encrypted key (PKCS#8 PEM) -----"; cat "$OUT_KEY"; echo "----- End encrypted key -----"; echo
  echo "SHA256($(basename \"$OUT_KEY\"))"
  echo "  Expected: $HASH"; echo
  echo "Passphrase hint (do NOT write the passphrase here):"
  echo "______________________________________________________________"
} > "$OUT_TXT"
success "Backup page prepared."
progress_current "KEY_IMPORT"
progress_set "BACKUP_PAGE" done

progress_current "KEY_IMPORT"
section "Import key to YubiKey slot $SLOT" "This loads the encrypted key into the hardware. You will be prompted for the management key."
info "Expect prompts for the key passphrase followed by the YubiKey PIN."
info "The sequence is: decrypt the backup with its passphrase, touch the YubiKey if asked, then enter the PIN (or management key)."
info "If you used --protect when rotating the management key, ykman unlocks it with your PIN before continuing."
acknowledge "Press Enter when you are ready to import the key onto the YubiKey."
if run_with_retry "ykman piv keys import $SLOT \"$OUT_KEY\""; then
  success "Private key imported to slot $SLOT."
  KEY_IMPORTED=1
  progress_current "CERT_ATTACH"
  progress_set "KEY_IMPORT" done
else
  warn "YubiKey import skipped; hardware operations will be skipped."
  progress_current "CERT_ATTACH"
  progress_set "KEY_IMPORT" skipped
fi
if [ "$KEY_IMPORTED" -eq 1 ]; then
  info "Many clients expect a certificate to accompany the private key."
  info "Certificate generation will prompt for the key passphrase followed by the PIN."
  progress_current "CERT_ATTACH"
  if prompt_yes_no "Generate a matching self-signed certificate for slot $SLOT" "" Y; then
    CSR_PATH="$RUN_DIR/self-signed-certificate.csr"
    printf "%s> Create certificate signing request (CSR)%s\n" "$STYLE_PROMPT" "$STYLE_RESET"
    if run_with_retry "openssl req -new -key \"$OUT_KEY\" -subj \"$SUBJECT\" -out \"$CSR_PATH\""; then
      printf "%s> Sign CSR to create a self-signed certificate%s\n" "$STYLE_PROMPT" "$STYLE_RESET"
      if run_with_retry "openssl x509 -req -in \"$CSR_PATH\" -signkey \"$OUT_KEY\" -days $CERT_DAYS -out \"$CERT_PATH\""; then
        CERT_CREATED=1
        rm -f "$CSR_PATH" 2>/dev/null || true
        success "Self-signed certificate written to $CERT_PATH."
        if prompt_yes_no "Import the new certificate into slot $SLOT now" "" Y; then
          if run_with_retry "ykman piv certificates import $SLOT \"$CERT_PATH\""; then
            success "Self-signed certificate imported."
            progress_current "PRINT_BACKUP"
            progress_set "CERT_ATTACH" done
          else
            warn "Certificate import skipped by request."
            progress_current "PRINT_BACKUP"
            progress_set "CERT_ATTACH" skipped
          fi
        else
          info "Certificate left on disk for manual import."
          progress_current "PRINT_BACKUP"
          progress_set "CERT_ATTACH" skipped
        fi
      else
        rm -f "$CSR_PATH" 2>/dev/null || true
        warn "Self-signed certificate generation skipped."
        progress_current "PRINT_BACKUP"
        progress_set "CERT_ATTACH" skipped
      fi
    else
      rm -f "$CSR_PATH" 2>/dev/null || true
      warn "Certificate signing request generation skipped."
      progress_current "PRINT_BACKUP"
      progress_set "CERT_ATTACH" skipped
    fi
  else
    info "Skipping certificate creation."
    progress_current "PRINT_BACKUP"
    progress_set "CERT_ATTACH" skipped
  fi
else
  info "Skipping certificate creation because the private key was not imported."
  progress_current "PRINT_BACKUP"
  progress_set "CERT_ATTACH" skipped
fi

# Printer autodetect
if [ -z "${PRN_DEV:-}" ]; then
  if [ -e /dev/usb/lp0 ]; then PRN_DEV=/dev/usb/lp0
  elif [ -e /dev/lp0 ]; then PRN_DEV=/dev/lp0
  else PRN_DEV=""; fi
fi

section "Optional: Print the backup page" "Printing immediately gives you a paper record. Confirm your printer is connected."
progress_current "PRINT_BACKUP"
acknowledge "Press Enter to review printing options."
if [ -n "$PRN_DEV" ]; then
  info "Detected printer device at $PRN_DEV."
  if prompt_yes_no "Send the backup page to the printer now" "" N; then
    if run_with_retry "PRN_DEV=\"$PRN_DEV\" ./print.sh \"$OUT_TXT\""; then
      success "Print job sent."
      PRINT_DONE=1
      progress_current "CLEANUP_DONE"
      progress_set "PRINT_BACKUP" done
    else
      warn "Print step skipped after errors."
      progress_current "CLEANUP_DONE"
      progress_set "PRINT_BACKUP" skipped
    fi
  else
    info "Skipping print by request."
    progress_current "CLEANUP_DONE"
    progress_set "PRINT_BACKUP" skipped
  fi
else
  warn "No printer detected automatically; skipping print step."
  acknowledge "Press Enter to continue."
  progress_current "CLEANUP_DONE"
  progress_set "PRINT_BACKUP" skipped
fi

section "Secure cleanup" "Once you've confirmed backups are in hand, shred local copies to prevent leakage."
progress_current "CLEANUP_DONE"
if prompt_yes_no "Shred $OUT_KEY, $OUT_TXT (and any generated certificate) from disk" "" N; then
  shred_cmd="shred -u \"$OUT_KEY\" \"$OUT_TXT\""
  if [ -f "$CERT_PATH" ]; then
    shred_cmd="$shred_cmd \"$CERT_PATH\""
  fi
  if run_with_retry "$shred_cmd"; then
    success "Files shredded."
    FILES_SHREDDED=1
    progress_set "CLEANUP_DONE" done
  else
    warn "Shred skipped; files remain on disk."
    progress_set "CLEANUP_DONE" skipped
  fi
else
  info "Backup folder retained on disk:"
  printf "    %s\n" "$RUN_DIR"
  printf "    %s\n" "$OUT_KEY"
  printf "    %s\n" "$OUT_TXT"
  if [ -f "$CERT_PATH" ]; then
    printf "    %s\n" "$CERT_PATH"
  fi
  progress_set "CLEANUP_DONE" skipped
fi

draw_rule
success "All steps complete. Store your passphrase and printed backup securely."
print_next_steps
draw_rule
