#!/bin/bash

ssh_port=$(docker port magento2devbox_web_d5983e9313d9639b0b41d7e6b67443f8 22)
ssh_port=${ssh_port#*:}

ssh -N -p $ssh_port -R 9000:localhost:9000 magento2@127.0.0.1