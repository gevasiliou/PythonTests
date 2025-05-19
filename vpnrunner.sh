#!/bin/bash

DEFAULT_GATEWAY="192.168.2.1"
WIFI_IFACE="wlp2s0"
LOGFILE="vpnrunner.log"
REPORTFILE="vpnrunner_report.txt"
NM_CONF="/etc/NetworkManager/conf.d/disable-ipv6.conf"
OVPN_FILE="pl-free-17.protonvpn.udp.ovpn"
webRTCBlockRules=0

# Function to write log entries
log_entry() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOGFILE" 
}

detect_lan_ip() {
    LAN_IP=$(ip -o -4 addr show scope global | grep -v 'tun' | awk '{print $4}' | cut -d/ -f1)

    if [ -z "$LAN_IP" ]; then
        log_entry "Error: Unable to detect LAN IP!"
        exit 1
    fi

    log_entry "Detected LAN IP: $LAN_IP"
}

# Function to check VPN status
check_vpn_status() {
    VPN_IFACE=$(ip a | grep -Eo 'tun[0-9]+' | head -n 1)

    if [ -n "$VPN_IFACE" ]; then
        log_entry "VPN detected ($VPN_IFACE is active). Your ip is $(curl -s ifconfig.me)"
    else
        log_entry "No active VPN connection detected! Please connect to VPN first."
        echo "No active VPN connection detected! Please connect to VPN first."
        exit 1
    fi
}

# Function to ensure NetworkManager does not override IPv6 settings
ensure_nm_ipv6_disabled() {
    if ! grep -oq 'ipv6.method=disabled' "$NM_CONF"; then
        log_entry "Creating NetworkManager IPv6 disable config..."
        echo -e "[connection]\nipv6.method=disabled" | sudo tee "$NM_CONF"
        log_entry "Restarting NetworkManager to apply IPv6 settings..."
        sudo systemctl restart NetworkManager
    else
        log_entry "NetworkManager IPv6 disable config already includes ipv6.method=disabled. No restart of NetworkManager needed."
    fi
}


# Function to disable IPv6 permanently
disable_ipv6() {
    log_entry "Disabling IPv6..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
    # Drop all outgoing IPv6 traffic
    sudo ip6tables -A OUTPUT -j DROP
#alternatively edit the file /etc/sysctl.conf and add those lines:
#net.ipv6.conf.all.disable_ipv6 = 1
#net.ipv6.conf.default.disable_ipv6 = 1
#net.ipv6.conf.lo.disable_ipv6 = 1
}

# Function to enable/disable DNS leak protection
configure_dns_protection() {
    if [ "$1" == "enable" ]; then
        log_entry "Enforcing VPN-only DNS for $VPN_IFACE..."

        # Block UDP DNS traffic outside VPN
        if ! sudo iptables -C OUTPUT ! -o "$VPN_IFACE" -p udp --dport 53 -j DROP 2>/dev/null; then
            sudo iptables -A OUTPUT ! -o "$VPN_IFACE" -p udp --dport 53 -j DROP
            log_entry "Blocked UDP DNS traffic outside VPN."
        fi

        # Block TCP DNS traffic outside VPN
        if ! sudo iptables -C OUTPUT ! -o "$VPN_IFACE" -p tcp --dport 53 -j DROP 2>/dev/null; then
            sudo iptables -A OUTPUT ! -o "$VPN_IFACE" -p tcp --dport 53 -j DROP
            log_entry "Blocked TCP DNS traffic outside VPN."
        fi

    elif [ "$1" == "disable" ]; then
        log_entry "Restoring normal DNS settings for non-VPN mode..."

        # Remove UDP DNS blocking rule
        if sudo iptables -C OUTPUT ! -o "$VPN_IFACE" -p udp --dport 53 -j DROP 2>/dev/null; then
            sudo iptables -D OUTPUT ! -o "$VPN_IFACE" -p udp --dport 53 -j DROP
            log_entry "Restored UDP DNS settings."
        fi

        # Remove TCP DNS blocking rule
        if sudo iptables -C OUTPUT ! -o "$VPN_IFACE" -p tcp --dport 53 -j DROP 2>/dev/null; then
            sudo iptables -D OUTPUT ! -o "$VPN_IFACE" -p tcp --dport 53 -j DROP
            log_entry "Restored TCP DNS settings."
        fi
    fi
}


