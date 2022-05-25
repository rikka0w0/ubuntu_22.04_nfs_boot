Booting Ubuntu 22.04 via network (PXE) is similar to boot Ubuntu 20.04, the iPXE script looks like this:
```
# Set NFS strings
set nfs-server          ${next-server}
set nfs-mountpt         /srv/nfs
set nfs-linux-live      nfs://${nfs-server}${nfs-mountpt}
set nfs-linux-boot      ${nfs-server}:${nfs-mountpt}

......

:kubuntu2204_live
set kernel_extra_args hostname=kubuntu-nfs
:kubuntu2204_live_common
set dist-root ${nfs-linux-live}/kubuntu2204
kernel ${dist-root}/casper/vmlinuz
initrd ${dist-root}/casper/initrd
imgargs vmlinuz initrd=initrd nfsroot=${nfs-linux-boot}/kubuntu2204 netboot=nfs boot=casper ip=dhcp mitigations=off utc=no fsck.mode=skip ignore_uuid ${kernel_extra_args}
#imgargs vmlinuz initrd=initrd ip=dhcp url=${http-root}/kubuntu-22.04-desktop-amd64.iso root=/dev/ram0 cloud-config-url=/dev/null
boot
goto start
```
Here we use Kubuntu as an example, but the same procedure applies to all Ubuntu 20.04 based distros. On server that serves the files, assuming you have already had a DHCP server, you need to setup at least 1) a TFTP server, for iPEX, 2) a NFS server, serving the following files (copied from official Ubuntu ISO image):
```
# With respect to ${nfs-mountpt}
.disk
casper/
filesystem.squashfs
casper/initrd
casper/vmlinuz
```
After properly configure the abovementioned stuff, you can boot into Ubuntu 22.04 Live via PXE and NFS. However, you may notice two problems:

# 1. No DNS server
Although the instance can obtain its IP address via DHCP during early boot stage, it does not configure DNS properly, e.g. `ping www.google.com` fails immediately. You may still access the internet by specifying IP addresses.

The reason seems to be that Ubuntu does not switched to the netplan connection after the system boots from NFS (in this case, the interface has been assigned with IP address already). To fix this, we can run `nmcli connection up $netplan_name`, where "$netplan_name" is `netplan-` followed by the name of your primary network interface (e.g. `ens33`).

# 2. Firefox does not work
Since Ubuntu 22.04, Firefox is distributed through snap. Snap is not very compatible with NFS based file systems, its apparmor profile blocks NFS network communication, which causes access denied error. The most simple solution is to append `apparmor=0` to kernel args (see `kernel_extra_args` above). However, this may be insecure. An alternative solution is to fix those profiles before apparmor initializes, see [casper/fix-quirks.dir/usr/sbin/fix-snap-apparmor.sh](blob/main/casper/fix-quirks.dir/usr/sbin/fix-snap-apparmor.sh).

# Note
`fix-quirks.dir` contains the necessary scripts and systemd services to fix the abovementioned problems. To use it, simply place this folder in the casper directory (which contains the "filesystem.squashfs"). During booting, the live system will automatically mount it as an overlayfs lower layer.

`nfs_sshd.tar.gz` contains another overlayfs layer which adds NFS client and SSH server support, extract to `casper` folder to use. You need to generate the necessary files in `casper/nfs_sshd/etc/ssh`.
