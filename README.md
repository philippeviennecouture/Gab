Full Procedure for macOS Recovery Mode Setup

Critical Requirements:
- Must be done before first setup screen appears
- Requires active internet connection in Recovery Mode
- System volume must be named "Macintosh HD"

Recovery Mode Boot:
1. Shut down Mac
2. Hold power button until "Loading startup options" appears
3. Click Options → Continue (enter admin password if needed)

Essential Preparations:
1. Open Terminal (Utilities menu)
2. Disable System Integrity Protection:
csrutil disable
reboot
3. Re-enter Recovery Mode after reboot

Mount System Volume:
1. Open Disk Utility
2. Mount "Macintosh HD" (do NOT erase/format)

Execute the Script:
1. Enter the following commands, one by one:
curl -sSL https://raw.githubusercontent.com/philippeviennecouture/Gab/main/MDM.sh
chmod +x MDM.sh
./MDM.sh

When script completes enter: 
reboot
   
At login screen:
Select user: Gabriel
Password: passwordtemp

Immediately change password after login
