# board/keyceremony/post-build.sh
# ...
INI="${TARGET_DIR}/etc/inittab"

# Drop any extra gettys so only Buildroot's generic one on tty1 remains
sed -i -r '/^tty0::respawn:\/sbin\/(a)?getty/d' "$INI"
sed -i -r '/^tty1::respawn:\/sbin\/(a)?getty/d' "$INI"
sed -i -r '/^ttyS0::respawn:\/sbin\/(a)?getty/d' "$INI"


echo 'tty1::respawn:/sbin/getty -L 115200 tty1 linux' >> "$INI"
echo 'ttyS0::respawn:/sbin/getty -L 115200 ttyS0 vt100' >> "$INI"
