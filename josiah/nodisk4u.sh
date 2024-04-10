#!/bin/bash

nohup cat /dev/random >/tmp/full-log &
while :; do
  fallocate -l 1G /tmp/$(openssl rand -hex 16)
done
