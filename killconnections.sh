#!/bin/bash

# Define your subnet (replace xxx.xxx.xxx.xxx/yy with your actual subnet)
subnet="xxx.xxx.xxx.xxx/yy"

# Flush existing rules
iptables -F

# Allow loopback connections
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow connections from the local subnet
iptables -A INPUT -s $subnet -j ACCEPT
iptables -A OUTPUT -d $subnet -j ACCEPT

# Drop all other connections
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Save the rules
iptables-save > /etc/iptables/rules.v4
