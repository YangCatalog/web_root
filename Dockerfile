FROM ubuntu:18.04

RUN set -ex; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    pwgen \
    tzdata \
    xz-utils;

RUN apt-get update && apt-get -y install \
    software-properties-common \
    debian-archive-keyring \
    wget \
    aptitude \
    dialog \
    net-tools \
    mcrypt \
    build-essential \
    tcl8.5 \
    git \
    nginx

# Turn off daemon mode
# Reference: http://stackoverflow.com/questions/18861300/how-to-run-nginx-within-docker-container-without-halting
RUN echo "\ndaemon off;" >> /etc/nginx/nginx.conf

# Backup the default configurations
RUN mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.original

# Copy default site conf
COPY conf/default.conf /etc/nginx/sites-available/default

# Mount volumes
VOLUME ["/etc/nginx/certs", "/etc/nginx/conf.d", "/var/www/html"]

ARG YANG_ID
ARG YANG_GID
ARG NGINX_FILES

ENV YANG_ID "$YANG_ID"
ENV YANG_GID "$YANG_GID"
ENV NGINX_FILES "$NGINX_FILES"

RUN groupadd -g ${YANG_GID} -r yang \
    && useradd --no-log-init -r -g yang -u ${YANG_ID} -m -d /home/yang yang

RUN mkdir /var/run/mysqld
RUN chown -R $YANG_ID:$YANG_GID /var/run/mysqld
RUN chmod 777 /var/run/mysqld

RUN apt-get update
RUN echo postfix postfix/mailname string yangcatalog.org | debconf-set-selections; \
    echo postfix postfix/main_mailer_type string 'Internet Site' | debconf-set-selections; \
    apt-get -y install postfix rsyslog systemd
RUN apt-get -y install rsync xinetd
RUN apt-get -y install net-tools
RUN apt-get autoremove -y

COPY ./resources/rsync /etc/xinetd.d/rsync
RUN sed -i 's/disable[[:space:]]*=[[:space:]]*yes/disable = no/g' /etc/xinetd.d/rsync # enable rsync

RUN /etc/init.d/xinetd restart

COPY --chown=yang:yang web_root/downloadables /usr/share/nginx/html/downloadables/
# COPY --chown=yang:yang search/static/ /usr/share/nginx/html/yang-search/static/
# COPY --chown=yang:yang yangre/app/static/ /usr/share/nginx/html/yangre/static/
# COPY --chown=yang:yang bottle-yang-extractor-validator/yangvalidator/static/ /usr/share/nginx/html/yangvalidator/static/
COPY --chown=yang:yang conf/${NGINX_FILES}  /etc/nginx/conf.d/

COPY ./resources/main.cf /etc/postfix/main.cf
COPY ./resources/rsyncd.conf /etc/rsyncd.conf

RUN /etc/init.d/xinetd start
RUN ln -s /usr/share/nginx/html/stats/statistics.html /usr/share/nginx/html/statistics.html

RUN chown -R yang:yang /usr/share/nginx/html

CMD /etc/init.d/xinetd start && service postfix start && service rsyslog start && nginx

# Set the current working directory
WORKDIR /var/www/html

# Expose port 80
EXPOSE 80
EXPOSE 443
