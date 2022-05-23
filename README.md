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
Although the instance can obtain its IP address via DHCP during early boot stage, it does not configure DNS properly, e.g. `ping www.google.com` fails immediately. You may still access the internet by specifying IP addresses. To fix this, we can add `FallbackDNS=<your router's IPv4> <your router's ULA IPv6>` to `/etc/systemd/resolved.conf` of the image. Alternatively, you can try `sudo resolvectl dns ens33 8.8.8.8` (replace ens33 with your iface) or `sudo netplan apply`.

# 2. Firefox does not work
Since Ubuntu 22.04, Firefox is distributed through snap. Snap is not very compatible with NFS based file systems, its apparmor profile blocks NFS network communication, which causes access denied error. The most simple solution is to append `apparmor=0` to kernel args (see `kernel_extra_args` above). However, this may be insecure. An alternative solution is to fix those profiles before apparmor initializes, see [fix-quirks.dir/usr/sbin/fix-snap-apparmor.sh](fix-quirks.dir/usr/sbin/fix-snap-apparmor.sh).
