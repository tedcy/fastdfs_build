#!/bin/sh

function usage()
{
	echo "usage :"$0" [option]"
	echo "-m				build monitor"
	echo "-t MY_IP			build tracker"
	echo "-s tracker_ip	MY_IP		build storage"
	echo "-n tracker_ip			build nginx_module"
	echo "-g group			with group_id,storage and nginx must set this"
	echo "-d				delete all data(just for test)"
}
onlyone=""
function check_onlyone()
{
	if [ "$onlyone" != "" ] ;then
		usage
		exit 1
	fi
	onlyone="true"
}
while getopts :mts:n:g:d opt
do
	case $opt in
	m)	
		check_onlyone
		readonly monitor="true"
		;;
	t)	
		check_onlyone
		readonly tracker="true"
		;;
	s)	
		check_onlyone
		readonly storage="true"
		readonly tracker_ip=$OPTARG
		;;
	n)	
		check_onlyone
		readonly nginx="true"
		readonly tracker_ip=$OPTARG
		;;
	g)
		readonly group_id=$OPTARG
		;;
	d)
		readonly delete="true"
		;;
	'?')	
		echo "$0:invalid option -$OPTARG" >&2
		usage
		exit 1
		;;
	esac
done
shift $((OPTIND - 1))
if [ "$nginx" == "true" ] || [ "$storage" == "true" ] ;then
	if [ "$group_id" == "" ] ;then
		usage
		exit 1
	fi
fi
if [ "$tracker" == "true" ] || [ "$storage" == "true" ] ;then
	if [ "$2" != "" ] ;then
		usage
		exit 1
	fi
	readonly ip=$1
	if [ "$ip" == "" ]; then
			usage
			exit 1
	fi
fi
if [ "$monitor" == "true" ] || [ "$nginx" == "true" ] || [ "$delete" == "true" ];then
	if [ "$1" != "" ] ;then
		usage
		exit 1
	fi
fi
#echo $port|grep -q '^[-]\?[0-9]\+$' && echo yes || echo error

function check_exist_f()
{
	if [ ! -f $1 ];then
		echo "$1 doesn't exist"
		exit 1
	fi
}
function check_exist_and_mkd()
{
	if [ ! -d $1 ];then
		echo "$1 doesn't exist"
		mkdir -pv $1
	fi
}
function fix_config()
{
#key = $1
#value = $2
#config_file = $3
	if grep -q "$1*" $3;then
	    sed -i "s:$1.*$:$1$2:" $3
	else
		echo $1$2 >> $3
	fi
}

