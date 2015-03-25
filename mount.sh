#!/bin/sh
mkfs.ext4 /dev/sdb
mkfs.ext4 /dev/sdc
mkfs.ext4 /dev/sdd
mkfs.ext4 /dev/sde
mkfs.ext4 /dev/sdf
mkfs.ext4 /dev/sdg
mkfs.ext4 /dev/sdh
mkfs.ext4 /dev/sdi
mkfs.ext4 /dev/sdj
mkfs.ext4 /dev/sdk
mkdir -pv /data/fastdfs/data0
mkdir -pv /data/fastdfs/data1
mkdir -pv /data/fastdfs/data2
mkdir -pv /data/fastdfs/data3
mkdir -pv /data/fastdfs/data4
mkdir -pv /data/fastdfs/data5
mkdir -pv /data/fastdfs/data6
mkdir -pv /data/fastdfs/data7
mkdir -pv /data/fastdfs/data8
mkdir -pv /data/fastdfs/data9
mount /dev/sdb /data/fastdfs/data0
mount /dev/sdc /data/fastdfs/data1
mount /dev/sdd /data/fastdfs/data2
mount /dev/sde /data/fastdfs/data3
mount /dev/sdf /data/fastdfs/data4
mount /dev/sdg /data/fastdfs/data5
mount /dev/sdh /data/fastdfs/data6
mount /dev/sdi /data/fastdfs/data7
mount /dev/sdj /data/fastdfs/data8
mount /dev/sdk /data/fastdfs/data9
