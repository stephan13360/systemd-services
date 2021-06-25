# php-fpm systemd service

Like the nginx service, the php-fpm default service that comes with Ubuntu is very basic, even though the [upstream service](https://github.com/php/php-src/blob/master/sapi/fpm/php-fpm.service.in) includes some sandboxing options.

Running php-fpm without root is possible but also restricts us to a single user when using multiple pool files. Since I use a couple of pool files, each with its own `listen.owner` and `listen.group`, I would have to create a seperate php.fpm service and seperate php.ini files for each pool and start php-fpm multiple times. Here I decided to go with convenience over the security, but it's up to you.

That doesn't meen we can't restrict the root user and take away most of his [capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html). Using `CapabilityBoundingSet=CAP_SETGID CAP_SETUID CAP_CHOWN` we take away all but three capabilities root would normally have. These capabilities are used to run the different pools as different users, and also to set the owner and group of the listen unix socket.

We don't need the `php-fpm-socket-helper` used in `ExecStartPost=`and `ExecStopPost=` to create the socket directory or socket. The systemd option `RuntimeDirectory=php` takes care of creating and deleting the needed directory and also setting the correct permissions.

We also add a `Restart=on-failure` which most services should use, to recover of the service should ever crash. Which would be especially bad for a service that provides a public website.

We than use `TemporaryFileSystem=/:ro` to hide the entire filesystem tree from the service and also make it read only (This needs systemd 238 or higher, use `ProtectSystem=strict` and `ProtectHome=true` when using 237 or earlier). With `BindReadOnlyPaths=` we than add all directories and files to this now empty filesystem tree that php-fpm needs to have access to. The first two `BindReadOnlyPaths=` are defaults I add to every service. These are libraries and other files that most services need to have access to. Other important directories are automatically mounted by other systemd options like LogsDirectory, PrivateTmp, PrivateDevices, etc. The third line is the php-fpm binary itself, the kill binary used to reload the service, the php libraries and /etc/passwd and /etc/group used by the master process to change users. Some php apps use additional binaries on the system to work, add them to the forth line. I use strace to run php-fpm to find out which binaries the php apps try to access and add these. The final `BindPaths=` adds the directory where my websites are located so that php-fpm can write to them.

And lastly we add all the other sandboxing features this service should have had from the start. The Options `PrivateUsers=true` and `MemoryDenyWriteExecute=true` can not be used because of the ability to switch users and php using JIT.