configure_ipv6_dns_protection() {
    VPN_IFACE=$(ip a | grep -Eo 'tun[0-9]+' | head -n 1)  # Detect active VPN interface

    if [ "$1" == "enable" ]; then
        if [ -n "$VPN_IFACE" ]; then
            log_entry "VPN detected on $VPN_IFACE. Enforcing IPv6 DNS protection..."

            # Block IPv6 UDP DNS traffic outside VPN
            if ! sudo ip6tables -C OUTPUT ! -o "$VPN_IFACE" -p udp --dport 53 -j DROP 2>/dev/null; then
                sudo ip6tables -A OUTPUT ! -o "$VPN_IFACE" -p udp --dport 53 -j DROP
                log_entry "Blocked IPv6 UDP DNS traffic outside VPN."
            else
                log_entry "IPv6 UDP DNS blocking rule already exists."
            fi

            # Block IPv6 TCP DNS traffic outside VPN
            if ! sudo ip6tables -C OUTPUT ! -o "$VPN_IFACE" -p tcp --dport 53 -j DROP 2>/dev/null; then
                sudo ip6tables -A OUTPUT ! -o "$VPN_IFACE" -p tcp --dport 53 -j DROP
                log_entry "Blocked IPv6 TCP DNS traffic outside VPN."
            else
                log_entry "IPv6 TCP DNS blocking rule already exists."
            fi

        else
            log_entry "VPN is not active. Skipping IPv6 DNS protection changes."
        fi

    elif [ "$1" == "disable" ]; then
        log_entry "Restoring normal IPv6 DNS settings for non-VPN mode..."

        # Remove IPv6 UDP DNS blocking rule
        if sudo ip6tables -C OUTPUT -p udp --dport 53 -j DROP 2>/dev/null; then
            sudo ip6tables -D OUTPUT -p udp --dport 53 -j DROP
            log_entry "Restored IPv6 UDP DNS settings."
        else
            log_entry "No IPv6 UDP DNS blocking rule found—skipping removal."
        fi

        # Remove IPv6 TCP DNS blocking rule
        if sudo ip6tables -C OUTPUT -p tcp --dport 53 -j DROP 2>/dev/null; then
            sudo ip6tables -D OUTPUT -p tcp --dport 53 -j DROP
            log_entry "Restored IPv6 TCP DNS settings."
        else
            log_entry "No IPv6 TCP DNS blocking rule found—skipping removal."
        fi
    fi
}

# Function to enforce VPN-only traffic (Kill Switch)
configure_vpn_killswitch() {
    if [ "$1" == "enable" ]; then
        if ! sudo iptables -C OUTPUT ! -o "$VPN_IFACE" -j DROP 2>/dev/null; then
            log_entry "Enabling VPN kill switch for $VPN_IFACE ..."
            sudo iptables -A OUTPUT ! -o "$VPN_IFACE" -j DROP
        else
            log_entry "VPN kill switch is already enabled."
        fi
    else
        if sudo iptables -C OUTPUT ! -o "$VPN_IFACE" -j DROP 2>/dev/null; then
            log_entry "Disabling VPN kill switch for $VPN_IFACE ..."
            sudo iptables -D OUTPUT ! -o "$VPN_IFACE" -j DROP
        else
            log_entry "VPN kill switch is already disabled."
        fi
    fi
}


allow_remote_access() {
    log_entry "Allowing remote access traffic (TeamViewer, AnyDesk, TightVNC)..."
    
    # Common ports used by both TeamViewer & AnyDesk
    sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
    
    # TeamViewer-specific port
    sudo iptables -A OUTPUT -p tcp --dport 5938 -j ACCEPT
    
    # AnyDesk-specific port
    sudo iptables -A OUTPUT -p tcp --dport 7070 -j ACCEPT
    
    # TightVNC-specific port
    sudo iptables -A OUTPUT -p tcp --dport 5900 -j ACCEPT
}

