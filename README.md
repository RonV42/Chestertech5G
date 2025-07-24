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
