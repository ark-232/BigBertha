#!/bin/sh

echo 'export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"' >>/etc/profile
echo 'export HISTSIZE=100000' >>/etc/profile
echo 'export HISTFILESIZE=100000' >>/etc/profile
echo 'shopt -s histappend' >>/etc/profile
