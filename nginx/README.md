# nginx systemd service

The default NGINX service is very basic. I'm surprised that a company this big has no resources to create a solid service file with good default sandboxing. Especially since NGINX is a widely deployed webserver and also reachable from the internet.

The service runs as root and uses `Type=forking`, but it also needs to, for what it wants to do; binding on ports less then 1024. The default nginx config starts the master process as root and then starts child processes as the user nginx which handle the actually webserver part. The job of the master process is to listen on port 80 and 443 (or other ports below 1024) which non root users can't normally do. It also reads SSL/TLS private keys which are often not readable by non root users. The second part I simply fix by putting my keys in a directory that can be read by the group acme (other names are available) and add this group the the nginx service with `SupplementaryGroups=acme`.

To start the service as the nginx user directly and stop it from forking, we need to stop it from running as a daemon in the nginx.conf like this:

```
daemon off;
pid /run/nginx/nginx.pid;
```

Since we switched from `Type=forking` to `Type=exec` we no longer need to watch for a PID file, so we don't need the `PIDFile=/var/run/nginx.pid` from the default service. But there is no option to disable the creation of the PID file in the nginx.conf so we at least change its path from the default /var/run/nginx.pid which is deprecated to the /run/nginx directory. To make sure this directory exists and is owned my nginx we can use `RuntimeDirectory=nginx` which creates a directory called nginx inside /run and adjust the permissions according to the User= option. Moving the PID file is not needed but it feels cleaner.

Since NGINX no longer starts as root, it can not create its own logs and cache directory. This can be solved by adding `LogsDirectory=nginx` and `CacheDirectory=nginx`. Just like RuntimeDirectory these options ensure that the directories /var/log/nginx and /var/cache/nginx exists and are owned by the user nginx.

Without running as root the service would not be able to listen on port 80 or 443. But we are in luck, there is a [capability](https://man7.org/linux/man-pages/man7/capabilities.7.html) for it to allow non root users to listen on ports below 1024. We add this capability with `AmbientCapabilities=CAP_NET_BIND_SERVICE`.

The ExecStart= command is the same as the default service. The ExecStop= command is no longer needed since we are not forking anymore and systemd can just stop the binary directly.

We also add a `Restart=on-failure` which most services should use, to recover of the service should ever crash. Which would be especially bad for a service that provides a public website.

We than use `TemporaryFileSystem=/:ro` to hide the entire filesystem tree from the service and also make it read only (This needs systemd 238 or higher, use `ProtectSystem=strict` and `ProtectHome=true` when using 237 or earlier). With `BindReadOnlyPaths=` we than add all directories and files to this now empty filesystem tree that nginx needs to have access to. The first two `BindReadOnlyPaths=` are defaults I add to every service. These are libraries and other files that most services need to have access to. Other important directories are automatically mounted by other systemd options like LogsDirectory, PrivateTmp, PrivateDevices, etc. The third line is the nginx binary itself. The forth line are the directories where my websites and ssl certificates are located and the /run/ directory where my php-fpm sockets are created.

And lastly we add all the other sandboxing features this service should have had from the start.
