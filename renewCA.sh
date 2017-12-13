#!/bin/bash

# Force renewal of IPA CA by backdating clock to the day before the certificate expired.

# Author: Patrick Rutledge <prutledg@redhat.com>

# There is no support or guarantee implied for this script!  Use at your own risk.

# DANGER! Only do this if your IPA CA cert has expired!

echo "Stopping IPA if its up..."
ipactl stop 2>&1 > /dev/null

expire_date=`getcert list -d /etc/pki/pki-tomcat/alias -n 'subsystemCert cert-pki-ca'|grep expires|awk '{print $2}'`
echo "CA expiration date is/was $expire_date."
new_date=`date -d"$expire_date-1 day"`

echo "Rolling back system clock to $new_date"
timedatectl set-ntp false
timedatectl set-timezone UTC
timedatectl set-time $new_date

echo "Starting IPA..."
ipactl start
if [ $? -ne 0 ]
then
        echo "IPA failed to start after rolling back clock, you have other problems to look into."
        exit 1
fi

echo "Restarting certmonger..."
systemctl restart certmonger

echo "Issuing CA cert renewal..."
ipa-cacert-manage renew
if [ $? -ne 0 ]
then
        echo "IPA failed to renew CA certificate, cannot continue."
        exit 1
fi

echo -n "Waiting for certmonger to update certs.  Press Ctrl-C if this takes more than 10 minutes..."
while [ "$status" != "MONITORING" ]
do
        echo -n "."
        status=`getcert list -d /etc/pki/pki-tomcat/alias -n 'subsystemCert cert-pki-ca'|grep status|awk '{print $2}'`
        sleep 10
done

echo
timedatectl set-ntp true --adjust-system-clock
echo "System clock normalized.  You should reboot the system ASAP."
