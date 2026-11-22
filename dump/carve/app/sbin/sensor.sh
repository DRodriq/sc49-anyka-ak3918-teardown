#!/bin/sh


#v4l2_install() 
#{
#    insmod /usr/modules/4.4.192V1.5/kernel/drivers/media/media.ko
#    insmod /usr/modules/4.4.192V1.5/kernel/drivers/media/v4l2-core/videobuf2-core.ko
#    insmod /usr/modules/4.4.192V1.5/kernel/drivers/media/v4l2-core/videobuf2-memops.ko
#    insmod /usr/modules/4.4.192V1.5/kernel/drivers/media/v4l2-core/videodev.ko
#    insmod /usr/modules/4.4.192V1.5/kernel/drivers/media/v4l2-core/videobuf2-dma-contig.ko
#    insmod /usr/modules/4.4.192V1.5/kernel/drivers/media/v4l2-core/v4l2-common.ko
#    insmod /usr/modules/4.4.192V1.5/kernel/drivers/media/v4l2-core/videobuf2-v4l2.ko
#}
#
#v4l2_uninstall() 
#{
#    rmmod videobuf2-v4l2.ko
#    rmmod v4l2-common.ko
#    rmmod videobuf2-dma-contig.ko
#    rmmod videodev.ko
#    rmmod videobuf2-memops.ko
#    rmmod videobuf2-core.ko
#    rmmod media.ko
#}

install()
{
#    v4l2_install f37 and f37p the same
    insmod /usr/modules/ak_isp.ko
    insmod /usr/modules/sensor_f22_f23_f28_f35_f37_f37p.ko check_id=1
    insmod /usr/modules/sensor_q03.ko check_id=1
    insmod /usr/modules/sensor_sc3335.ko check_id=1
    insmod /usr/modules/sensor_sc2332.ko check_id=1
    insmod /usr/modules/sensor_sc2335.ko check_id=1
    insmod /usr/modules/sensor_sc1345.ko check_id=1
    insmod /usr/modules/sensor_h63.ko check_id=1
    insmod /usr/modules/sensor_sc2231.ko check_id=1
    insmod /usr/modules/sensor_sc2336.ko check_id=1
    insmod /usr/modules/sensor_sc2239.ko check_id=1
    insmod /usr/modules/sensor_sc223a.ko check_id=1
    insmod /usr/modules/sensor_sc401ai.ko check_id=1
}

uninstall()
{
    rmmod sensor_sc401ai
    rmmod sensor_h63
    rmmod sensor_sc1345
    rmmod sensor_sc2335
    rmmod sensor_sc2332
    rmmod sensor_sc3335
    rmmod sensor_f22_f23_f28_f35_f37_f37p
    rmmod sensor_q03
    rmmod sensor_sc2231
    rmmod sensor_sc2336
    rmmod sensor_sc2239
    rmmod sensor_sc223a
    rmmod ak_isp
#    v4l2_uninstall
}

usage()
{
    echo "usage :" 
    echo "    ./sensor.sh <install/uninstall>"
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
