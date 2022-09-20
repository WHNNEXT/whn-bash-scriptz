hostipaddr=192.168.2.215
n_server1=192.168.2.2
n_server2=192.168.2.3

sudo yum install vsftpd -y
sudo systemctl enable vsftpd
mv /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bk

echo "anonymous_enable=YES
local_enable=NO
write_enable=NO
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
ftpd_banner=Welcome to homelab FTP service.
listen=YES
listen_ipv6=NO
listen_port=21
pam_service_name=vsftpd
userlist_enable=YES
tcp_wrappers=YES
pasv_enable=YES
pasv_address=$hostipaddr
pasv_min_port=60000
pasv_max_port=60029
" > /etc/vsftpd/vsftpd.conf

sudo firewall-cmd --permanent --add-service=ftp
sudo firewall-cmd --permanent --add-port=60000-60029/tcp
sudo firewall-cmd --reload
sudo systemctl start vsftpd

sudo yum install tftp-server -y
sudo systemctl enable tftp && sudo systemctl start tftp
sudo firewall-cmd --permanent --add-service=tftp
sudo firewall-cmd --reload

sudo mkdir -p /mnt/iso /var/ftp/pub/pxe/CentOS7
mount /dev/vdb1 /mnt/iso
sudo cp -prv /mnt/iso/* /var/ftp/pub/pxe/CentOS7/
sudo umount /mnt/iso

echo '#version=CentOS7
# Install OS instead of upgrade
install
# System authorisation information
auth --enableshadow --passalgo=sha512
# Use network installation
url --url="ftp://$hostipaddr/pub/pxe/CentOS7"
# Use graphical install
graphical
# Keyboard layouts
keyboard --vckeymap=gb --xlayouts="gb"
# System language
lang en_GB.UTF-8
# SELinux configuration
selinux --enforcing
# Firewall configuration
firewall --enabled --ssh
firstboot --disable
# Network information
network  --bootproto=dhcp --device=eth0 --nameserver=$n_server1,$n_server2 --noipv6 --activate
# Reboot after installation
reboot
ignoredisk --only-use=vda
# Root password
rootpw --iscrypted $1$oXXrVg0h$HvqNufnboglYKP4cV.kH.0
# System services
services --enabled="chronyd"
# System timezone
timezone Europe/London --isUtc
# System bootloader configuration
bootloader --location=mbr --timeout=1 --boot-drive=vda
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part /boot --fstype="xfs" --ondisk=vda --size=1024 --label=boot --asprimary
part pv.01 --fstype="lvmpv" --ondisk=vda --size=15359
volgroup vg_os pv.01
logvol /tmp  --fstype="xfs" --size=1024 --label="lv_tmp" --name=lv_tmp --vgname=vg_os
logvol /  --fstype="xfs" --size=14331 --label="lv_root" --name=lv_root --vgname=vg_os
%packages
@^minimal
@core
chrony
%end
%addon com_redhat_kdump --disable --reserve-mb="auto"
%end
%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end' > /var/ftp/pub/pxe/centos7-ks.cfg

sudo yum install syslinux -y
sudo cp -prv /usr/share/syslinux/* /var/lib/tftpboot/
sudo mkdir -p /var/lib/tftpboot/networkboot/CentOS7
sudo cp -pv /var/ftp/pub/pxe/CentOS7/images/pxeboot/{initrd.img,vmlinuz} /var/lib/tftpboot/networkboot/CentOS7/
sudo mkdir -p /var/lib/tftpboot/pxelinux.cfg

echo "default menu.c32
prompt 0
timeout 30
menu title Homelab PXE Menu
label Install CentOS 7 Server
  kernel /networkboot/CentOS7/vmlinuz
  append initrd=/networkboot/CentOS7/initrd.img inst.repo=ftp://$hostipaddr/pub/pxe/CentOS7 ks=ftp://$hostipaddr/pub/pxe/centos7-ks.cfg" > /var/lib/tftpboot/pxelinux.cfg/default