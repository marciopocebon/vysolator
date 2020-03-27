#!/bin/vbash
source /opt/vyatta/etc/functions/script-template

#ensure script is running correctly
if [ "$(id -g -n)" != 'vyattacfg' ] ; then
    exec sg vyattacfg -c "/bin/vbash $(readlink -f $0) $@"
fi

########################-overview interfaces-######################################################
# eth0 - uplink
# eth1 - management interfaces 10.7.7.0/24
# eth2 - internet only interface 10.8.8.0/24
###################################################################################################

########################-configuration starts here-################################################
configure

######## Interfaces
echo "[*] configuring interfaces"
set interfaces ethernet eth0 description 'uplink'
set interfaces ethernet eth0 address dhcp
commit
echo "[V] eth0 configured"
set interfaces ethernet eth2 description 'inetonly'
set interfaces ethernet eth2 address '10.8.8.1/24'
commit
echo "[V] eth1 configured"

######## DHCP
echo "[*] configuring DHCP"
set service dhcp-server shared-network-name inetonly subnet 10.8.8.0/24 default-router '10.8.8.1'
set service dhcp-server shared-network-name inetonly subnet 10.8.8.0/24 dns-server '8.8.8.8'
set service dhcp-server shared-network-name inetonly subnet 10.8.8.0/24 domain-name 'inetonly'
set service dhcp-server shared-network-name inetonly subnet 10.8.8.0/24 lease '86400'
set service dhcp-server shared-network-name inetonly subnet 10.8.8.0/24 range 0 start '10.8.8.2'
set service dhcp-server shared-network-name inetonly subnet 10.8.8.0/24 range 0 stop '10.8.8.254'
commit
echo "[V] DHCP configured"

######## NAT
echo "[*] configuring NAT"
set nat source rule 100 outbound-interface 'eth0'
set nat source rule 100 source address '10.8.8.0/24'
set nat source rule 100 translation address masquerade
commit
echo "[V] NAT configured"

save

######## Firewall
echo "[*] configuring firewall"

set firewall state-policy established action accept
set firewall state-policy related action accept
set firewall state-policy invalid action drop

set firewall group network-group internalranges
set firewall group network-group internalranges network 10.0.0.0/8
set firewall group network-group internalranges network 172.16.0.0/12
set firewall group network-group internalranges network 192.168.0.0/16
commit

set zone-policy zone uplink
set zone-policy zone uplink interface eth0
set zone-policy zone uplink default-action drop
set zone-policy zone uplink description 'uplink zone'

set zone-policy zone inetonly
set zone-policy zone inetonly interface eth2
set zone-policy zone inetonly default-action drop
set zone-policy zone inetonly description 'internet only'
commit

save

set firewall name uplinkTOinetonly default-action drop
commit

set firewall name inetonlyTOuplink default-action accept
set firewall name inetonlyTOuplink rule 10 action drop
set firewall name inetonlyTOuplink rule 10 protocol tcp_udp
set firewall name inetonlyTOuplink rule 10 destination group network-group internalranges
commit

set zone-policy zone uplink from inetonly firewall name inetonlyTOuplink
set zone-policy zone inetonly from uplink firewall name uplinkTOinetonly
commit
echo "[V] firewall configured"

save

exit

exit