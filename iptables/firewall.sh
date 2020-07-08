#!/bin/bash

if test -z "$1"; then

    echo "Please specify 'on', 'off', or 'reload'"
    exit 1

elif test "$1" == 'on'; then

    # Default Policy setzen und Chains leeren
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -F
    iptables -X
    iptables -Z
    iptables -t nat -F
    iptables -t nat -X
    iptables -t nat -Z

    ip6tables -P INPUT ACCEPT
    ip6tables -P OUTPUT ACCEPT
    ip6tables -P FORWARD ACCEPT
    ip6tables -F
    ip6tables -X
    ip6tables -Z
    ip6tables -t nat -F
    ip6tables -t nat -X
    ip6tables -t nat -Z

    # Lokale Kommunikation erlauben
    iptables -A INPUT -i lo -j ACCEPT

    ip6tables -A INPUT -i lo -j ACCEPT

    # Bereits etablierte Verbindungen erlauben
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Unsinnige Pakete verbieten
    iptables -A INPUT -p tcp ! --tcp-flags SYN,FIN,ACK SYN -m conntrack --ctstate NEW -j REJECT
    iptables -A INPUT -m conntrack --ctstate INVALID -j REJECT
    iptables -A FORWARD -m conntrack --ctstate INVALID -j REJECT

    ip6tables -A INPUT -p tcp ! --tcp-flags SYN,FIN,ACK SYN -m conntrack --ctstate NEW -j REJECT
    ip6tables -A INPUT -m conntrack --ctstate INVALID -j REJECT
    ip6tables -A FORWARD -m conntrack --ctstate INVALID -j REJECT

    # Pings und andere icmp Pakete erlauben
    iptables -A INPUT -p icmp -j ACCEPT

    ip6tables -A INPUT -p ipv6-icmp -j ACCEPT

    # Service spezifische Regeln importieren
    iptables -N MAIN-INPUT
    iptables -N MAIN-FORWARD
    iptables -t nat -N MAIN-PREROUTING
    iptables -t nat -N MAIN-POSTROUTING

    ip6tables -N MAIN-INPUT
    ip6tables -N MAIN-FORWARD
    ip6tables -t nat -N MAIN-PREROUTING
    ip6tables -t nat -N MAIN-POSTROUTING

    iptables -A INPUT -j MAIN-INPUT
    iptables -A FORWARD -j MAIN-FORWARD
    iptables -t nat -A PREROUTING -j MAIN-PREROUTING
    iptables -t nat -A POSTROUTING -j MAIN-POSTROUTING

    ip6tables -A INPUT -j MAIN-INPUT
    ip6tables -A FORWARD -j MAIN-FORWARD
    ip6tables -t nat -A PREROUTING -j MAIN-PREROUTING
    ip6tables -t nat -A POSTROUTING -j MAIN-POSTROUTING

    run-parts --regex '\.fw$' --arg='on' /usr/local/etc/firewall

    # Den Rest verbieten
    #iptables -A INPUT -j LOG --log-prefix "iptables reject: " --log-level 7
    iptables -A INPUT -j REJECT

    #ip6tables -A INPUT -j LOG --log-prefix "iptables reject: " --log-level 7
    ip6tables -A INPUT -j REJECT

    #iptables -A FORWARD -j LOG --log-prefix "iptables reject: " --log-level 7
    iptables -A FORWARD -j REJECT

    #ip6tables -A FORWARD -j LOG --log-prefix "iptables reject: " --log-level 7
    ip6tables -A FORWARD -j REJECT

elif test "$1" == 'off'; then

    # Default Policy setzen und Chains leeren
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -F
    iptables -X
    iptables -Z
    iptables -t nat -F
    iptables -t nat -X
    iptables -t nat -Z

    # Default Policy setzen und Chains leeren
    ip6tables -P INPUT ACCEPT
    ip6tables -P OUTPUT ACCEPT
    ip6tables -P FORWARD ACCEPT
    ip6tables -F
    ip6tables -X
    ip6tables -Z
    ip6tables -t nat -F
    ip6tables -t nat -X
    ip6tables -t nat -Z

elif test "$1" == 'reload'; then

    iptables -F MAIN-INPUT
    iptables -F MAIN-FORWARD
    iptables -t nat -F MAIN-PREROUTING
    iptables -t nat -F MAIN-POSTROUTING

    ip6tables -F MAIN-INPUT
    ip6tables -F MAIN-FORWARD
    ip6tables -t nat -F MAIN-PREROUTING
    ip6tables -t nat -F MAIN-POSTROUTING

    run-parts --regex '\.fw$' --arg='reload' /usr/local/etc/firewall

else

    echo "Please specify 'on', 'off', or 'reload'"
    exit 1

fi
