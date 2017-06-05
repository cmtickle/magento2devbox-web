#!/bin/sh

ssh_port=$(docker port magento2devbox_web_d5983e9313d9639b0b41d7e6b67443f8 22)
ssh_port=${ssh_port#*:}
echo ssh -p $ssh_port magento2@127.0.0.1
ssh -p $ssh_port magento2@127.0.0.1
