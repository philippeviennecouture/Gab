#!/bin/bash

# Enable strict error checking
set -euo pipefail

# Define system volume names to check (adjust as needed)
VOLUME_NAMES=("/Volumes/Macintosh HD" "/Volumes/MyVolume")

# Check if running in Recovery Mode
if ! csrutil status | grep -qi "disabled"; then
  echo "ERROR: System Integrity Protection (SIP) must be disabled in Recovery Mode."
  echo "1. Reboot to Recovery Mode (Hold Power button)"
  echo "2. Utilities > Terminal: csrutil disable"
  echo "3. Reboot to Recovery Mode again"
  exit 1
fi

# Find system volume
for vol in "${VOLUME_NAMES[@]}"; do
  if [[ -d "$vol" ]]; then
    SYSTEM_VOLUME="$vol"
    break
  fi
done

if [[ -z "${SYSTEM_VOLUME:-}" ]]; then
  echo "ERROR: System volume not found. Mount it in Disk Utility first."
  exit 1
fi

# Mount system volume as writable
if ! mount | grep -q " ${SYSTEM_VOLUME} "; then
  echo "Mounting system volume as writable..."
  if ! diskutil mount -rw "$SYSTEM_VOLUME"; then
    echo "ERROR: Failed to mount system volume"
    exit 1
  fi
else
  echo "System volume already mounted"
fi

# Backup original hosts file
HOSTS_FILE="${SYSTEM_VOLUME}/etc/hosts"
HOSTS_BAK="${HOSTS_FILE}.bak"
if [[ ! -f "$HOSTS_BAK" ]]; then
  cp -v "$HOSTS_FILE" "$HOSTS_BAK" || {
    echo "ERROR: Failed to backup hosts file"
    exit 1
  }
fi

# MDM domains to block
MDM_DOMAINS=(
  "deviceenrollment.apple.com"
  "mdmenrollment.apple.com"
  "iprofiles.apple.com"
  "gdmf.apple.com"
  "albert.apple.com"
  "captive.apple.com"
)

# Modify hosts file
{
  echo "# MDM Blocking" >> "$HOSTS_FILE"
  for domain in "${MDM_DOMAINS[@]}"; do
    if ! grep -q "127.0.0.1 $domain" "$HOSTS_FILE"; then
      echo "127.0.0.1 $domain" >> "$HOSTS_FILE"
    fi
  done
} || {
  echo "ERROR: Failed to modify hosts file"
  exit 1
}

# Make hosts file immutable
chflags uchg "$HOSTS_FILE" || {
  echo "WARNING: Failed to make hosts file immutable"
}

# Create admin user
USERNAME="Gabriel"
USER_ID=505
ADMIN_GROUP_ID=80
DSCL_DIR="${SYSTEM_VOLUME}/var/db/dslocal/nodes/Default"

if ! dscl -f "$DSCL_DIR" localhost -read "/Local/Default/Users/$USERNAME" &>/dev/null; then
  echo "Creating admin user: $USERNAME"
  dscl -f "$DSCL_DIR" localhost -create "/Local/Default/Users/$USERNAME" || exit 1
  dscl -f "$DSCL_DIR" localhost -create "/Local/Default/Users/$USERNAME" UserShell "/bin/bash"
  dscl -f "$DSCL_DIR" localhost -create "/Local/Default/Users/$USERNAME" RealName "$USERNAME"
  dscl -f "$DSCL_DIR" localhost -create "/Local/Default/Users/$USERNAME" UniqueID "$USER_ID"
  dscl -f "$DSCL_DIR" localhost -create "/Local/Default/Users/$USERNAME" PrimaryGroupID "$ADMIN_GROUP_ID"
  dscl -f "$DSCL_DIR" localhost -create "/Local/Default/Users/$USERNAME" NFSHomeDirectory "/Users/$USERNAME"
  dscl -f "$DSCL_DIR" localhost -passwd "/Local/Default/Users/$USERNAME" "passwordtemp"
  dscl -f "$DSCL_DIR" localhost -append "/Local/Default/Groups/admin" GroupMembership "$USERNAME"
else
  echo "User $USERNAME already exists"
fi

# Create home directory
HOME_DIR="${SYSTEM_VOLUME}/Users/$USERNAME"
mkdir -p "$HOME_DIR" || {
  echo "ERROR: Failed to create home directory"
  exit 1
}
chown "${USER_ID}:${ADMIN_GROUP_ID}" "$HOME_DIR" || {
  echo "WARNING: Failed to set home directory permissions"
}

# Configure passwordless sudo
SUDOERS_DIR="${SYSTEM_VOLUME}/etc/sudoers.d"
mkdir -p "$SUDOERS_DIR"
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_DIR/99-$USERNAME" || {
  echo "ERROR: Failed to configure sudoers"
  exit 1
}
chmod 440 "$SUDOERS_DIR/99-$USERNAME" || {
  echo "WARNING: Failed to set sudoers file permissions"
}

# Create persistence script
PERSISTENT_SCRIPT="${SYSTEM_VOLUME}/usr/local/bin/mdm_persistent.sh"
mkdir -p "${SYSTEM_VOLUME}/usr/local/bin"
cat > "$PERSISTENT_SCRIPT" << 'EOF'
#!/bin/bash
# Re-block MDM domains if needed
if ! grep -q "deviceenrollment.apple.com" /etc/hosts; then
  for domain in deviceenrollment.apple.com mdmenrollment.apple.com iprofiles.apple.com gdmf.apple.com albert.apple.com captive.apple.com; do
    grep -q "$domain" /etc/hosts || echo "127.0.0.1 $domain" | sudo tee -a /etc/hosts
  done
  sudo chflags uchg /etc/hosts
fi
# Disable MDM services
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.mdmclient.plist 2>/dev/null
EOF
chmod +x "$PERSISTENT_SCRIPT" || {
  echo "ERROR: Failed to make persistent script executable"
  exit 1
}

# Create LaunchAgent
LAUNCH_AGENT_DIR="${HOME_DIR}/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENT_DIR"
cat > "${LAUNCH_AGENT_DIR}/com.user.mdmblock.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.mdmblock</string>
    <key>ProgramArguments</key>
    <array>
        <string>${PERSISTENT_SCRIPT}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
chown -R "${USER_ID}:${ADMIN_GROUP_ID}" "$LAUNCH_AGENT_DIR" || {
  echo "WARNING: Failed to set LaunchAgent permissions"
}

echo -e "\nSetup complete! Reboot and log in as '$USERNAME' (password: passwordtemp)."
echo "Immediately change the password after first login!"