FROM debian:jessie
MAINTAINER "Magento"

# libvmod-header
RUN apt-get update && \
    apt-get install -y curl make gnupg && \
    curl -s https://packagecloud.io/install/repositories/varnishcache/varnish41/script.deb.sh | bash
RUN apt-get update && \
    apt-get install -y apt-utils varnish varnish-dev vim && \
    mkdir /etc/varnish/default && \
    apt-get build-dep -y varnish
RUN apt-get install -y git  && \
    mkdir ~/src && \
    cd ~/src && \
    git clone https://github.com/varnish/varnish-modules.git
RUN cd ~/src/varnish-modules && \
    ./bootstrap && \
    ./configure && \
    make && \
    make install
RUN apt-get install python-docutils && \
    cd ~/src && \
    git clone https://github.com/Dridi/libvmod-querystring.git && \
    cd ~/src/libvmod-querystring && \
    git checkout tags/v1.0.4 && \
    ./bootstrap && \
    make && \
    make install

COPY conf/default.vcl /etc/varnish/default/default.vcl

COPY conf/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 6081 6082

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
