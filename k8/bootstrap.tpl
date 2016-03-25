#!/usr/bin/env bash
OS=$(uname -s)

if [ "$OS" == "SunOS" ]; then
    echo BAL1
    if [ -f /root/.uscript.lock ]; then
        echo "we have already ran"
        exit 0
    else
        date > /root/.uscript.lock
    fi
    # Grab serial number from zonename
    SERIAL=`zonename`
elif [ -d /var/lib/cloud/instance ]; then
    SERIAL=`basename $(ls /var/lib/cloud/instances)`
else
    # Grab serial number from dmidecode
    SERIAL=`dmidecode |grep -i serial |awk '{print $NF}' |head -n 1`
fi

if [ ! -f /etc/ict.profile ]; then
    cat >> /etc/ict.profile << EOP
CHASSIS=EC2_VIRTUAL
CONFTAG=${conftag}
PACKAGE_SIZE=${package_size}
LOCATION=ec2
OWNER=ictops
CUSTOMER=${barge_customer}
SERIAL=$${SERIAL}
CREATOR=autoscale
NETWORK=PROD
EOP
fi

export PATH=$PATH:/usr/local/bin/:/opt/local/bin:/sbin:/usr/sbin
. /etc/ict.profile

mkdir -p /opt/emeril
mkdir -p /etc/products

if [ "$OS" == "SunOS" ]; then
    IP=$(/sbin/ifconfig net0 | awk '/inet/ {print $2}')
    HN=$(echo $IP |tr "." "-"|awk '{print "prd-"$1}')
    DOMAIN=nodes.ec2.dmtio.net
    echo $DOMAIN > /etc/defaultdomain
    echo "$IP $HN.$DOMAIN $HN" >> /etc/hosts
    hostname $HN
    echo $HN > /etc/nodename

    pkgin -y in pdsh

else
    IP=$(/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
    HN=$(echo $IP |tr "." "-"|awk '{print "prd-"$1}')
    DOMAIN=nodes.ec2.dmtio.net

    if [ $HN != $(hostname -s) ]; then
        echo "$HN.$DOMAIN" > /etc/hostname
        hostname $HN
        echo "$IP $HN.$DOMAIN $HN" >> /etc/hosts
    fi

    cd /tmp
    curl -k -O https://artifacts:negvsnpgf@artifacts.api.56m.vgtf.net/pdsh/pdsh_2.26_amd64.deb
    dpkg -i pdsh_2.26_amd64.deb

fi

which emeril
if [ $? == 0 ]; then
    echo "we already have emeril, so assume we already ran"
    exit 0
fi

REPO=repo.ec2.dmtio.net

if [ "$OS" == "SunOS" ]; then
    export PATH=/opt/local/bin:/opt/local/sbin:$PATH

    RET=1
    until [ $${RET} -eq 0 ]; do
        host $REPO
        RET=$?
        if [ $RET -ne 0 ]; then
            sleep 10
        fi
    done

else
    apt-get update
    apt-get install -y curl
fi

cd /tmp
curl -s -L -O http://$REPO/emeril/master/emeril.tar.gz
cd /opt/emeril
tar -xf /tmp/emeril.tar.gz
if [ -f  /opt/emeril/scripts/install.sh ]; then
    /opt/emeril/scripts/install.sh
fi

cd /tmp
ASSETS_URL="assets.services.ec2.dmtio.net"
[ -z "$(dig +noall +answer +nocomments $ASSETS_URL)" ] && ASSETS_URL='assets.services.dmtio.net'
curl -O http://$ASSETS_URL/emeril-assets/${conftag}.tgz
cd /opt/emeril
tar -xzf /tmp/${conftag}.tgz

rm /tmp/${conftag}.tgz

chown root /opt/emeril/cookbooks
chmod 0700 /opt/emeril/cookbooks

chown root /opt/emeril/products
chmod 0700 /opt/emeril/products

# On startup make sure we are online
cat <<EOF > /etc/rc.startup
#!/bin/sh -e
/usr/local/bin/host-online
EOF

/bin/chmod 755 /etc/rc.startup

# On shutdown/reboot, take offline
cat <<EOF > /etc/rc.shutdown
#!/bin/sh -e
/usr/local/bin/host-offline
EOF

/bin/chmod 755 /etc/rc.shutdown

cat <<EOF > /etc/init.d/rc.startup
#! /bin/sh
### BEGIN INIT INFO
# Provides:          rc.shutdown
# Required-Start:
# Required-Stop:     \$network
# Default-Start:     2 3 4 5
# Default-Stop:
# Short-Description: Run /etc/rc.startup if it exist
### END INIT INFO


PATH=/sbin:/usr/sbin:/bin:/usr/bin

. /lib/init/vars.sh
. /lib/lsb/init-functions

do_start() {
  if [ -x /etc/rc.startup ]; then
          [ "\$VERBOSE" != no ] && log_begin_msg "Running local startup scripts (/etc/rc.startup)"
    /etc/rc.startup
    ES=\$?
    [ "\$VERBOSE" != no ] && log_end_msg \$ES
    return \$ES
  fi
}

case "\$1" in
    start)
        do_start
        ;;
    restart|reload|force-reload)
        echo "Error: argument '\$1' not supported" >&2
        exit 3
        ;;
    stop)
        ;;
    *)
        echo "Usage: \$0 start|stop" >&2
        exit 3
        ;;
