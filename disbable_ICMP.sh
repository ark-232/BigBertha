#!/bin/sh

# RUN ON OUR OWN BOXES
# This script disables ICMP ping responses

# Block ICMP echo-requests (ping requests)
iptables -I INPUT -p icmp --icmp-type echo-request -j DROP

#make the rule persistent across reboots on systems using iptables-persistent
iptables-save > /etc/iptables/rules.v4
ip6tables -I INPUT -p ipv6-icmp --icmpv6-type echo-request -j DROP

echo "ICMP ping responses have been disabled."
