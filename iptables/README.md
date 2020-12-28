# Firewall / iptables service

For my firewall service I use iptables because until now it's still the default tool on ubuntu. When creating the service I tried to do it without using root, but this was not possible, as written below. I also wanted to allow other software to create firewall rules without needing to modifying the base script.

## basics

My firewall script has three options: on, off and reload.

ON creates some basic rules like allowing ICMP traffic and already established connections. It also creates an additional chain for each of the four chains INPUT, FORWARD, PREROUTING, and POSTROUTING. These additonal chains allows me to add and remove rules and then reload the firewall without flushing the default chains which would also flush the REJECT at the end. This would ideally only disable the firewall protection for a brief moment, but if I had an error somewhre in my ON section it could leave me without any rules. This way, when the reload fails, I at least have the default REJECT in place and can fix the problem over my still established ssh connection or through the console.

RELOAD flushes my additional base chains and then executes all scripts inside /usr/local/etc/firewall.

OFF just flushes and deletes all chains.

Because the iptables script is not a service that remains running (`Type=oneshot`), I use `RemainAfterExit=true` to be able to start, reload and stop my firewall with a single service instead of having to create three services. RemainAfterExit= reports the service as active even when the ExecStart= command terminates and thus allows to stop the service later.

## not running as root

Sadly I was not able to get my firewall / iptables service running without root. The reason is that iptables needs to create / write the file /run/xtables.lock which is owned by root and not writeable by any other user. If anyone has an idea around that, please open an issue, thank you.

But I was able to remove most of the [capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html) root normaly has. With `CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_SYS_MODULE` the services only has access to three out of over 40+ capabilities even though it is running as root.

Combining ProtectSystem=strict and ReadWritePaths=/run/ prevents the service from modifying most parts of the filesystem whils still allowing creating / writing the /run/xtables.lock file. Futher restricting ReadWritePaths=-/run/xtables.lock does not work, because the file does not exist at boot time. The - (minus) would ignore the missing file at boot but would than also not allow writing to that path which prevents creating the file and fails the iptables script.

## modularity

I use ansible to configure my servers and I don't want to edit my firewall role or the iptables script each time I add a new role / software that I want to open ports for.

Instead each ansible role / software has its own small iptables script to open its ports. These script are copied to /usr/local/etc/firewall and executed by the base script through run-parts whenever something changes inside the /usr/local/etc/firewall directory.

To detect new or changed rules I use a systemd path unit. With a simple `PathChanged=/usr/local/etc/firewall/` this unit watches for modified or new files within the path and then starts a service of the same name. Because the only option is to start a service not to reload it, I can not directly reload the firewall service. So I created a service which runs systemctl reload firewall.
