# Teamspeak service

Teamspeak is a great example of a service that comes with a bash start script, but no systemd service and where most people online just put the bash script inside ExecStart= like this:

```
Type=forking
WorkingDirectory=/home/ts3/teamspeak3-server_linux_amd64/
ExecStart=/home/ts3/teamspeak3-server_linux_amd64/ts3server_startscript.sh start
ExecStop=/home/ts3/teamspeak3-server_linux_amd64/ts3server_startscript.sh stop
PIDFile=/home/ts3/teamspeak3-server_linux_amd64/ts3server.pid
```

The script is 128 lines long and does nothing we need to copy to our systemd service. It creates and deletes a PID File, which wie dont need when systemd manages the binary directly. It checks if the binary is executable, which systemd also does itself and logs a status=203/EXEC when it is not executable.

On line 5 we see the binary that the scripts executes: `BINARYNAME=ts3server`

On line 44 we see the command that calls the binary: `"./${BINARYNAME}" "${@}" "daemon=1" "pid_file=$PID_FILE"`

`"${@}"` passes all arguments that the script is run with to the binary, `"daemon=1"` runs teamspeak as a deamon with is just another fork we don't need or want and `"pid_file=$PID_FILE"` specifies the PID file we don't need.

So reading the scripts tells us we just need to run the binary ts3server directly and we are done. The scripts also opens the teamspeak folder befor executing, so we will also do this with WorkingDirectory=.

When running the Teamspeak server you need to accept a license to continue. You can do this non interactively in different ways, I use the environment variable and add `Environment=TS3SERVER_LICENSE=accept` to the service.

I then slap every sandbox feature on it, allow it to write to its own sqlite database with `ReadWritePaths=/srv/teamspeak/teamspeak3-server_linux_amd64/` and it works.

By getting rid of Type=forking and the bash start script we don't just get more reliable tracking we can also now see the log output of the binary which it writes to stdout inside journald or when we run systemd status.
