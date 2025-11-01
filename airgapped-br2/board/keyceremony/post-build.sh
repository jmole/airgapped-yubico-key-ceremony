# board/keyceremony/post-build.sh
# ...
INI="${TARGET_DIR}/etc/inittab"

# Drop any extra gettys so only Buildroot's generic one on tty1 remains
sed -i -r '/^tty0::respawn:\/sbin\/(a)?getty/d' "$INI"
sed -i -r '/^tty1::respawn:\/sbin\/(a)?getty/d' "$INI"
sed -i -r '/^ttyS0::respawn:\/sbin\/(a)?getty/d' "$INI"


echo 'tty1::respawn:/sbin/getty -L 115200 tty1 linux' >> "$INI"
echo 'ttyS0::respawn:/sbin/getty -L 115200 ttyS0 vt100' >> "$INI"

# Install RSA keygen helpers into /root from the repo's rsa-keygen directory
fail() { echo "ERROR: $*" >&2; exit 1; }

[ -n "${RSA_KEYGEN_DIR:-}" ] || fail "RSA_KEYGEN_DIR not set. Please run the build via ./build.sh"
[ -d "$RSA_KEYGEN_DIR" ] || fail "rsa-keygen source directory not found: $RSA_KEYGEN_DIR"

# Ensure target /root exists
mkdir -p "${TARGET_DIR}/root"

# Install files with desired modes
install -m 0755 "${RSA_KEYGEN_DIR}/rsa-keygen.sh" "${TARGET_DIR}/root/rsa-keygen.sh"
install -m 0644 "${RSA_KEYGEN_DIR}/rsa-keygen.ini" "${TARGET_DIR}/root/rsa-keygen.ini"
install -m 0755 "${RSA_KEYGEN_DIR}/print.sh"       "${TARGET_DIR}/root/print.sh"