# Function to remove default non-VPN routes while keeping LAN access
remove_default_routes() {
    log_entry "Removing non-VPN default routes, preserving LAN..."

    # Remove default Wi-Fi route to prevent leaks
    #sudo ip route del default via 192.168.2.1 dev wlp2s0
    sudo ip route del default via $DEFAULT_GATEWAY dev $WIFI_IFACE

    # Preserve LAN access
    #sudo ip route add 192.168.2.0/24 dev wlp2s0
    # Extract subnet dynamically from DEFAULT_GATEWAY
    SUBNET="$(echo $DEFAULT_GATEWAY | awk -F'.' '{print $1"."$2"."$3".0/24"}')"
    # Check if the route already exists
	if ! ip route show | grep -q "$SUBNET dev $WIFI_IFACE"; then
		sudo ip route add $SUBNET dev $WIFI_IFACE
		log_entry "Added route: $SUBNET via $WIFI_IFACE"
	else
		log_entry "Route already exists: $SUBNET via $WIFI_IFACE. No changes needed."
	fi
}

# Function to restore default LAN routes
restore_default_routes() {
    log_entry "Restoring default network routes..."
    
    # Restore default route to allow normal networking
    # sudo ip route add default via 192.168.2.1 dev wlp2s0
    sudo ip route add default via $DEFAULT_GATEWAY dev $WIFI_IFACE
    
    # Ensure the LAN route remains valid
    # sudo ip route add 192.168.2.0/24 dev wlp2s0
    SUBNET="$(echo $DEFAULT_GATEWAY | awk -F'.' '{print $1"."$2"."$3".0/24"}')"
	# Check if the route already exists
	if ! ip route show | grep -q "$SUBNET dev $WIFI_IFACE"; then
		sudo ip route add $SUBNET dev $WIFI_IFACE
		log_entry "Added route: $SUBNET via $WIFI_IFACE"
	else
		log_entry "Route already exists: $SUBNET via $WIFI_IFACE. No changes needed."
	fi
}

disable_webrtc_leaks() {
    log_entry "Blocking WebRTC leaks by blocking udp ports 3478 to 3481..."
        
    # Array of WebRTC-related ports
    PORTS=(3478 3479 3480 3481)

    for PORT in "${PORTS[@]}"; do
        if ! sudo iptables -C OUTPUT -p udp --dport $PORT -j DROP 2>/dev/null; then
            sudo iptables -A OUTPUT -p udp --dport $PORT -j DROP
        else
            log_entry "WebRTC blocking rule for port $PORT already exists."
        fi
    done

    webRTCBlockRules=1
    log_entry "WebRTC leak protection applied successfully."
}


enable_webrtc() {
    if [ $webRTCBlockRules -eq 1 ]; then
    log_entry "Re-enabling WebRTC traffic..."
    read -p "press any key to continue"
    # Remove WebRTC blocking rules (STUN/TURN requests)
    sudo iptables -D OUTPUT -p udp --dport 3478 -j DROP
    sudo iptables -D OUTPUT -p udp --dport 3479 -j DROP
    sudo iptables -D OUTPUT -p udp --dport 3480 -j DROP
    sudo iptables -D OUTPUT -p udp --dport 3481 -j DROP
	webRTCBlockRules=0
    log_entry "WebRTC traffic re-enabled successfully, blocking of udp ports 3478 to 3481 restored"
    else
    log_entry "No webRTCBlockRules have been applied - exiting"
    fi
}



# Function to detect WebRTC leaks before applying firewall blocks
#check_webrtc_leak() {
#    log_entry "Checking WebRTC leaks..."
#    
#    if curl -s https://browserleaks.com/webrtc | grep -E "Public IP Address|Local IP Address"; then
#        log_entry "WebRTC leak detected! Applying firewall blocks."
#        disable_webrtc_leaks
#    else
#        log_entry "No WebRTC leak detected. Firewall blocking skipped."
#    fi
#}

