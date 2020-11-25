# nginx systemd service

The default nginx service is very basic. I'm surprised that a company this big has no ressources to create a solid service file with good default sandboxing. Especially since nginx is a widely deployed webserver and also reachable from the internet.

The service runs as root and uses `Type=forking`, but it also needs to for what it wants to do. The default nginx config starts the master process as root and then starts child processes as the user nginx which handle the actually webserver part. The job of the master process is to listen on port 80 and 443 (or other ports below 1024) which non root users can't normally do. It also often needs to read SSL/TLS private keys which are often no readable by non root users. The second part I simply fix by putting my keys in a directory that can be read by the group acme (other names are available) and add this group the the nginx service with `SupplementaryGroups=acme`.

To start the service as the nginx user directly and stop it from forking, we need to stop it from running as a daemon in the nginx.conf like this:

```
daemon off;
pid /run/nginx/nginx.pid;
```

Since we switched from `Type=forking` to `Type=exec` we no longer need to watch for a PID file, so we don't need the `PIDFile=/var/run/nginx.pid` from the default service. But there is no option to disable the creation of the PID file in the nginx.conf so we at least change its path from the default /var/run/nginx.pid which is deprecated to the /run/nginx directory. To make sure this directory exists and is owned my nginx we can use `RuntimeDirectory=nginx` which creates a directoy called nginx inside /run and adjust the permissions according to the User= option. Moving the PID file is not needed but it feels cleaner.

Without running as root the service would not be able to listen on port 80 or 443. But we are in luck, there is a [capability](https://man7.org/linux/man-pages/man7/capabilities.7.html) for it to allow non root users to listen on ports below 1024. We add this capability with `AmbientCapabilities=CAP_NET_BIND_SERVICE`.

The ExecStart= comamnd is the same as the default service. The ExecStop= comamnd is no longer needed since we are not forking anymore and systemd can just stop the binary directly. The ExecReload= does no longer need to read a PID file for the process id and can instead use the systemd variable $MAINPID which systemd keeps track of itself.

We also add a `Restart=on-failure` which most services should use, to recover of the service should ever crash. Which would be especially bad for a service that provides a public website.

And lastly we add all the sandboxig features this service should have had from the start. We also add two directories to ReadWritePaths= to allow nginx to write logs and also use the proxy_cache and fastcgi_cache directives.
