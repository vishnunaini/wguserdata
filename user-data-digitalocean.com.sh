#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

WIREUSERNAME="wireuser"
SSHPUBKEY="<insert pubkey here>"

KRED='\033[0;31m'
KNORM='\033[0m'
KGREEN='\033[0;32m'
KBLUE='\033[0;34m'

print_success (){
	printf "${KGREEN}successful\n${KNORM}";
}
print_fail (){
        printf "${KRED}failure\n${KNORM}";
}
print_intact (){
        printf "${KBLUE}left intact\n${KNORM}";
}


#create user
useradd -G sudo -s /bin/bash -m $WIREUSERNAME

block_root_shell (){
	#block root shell
	usermod --shell /usr/sbin/nologin root
	printf "root bash shell block : " 
	if grep -Fxq "root:x:0:0:root:/root:/usr/sbin/nologin" /etc/passwd
		then
		print_success
	else
		print_fail
}

if [ -f /home/$WIREUSERNAME/.ssh/authorized_keys ]
	then
	echo $SSHPUBKEY >> ~/.ssh/authorized_keys

	if grep -Fxq "$SSHPUBKEY" /home/$WIREUSERNAME/.ssh/authorized_keys
	then
		printf "add ssh pub key to authorized_keys : " 
			print_success
		block_root_shell
	else
		printf "add ssh pub key to authorized_keys : "
			print_fail
		printf "root bash shell block : "
			print_intact
	fi
else
	printf "add ssh pub key to authorized_keys : "
			print_fail
	printf "${KRED}Error : user ${KBLUE}${WIREUSERNAME}${KRED}'s .ssh folder doesn't exist\n${KNORM}"
fi

sudo sed -i {s/mirrors.digitalocean.com/archive.ubuntu.com/} /etc/apt/sources.list
printf "change update servers to upstream : completed\n"

printf "updating apt lists\n Installing wireguard, unbound dns server and upgrading everything else\n"
sudo apt update

printf "Installing wireguard, unbound dns server and qrencode\n"
sudo apt install wireguard unbound unbound-host qrencode -y

printf "applying latest security and kernel updates\n"
sudo apt full-upgrade -y

printf "Generating wireguard server private and public keys in /etc/wireguard\n"

	umask 077
	sudo wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key

printf "wg server private key is at ${KBLUE}/etc/wireguard/server_private.key\n${KNORM}"

printf "wg server public key is at ${KBLUE}/etc/wireguard/server_public.key\n${KNORM}"

WG_SERVER_PUBKEY="$( sudo cat /etc/wireguard/server_public.key )"

printf "Your wg server public key is: ${KBLUE}${WG_SERVER_PUBKEY}\n${KNORM}"

printf  



input_peer_count () {

	printf "How many peers do you want to add to this server? Enter a number:"
	read NUM_PEERS

}


sudo mv ~/wg/* /etc/wireguard/
sudo curl -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache
sudo chown unbound:unbound /var/lib/unbound/root.hints
#sudo nano /etc/unbound/unbound.conf
sudo ln /etc/wireguard/unbound-wg.conf /etc/unbound/unbound.conf.d/unbound-wg.conf
#echo 1 > /proc/sys/net/ipv4/ip_forward
#echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1
sysctl -q net.ipv4.conf.all.src_valid_mark=1
#echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
#echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.conf.all.src_valid_mark=1" | sudo tee -a /etc/sysctl.conf
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0
sudo systemctl enable unbound
sudo service sshd restart
sudo service ssh restart
sudo systemctl daemon-reload

sudo ufw allow 22/tcp
sudo ufw allow 49151/tcp
sudo ufw allow 49152/udp
sudo ufw route allow in on wg0 out on eth0
sudo ufw route allow in on wg0 out on eth1

sudo ufw allow in on wg0 from 10.3.0.0/16
sudo ufw allow in on wg0 from fdc9:281f:04d7:9ee9::1/64

sudo ufw allow in on wg0 from anywhere

sudo ufw enable
udo ufw status verbose

echo "DNS=8.8.8.8#dns.google 2001:4860:4860::8888#dns.google 1.1.1.1#one.one.one.one 2606:4700:4700::1111#one.one.one.one" >> /etc/systemd/resolved.conf
echo "DNSOverTLS=yes" >> /etc/systemd/resolved.conf
echo "Cache=yes" >> /etc/systemd/resolved.conf
sudo systectl restart systemd-resolved

sudo resolvectl status

sudo reboot
