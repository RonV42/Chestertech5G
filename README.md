# Chestertech5G
Scripts and stuff for managing the Chestertech5G gateway

This script will set 5G parameters to lock the modem to the cell tower and set the mode to 5G and SA.  It will ping a configured address every minute and if the ping fails 3 times in a row it will start the reconnect process.  Since this is on a OpenWRT ROM this script will not persist a reset to factory and will have to be reloaded.

I was recomended to use the /overlay directory so I installed the script in:

/overlay/utility/monitor.sh

As for starting at boot there are multiple methods:

