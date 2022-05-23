#!/bin/bash
# This script adds two lines to /etc/apparmor.d/usr.lib.snapd.snap-confine.real
#    network inet,
#    network inet6,
sudo sed -i '\/\/usr\/lib\/snapd\/snap-confine\ (attach_disconnected)\ {/a \ \ \ \ network\ inet,\ \n\ \ \ \ network\ inet6,' /etc/apparmor.d/usr.lib.snapd.snap-confine.real

# This may not work
sudo sed -i '\/profile\ "snap.firefox.hook.configure" (attach_disconnected,mediate_deleted)\ {/a \ \ network\ inet,\ \n\ \ network\ inet6,' /var/lib/snapd/apparmor/profiles/snap.firefox.hook.configure

echo -e '\n  network inet,\n  network inet6,'  >> /etc/apparmor.d/abstractions/base

# https://bugs.launchpad.net/ubuntu/+source/snapd/+bug/1662552
# Additionally, we can append "apparmor=0" to fully disable apparmor
