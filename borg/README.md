# Borg backup systemd service

My borg backup service has gone through multiple version until I reached a state that I was happy with. And to be honest, I'm very pleased with what I came up with in the end. I had two goals that took me some time to achieve. First I did not want to run borg as root and second I wanted it to be modular so other software could "inject" itself to be also backed up when the borg service runs.

## basics

## not running as root

## modularity
