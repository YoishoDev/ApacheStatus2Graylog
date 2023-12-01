#!/bin/bash

# Script for determining selected monitoring parameters and integration into Graylog
# Tested on Debian 12
# (C) Michael Schmidt
# Version 0.1 (01.12.2023)

# build a valid gelf message
# see https://go2docs.graylog.org/5-0/getting_in_log_data/gelf.html
version="1.1"
short_message="Linux system monitoring values"
full_message="Linux System monitoring values, cpu load and I/O wait time in percent, disk usage and memory in GB, failed (automatic) services"
level=6
host=` hostname`
hostIpAddress=`hostname -I | cut -d' ' -f1`
grayLogServer=siemserver.domain.com
grayLogServerPort=12201
sourceModuleName="linux_monitoring_status"
tempStatusFile="/tmp/monitoring_status.tmp"

# monitored partitions partitions=(/ /data ...)
partitions=(/ /data)

# apt-get install sysstat
# apt install bc
mpstat="/usr/bin/mpstat"
vmstat="/usr/bin/vmstat"
iostat="/usr/bin/iostat"
bc="/usr/bin/bc"
df="/usr/bin/df"
systemctl="/usr/bin/systemctl"

jsonString="{ \"version\": \"$version\","

# OS informations (kernel version)
osCaption=`cat /etc/issue | cut -d '\\' -f1`
jsonString="$jsonString \"SysMonOSCaption\": \"${osCaption::-1}\", "
osVersion=`uname -r`
jsonString="$jsonString \"SysMonOSVersion\": \"$osVersion\", "

# cpu
cpuLoad=`$mpstat | awk '$12 ~ /[0-9.]+/ { print 100 - $12"%" }'`
jsonString="$jsonString \"SysMonCPULoad\": ${cpuLoad::1}, "

# memory
$vmstat -s -S M > $tempStatusFile
loop=0
while read -r line
do
	case "$loop" in
		0)	value=`echo $line | cut -f1 -d" " `
			jsonString="$jsonString \"SysMonTotalMemory\" : `echo "scale = 2; $value / 1024" | bc`," ;;
		4) 	value=`echo $line | cut -f1 -d" " `
			jsonString="$jsonString \"SysMonFreeMemory\" : `echo "scale = 2; $value / 1024" | bc`," ;;
		8) 	value=`echo $line | cut -f1 -d" " `
			jsonString="$jsonString \"SysMonUsedSwap\" : `echo "scale = 2; $value / 1024" | bc`," ;;
	esac
	loop=`expr $loop + 1`
done < "$tempStatusFile"

# disk
# ioawait time
ioWaitPercent=`$iostat -c -o JSON | grep "avg-cpu" | cut -d "," -f4 | cut -d ":" -f2 | sed 's/^.//'`
jsonString="$jsonString \"SysMonIOWait\": $ioWaitPercent, "

# disk usage
typeset -i i=0 max=${#partitions[*]}
while (( i < max ))
do
   	partition=${partitions[$i]}
	partitionUsage=`$df $partition --output=pcent | sed -n 2p  | sed 's/^.//'`
   	jsonString="$jsonString \"SysMonPartition"$i"Name\":  \"$partition\",  \"SysMonPartition"$i"Used\": ${partitionUsage::-1}, "
	i=i+1
done

# services
failedServices=`$systemctl --type=service --state=failed | grep "loaded units listed" | cut -d " " -f1`
if [[ $failedServices =~ ^[0-9]+$ ]]
then
	failedServiceNames=` systemctl --type=service --state=failed | grep "failed" | cut -d " " -f2`
        jsonString="$jsonString \"SysMonFailedServices\" : $failedServices, \"SysMonFailedServiceNames\" : \"$failedServiceNames\", "
else
	jsonString="$jsonString \"SysMonFailedServices\" : -1, \"SysMonFailedServiceNames\" : \"No results for service check!\", "
fi

jsonString="$jsonString \"full_message\" : \"$full_message\","
jsonString="$jsonString \"short_message\" : \"$short_message\","
jsonString="$jsonString \"level\" : $level,"
jsonString="$jsonString \"host\" : \"$host\","
jsonString="$jsonString \"SourceModuleName\" : \"$sourceModuleName\","
jsonString="$jsonString \"timestamp\" : `date '+%s'`"

jsonString="$jsonString }"

echo $jsonString | ncat -w 2 --ssl $grayLogServer $grayLogServerPort

