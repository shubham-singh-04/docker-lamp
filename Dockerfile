# MySQL Server with Apache and phpmyadmin
#
# VERSION               0.0.1
#
# Logging is performed via syslog to a server named beservices
#

FROM     centos:6
MAINTAINER Jonas Colmsjö "jonas@gizur.com"

RUN yum install -y wget nano curl git unzip which tar gcc


#
# Install supervisord (used to handle processes)
# ----------------------------------------------
#
# Installation with easy_install is more reliable. yum don't always work.

RUN yum install -y python python-setuptools
RUN easy_install supervisor
ADD ./etc-supervisord.conf /etc/supervisord.conf
ADD ./etc-supervisor-conf.d-supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN mkdir -p /var/log/supervisor/


#
# Install rsyslog
# ---------------

RUN yum install -y rsyslog
ADD ./etc-rsyslog.conf /etc/rsyslog.conf


#
# Install Apache
# ---------------

RUN yum install -y httpd php

#RUN rm /var/www/html/index.html
RUN echo -e "<?php\nphpinfo();\n " > /var/www/html/info.php


#
# Customized ini files
# ------------------
#

ADD ./etc-php.ini /etc/php.ini
ADD ./etc-httpd-conf-httpd.conf /etc/httpd/conf/httpd.conf


#
# Install MySQL
# -------------

# Add scripts, source code for SQL-scripts and vTiger instances
ADD ./init-mysql.sh /

# Run installation
RUN yum -y update; yum clean all
RUN yum -y install epel-release; yum clean all
RUN yum -y install mysql-server mysql pwgen bash-completion psmisc net-tools; yum clean all

# Setup admin user and load data
RUN /init-mysql.sh


#
# Misc modules
# ------------

# Alternative to pecl due to problems with sasl
RUN yum install -y cyrus-sasl-devel zlib-devel gcc-c++ php-pear php-common php-devel
RUN wget https://launchpad.net/libmemcached/1.0/1.0.16/+download/libmemcached-1.0.16.tar.gz
RUN tar -xvf libmemcached-1.0.16.tar.gz
#RUN cd libmemcached-1.0.16; ./configure --disable-memcached-sasl
RUN cd libmemcached-1.0.16; ./configure
RUN cd libmemcached-1.0.16; make; make install
RUN echo -e "\n" | pecl install memcached memcache
RUN echo "extension=memcached.so" > /etc/php.d/memcached.ini
RUN echo "extension=memcache.so" > /etc/php.d/memcache.ini

# More modules
#RUN yum install -y libmemcached-devel pcre-devel cyrus-sasl-devel
#RUN yum install -y php-pecl-memcache php-pecl-memcached

RUN yum install -y php-pecl-redis php-curl

# Not needed: phpmyadmin mysql mysql-server httpd
RUN yum install -y php-mysql php-gd php-imap php-ldap php-odbc php-pear php-xml \
php-xmlrpc php-mapserver php-mbstring php-mcrypt php-mssql php-snmp php-soap \
php-tidy libpng libpng-devel libjpeg \
libjpeg-devel freetype freetype-devel zlib xFree86-dev openssl openssl-devel \
krb5-devel imap-2004d

#RUN cd `pear config-get php_dir`; mv .channels .channels-broken; pear update-channels
#RUN echo -e "\n" | pecl upgrade
#RUN echo -e "\n" | pecl install apc


#
# Install phpMyAdmin
# ------------------
#

ADD ./src-phpmyadmin/phpMyAdmin-4.0.8-all-languages.tar.gz /var/www/html/
ADD ./src-phpmyadmin/config.inc.php /var/www/html/phpMyAdmin-4.0.8-all-languages/config.inc.php


#
# Install RDS Command Line Tools (for MySQL performance tuning of RDS MySQL)
# --------------------------------------------------------------------------
# http://docs.aws.amazon.com/AmazonRDS/latest/CommandLineReference/StartCLI.html

RUN yum install -y groff
RUN easy_install pip
RUN pip install awscli


#
# Setup S3
# ---------

RUN wget https://github.com/s3tools/s3cmd/archive/master.zip
RUN unzip /master.zip
RUN cd /s3cmd-master; python setup.py install
RUN yum install -y python-dateutil

ADD ./s3cfg /.s3cfg


#
# Install cron and batches
# ------------------------

RUN yum install -y vixie-cron

# Add batches here since it changes often (use cache when building)
#ADD ./batches.py /
ADD ./batches.sh /

# Run backup job every hour
ADD ./backup.sh /
RUN echo '0 1 * * *  /bin/bash -c "/backup.sh"' > /mycron

RUN crontab /mycron

# only used in ubuntu?
#ADD ./etc-pam.d-cron /etc/pam.d/cron


#
# Start apache and mysql using supervisord
# -----------------------------------------


RUN mkdir /apps

EXPOSE 80 443
CMD ["supervisord"]
