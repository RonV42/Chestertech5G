# Chestertech5G
Scripts and stuff for managing the Chestertech5G gateway

This script will set 5G parameters to lock the modem to the cell tower and set the mode to 5G and SA.  It will ping a configured address every minute and if the ping fails 3 times in a row it will start the reconnect process.  Since this is on a OpenWRT ROM this script will not persist a reset to factory and will have to be reloaded.

I was recomended to use the /overlay directory so I installed the script in:

/overlay/utility/5g_monitor.sh

As for starting at boot there are multiple methods:

```
## Using rc_local

# Edit /etc/rc.local
vi /etc/rc.local

# Add your script before 'exit 0'
/path/to/your/script.sh &

exit 0
```


```
# Create init script
vi /etc/init.d/your-script-name

#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /path/to/your/script.sh
    procd_set_param respawn
    procd_close_instance
}

stop_service() {
    killall your-script-name 2>/dev/null
}


# Made your script executable
chmod +x /etc/init.d/your-script-name
/etc/init.d/your-script-name enable




```
