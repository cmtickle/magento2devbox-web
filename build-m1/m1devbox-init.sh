#!/bin/bash
touch /Users/colintickle/Development/RibbleCycles/sync-wait
echo 'Build docker images'
docker-compose up --build -d
web_port=$(docker-compose port web 80)
web_port=${web_port#*:}

echo 'Copy Webroot'
cp -rf /Users/colintickle/Development/RibbleCycles ./magento2
docker cp magento2 magento2devbox_web_d5983e9313d9639b0b41d7e6b67443f8:/var/www
rm -rf magento2
rm -rf /Users/colintickle/Development/RibbleCycles/sync-wait
sleep 5

echo 'Install Magento'

docker-compose exec --user magento2 web m1init magentoone:install --no-interaction --webserver-home-port=$web_port