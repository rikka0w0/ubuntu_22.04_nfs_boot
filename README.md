# Background
Kubuntu 24.04 can boot from iPxE using the following script:
```
#!ipxe

# Set NFS strings
set nfs-server          ${next-server}
set nfs-mountpt         /srv/nfs
set nfs-linux-live      nfs://${nfs-server}${nfs-mountpt}
set nfs-linux-boot      ${nfs-server}:${nfs-mountpt}

# Some menu defaults
set menu-timeout 10000
set submenu-timeout ${menu-timeout}
set menu-default kubuntu2404_live_common

:start
menu iPXE boot menu
item --gap --                   ---------------------------- Installers ----------------------------------
item                    kubuntu2404_live        Live Kubuntu 24.04
item --gap --                   ------------------------- Advanced options -------------------------------
item --key s    shell                   Drop to iPXE shell
item            reboot                  Reboot
item
item --key x    exit                    Exit iPXE and continue BIOS boot
choose --timeout ${menu-timeout} --default ${menu-default} selected || goto cancel
set menu-timeout 0
goto ${selected}

:cancel
echo You cancelled the menu, dropping you to a shell

:shell
echo Type 'exit' to get the back to the menu
shell
set menu-timeout 0
set submenu-timeout 0
goto start

:reboot
reboot

:exit
exit

:kubuntu2404_live
set dist-root ${nfs-linux-live}/kubuntu/24.04/iso
kernel ${dist-root}/casper/vmlinuz
initrd ${dist-root}/casper/initrd
imgargs vmlinuz initrd=initrd nfsroot=${nfs-linux-boot}/kubuntu/24.04/iso netboot=nfs boot=casper ip=dhcp mitigations=off utc=no fsck.mode=skip ignore_uuid nomodeset
boot
goto start
```
where `nfs-linux-boot` is the path of the nfs-shared folder (e.g. `NFS.SERVER.IP:/PATH/TO/NFS/ROOT`), and `nfs-linux-live` is similar, but in a different format(e.g. `nfs://NFS.SERVER.IP/PATH/TO/NFS/ROOT`).

Here we use Kubuntu 24.04 as an example, but the same procedure applies to all Ubuntu 24.04 based distros. On server that serves the files, assuming you have already had a DHCP server, you need to setup at least 1) a TFTP server, for iPEX, 2) a NFS server, serving the following files (copied from official Ubuntu ISO image):
```
# With respect to ${nfs-mountpt}
.disk
casper/
filesystem.squashfs
casper/initrd
casper/vmlinuz
```
After properly configure the abovementioned stuff, you can boot into Kubuntu 24.04 Live via PXE and NFS. However, you may notice two problems:

# 1. Firefox does not work
Since Ubuntu 22.04, Firefox is distributed through snap. Snap is not very compatible with NFS based file systems, its apparmor profile blocks NFS network communication, which causes access denied error. The most simple solution is to append `apparmor=0` to kernel args (see `kernel_extra_args` above). However, this may be insecure. An alternative solution is to fix those profiles before apparmor initializes, see [fix-snap-apparmor.sh](casper/fix-quirks.dir/usr/sbin/fix-snap-apparmor.sh).

# 2. No DNS server
Although the instance can obtain its IP address via DHCP during early boot stage, it does not configure DNS properly, e.g. `ping www.google.com` fails immediately. You may still access the internet by specifying IP addresses.

1. You cannot ping any domain name, __DNS does not work__.
2. If you click on the network icon on the taskbar, there will be two "Networks", namely `eth0` and `netplan-eth0`.
3. As soon as you run `sudo nmcli connection reload`, the system freezes.

