# systemd services

This repository includes systemd services that I wrote because I was not satisfied with the provided ones or there simply were none.

## Disclaimer

I'm a linux administrator for about 6+ years and have been using linux for 15+ years, but I'm no kernel developer and some of the options to sandbox the service I use, I only understand to a degree. This is mostly true for some of the options that remove access to some part of the system, but where the documentation is clear that no service should ever need them.

## Goals

The goal with all services is to use modern systemd settings and as much sandboxing as possible. I say modern as in, using a better way if there is one, for something that has been done the same way for 20 years. I'm not saying to replace everything with something new, just because it is new and may not even offer anything over the established way. The following explanations may include exaggerations about how bad it was befor, these are a combination of facts and tears.

Some of the sandboxing options remove abilities from services that unprivileged users don't have access to anyway. These are just an additional layer of security in case they obtain these abilities in some other way.

### Avoid Type=forking

The forking Type is the [behavior of traditional UNIX services](https://www.freedesktop.org/software/systemd/man/systemd.service.html#Type=), were systemd starts a process which then forks to start the actual binary. Often you need to specify a PIDFile= or systemd will loose track of the correct process.

This is often used with some archaic bash startup scripts that were last updated in 1997. These scripts set a few environment variables, maybe check the existence of a folder or config file and run start-stop-daemon with an incomprehensible list of parameters. All these things can be done directly in the service file in a few lines, instead of hundred of lines of bash.

What we want to achieve is to run the binary, that contains the programm, directly with ExecStart=. The Type we want to use is Type=exec (with systemd >= 240) or Type=simple (with systemd < 240). The difference is described [here](https://www.freedesktop.org/software/systemd/man/systemd.service.html#Type=).

### Avoid running as root

For obvious reasons we normally don't want our services to run as root and be able to do everything. Many services don't need any administrative privileges and are happy running as an unprivileged process. These can be achieved with the [User= and Group=](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#User=) options.

Some services do need some administrative privileges (called [capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html) in the linux kernel), but we can give them everything they need without them running as root. This is where [AmbientCapabilities=](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#AmbientCapabilities=) comes into play. With this option we can include needed capabilities into the process.

For example with AmbientCapabilities=CAP_DAC_READ_SEARCH we can give a service the permission to read every file and open every folder in the filesystem without beeing able to modify them. Great for backup services like my borg service.

### Prevent unintended changes to the system

There are many options which remove some abilities for a service to change things in the system.

#### ProtectSystem=strict

This makes the whole filesystems read-only to the process, even if it would run as root. I combine this with ReadWritePaths= to make some paths of the filesystem writeable again, if the service needs them.

#### ProtectControlGroups=true

Makes the Linux Control Groups hierarchies accessible through /sys/fs/cgroup read-only. When ProtectSystem=strict is used, this is redundant but I keep it in case I have a service without it.

#### ProtectKernelTunables=true

Makes the kernel variables accessible through /proc/sys, /sys, /proc/sysrq-trigger, /proc/latency_stats, /proc/acpi, /proc/timer_stats, /proc/fs and /proc/irq read-only. When ProtectSystem=strict is used, this is redundant but I keep it in case I have a service without it.

#### ProtectHostname=true

Removes the ability to change the system hostname.

#### ProtectClock=true

Removes the ability to change the system clock or hardware clock.

### Prevent unnecessary access to the system

Some parts of the system are not needed by most services to be accessible at all, so we make them inaccessible.

#### ProtectHome=true

Makes the directories /home, /root, and /run/user inaccessible for the service. When I create user accounts for the services I create the home directory outside of /home, normally inside /srv to not take away the users own home directory.

#### PrivateTmp=true

Creates a private /tmp directory just for the service. It can write files to it, but can't access any files in the "real" /tmp directory. Additionally the private /tmp will be deleted when the service stops.

#### PrivateDevices=true

Creates a private /dev directory just for the service. Only /dev/null, /dev/zero and /dev/random are added to this private /dev. This blocks raw access to physical devices like the harddrive and system memory.

#### ProtectKernelLogs=true

Remove the ability to access the kernel log ring buffer.

#### PrivateNetwork=true

This basically removes network access for the service. It does so by hiding all network interfaces from the service and only giving it access to a private localhost interface. The localhost interface will not contain traffic from the "real" localhost interface.

#### ProtectKernelModules=true

Prevent the service from loading additional kernel modules.

#### PrivateUsers=true

Creates a private User/Group database for the service that only includes nobody and root. All files not owned by root will look like they are owned by nobody for the service. This options sometimes breaks services when the service needs to changes users for example.

### Reduce attack surface

These options disable exotic or old and unnecessary features.

#### RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6

Restricts the set of socket address families that the service can create/use. The linux kernel knows a lot of [sockets](https://man7.org/linux/man-pages/man2/socket.2.html) that most service don't need and I never heard of. AF_UNIX allows the use for local communications like syslog, AF_INET AF_INET6 allows "normal" network access over IPv4/IPv6. The only other family I ever needed to add was AF_NETLINK for sending mails with sendmail for some services.

#### NoNewNoNewPrivileges=true

This options prevents the service from ever getting more privileges than it had when it started. This is redundant since many of the other options also enable this option. But I like to add it explicity to be reminded that it exists.

#### SystemCallArchitectures=native

This options restricts the service to only be able to call native system calls. Most systems nowadays are x86-64 (64 bit) and this options disables all systems calls for other architectures like x86 (32 bit). Being able to use older system calls like those for 32 bit systems allows the circumvention of some of the here listed sandbox features.

You can also set this as a global option for all services running on the system. To do that, add SystemCallArchitectures=native to /etc/systemd/system.conf. That's what I'm doing and would recommend for everyone, but I included the option in the service files here for people who only copy and paste without reading the README.

#### MemoryDenyWriteExecute=true

Prevent the service from creating memory mappings that are writable and executable at the same time. This makes it harder for software exploits to change running code dynamically. This is the option I most often have to disable because it breaks some part of the programm.

#### RestrictSUIDSGID=true

Prevents the service from setting the SUID or SGID bits on files and folders. SUID and SGID can be used to elevate privileges and most programms don't need to set them.

#### RestrictRealtime=true

Prevent the service to enable realtime scheduling. This can be used clog up CPU and lead to a Denial-of-Service.

#### LockPersonality=true

 If set, locks down the personality system call so that the kernel execution domain may not be changed from the default or the personality selected with Personality= directive. I copied the explanation directly from the systemd documentaion, because this is the option I understand the least. It can improve security and sometimes breaks the service. I just turn it on and see if everything is still working.

### miscellaneous

#### RemoveIPC=true

Clean up leftover IPC objects after the service stops. This stops the service from using some system resources after it was stopped. Also something I only understand barely, but seems to be useful. When in doubt just remove it, but for the services I created here it doesn't cause any problems.
