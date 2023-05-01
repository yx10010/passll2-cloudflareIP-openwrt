#!/bin/bash

[[ ! -d "/mnt/sdb3/paniy/cloudflare" ]] && mkdir -p /mnt/sdb3/paniy/cloudflare
cd /mnt/sdb3/paniy/cloudflare

opkg install jq

arch=$(uname -m)
if [[ ${arch} =~ "x86" ]]; then
	tag="amd"
	[[ ${arch} =~ "64" ]] && tag="amd64"
elif [[ ${arch} =~ "aarch" ]]; then
	tag="arm"
	[[ ${arch} =~ "64" ]] && tag="arm64"
else
	exit 1
fi

version=$(curl -s https://api.github.com/repos/XIU2/CloudflareSpeedTest/tags | jq -r .[].name | head -1)
old_version=$(cat CloudflareST_version.txt )

if [[ ! -f "CloudflareST" || ${version} != ${old_version} ]]; then
	rm -rf CloudflareST_linux_${tag}.tar.gz
	wget -N https://ghproxy.com/https://github.com/XIU2/CloudflareSpeedTest/releases/download/${version}/CloudflareST_linux_${tag}.tar.gz
	echo "${version}" > CloudflareST_version.txt
	zcat CloudflareST_linux_${tag}.tar.gz | tar -xvf-
	chmod +x CloudflareST
fi

##注意修改！！！
/etc/init.d/haproxy stop
/etc/init.d/passwall2 stop
wait

./CloudflareST -dn 10 -tll 40 -o cf_result.txt
wait
sleep 3

if [[ -f "cf_result.txt" ]]; then
	first=$(sed -n '2p' cf_result.txt | awk -F ',' '{print $1}') && echo $first >>ip-all.txt
	second=$(sed -n '3p' cf_result.txt | awk -F ',' '{print $1}') && echo $second >>ip-all.txt
	third=$(sed -n '4p' cf_result.txt | awk -F ',' '{print $1}') && echo $third >>ip-all.txt
	wait
	uci commit passwall2
	wait
	##注意修改！！！
	sed -i "s/$(uci get passwall.833a160527914460964d246323af9a6e.address)/${first}/g" /etc/config/passwall
	sed -i "s/$(uci get passwall.0fd176bd14f542d6a4a1f81f00df8eff.address)/${second}/g" /etc/config/passwall
	#sed -i "s/$(uci get passwall.xxxxxxxxxx.address)/${third}/g" /etc/config/passwall
	wait
	uci commit passwall2
	wait
	[[ $(/etc/init.d/haproxy status) != "running" ]] && /etc/init.d/haproxy start
	wait
	[[ $(/etc/init.d/passwall status) != "running" ]] && /etc/init.d/passwall2 start
	# wait
	# if [[ -f "ip-all.txt" ]]; then
	# 	sort -t "." -k4 -n -r ip-all.txt >ip-all-serialize.txt
	# 	uniq -c ip-all.txt ip-mediate.txt
	# 	sort -r ip-mediate.txt >ip-statistics.txt
	# 	rm -rf ip-mediate.txt
	# fi
fi
