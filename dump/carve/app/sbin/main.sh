#!/bin/sh

function get_partition_dev()
{
	mtdblockid=`cat /proc/mtd| grep "$1"| grep -E -o "mtd[0-9]+" | grep -E -o "[0-9]+"`
	if [ "$mtdblockid" != "" ];then
		echo "/dev/mtdblock$mtdblockid"
	else
		echo ""
	fi
}

InsmodModuleWhenExists ()
{
	if [ -f "$1" ];then
		insmod "$1"
	else
		echo "$1 not exist "
	fi
}

#print kernel error default
echo 4 > /proc/sys/kernel/printk

#start ftp server, dir=root r/w, -t 600s(timeout)
#/usr/bin/tcpsvd 0 21 ftpd -w / -t 600 &

echo "start telnet......"

echo "                     __                     "
echo "            _   ____ \/ ____  __            "
echo "     /\    | \ | |\ \  / /| |/ /    /\      "
echo "    /  \   |  \| | \ \/ / | ' /    /  \     "
echo "   / /\ \  | . ' |  \  /  |  <    / /\ \    "
echo "  / ____ \ | |\  |  |  |  | . \  / ____ \   "
echo " /_/    \_\|_| \_|  |__|  |_|\_\/_/    \_\  "
echo "                                            " 

#start syslogd & klogd, log rotated 3 files(200KB) to /var/log/messages
#syslogd -D -n -O /var/log/messages -s 200 -b 3 & # -l prio
#klogd -n & # -c prio

ifconfig lo 127.0.0.1

ifconfig eth0 up

dmesg > /tmp/start_message

## set min free reserve bytes
echo 2048 > /proc/sys/vm/min_free_kbytes

echo "/tmp/core_%e_%p_%t" > /proc/sys/kernel/core_pattern

#insmod /usr/modules/ak_adc_key.ko
insmod /usr/modules/ak_rtc.ko
hwclock -s

#echo "start usb driver..."
insmod /usr/modules/cfg80211.ko
insmod /usr/modules/mac80211.ko

insmod /usr/modules/ak_mci.ko
/usr/sbin/load_wifi.sh

insmod /usr/modules/usb-common.ko
insmod /usr/modules/usbcore.ko
insmod /usr/modules/ak_hcd.ko
insmod /usr/modules/mii.ko
insmod /usr/modules/usbnet.ko
insmod /usr/modules/cdc_ether.ko
insmod /usr/modules/rndis_host.ko
insmod /usr/modules/usbserial.ko
insmod /usr/modules/usb_wwan.ko
insmod /usr/modules/option.ko
insmod /usr/modules/firmware_class.ko
InsmodModuleWhenExists /usr/modules/ipv6.ko
InsmodModuleWhenExists /usr/modules/xfrm6_mode_beet.ko
InsmodModuleWhenExists /usr/modules/xfrm6_mode_transport.ko
InsmodModuleWhenExists /usr/modules/xfrm6_mode_tunnel.ko

#insmod /usr/modules/ak_fb.ko lcd_ctl_force_init=1
#insmod /usr/modules/ak_pwm_char.ko
#insmod /usr/modules/ak_fb.ko
#insmod /usr/modules/ak_saradc.ko
insmod /usr/modules/ak_i2c.ko
#insmod /usr/modules/ak_gpio_keys.ko
#insmod /usr/modules/ak_gui.ko
insmod /usr/modules/ak_ion.ko
#insmod /usr/modules/ak_leds.ko
#insmod /lib/modules/4.4.192V1.5/kernel/drivers/mmc/core/mmc_core.ko
#insmod /lib/modules/4.4.192V1.5/kernel/drivers/mmc/card/mmc_block.ko
#insmod /usr/modules/ak_mci.ko
insmod /usr/modules/ak_uio.ko
insmod /usr/modules/exfat.ko
#insmod /usr/modules/ak_gpio_uart.ko
insmod /usr/modules/ak_motor.ko
insmod /usr/modules/ak_efuse.ko
insmod /usr/modules/ak_pcm.ko
#insmod /usr/modules/ak_gpio_uart.ko
#insmod /usr/modules/ak_eth.ko
#ifconfig eth0 up
#/usr/sbin/screen.sh

#echo "start nfs driver..."
#/usr/sbin/nfs_start.sh install
 
#echo "start sensor driver..."
#/usr/sbin/sensor.sh install
 
echo "start sar-adc driver..."
/usr/sbin/sar-adc.sh install

cp -rf /usr/sbin/nk_update.sh /tmp

# mount yaffs2 file-system.
# mount -t yaffs2 /dev/mtdblock9 /data
partition_data=`get_partition_dev DATA`
if [ "$partition_data" != "" ];then
	echo "/bin/mount -t yaffs2 $partition_data /data"
	/bin/mount -t yaffs2 $partition_data /data
fi

#start system service
/usr/sbin/anyka_ipc.sh start

