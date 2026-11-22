#!/bin/sh

# 读板型
hw_board_type=$(cat /sys/ak_info_dump/board_version)

if [ "$hw_board_type" == "0x1001" -o "$hw_board_type" == "0x3000" ];then
	trycnt=0
	#配置GPIO23/24为SD1_D0/D1功能
	#insmod /usr/modules/ak_mci.ko
	WIFI_VENDOR_HI3881="0x0296"
	WIFI_DEVICE_HI3881="0x5347"
	WIFI_VENDOR_HI3881_PATH="/sys/devices/platform/soc/201b0000.mmc2/mmc_host/mmc1/mmc1:0001/mmc1:0001:1/vendor"
	WIFI_DEVICE_HI3881_PATH="/sys/devices/platform/soc/201b0000.mmc2/mmc_host/mmc1/mmc1:0001/mmc1:0001:1/device"
	# 获取当前SDIO设备类型
	while [ "$trycnt" -le "5" ]
	do
		sdio_vendor=$(cat $WIFI_VENDOR_HI3881_PATH)
		sdio_device=$(cat $WIFI_DEVICE_HI3881_PATH)
		echo "trycnt=$trycnt $sdio_vendor $sdio_device"
		if [ "$sdio_vendor" == "$WIFI_VENDOR_HI3881" ]&&[ "$sdio_device" == "$WIFI_DEVICE_HI3881" ]; then
			echo "insert hi3881 ko..."
			insmod /usr/modules/hi3881.ko
			echo "ID ${sdio_vendor:2}:${sdio_device:2}" > /tmp/sdio_dev
			break
		fi
		trycnt=$((trycnt + 1))
		sleep 1
	done
	#规避加载usb驱动后，4G枚举异常
	sleep 1
elif [ "$hw_board_type" == "0x1" -o "$hw_board_type" == "0x1002" -o "$hw_board_type" == "0x1003" -o "$hw_board_type" == "0x3000" -o "$hw_board_type" == "0x3002" ];then
	#摇头机模组，不需要加载eth驱动
	echo "no eth..."
else
	insmod /usr/modules/ak_eth.ko
	ifconfig eth0 up
fi
