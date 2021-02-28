# Plex Media Server service sandboxing

The systemd service for the plex media service is fine, it just lacks some sandboxing features. Adding additional options to a systemd service can be easily achieved without modifying the original service, which would prevent an apt-get upgrade to update the service to a new version.

To add additional options to the /etc/systemd/system/plexmediaserver.service we create the /etc/systemd/system/plexmediaserver.service.d/ directory and then put a .conf file within it. These conf files have the exact same syntax as the service files but only include stuff you want to add or overwrite from the original service.

For the plex media server I added most of the sandoxing features. The exceptions are `PrivateDevices=true` and `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6`. The first still allows the service to work but prevents it from being upgraded with apt-get for whatever reason. The second one just stops it from working entirely, I'm not sure why or what other socket it tries to use.
