#!/bin/bash
#Enter ipmi mac address 
#use: ipmitool lan print 1
read -p "IPMI MAC: " macaddr
echo -n $macaddr | xxd -r -p | openssl dgst -sha1 -mac HMAC -macopt hexkey:8544E3B47ECA58F9583043F8 | awk '{print $2}' | cut -c 1-24 | sed 's/./&-/4;s/./&-/9;s/./&-/14;s/./&-/19;s/./&-/24;'
