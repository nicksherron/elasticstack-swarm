FROM ubuntu:latest

ARG INTERFACE

RUN apt-get update &&  apt-get install -y libpcre3 libpcre3-dbg libpcre3-dev build-essential libpcap-dev   \
                libyaml-0-2 libyaml-dev pkg-config zlib1g zlib1g-dev \
                make libmagic-dev python-pip suricata cron


RUN pip install --upgrade suricata-update && suricata-update

RUN ( crontab -l ; echo "* 12 * * *  /usr/local/bin/suricata-update ") | crontab && service cron start

CMD suricata -c /etc/suricata/suricata.yaml -i ${INTERFACE:-eth0}

