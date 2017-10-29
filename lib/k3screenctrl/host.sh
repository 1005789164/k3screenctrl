#!/bin/bash
# Copyright (C) 2017 XiaoShan https://www.mivm.cn

temp_dir=/var/k3screenctrl
dhcp_leases=$(uci get dhcp.@dnsmasq[0].leasefile)
lan_ip=$(uci get network.lan.ipaddr | awk -F . '{print $1"."$2"."$3"."}')
#dhcp_ip_list=$(cat $dhcp_leases | grep "$lan_ip" | awk '{print $3}')
#arp_ip_list=$(cat /proc/net/arp | grep br-lan | grep "$lan_ip" | awk '{print $1}')
#device_list_ip=($(echo -e "$dhcp_ip_list\n$arp_ip_list" | sort -u))
device_list_ip=($(cat $dhcp_leases | grep "$lan_ip" | awk '{print $3}'))
device_list_mac=($(cat $dhcp_leases | awk '{print $2}'))
device_list_host=($(cat $dhcp_leases | awk '{print $4}' | sed 's/*//g'))
oui_data=$(cat /lib/k3screenctrl/oui/oui.txt)
last_time=$(cat $temp_dir/device_speed/time 2>/dev/null || date +%s)
curr_time=$(date +%s)
time_s=$(($curr_time - $last_time))
[ $? -ne 0 -o $time_s -eq 0 ] && time_s=$(uci -q get k3screenctrl.@general[0].refresh_time || echo 2)

for ((i=0;i<${#device_list_ip[@]};i++))
do
	temp_file=$temp_dir/device_speed/${device_list_ip[i]}
	[ -s  $temp_file ] || {
		[ -z "$(iptables -nvx -L FORWARD | grep -w K3_SEREEN_U | grep -w ${device_list_ip[i]})" ] && iptables -I FORWARD 1 -s ${device_list_ip[i]} -j K3_SEREEN_U
		[ -z "$(iptables -nvx -L FORWARD | grep -w K3_SEREEN_D | grep -w ${device_list_ip[i]})" ] && iptables -I FORWARD 1 -d ${device_list_ip[i]} -j K3_SEREEN_D
		echo -e "0\n0" > $temp_file
	}
done

curr_speed_u_ipt=$(iptables -nvx -L FORWARD | grep -w K3_SEREEN_U)
curr_speed_d_ipt=$(iptables -nvx -L FORWARD | grep -w K3_SEREEN_D)
online_code_data=$(cat $temp_dir/device_online)
device_custom_data=$(cat $temp_dir/device_custom)

for ((i=0;i<${#device_list_ip[@]};i++))
do
	online_code=$(echo -e "$online_code_data" | grep ${device_list_ip[i]} | awk '{print $2}') && [ -z "$online_code" ] && online_code=0
	[ $online_code -ne 0 ] && continue
	hostmac=${device_list_mac[i]//:/}
	temp_file=$temp_dir/device_speed/${device_list_ip[i]}
	device_custom=($(echo -e "$device_custom_data" | grep -w -i ${device_list_mac[i]}))
	name=${device_custom[1]=${device_list_host[i]}}
	logo=${device_custom[2]=$(echo -e "$oui_data" | grep -w -i ${hostmac:0:6} | awk '{print $1}')}
	[ "$name" = "?" -o -z "$name" ] && name=${device_list_host[i]}
	[ "$name" = "*" -o -z "$name" ] && name="Unknown"
	last_data=($(cat $temp_file))
	last_speed_u=${last_data[0]}
	last_speed_d=${last_data[1]}
	curr_speed_u=$(echo -e "$curr_speed_u_ipt" | grep -w ${device_list_ip[i]}  | awk '{print $2}')
	curr_speed_d=$(echo -e "$curr_speed_d_ipt" | grep -w ${device_list_ip[i]}  | awk '{print $2}')
	up=$(((${curr_speed_u} - $last_speed_u) / $time_s))
	dp=$((($curr_speed_d - $last_speed_d) / $time_s))
	temp_data="$name\n$dp\n$up\n${logo:=0}\n"
	data=${data}${temp_data}
	x=$(($x + 1))
	echo -e "$curr_speed_u\n$curr_speed_d" > $temp_file
done
echo ${x=0}
echo -e "${data=""}"
echo $curr_time > $temp_dir/device_speed/time