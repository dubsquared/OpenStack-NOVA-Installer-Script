#!/bin/sh

# Copyright (c) 2011 OpenStack, LLC.	
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#    http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.

# See the License for the specific language governing permissions and
# limitations under the License.

# Written by Wayne A. Walls (dubsquared) with the amazing help of Jordan Rinke (JordanRinke), Vish Ishaya (vishy), 
# and a lot of input from the fine folks in #openstack on irc.freenode.net!

# Please contact script maintainers for questions, comments, or concerns:
# Wayne  ->  wayne@openstack.org
# Jordan ->  jordan@openstack.org

# This script is intended to be ran on a fresh install on Ubuntu 10.04 64-bit.  Once ran with 
# the appropiate varibles, will produce a fully functioning Nova Cloud Contoller.  I am working on 
# getting this working on all flavors of Ubuntu, and eventually RPM based distros.  Please feel free 
# to reach out to script maintainers for anything that can be done better.  I'm pretty new to this scripting business 
# so I'm sure there is room for improvement!

#Usage:  bash nova-NODE-installer.sh

#This is a Linux check
if [ `uname -a | grep -i linux | wc -l` -lt 1 ]; then
	echo "Not Linux, not compatible."
	exit 1
fi

#Compatible OS Check
    DEB_OS=`cat /etc/issue | grep -i 'ubuntu'`
    RH_OS=`cat /etc/issue | grep -i 'centos'`
    if [[ ${#DEB_OS} -gt 0 ]] ; then
        echo "Valid OS, continuing..."
        CUR_OS="Ubuntu"
    elif [[ ${#RH_OS} -gt 0 ]] ; then
        echo "Unsupported OS, sorry!"
        CUR_OS="CentOS"
        exit 1
    else
    	echo "Unsupported OS, sorry!"
        CUR_OS="Unknown"
        exit 1
    fi
    echo $CUR_OS detected! 
    
#Set up log file for debugging
LOGFILE=/var/log/nova/nova-node-install.log
mkdir /var/log/nova
touch /var/log/nova/nova-node-install.log

#Setting up sanity check function
valid_ipv4(){
 newmember=$(echo $1 | egrep '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$');
 members=$(echo $newmember | tr "." "\n");
 memcount=$(echo $newmember | tr "." "\n" | wc -l);
 if [ $memcount -ne 4 ]; then
  echo "fail";
  exit;
 fi
 for i in $members; do
  if [ $i -lt 0 ] || [ $i -gt 255 ]; then
   echo "fail";
   exit;
  fi;
 done;
 echo "success";
}

echo "Installing required packages"
echo "############################"

apt-get install -y python-software-properties
add-apt-repository ppa:nova-core/trunk
apt-get update
apt-get install -y nova-compute python-mysqldb

#Configuring S3 Host IP
set -o nounset
echo

debug=":"
debug="echo"

echo

#Grabs the first real IP of ifconfig, and set it as the default entry
#read -p "What is the IP address of your NOVA CONTROLLER? " default
#echo

#Configuring Cloud Controller Host IP
read -p "What is the IP address of your NOVA CONTROLLER? " default

set -o nounset
echo

debug=":"
debug="echo"

echo

while true; do
read -p "NOVA Controller IP (Default is $default -- ENTER to accept): " -e t1
if [ -n "$t1" ]
then
  CC_HOST_IP="$t1"
else
  CC_HOST_IP="$default"
fi

if [ $(valid_ipv4 $CC_HOST_IP) == "fail" ]; then
    echo "You have entered an invalid IP address, please try again."
    continue
fi
break;
done;

echo
echo " Cloud Controller Host IP set as \"$CC_HOST_IP\""

#default=`/sbin/ifconfig -a | egrep '.*inet ' | head -n 1|perl -pe 's/.*addr:(.+).*Bcast.*/$1/g' | tr -d " "`

while true; do
read -p "S3 Host IP (Default is $default -- ENTER to accept):" -e t1
if [ -n "$t1" ]
then
  S3_HOST_IP="$t1"
else
  S3_HOST_IP="$default"
fi
if [ $(valid_ipv4 $S3_HOST_IP) == "fail" ]; then
    echo "You have entered an invalid IP address, please try again."
   continue
fi
break;
done;

echo
echo " S3 Host IP set as \"$S3_HOST_IP\""

#Configuring RabbitMQ IP
set -o nounset
echo

debug=":"
debug="echo"

echo

while true; do
read -p "RabbitMQ Host IP (Default is $default -- ENTER to accept): " -e t1
if [ -n "$t1" ]
then
  RABBIT_IP="$t1"
else
  RABBIT_IP="$default"
fi

if [ $(valid_ipv4 $RABBIT_IP) == "fail" ]; then
    echo "You have entered an invalid IP address, please try again."
    continue
fi
break;
done;

echo
echo " RabbitMQ Host IP set as \"$RABBIT_IP\""
echo

#Configuring mySQL Host IP
set -o nounset
echo

debug=":"
debug="echo"


echo

while true; do
read -p "mySQL Host IP (Default is $default -- ENTER to accept): " -e t1
if [ -n "$t1" ]
then
  MYSQL_HOST_IP="$t1"
else
  MYSQL_HOST_IP="$default"
fi

if [ $(valid_ipv4 $MYSQL_HOST_IP) == "fail" ]; then
    echo "You have entered an invalid IP address, please try again."
    continue
fi
break;
done;

echo
echo "mySQL Host IP set as \"$MYSQL_HOST_IP\""

echo 

echo "mySQL User Config"
echo "#################"
echo

#Setting up mySQL root password, and verify
while true; do
read -s -p "Enter mySQL password on controller node: " MYSQL_PASS
       echo "";
       read -s -p "Verify password: " MYSQL_PASS2
       echo "";

       if [ $MYSQL_PASS != $MYSQL_PASS2 ]
       then
echo "Passwords do not match...try again.";
               continue;
       fi
break;
done

echo "Setting up Nova configuration files"
echo "###################################"
echo

#Info to be passed into /etc/nova/nova.conf

cat >> /etc/nova/nova.conf << NOVA_CONF_EOF
--s3_host=$S3_HOST_IP
--rabbit_host=$RABBIT_IP
--cc_host=$CC_HOST_IP
--ec2_url=http://$S3_HOST_IP:8773/services/Cloud
--sql_connection=mysql://root:$MYSQL_PASS@$MYSQL_HOST_IP/nova
--network_manager=nova.network.manager.FlatManager
NOVA_CONF_EOF
echo "...done..."
echo

echo "Setting up br100"
echo "################"
echo
LOCALIP=`/sbin/ifconfig -a | egrep '.*inet ' | head -n 1|perl -pe 's/.*addr:(.+).*Bcast.*/$1/g' | tr -d " "`

 
while true; do
read -p "Please enter your local server IP (Default is $LOCALIP -- ENTER to accept):" -e t1
if [ -n "$t1" ]
then
  LOCALIP="$t1"
else
  LOCALIP="$LOCALIP"
fi
if [ $(valid_ipv4 $LOCALIP) == "fail" ]; then
    echo "You have entered an invalid IP address, please try again."
   continue
fi
break;
done;

echo
BROADCAST=`ifconfig -a | egrep '.*inet ' | head -n 1 | perl -pe 's/.*Bcast:(.+).*Mask.*/$1/g' | tr -d " "`

while true; do
read -p "Please enter your broadcast IP (Default is $BROADCAST -- ENTER to accept):" -e t1
if [ -n "$t1" ]
then
  BROADCAST="$t1"
else
  BROADCAST="$BROADCAST"
fi
if [ $(valid_ipv4 $BROADCAST) == "fail" ]; then
    echo "You have entered an invalid IP address, please try again."
   continue
fi
break;
done;

echo

NETMASK=`ifconfig -a | egrep '*inet '| head -n 1 | perl -pe 's/.*Mask:/$1/g'| tr -d " "`

while true; do
read -p "Please enter your netmask (Default is $NETMASK -- ENTER to accept):" -e t1
if [ -n "$t1" ]
then
  NETMASK="$t1"
else
  NETMASK="$NETMASK"
fi
if [ $(valid_ipv4 $NETMASK) == "fail" ]; then
    echo "You have entered an invalid IP address, please try again."
   continue
fi
break;
done;

echo

GATEWAY=`ip route | awk '/default/{print $3}'`

while true; do
read -p "Please enter your gateway (Default is $GATEWAY -- ENTER to accept):" -e t1
if [ -n "$t1" ]
then
  GATEWAY="$t1"
else
 GATEWAY="$GATEWAY"
fi
if [ $(valid_ipv4 $GATEWAY) == "fail" ]; then
    echo "You have entered an invalid IP address, please try again."
   continue
fi
break;
done;

echo

NAMESERVER=`cat /etc/resolv.conf| awk '/nameserver/{print $2}'`

while true; do
read -p "Please enter your default nameserver (Default is $NAMESERVER -- ENTER to accept):" -e t1
if [ -n "$t1" ]
then
  NAMESERVER="$t1"
else
  NAMESERVER="$NAMESERVER"
fi
if [ $(valid_ipv4 $NAMESERVER) == "fail" ]; then
    echo "You have entered an invalid IP address, please try again."
   continue
fi
break;
done;

echo
while true; do
read -p "Please enter the IP where nova-api lives: " NOVA_API_IP

if [ $(valid_ipv4 $NOVA_API_IP) == "fail" ]; then
    echo "You have entered an invalid IP address, please try again."
   continue
fi
break;
done;

cat > /etc/network/interfaces << NOVA_BR100_CONFIG_EOF
# The loopback network interface
auto lo
iface lo inet loopback

auto br100
iface br100 inet static
        bridge_ports eth0
        bridge_stp off
        bridge_maxwait 0
        bridge_fd 0
        address $LOCALIP
        netmask $NETMASK
        broadcast $BROADCAST
        gateway $GATEWAY
        dns-nameservers $NAMESERVER
NOVA_BR100_CONFIG_EOF

echo
echo "Bouncing services"
echo "#################"
/etc/init.d/networking restart; restart libvirt-bin; service nova-compute restart
echo "...done..."

#Needed for KVM to initialize, VMs run in qemu mode otherwise and is very slow
chgrp kvm /dev/kvm
chmod g+rwx /dev/kvm

#Any server that does /NOT/ have nova-api running on it will need this rule for UEC images to get metadata info
iptables -t nat -A PREROUTING -d 169.254.169.254/32 -p tcp -m tcp --dport 80 -j DNAT --to-destination $NOVA_API_IP:8773

