#!/bin/bash

export WIREGUARD_INTERFACE=wg0
export WIREGUARD_ADMIN_TOKEN=12345

POOL='https://deb.debian.org/debian/pool/main/w/wireguard/'

[ `dpkg -s libc6 |grep '^Version' |grep -o '[0-9\.]\{4\}' |head -n1 |cut -d'.' -f2` -ge "14" ] || exit 0

apt-get update
apt-get install -y libmnl-dev libelf-dev linux-headers-$(uname -r) build-essential pkg-config dkms resolvconf 

arch=`dpkg --print-architecture`
Version=`wget --no-check-certificate -qO- "${POOL}" |grep -o 'wireguard_[0-9\_\.\-]\{1,\}_' |head -n1 |cut -d'_' -f2`
[ -n "$Version" ] || exit 1

wget --no-check-certificate -qO "/tmp/wireguard_${Version}_all.deb" "${POOL}wireguard_${Version}_all.deb"
wget --no-check-certificate -qO "/tmp/wireguard-dkms_${Version}_all.deb" "${POOL}wireguard-dkms_${Version}_all.deb"
wget --no-check-certificate -qO "/tmp/wireguard-tools_${Version}_${arch}.deb" "${POOL}wireguard-tools_${Version}_${arch}.deb"

dpkg -i "/tmp/wireguard-tools_${Version}_${arch}.deb"
dpkg -i "/tmp/wireguard-dkms_${Version}_all.deb"
dpkg -i "/tmp/wireguard_${Version}_all.deb"

[ -d /etc/wireguard ] && {
command -v wg >/dev/null 2>&1
[ $? == 0 ] || exit 1
sed -i '/#\?net.ipv4.ip_forward/d' /etc/sysctl.conf
sed -i '$a\net.ipv4.ip_forward=1' /etc/sysctl.conf
sysctl -p


# make sure WIREGUARD_PORT exists and is a number
if ! [[ $WIREGUARD_PORT =~ ^[0-9]+$ ]] ; then
  export WIREGUARD_PORT=1337
fi

# make sure iptables is natting the default interface
# alpine will default the interface name to eth0
if ! iptables -t nat -C POSTROUTING -o eth0 --source 10.200.0.0/16 -j MASQUERADE
then
  iptables -t nat -A POSTROUTING -o eth0 --source 10.200.0.0/16 -j MASQUERADE
fi

# handle wireguard stuff required for the script
ip link add dev "${WIREGUARD_INTERFACE}" type wireguard
touch private-key
chmod 600 private-key
wg genkey > private-key
wg set "${WIREGUARD_INTERFACE}" listen-port "${WIREGUARD_PORT}" private-key private-key
ip link set up dev "${WIREGUARD_INTERFACE}"
ip address add dev "${WIREGUARD_INTERFACE}" 10.200.0.1/16

# generate TLS key and cert
openssl ecparam -genkey -name secp384r1 -out server.key
openssl req -new -x509 -sha256 -key server.key -out server.crt -days 3650 \
  -subj "/C=RO/ST=B/L=B/O=CG/OU=Infra/CN=CG/emailAddress=gheorghe@linux.com"

# run the webserver
/opt/wireguard-mariadb-auth ":${WIREGUARD_PORT}"