esac
EOF

/bin/chmod 755 /etc/init.d/rc.startup

cat <<EOF > /etc/init.d/rc.shutdown
#! /bin/sh
### BEGIN INIT INFO
# Provides:          rc.shutdown
# Required-Start:
# Required-Stop:     \$network
# Default-Start:
# Default-Stop:      0 6
# Short-Description: Run /etc/rc.shutdown if it exist
### END INIT INFO


PATH=/sbin:/usr/sbin:/bin:/usr/bin

. /lib/init/vars.sh
. /lib/lsb/init-functions

do_stop() {
  if [ -x /etc/rc.shutdown ]; then
          [ "\$VERBOSE" != no ] && log_begin_msg "Running local shutdown scripts (/etc/rc.shutdown)"
    /etc/rc.shutdown
    ES=\$?
    [ "\$VERBOSE" != no ] && log_end_msg \$ES
    return \$ES
  fi
}

case "\$1" in
    start)
        ;;
    restart|reload|force-reload)
        echo "Error: argument '\$1' not supported" >&2
        exit 3
        ;;
    stop)
        do_stop
        ;;
    *)
        echo "Usage: \$0 start|stop" >&2
        exit 3
        ;;
esac
EOF

/bin/chmod 755 /etc/init.d/rc.shutdown

/usr/sbin/update-rc.d rc.startup start 20 2 3 4 5 .
/usr/sbin/update-rc.d rc.shutdown stop 20 0 6 .

TYPE=${barge_type}
if [ "$TYPE" == "barge-node" ]; then
# Setup disks on node
umount /mnt
mkfs.ext4 -t ext4 -T small /dev/xvdb
mount /dev/xvdb /mnt

cat <<EOF > /root/bootstrap.sh
#!/usr/bin/env bash
/usr/local/bin/product-install base prod

/usr/local/bin/emeril base
/usr/local/sbin/emeril-assets-update
/usr/local/bin/emeril base

# Install barge products in order
/usr/local/bin/product-install ${customer}-barge-flannel ${environment}
/usr/local/bin/emeril ${customer}-barge-flannel

/usr/local/bin/product-install ${customer}-barge-docker ${environment}
/usr/local/bin/emeril ${customer}-barge-docker

/usr/local/bin/product-install ${customer}-barge-node ${environment}
/usr/local/bin/emeril ${customer}-barge-node

/usr/local/bin/product-install mss-barge-docker-proxy ${environment}
/usr/local/bin/emeril mss-barge-docker-proxy

/usr/local/bin/product-install ${customer}-barge-node-datadog ${environment}
/usr/local/bin/emeril ${customer}-barge-node-datadog

/usr/local/bin/product-install ${customer}-barge-node-fluentd ${environment}
/usr/local/bin/emeril ${customer}-barge-node-fluentd

EOF

elif [ "$TYPE" == "barge-api" ]; then

cat <<EOF > /root/bootstrap.sh
#!/usr/bin/env bash
/usr/local/bin/product-install base ${environment}

/usr/local/bin/emeril base
/usr/local/sbin/emeril-assets-update
/usr/local/bin/emeril base

# Install barge products in order
/usr/local/bin/product-install ${customer}-barge-api ${environment}
/usr/local/bin/emeril ${customer}-barge-api

/usr/local/bin/product-install ${customer}-barge-api-datadog ${environment}
/usr/local/bin/emeril ${customer}-barge-api-datadog

EOF
fi

echo "bash /root/bootstrap.sh > /var/log/bootstrap.log 2>&1" | at now