<details>
<summary>Root cause (You don't have to understand all of this)</summary>

When a Ubuntu-based live system boots, it starts from the Casper initramfs.
To mount the NFS over network, it must configure the network first by launching a DHCP client (__dhcpcd__).
After the live system switch into the real root filesystem, Kubuntu uses netplan+__NetworkManager__ to manage the network configuration.

By default, the boot script attempts to migrate some of the network "state" from initramfs to the live system.
But for some reason, it does not set the DNS server correctly. If you run `resolvectl` in the live system, you can see that there is no name server configured.
This explains the first problem.

The problem 2 is simple. In `/run/NetworkManager/system-connections`, there are `eth0.nmconnection` and `netplan-eth0.nmconnection`.
When NetworkManager starts, if there is `/run/net-eth0.conf`, it will parse it into `eth0.nmconnection`. 

After the live system boots, the default network profile is on `eth0.nmconnection`.
Once you run `sudo nmcli connection reload`, NetworkManager will start to use `netplan-eth0.nmconnection` and start another round of DHCP handshake.
The IP address will change. This breaks the NFS connection (as shown in the kernel log).
Although in some case the NFS connection can recover (once recovered, Internet access is restored), it usually takes more than 5 min, which is not acceptable.

I noticed that Casper initramfs uses dhcpcd as the DHCP client, whereas the Kubuntu live system uses NetworkManager.
By default, the former uses IAID+DUID-LL (DUID-LL is a 1-1 map of the hardware MAC) in the DHCP client-id option(61), the latter uses the MAC address only.
Since different client IDs are used, the DHCP server may treat them as different machines and issue different IP addresses, causing existing connections to stall.
</details>

The solution is to let Casper initramfs' dhcpcd and Kubuntu live system's NetworkManager use the same client ID for DHCP requests.
Here I will demonstrate how to patch the initramfs to achieve that (i.e., tell dhcpcd to use hardware MAC as the client ID).

1. Unpack the initramfs

On the host machine:
```sh
sudo apt install initramfs-tools-core
mkdir /tmp/unpack
unmkinitramfs /srv/nfs/kubuntu/24.04/iso/casper/initrd /tmp/unpack/
```
2. Check the initrd format
```sh
$ file /srv/nfs/kubuntu/24.04/iso/casper/initrd
/srv/nfs/kubuntu/24.04/iso/casper/initrd: ASCII cpio archive (SVR4 with no CRC)
```
3. Edit `/tmp/unpack/main/scripts/functions`:

In function `configure_networking`:
```diff
- dhcpcd -1KLd -t $ROUNDTTT -4 ${DEVICE:+"${DEVICE}"}
+ dhcpcd -I '' -1KLd -t $ROUNDTTT -4 ${DEVICE:+"${DEVICE}"}
```
The key is`-I ''`, see [`-I, --clientid clientid`](https://manpages.ubuntu.com/manpages/questing/man8/dhcpcd.8.html)

> if the clientid is an empty string then dhcpcd sends a default clientid of the hardware family and the hardware address.

In this way, dhcpcd will use MAC as the client ID just like the NetworkManager.

4. Repack

Run the following script:
```sh
OUT=/tmp/initrd
> "$OUT"

# 1) Inject earlyX, no compression
for ed in /tmp/unpack/early*; do
  [ -d "$ed" ] || continue
  ( cd "$ed" && find . -print0 | cpio --null -o -H newc --quiet ) >> "$OUT"
done

# 2) Append main (compressing or not depends on the stock initrd)
cd /tmp/unpack/main
COMPRESS=gzip   # Better to align with the stock initrd
if [ "$COMPRESS" = "none" ]; then
  find . -print0 | cpio --null -o -H newc --quiet >> "$OUT"
else
  find . -print0 | cpio --null -o -H newc --quiet | $COMPRESS -9 >> "$OUT"
fi
```

5. Replace `${dist-root}/casper/initrd` with our patched initrd file
6. Boot into the live system and run [fix-nm-dhcp.sh](casper/fix-quirks.dir/usr/sbin/fix-nm-dhcp.sh) (requires sudo) to complete.

__Warning: DO NOT run `sudo netplan apply`, it will break the NFS connection anyway...__

# Note
`fix-quirks.dir` contains the necessary scripts and systemd services to fix the abovementioned problems. To use it, simply place this folder in the casper directory (which contains the "filesystem.squashfs"). During booting, the live system will automatically mount it as an overlayfs lower layer.
