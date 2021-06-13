# Borg backup systemd service

My borg backup service has gone through multiple version until I reached a state that I was happy with. And to be honest, I'm very pleased with what I came up with in the end. I had two goals that took me some time to achieve. First I did not want to run borg as root and second I wanted it to be modular so other software could "inject" itself to be also backed up when the borg service runs.

## basics

My backup works as follows: The borg backup script backups all specified directories and also the /backup directory. The /backup directory can be used by other software to write files they want to be backed up. The /backup directory is owned by the borg user and group. After the backup script finishes the systemd service touches the file /backup.last which can be used by monitoring software to check when the last successful backup was created.

## not running as root

This was the easier of my two goals. Borg needs root to access and read all files on the system, or to be more specific, all files you want to backup. Also services not running as root can't send mails via sendmail

As mentioned in the top level readme, you can give a service the [capability](https://man7.org/linux/man-pages/man7/capabilities.7.html) to open all directories and read all files in the system. The needed capability is CAP_DAC_READ_SEARCH and can be added to the service with `AmbientCapabilities=CAP_DAC_READ_SEARCH`.

To send mails the service needs to be able to create files in /var/spool/postfix/maildrop which can be achieved by adding the service to the postdrop group via `SupplementaryGroups=postdrop`. Because I also use `ProtectSystem=strict` I also need to add the path to ReadWritePaths. The service also needs to access netlink sockets which can be achieved by adding it to `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK`.

## modularity

I use ansible to configure my servers and I don't want to edit my borg backup role or the backup script each time I add a new role / software that I want to backup. When my service was still running as root I could do this by using run-parts in my main backup script and then each role / software could create a backup file in some directory and it would be executed. Now that the script no longer has root privileges the scripts started by run-parts would often be missing privileges they need. For example to backup postgresql databases you need to run pg_dump as the postgres user.

My solution is to run the additional backup scripts via their own service files which include all the privileges needed. These service files are injected into the main backup service through a systemd conf files located in /etc/systemd/system/backup.service.d/. The file contains one line in the `[Service]` section: `ExecStartPre=!/bin/systemctl start backup-postgresql.service`. Normally this command would be executed as the user borg, because of the User=borg and fail, since only root can use systemctl start. The ! at the start of the command can be used to execute this single command as root instead without running the wholes service as root. This injection via /etc/systemd/system/backup.service.d/ can be done by any number of services. All ExecStartPre= command have to exit successfully or the backup service as a whole fails. I could prefix the ExecStartPre= comamnds with a - (minus) but I prefer the whole service to fail because I monitor successfully backups via the /backup.last file.

The additional systemd services need to be able to write to /backup which can be achieved by adding the group borg to the service with `SupplementaryGroups=borg`.

## sandboxing

Not all sandboxing options can be used. ProtectHome=true prevents the backup of the user home directories, PrivateUsers=true prevents borg from preserving the correct file permissions, LockPersonality=true prevents sending mails.

The directories /home/borg/.cache/borg and /home/borg/.config/borg need to be added to ReadWritePaths= to allow borg to work.
