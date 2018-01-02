#!/bin/bash
touch /Users/colin.tickle/Documents/Development/InTheStyle/sync-wait
echo 'Build docker images'
docker-compose up --build -d
web_port=$(docker-compose port web 80)
web_port=${web_port#*:}

echo 'Copy Webroot to temporary location'
cp -Rf /Users/colin.tickle/Documents/Development/InTheStyle ./magento2
echo 'Docker copy Webroot'
docker cp magento2 magento2devbox_web_d5983e9313d9639b0b41d7e6b67443f8:/var/www
echo 'Remove temporary files'
rm -rf magento2
rm -rf /Users/colin.tickle/Documents/Development/InTheStyle/sync-wait
sleep 5

echo 'Install Magento'

docker-compose exec --user magento2 web m1init magentoone:install --no-interaction --webserver-home-port=$web_port