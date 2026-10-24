# NanoPods

AirPods audio on the iPod nano 7, with a Windows build and installation workflow powered by [blueth4w](https://github.com/kilo2071/blueth4w).

NanoPods provides documentation and PowerShell helpers. The Bluetooth patch is developed by blueth4w. No Apple firmware, patched images, device backups, or third-party binaries are distributed here.

## Tested setup

- Original 2012 iPod nano 7, **1.0.4 PC / build 37A40005**, FAT32.
- AirPods Pro 2, USB-C edition.
- Build: Ubuntu 24.04 in WSL2. Installation: native Windows iTunes.
- Audio confirmed before and after restarting the nano.

This records one successful setup, not a guarantee for other devices. The blueth4w author documented Linux flashing and did not originally test FAT32. Firmware modification can leave the iPod unusable. Keep the original firmware and copies of your music. A stock restore removes the fix; other firmware modifications may overwrite its font payload.

## 1. Obtain official firmware

Update the nano through iTunes to **1.0.4 PC**. Download the original package separately:

[iPod_1.0.4_37A40005.ipsw from Apple](https://secure-appldnld.apple.com/iPod/SBML/osx/bundles/031-26260-201500810-D2BC269E-3FBC-11E5-885A-067B3A53DB92/iPod_1.0.4_37A40005.ipsw)

- Size: `117989754` bytes
- SHA1: `fc6d4346e8a0fafe700833ccd4e26b956d8fbfd5`

Keep this original unchanged. This guide targets the **2012 nano on 1.0.4**, not the 2015 revision's 1.1.2 firmware.

## 2. Build in WSL2

If needed, run in administrator **Windows PowerShell**, then restart if requested and complete Ubuntu's initial setup:

```powershell
wsl --install -d Ubuntu-24.04
```

Run the following in **Ubuntu**, not PowerShell:

```bash
sudo apt update
sudo apt install -y build-essential git curl ca-certificates unzip \
  python3.12 python3.12-venv fontforge \
  binutils-arm-none-eabi gcc-arm-none-eabi \
  pkg-config libssl-dev libusb-1.0-0-dev

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup-init.sh
sh /tmp/rustup-init.sh
```

Choose the default Rust installation, then:

```bash
source "$HOME/.cargo/env"
cd ~
git clone https://github.com/kilo2071/blueth4w.git
cd blueth4w
explorer.exe .
```

Copy the original IPSW into the folder opened in Explorer. Back in Ubuntu:

```bash
sha1sum iPod_1.0.4_37A40005.ipsw

bash release/build.sh \
  --ipsw ./iPod_1.0.4_37A40005.ipsw \
  --out ./Firmware-nano7-btfix.MSE

bash release/build.sh \
  --ipsw ./iPod_1.0.4_37A40005.ipsw \
  --out ./Firmware-stock.MSE --stock
```

Check the SHA1 against the value above. The patched build must finish successfully with `DONE -> ./Firmware-nano7-btfix.MSE`. Do not use output from a failed build.

Run `explorer.exe .` to copy the MSE files to a Windows working folder. WSL is used only for building; USB passthrough and DFU are not required for this installation route.

## 3. Back up exposed storage

Open administrator PowerShell in this repository's folder. Close iTunes/Apple Devices and connect the nano normally. Use an existing destination folder on your computer:

```powershell
.\scripts\Backup-NanoWindows.ps1 -OutputPath 'C:\NanoPods\ipod-backup.img'
```

Replace example paths throughout this guide with your own. Allow at least 17 GB free space on a filesystem supporting files larger than 4 GB.

The helper identifies one Apple iPod of the expected capacity, opens its disk read-only, refuses to overwrite files, copies the reported disk length, and computes SHA256. An incomplete image is not a backup. It backs up only storage Windows exposes; hidden firmware coverage and restoration are **not verified**. Preserve your music separately too.

If execution policy blocks a script, review its source and use a process-scoped policy appropriate for your system. Organizational policy may override it.

## 4. Package the patched firmware

In Windows PowerShell:

```powershell
.\scripts\Build-NanoIPSW.ps1 `
  -OriginalIPSW 'C:\NanoPods\iPod_1.0.4_37A40005.ipsw' `
  -PatchedMSE 'C:\NanoPods\Firmware-nano7-btfix.MSE' `
  -OutputIPSW 'C:\NanoPods\iPod_1.0.4_37A40005-btfix.ipsw'
```

The helper checks the original IPSW checksum, copies it, and replaces only `Firmware.MSE`. It verifies that the original manifest and bootloader remain unchanged and that the packaged payload matches the input. It refuses existing output paths. These are packaging checks, not a guarantee of patch safety. The script does not write to the iPod.

## 5. Install with native Windows iTunes

1. Connect the nano normally, with its storage visible in File Explorer.
2. Open iTunes, select the nano, and open **Summary**.
3. Hold **Shift** and click **Check for Update**.
4. Select the custom `iPod_1.0.4_37A40005-btfix.ipsw`.
5. Follow the prompts and leave the cable connected until completion.

Use **Check for Update**, not Restore. If iTunes rejects the file, record the error rather than changing firmware versions to bypass it.

## 6. Verify

Safely eject and disconnect the nano. Temporarily disable Bluetooth on nearby devices that may take the AirPods connection. Connect the AirPods to the nano and play a downloaded song at low volume. Confirm both earbuds work, restart the nano, and test again.

Playback before and after restarting is the functional verification. Settings can still report **1.0.4 PC**.

Keep the working IPSW, original IPSW, both MSE files, and storage backup locally. None belong in this repository.

## Credits

- [kilo2071 / blueth4w](https://github.com/kilo2071/blueth4w): Bluetooth fix integration for 1.0.4 and boot-time font payload. See its [technical explanation](https://github.com/kilo2071/blueth4w/blob/main/docs/HOW_IT_WORKS.md).
- [CUB3D / ipod_sun](https://github.com/CUB3D/ipod_sun): iPod font exploit groundwork.
- [olievans123 / nano7-untethered](https://github.com/olievans123/nano7-untethered): untethered firmware framework.
- [nfzerox / ipod_theme](https://github.com/nfzerox/ipod_theme): documented custom IPSW installation with Windows iTunes, the precedent for this route.

Upstream projects retain their own licenses. This repository does not redistribute their source or Apple firmware.