if [ "$monitor" == "true" ] ;then
	echo "init installation of monitor ..."
	readonly monitor_tar="fdfs_jobs_monitor.tar.gz"
	readonly fastdfs_tar="FastDFS_v5.05.tar.gz"
	readonly monitor_path="/data/fdfs_jobs_monitor"
	readonly monitor_exec="fdfs_jobs_monitor"
	readonly monitor_config="fdfs_jobs_monitor.config"

	check_exist_f $monitor_tar 
	check_exist_and_mkd $monitor_path
	yum install mysql
	yum install mysql-server
	tar xf $monitor_tar
	tar xf $fastdfs_tar
	rm -rf $monitor_exec/fdfs_headers
	mkdir $monitor_exec/fdfs_headers
	cp FastDFS/*/*.h $monitor_exec/fdfs_headers
	cp /usr/include/fastcommon/*.h $monitor_exec/fdfs_headers
	echo "enter dir $monitor_exec"
	cd $monitor_exec
	echo "building ..."
	./build.sh
	cp $monitor_exec $monitor_path
	cp $monitor_config $monitor_path
	cp libmysqlclient.so.16 /usr/lib64
	ln -s /usr/lib64/libmysqlclient.so.16 /usr/lib64/libmysqlclient.so
	cd ..
	rm -rf $monitor_exec
	rm -rf FastDFS
	echo "clean and leave dir $monitor_exec"
	exit 0
fi
if [ "$tracker" == "true" ] ;then
	echo "init installation of tracker ..."
	readonly tracker_tar="FastDFS_v5.05.tar.gz"
	readonly libfastcommon_tar="libfastcommon_v1.11.tar.gz"
	readonly tracker_path="/usr/local/bin/"
	readonly tracker_conf="/etc/fdfs/tracker.conf"
	
	check_exist_f $tracker_tar
	check_exist_f $libfastcommon_tar
	#check_exist_and_mkd $tracker_path

	tar xf $libfastcommon_tar
	echo "enter dir libfastcommon"
	cd libfastcommon
	./make.sh
	./make.sh install
	cd ..
	rm -rf libfastcommon
	echo "clean and leave dir libfastcommon"
	#mkdir -p /usr/include/fastcommon
	#ln -fs /usr/local/include/fastcommon /usr/include/fastcommon

	tar xf $tracker_tar
	echo "enter dir FastDFS"
	cd FastDFS
	./make.sh
	./make.sh install
	cd ..
	rm -rf FastDFS
	echo "clean and leave dir FastDFS"

	check_exist_f /etc/fdfs/tracker.conf.sample
	cp /etc/fdfs/tracker.conf.sample $tracker_conf
	fix_config "bind_addr=" $ip $tracker_conf
	fix_config "max_connections=" 65536 $tracker_conf
	fix_config "work_threads=" 24 $tracker_conf
	fix_config "base_path=" "/data/fastdfs" $tracker_conf
	fix_config "http.server_port=" "80" $tracker_conf
	mkdir -pv /data/fastdfs
	echo "finished"
	exit 0
fi
if [ "$storage" == "true" ] ;then
	echo "init installation of storage ..."
	readonly storage_tar="FastDFS_v5.05.tar.gz"
	readonly libfastcommon_tar="libfastcommon_v1.11.tar.gz"
	readonly storage_path="/usr/local/bin/"
	readonly storage_conf="/etc/fdfs/storage.conf"
	
	check_exist_f $storage_tar
	check_exist_f $libfastcommon_tar

	tar xf $libfastcommon_tar
	echo "echo dir libfastdfscommon"
	cd libfastcommon
	./make.sh
	./make.sh install
	cd ..
	rm -rf libfastcommon
	echo "clean and leave dir libfastdfscommon"

	tar xf $storage_tar
	echo "enter dir FastDFS"
	cd FastDFS
	mkdir -pv /etc/fdfs
	cp conf/storage.conf $storage_conf
	./make.sh
	./make.sh install
	cd ..
	rm -rf FastDFS
	echo "clean and leave dir FastDFS"
	check_exist_f $storage_conf
	fix_config "group_name=group" $group_id $storage_conf
	fix_config "max_connections=" 65536 $storage_conf
	fix_config "work_threads=" 24 $storage_conf
	fix_config "bind_addr=" $ip $storage_conf
	fix_config "base_path=" "/data/fastdfs" $storage_conf
	fix_config "store_path_count=" "10" $storage_conf
	fix_config "store_path0=" "/data/fastdfs/data0\n"\
"store_path1=/data/fastdfs/data1\n"\
"store_path2=/data/fastdfs/data2\n"\
"store_path3=/data/fastdfs/data3\n"\
"store_path4=/data/fastdfs/data4\n"\
"store_path5=/data/fastdfs/data5\n"\
"store_path6=/data/fastdfs/data6\n"\
"store_path7=/data/fastdfs/data7\n"\
"store_path8=/data/fastdfs/data8\n"\
"store_path9=/data/fastdfs/data9"\
	$storage_conf
	fix_config "http.server_port=" "80" $storage_conf
	
	var1=`echo $tracker_ip|awk -F ',' '{print $1}' `
	fix_config "tracker_server=" $var1"\:22122" $storage_conf
	var2=`echo $tracker_ip|awk -F ',' '{print $2}' `
	if [ "$var2" != "" ] ;then
		fix_config "tracker_server=$var1""\:22122" "\ntracker_server="$var2"\:22122" $storage_conf
	fi
	var3=`echo $tracker_ip|awk -F ',' '{print $3}' `
	if [ "$var3" != "" ] ;then
		fix_config "tracker_server=$var2""\:22122" "\ntracker_server="$var3"\:22122" $storage_conf
	fi
	var4=`echo $tracker_ip|awk -F ',' '{print $4}' `
	if [ "$var4" != "" ] ;then
		fix_config "tracker_server=$var3""\:22122" "\ntracker_server="$var4"\:22122" $storage_conf
	fi
	var5=`echo $tracker_ip|awk -F ',' '{print $5}' `
	if [ "$var5" != "" ] ;then
		fix_config "tracker_server=$var4""\:22122" "\ntracker_server="$var5"\:22122" $storage_conf
	fi
	mkdir -pv /data/fastdfs
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

	exit 0
fi
if [ "$nginx" == "true" ] ;then
	echo "init installation of nginx ..."
	readonly nginx_tar="nginx-1.2.9.tar.gz"
	readonly nginx_src_path="nginx-1.2.9"
	readonly fastdfs_tar="FastDFS_v5.05.tar.gz"
	readonly fdfs_nginx_tar="fastdfs-nginx-module_v1.16.tar.gz"
	readonly fdfs_nginx_conf="/etc/fdfs/mod_fastdfs.conf"
    readonly lib_webp_tar="libwebp-0.4.3.tar.gz"
    readonly lib_webp_src_path="libwebp-0.4.3"

	check_exist_f $nginx_tar
	check_exist_f $fdfs_nginx_tar
	check_exist_f $lib_webp_tar

	tar xf $nginx_tar
	tar xf $fdfs_nginx_tar
	tar xf $fastdfs_tar
    tar xf $lib_webp_tar
	cp FastDFS/conf/http.conf /etc/fdfs
	cp FastDFS/conf/mime.types /etc/fdfs
	rm -rf FastDFS

	fix_config "CORE_INCS=" "\"\$CORE_INCS /usr/include/fastdfs /usr/include/fastcommon/\"" fastdfs-nginx-module/src/config
	fix_config "CORE_LIBS=" "\"\$CORE_LIBS -L/usr/local/lib -lfastcommon -lfdfsclient\"" fastdfs-nginx-module/src/config
	userdel nginx
	groupdel nginx
	usermod –G nginx nginx
	rm -rf /home/nginx
	#check_exist_and_mkd /home/nginx
	useradd nginx -s /sbin/nologin -d /home/nginx
	#yum -y groupinstall "Development tools" "Server Platform Libraries" 
	yum -y install gd gd-devel pcre-devel

    cd $lib_webp_src_path
    ./configure
    make
    make install
    ldconfig
    cd ..
    rm -rf $lib_webp_src_path

	cd $nginx_src_path
	cp ../nginx_image_cache_module/src/ngx_http_image_filter_module.c src/http/modules/ngx_http_image_filter_module.c
	cp ../ngx_http_fastdfs_module.c ../fastdfs-nginx-module/src/ngx_http_fastdfs_module.c
	./configure \
        --with-ld-opt='-lwebp' \
		--prefix=/data/nginx \
		--error-log-path=/data/log/nginx/error.log \
		--http-log-path=/data/log/nginx/access.log \
		--pid-path=/var/run/nginx/nginx.pid  \
		--lock-path=/var/lock/nginx.lock \
		--user=nginx \
		--group=nginx \
		--with-http_ssl_module \
		--with-http_flv_module \
		--with-http_stub_status_module \
		--with-http_gzip_static_module \
		--http-client-body-temp-path=/var/tmp/nginx/client/ \
		--http-proxy-temp-path=/var/tmp/nginx/proxy/ \
		--http-fastcgi-temp-path=/var/tmp/nginx/fcgi/ \
		--http-uwsgi-temp-path=/var/tmp/nginx/uwsgi \
		--http-scgi-temp-path=/var/tmp/nginx/scgi \
		--with-pcre \
		--with-file-aio \
		--with-http_image_filter_module \
		--add-module=../fastdfs-nginx-module/src \
		--add-module=../nginx_image_cache_module/src
	make
	make install
	cd ..
	cp conf/mod_fastdfs.conf $fdfs_nginx_conf
	fix_config "group_name=group" $group_id $fdfs_nginx_conf
	fix_config "base_path=" "/data/fastdfs" $fdfs_nginx_conf
	fix_config "store_path_count=" "10" $fdfs_nginx_conf
	fix_config "store_path0=" "/data/fastdfs/data0\n"\
"store_path1=/data/fastdfs/data1\n"\
"store_path2=/data/fastdfs/data2\n"\
"store_path3=/data/fastdfs/data3\n"\
"store_path4=/data/fastdfs/data4\n"\
"store_path5=/data/fastdfs/data5\n"\
"store_path6=/data/fastdfs/data6\n"\
"store_path7=/data/fastdfs/data7\n"\
"store_path8=/data/fastdfs/data8\n"\
"store_path9=/data/fastdfs/data9"\
	$fdfs_nginx_conf

	fix_config "url_have_group_name = " "true" $fdfs_nginx_conf
	var1=`echo $tracker_ip|awk -F ',' '{print $1}' `
	fix_config "tracker_server=" $var1"\:22122" $fdfs_nginx_conf
	var2=`echo $tracker_ip|awk -F ',' '{print $2}' `
	if [ "$var2" != "" ] ;then
		fix_config "tracker_server=$var1""\:22122" "\ntracker_server="$var2"\:22122" $fdfs_nginx_conf
	fi
	var3=`echo $tracker_ip|awk -F ',' '{print $3}' `
	if [ "$var3" != "" ] ;then
		fix_config "tracker_server=$var2""\:22122" "\ntracker_server="$var3"\:22122" $fdfs_nginx_conf
	fi
	var4=`echo $tracker_ip|awk -F ',' '{print $4}' `
	if [ "$var4" != "" ] ;then
		fix_config "tracker_server=$var3""\:22122" "\ntracker_server="$var4"\:22122" $fdfs_nginx_conf
	fi
	var5=`echo $tracker_ip|awk -F ',' '{print $5}' `
	if [ "$var5" != "" ] ;then
		fix_config "tracker_server=$var4""\:22122" "\ntracker_server="$var5"\:22122" $fdfs_nginx_conf
	fi
	mkdir -pv /data/fastdfs/data
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
	mkdir -pv /data/fastdfs/data10
	ln -fs /data/fastdfs/data0/data /data/fastdfs/data0/data/M00
	ln -fs /data/fastdfs/data1/data /data/fastdfs/data1/data/M01
	ln -fs /data/fastdfs/data2/data /data/fastdfs/data2/data/M02
	ln -fs /data/fastdfs/data3/data /data/fastdfs/data3/data/M03
	ln -fs /data/fastdfs/data4/data /data/fastdfs/data4/data/M04
	ln -fs /data/fastdfs/data5/data /data/fastdfs/data5/data/M05
	ln -fs /data/fastdfs/data6/data /data/fastdfs/data6/data/M06
	ln -fs /data/fastdfs/data7/data /data/fastdfs/data7/data/M07
	ln -fs /data/fastdfs/data8/data /data/fastdfs/data8/data/M08
	ln -fs /data/fastdfs/data9/data /data/fastdfs/data9/data/M09
#fix_config "#charset koi8-r;" "\n\tlocation /group$group_id/M00{\n\t    alias   /data/fastdfs/data0/data;\n\t    ngx_fastdfs_module;\n\t}"\
#"\n\tlocation /group$group_id/M01{\n\t    alias   /data/fastdfs/data1/data;\n\t    ngx_fastdfs_module;\n\t}"\
#"\n\tlocation /group$group_id/M02{\n\t    alias   /data/fastdfs/data2/data;\n\t    ngx_fastdfs_module;\n\t}"\
#"\n\tlocation /group$group_id/M03{\n\t    alias   /data/fastdfs/data3/data;\n\t    ngx_fastdfs_module;\n\t}"\
#"\n\tlocation /group$group_id/M04{\n\t    alias   /data/fastdfs/data4/data;\n\t    ngx_fastdfs_module;\n\t}"\
#"\n\tlocation /group$group_id/M05{\n\t    alias   /data/fastdfs/data5/data;\n\t    ngx_fastdfs_module;\n\t}"\
#"\n\tlocation /group$group_id/M06{\n\t    alias   /data/fastdfs/data6/data;\n\t    ngx_fastdfs_module;\n\t}"\
#"\n\tlocation /group$group_id/M07{\n\t    alias   /data/fastdfs/data7/data;\n\t    ngx_fastdfs_module;\n\t}"\
#"\n\tlocation /group$group_id/M08{\n\t    alias   /data/fastdfs/data8/data;\n\t    ngx_fastdfs_module;\n\t}"\
#"\n\tlocation /group$group_id/M09{\n\t    alias   /data/fastdfs/data9/data;\n\t    ngx_fastdfs_module;\n\t}"\
#"\n\tlocation /group$group_id/M10{\n\t    alias   /data/fastdfs/data10/data;\n\t    ngx_fastdfs_module;\n\t}"\
	rm -rf /data/nginx/conf/nginx.conf
	cp conf/nginx.conf /data/nginx/conf/nginx.conf
	mkdir -pv /data/nginx/conf/vhosts/
	cp conf/default.conf /data/nginx/conf/vhosts
    fix_config "image_cache_group_name " "group"$group_id";" /data/nginx/conf/vhosts/default.conf
    fix_config "image_filter_group_name " "group"$group_id";" /data/nginx/conf/vhosts/default.conf
	mkdir -pv /var/tmp/nginx/client/
	rm -rf $nginx_src_path
	rm -rf fastdfs-nginx-module
	
fi
if [ "$delete" == "true" ] ;then
	echo "delete all of fastdfs ..."
	rm -rf /data/fastdfs
fi

exit 0
