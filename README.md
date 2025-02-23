Procédure pour la désactivation du MDM :

Boot to Recovery Mode:
1. Shut down Mac
2. Hold power button until "Loading startup options" appears
3. Click Options → Continue

Disable System Integrity Protection:
1. Open Terminal (Utilities menu)
2. Run: csrutil disable
3. Run: reboot and re-enter Recovery Mode

Mount System Volume:
1. Open Disk Utility
2. Select "Macintosh HD" (or your system volume)
3. Click "Mount" (don't reformat)
4. Close Disk Utility

Prepare Script Execution:
1. Open Terminal
2. Enter:
curl -O https://raw.githubusercontent.com/philippeviennecouture/Gab/main/MDM.sh
chmod +x script.sh
3. Run script with:
./script.sh
4. After script completes:
reboot

At login screen, select "Gabriel", password: passwordtemp
