#!/bin/bash

echo 'Reset Magento'
web_port=$(docker-compose port web 80)
web_port=${web_port#*:}


docker-compose exec --user magento2 web m1init magentoone:reset --no-interaction --webserver-home-port=${web_port}
