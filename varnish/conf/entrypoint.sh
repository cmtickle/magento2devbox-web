#!/usr/bin/env bash

# workaround for situations when shared dir between 2 containers and host is yet not accessible

echo 'Waiting for config file to be accessible'

varnish_config_file='/etc/varnish/default/default.vcl'

while [ ! -f $varnish_config_file ]
do
    echo '.'
    sleep 10
done

/usr/sbin/varnishd -P /run/varnishd.pid -a :6081 -F -T :6082 -f $varnish_config_file -S /etc/varnish/secret -s malloc,256m