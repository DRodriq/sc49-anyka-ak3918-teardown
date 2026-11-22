#!/bin/sh

install()
{
#    insmod /usr/modules/4.4.192V1.5/kernel/drivers/iio/industrialio.ko
#    insmod /usr/modules/4.4.192V1.5/kernel/drivers/iio/trigger/iio-trig-interrupt.ko
#    insmod /usr/modules/4.4.192V1.5/kernel/drivers/iio/trigger/iio-trig-sysfs.ko
    insmod /usr/modules/ak_saradc.ko
}

uninstall()
{
    rmmod ak_saradc.ko

#    rmmod industrialio.ko
#    rmmod iio-trig-interrupt.ko
#    rmmod iio-trig-sysfs.ko
}

usage()
{
    echo "usage :" 
    echo "    ./sar-adc.sh <install/uninstall>"
    echo "    default : install"

}

if test $# -gt 1 ; then
    usage
elif test $# -eq 0 ; then
    install
elif test $# -eq 1 ; then
    if test $1 = "install" ; then
        install
    elif test $1 = "uninstall" ; then
        uninstall
    else
        usage
    fi
fi

