#!/bin/sh

install()
{
    insmod /usr/modules/sunrpc.ko
    insmod /usr/modules/grace.ko
    insmod /usr/modules/lockd.ko
    insmod /usr/modules/nfs.ko
    insmod /usr/modules/nfsv2.ko
    insmod /usr/modules/nfsv3.ko
}

uninstall()
{
    rmmod nfsv3
    rmmod nfsv2
    rmmod nfs
    rmmod lockd
    rmmod grace
    rmmod sunrpc
}

usage()
{
    echo "usage :" 
    echo "    ./nfs_start.sh <install/uninstall>"
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
