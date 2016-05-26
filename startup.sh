#!/bin/bash

ENV_CONF=/etc/php5/fpm/pool.d/env.conf

ENV_CRON=/etc/cron.d/drupal

# Force deletion and creation of new file
rm -f $ENV_CRON

echo "Configuring Nginx and PHP5-FPM with environment variables"

# Update php5-fpm with access to Docker environment variables
echo '[www]' > $ENV_CONF
for var in $(env | awk -F= '{print $1}')
do
	echo "Adding variable {$var}"
	echo "env[${var}] = ${!var}" >> $ENV_CONF
        echo "${var}=${!var}" >> $ENV_CRON
done

# We need to configure the /etc/hosts file so sendmail works properly
# sendmail needs in this file something in the form of host.domain
# this is actually really easy to do with docker itself, adding -h something.localdomain
# when running the container, but it presents two problems:
# first, it doesn't work with maestro-ng and many other solutions that don't support
# the -h argument
# second, there's no way to use the container's name, when using -h we need to define
# the container's name so is not an ideal solution because other thinks can break
# when setting the name manually
# We then just rewrite the hosts file
echo "Configuring /etc/hosts"

CONTAINER_IP=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
CONTAINER_NAME=$(echo $HOSTNAME)

echo $CONTAINER_IP "	" $CONTAINER_NAME $CONTAINER_NAME".localdomain" > /etc/hosts
echo "127.0.0.1 	localhost" >> /etc/hosts
echo "::1	localhost ip6-localhost ip6-loopback" >> /etc/hosts
echo "fe00::0	ip6-localnet" >> /etc/hosts
echo "ff00::0	ip6-mcastprefix" >> /etc/hosts
echo "ff02::1	ip6-allnodes" >> /etc/hosts
echo "ff02::2	ip6-allrouters" >> /etc/hosts

# Runnning supervisor
/usr/bin/supervisord -n

# Setting up drush cron to run according CRON_SCHEDULE or 15 min by default
if [[ -z $CRON_SCHEDULE ]]; then
        CRON_SCHEDULE="*/15 * * * *"
else
        echo "CRON setup to user input"
fi

# Checking if the cron is already set up
# Cron job written according http://www.drush.org/en/master/cron/
CRON_JOB="root /usr/bin/env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin COLUMNS=72 /usr/local/bin/drush --root=/var/www cron"
CHECK=$(cat /etc/crontab | grep -o "$CRON_JOB" )

if [[ -z $CHECK ]]; then
	echo "$CRON_SCHEDULE $CRON_JOB" >> /etc/cron.d/drupal
	echo "$(date "+%Y-%m-%d %H:%M:%S") CRON_JOB set in /etc/crontab" >> /var/log/supervisor/cron.log
else
	echo "$(date "+%Y-%m-%d %H:%M:%S") CRON_JOB already created, doing nothing..." >> /var/log/supervisor/cron.log
fi

# Adding .htaccess to sites/default/files/ and /tmp according https://www.drupal.org/SA-CORE-2013-003

FILES_HTACCESS="# Turn off all options we don't need.
Options None
Options +FollowSymLinks

# Set the catch-all handler to prevent scripts from being executed.
SetHandler Drupal_Security_Do_Not_Remove_See_SA_2006_006
<Files *>
  # Override the handler again if we're run later in the evaluation list.
  SetHandler Drupal_Security_Do_Not_Remove_See_SA_2013_003
</Files>

# If we know how to do it safely, disable the PHP engine entirely.
<IfModule mod_php5.c>
  php_flag engine off
</IfModule>"

TMP_HTACCESS="# Turn off all options we don't need.
Options None
Options +FollowSymLinks

# Set the catch-all handler to prevent scripts from being executed.
SetHandler Drupal_Security_Do_Not_Remove_See_SA_2006_006
<Files *>
  # Override the handler again if we're run later in the evaluation list.
  SetHandler Drupal_Security_Do_Not_Remove_See_SA_2013_003
</Files>

# If we know how to do it safely, disable the PHP engine entirely.
<IfModule mod_php5.c>
  php_flag engine off
</IfModule>
Deny from all"

# Checking files/.htaccess
if [[ -e /var/www/sites/default/files/.htaccess ]]; then
	if [[ "$FILES_HTACCESS" = $(cat htaccessfiles.txt) ]]; then
		echo "File already exists"
	else
		echo "Files different"
		echo "$FILES_HTACCESS" > /var/www/sites/default/files/.htaccess
	fi
else
	echo "$FILES_HTACCESS" > /var/www/sites/default/files/.htaccess
fi

# Checking /tmp/.htaccess
if [[ -e /tmp/.htaccess ]]; then
	if [[ "$TMP_HTACCESS" = $(cat htaccessfiles.txt) ]]; then
		echo "File already exists"
	else
		echo "Files different"
		echo "$TMP_HTACCESS" > /tmp/.htaccess
	fi
else
	echo "$TMP_HTACCESS" > /tmp/.htaccess
fi