check_webrtc_leak() {
    log_entry "Checking WebRTC leaks..."
    
    LEAK_INFO=$(curl -s https://browserleaks.com/webrtc | jq '. | select(.PublicIPAddress or .LocalIPAddress)')
    
    if [[ -n "$LEAK_INFO" ]]; then
        log_entry "WebRTC leak detected! Applying firewall blocks."
        disable_webrtc_leaks
    else
        log_entry "No WebRTC leak detected. Firewall blocking skipped."
    fi
}


# Function to modify OpenVPN DNS settings
modify_ovpn_config_block_outside_dns() {
    if [ "$1" == "enable" ]; then
        log_entry "Enforcing VPN DNS protection in $OVPN_FILE by adding block-outside-dns option..."
        read -p "Press any key to continue..."
        sudo sed -i '/block-outside-dns/d' "$OVPN_FILE"
        echo "block-outside-dns" | sudo tee -a "$OVPN_FILE"
    else
        log_entry "Removing VPN DNS protection (block-outside-dns) in $OVPN_FILE..."
        read -p "Press any key to continue..."
        sudo sed -i '/block-outside-dns/d' "$OVPN_FILE"
    fi

    log_entry "Restarting OpenVPN to apply changes..."
    read -p "Press any key to continue..."
    restart_openvpn
}

# Function to generate privacy report
anonymity_report() {
    log_entry "
    Generating VPN Privacy Report...
    Date: $(date)"
    log_entry "-----------------------------------------------------------------------------------------------"
	#read -p "External IP Check....press any key to continue"
    log_entry "### External IP Check using curl ifconfig.me & curl nodedata.io/whoami ###"
    log_entry "$(curl -s ifconfig.me)"
    log_entry "$(curl -s https://nodedata.io/whoami |grep 'hostname' |sed 's/,/\n/g')"
    log_entry "-----------------------------------------------------------------------------------------------"
	#read -p "IPv6 Leak Check....press any key to continue"
    log_entry "### IPv6 Leak Check ###"
    log_entry "$(ip a | grep inet6)"
    log_entry "-----------------------------------------------------------------------------------------------"
	#read -p "DNS Leak Check (nslookup google.com)....press any key to continue"
    log_entry "### DNS Leak Test (nslookup google.com) ###"
    #log_entry "$(nslookup google.com | grep -E 'Address|Server')"
    log_entry "$(nslookup google.com)"
    log_entry "-----------------------------------------------------------------------------------------------"
	#read -p "VPN Routing Test (ip route show)....press any key to continue"
    log_entry "### VPN Routing Test (ip route show)###"
    log_entry "$(ip route show)"
    log_entry "-----------------------------------------------------------------------------------------------"
	#read -p "WHOIS Simple Test - press any key to continue"
	IP_ADDR=$(curl -s ifconfig.me)
	log_entry "Simple WHOIS Test using whois.cymru.com"
	log_entry "$(whois -h whois.cymru.com " -v $IP_ADDR")"
    log_entry "-----------------------------------------------------------------------------------------------"
	#read -p "WHOIS Extended Test....press any key to continue"
    #log_entry "### WHOIS Test (Checking VPN IP) ###"
    #log_entry "$(whois $(curl -s ifconfig.me))"

	#read -p "WebRTC Leak Test ....press any key to continue"
    log_entry "### WebRTC Leak Test using curl -s https://browserleaks.com/webrtc  ###"
    log_entry "$(curl -s https://browserleaks.com/webrtc | grep -E 'Public IP Address|Local IP Address')"
    log_entry "$(lynx -dump https://browserleaks.com/webrtc | grep 'Public IP Address')"
    log_entry "-----------------------------------------------------------------------------------------------"
    log_entry "Anonymity verification tests completed."
    log_entry "VPN Privacy Report saved to $REPORTFILE"
    log_entry "-----------------------------------------------------------------------------------------------"
    echo "
### More tools for online testing about IP, IP6, DNS Leaks, etc ###
https://nodedata.io/whoami
https://dnsleaktest.com/
https://ipleak.net/
https://browserleaks.com/webrtc
https://www.hashemian.com/ (this one is really good to expose leaks like IP6)
"
}

verify_remote_access() {
    log_entry "Verifying LAN access for TightVNC, TeamViewer, and Anydesk..."

    echo "### LAN Connectivity Test ###"
    if ping -c 2 "$LAN_IP" ; then
        log_entry "LAN connectivity confirmed!"
    else
        log_entry "Error: LAN connectivity failed!"
    fi

    echo "### TightVNC Accessibility Test ###"
    if nc -zv "$LAN_IP" 5900; then
        log_entry "TightVNC is reachable within LAN."
    else
        log_entry "Error: TightVNC is NOT accessible!"
    fi

    echo "### TeamViewer Accessibility Test ###"
    if nc -zv "$LAN_IP" 5938 || nc -zv "$LAN_IP" 443 || nc -zv "$LAN_IP" 80; then
        log_entry "TeamViewer is reachable within LAN."
    else
        log_entry "Error: TeamViewer is NOT accessible!"
    fi

    echo "### Anydesk Accessibility Test ###"
    if nc -zv "$LAN_IP" 7070; then
        log_entry "Anydesk is reachable within LAN."
    else
        log_entry "Error: Anydesk is NOT accessible!"
    fi
}

show_help() {
echo "This is a tool to help you secure your anonymity through vpns.
Available switches:
    --anonymous : Performs bellow tasks (functions)
            check_vpn_status                    --> Check if vpn is enabled, and exit if not

            ensure_nm_ipv6_disabled             --> inject ipv6.method=disabled to $NM_CONF

            disable_ipv6                        --> ensure IP6 is disabled since IP leaking can occur due to IPv6 by running:
                                                    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
                                                    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1

            configure_dns_protection enable     --> Uses iptables to block outgoing DNS traffic (UDP port 53) 
                                                    unless it goes through the VPN interface ($VPN_IFACE). 
                                                    This ensures that DNS queries don't leak outside the VPN
                                                    command: sudo iptables -A OUTPUT ! -o VPN_IFACE -p udp --dport 53 -j DROP

            configure_vpn_killswitch enable     --> blocks any traffic that doesn't go through the VPN, acting as a full kill switch.
                                                    command: sudo iptables -A OUTPUT ! -o VPN_IFACE -j DROP

            remove_default_routes               --> Removing non-VPN default routes, preserving LAN...
                                                    command: sudo ip route del default via 192.168.2.1 dev wlp2s0

            allow_remote_access                 --> Rules that will preserve remote access like Anydesk, vnc, etc inside the lan

            modify_ovpn_config_block_outside_dns --> Inject block-outside-dns to your .ovpn configuration file

            check_webrtc_leak                   --> Check for webrtc leaking and disable webrtc leaks if necessary
            anonymity_report                    --> Print a report that will verify your anonymity
            verify_remote_access                --> Ensures TightVNC, TeamViewer, and Anydesk work inside LAN

    --default : Restores changes made by --anonymous - run bellow functions:
                restore_default_routes
                configure_vpn_killswitch disable
                configure_dns_protection disable
                modify_ovpn_config_block_outside_dns disable

    --report                : detect_lan_ip & anonymity_report
    --vpn-status            : Check VPN status
    --verify-remote-access  : Checks if lan access for remote tools like anydesk, vnc, etc is granted.
"
}


# Main script logic
if [ "$#" -eq 0 ]; then
    show_help
elif [ "$1" == "--anonymous" ]; then
    check_vpn_status
    ensure_nm_ipv6_disabled
    disable_ipv6
    configure_dns_protection enable
    configure_ipv6_dns_protection enable
    configure_vpn_killswitch enable
    remove_default_routes
    allow_remote_access
    modify_ovpn_config_block_outside_dns enable
    check_webrtc_leak
    anonymity_report
    log_entry "Anonymous mode activated!"
    verify_remote_access  # Ensures TightVNC, TeamViewer, and Anydesk work inside LAN
    echo "Anonymous mode activated! Logs saved to $LOGFILE"
elif [ "$1" == "--default" ]; then
    restore_default_routes
    configure_dns_protection disable
    configure_ipv6_dns_protection disable
    configure_vpn_killswitch disable
    configure_dns_protection disable
    modify_ovpn_config_block_outside_dns disable
    log_entry "Default network mode restored."
elif [ "$1" == "--report" ];then
	detect_lan_ip
	anonymity_report
elif [ "$1" == "--vpn-status" ];then
	check_vpn_status
elif [ "$1" == "--verify-lan-access" ];then
	detect_lan_ip
	verify_remote_access
elif [ "$1" == "--help" ];then
	show_help
else 
	echo "unknown option $1"
	show_help
fi
