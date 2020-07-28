# Minecraft systemd service

The minecraft service was a tricky one. At first it looked like I can create a service just like with any other java service I have created in the past, but that was not the case. When the minecraft java server receives a signal to stop it stops immediately without saving the world, thus you loose everything you have done since the last save.

## basics

Running a java programm with systemd is straight forward. Inside ExecStart= run java and then specify your jar file with the -jar argument. Here you can also set the amount of memory the server can use with -Xms and -Xmx (Adjust the amount to your needs). And we also disable the command promt that you could use if you would run the server inside your terminal, since we can't access it anyway when running under systemd. The line then looks like this:

`ExecStart=/usr/bin/java -Xms2G -Xmx2G -jar /srv/minecraft/server.jar --nogui`

There are also lots of discussions online about additional java options to make the server run faster, but I don't need them for my server so I don't know what can be useful.

When running a java process with systemd all logs inside jounald will look like they a send from a process named java. Which is correct, but can be annoying when you run multiple java services. To change the name we add `SyslogIdentifier=minecraft` to the service file.

## graceful shutdown

We need a way to gracefully shutdown the server. Fot that the minecraft server can [listen on an additional port](https://minecraft.gamepedia.com/Server.properties) speaking the [RCON](https://developer.valvesoftware.com/wiki/Source_RCON_Protocol) protocol. We can then send a signal over RCON to save the world and stop the server. To send the signal I use [mcrcon](https://github.com/Tiiffi/mcrcon).

A simple "stop" over RCON is enough to initiate a world save and then shutdown the server gracefully: `ExecStop=/path/to/mcrcon-dir/mcrcon "stop"`

For this to work we need to give mcron the ip, port and password of the rcon connection that. We do that by passing it three environment variables. Because one of the variables is a password, putting it inside the systemd service file would be unwise, since every user on the system can read them wich systemd cat. Instead we put them into a seperate file that only root can read and then include it via `EnvironmentFile=/srv/minecraft/environment`. The content of the file looks like this:

```
MCRCON_HOST=127.0.0.1
MCRCON_PORT=25575
MCRCON_PASS=password123
```

We now need one additional option to prevent systemd from killing the server bevor the shutdown is finished: `KillMode=none`. Without it, systemd would run the ExecStop= command, wait for it to exit successfully (which it does immediately, since mcrcon only sends a stop and then exits itself) and then kill all remaining processes. When setting KillMode to none it will not stop the server which is still in the Process of shuting down.

I'm not completly happy with this solution, since it can leave processes hanging which systemd will never kill, when the server would crash on shutdown. Currently I do not know a better way. If anyone has one please let me know :-)

## sandboxing

The minecraft server can deal with most of the sandboxing feature with the only exception being `MemoryDenyWriteExecute=true`. Since is a limitation of how java works and not the minecraft server itself.
