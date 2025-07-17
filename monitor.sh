#!/bin/ash

# Enhanced 5G Modem Monitor Script
# Monitors cell lock status and network connectivity, reconnects when needed
# Usage: ./5g_monitor.sh

# Configuration
SERIAL_DEVICE="/dev/ttyUSB3"
LOG_FILE="/var/log/5g_monitor.log"
PING_HOST="8.8.8.8"
PING_TIMEOUT=5
CHECK_INTERVAL=60  # seconds between checks
CONNECTIVITY_FAILURES_THRESHOLD=3
MAX_RECONNECT_ATTEMPTS=3
DEBUG=0

# Network Mode Configuration
# 1 = GSM only, 3 = LTE only, 9 = LTE + GSM, 11 = 5G + LTE + GSM, 12 = 5G only
#NETWORK_MODE="12"  # Force 5G SA only - change to 11 for 5G + LTE fallback

# Network Mode Pref for Quectel
# AUTO = autonmatic, LTE = LTE Only, NR5G = 5G Only, 
# LTE:NR5G = LTE and 5G, GSM = 2G only, WCDMA = 3G only
# GSM:WCDMA:LTE:NR5G = all modes
NETWORK_MODE="NR5G"  # Force 5G

# 5G SA Mode Enable
# 0 = enable both SA and NSA, 1 = disable SA, 2 = disable NSA
NR5G_MODE="2"

# 5G Lock Parameters - **Customize These Values**
FIVEG_ARFCN="126270"
FIVEG_PCI="622"
FIVEG_SCS="15"
FIVEG_BAND="71"


# Build Cell Lock Command
FIVEG_CELL_LOCK_COMMAND=$(echo -ne "AT+QNWLOCK=\"common/5g\",$FIVEG_PCI,$FIVEG_ARFCN,$FIVEG_SCS,$FIVEG_BAND\r")

# Counters
connectivity_failures=0
script_start_time=$(date)


# Logging function
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}


# Function to send AT command and get response
send_at_command() {
    local command="$1"
    local timeout="${2:-1000}"
    local response=$(echo -ne "$command\r" | microcom -t "$timeout" "$SERIAL_DEVICE" 2>/dev/null)
    echo "$response"
}

# Function to check modem response
check_modem_responsive() {
    local response=$(send_at_command "AT" 500)
    if echo "$response" | grep -q "OK"; then
        return 0
    else
        return 1
    fi
}

# Function to get signal quality
get_signal_quality() {
    local response=$(send_at_command "AT+CSQ")
    local signal=$(echo "$response" | grep "+CSQ:" | cut -d':' -f2 | cut -d',' -f1 | tr -d ' ')
    echo "$signal"
}

# Function to get network registration status
get_network_status() {
    local response=$(send_at_command "AT+CREG?")
    local status=$(echo "$response" | grep "+CREG:" | cut -d',' -f2 | tr -d ' ')
    echo "$status"
}

# Function to check data connection status
check_data_connection() {
    local response=$(send_at_command "AT+CGACT?")
    echo "$response" | grep "+CGACT:" | grep ",1" > /dev/null
    local result=$?
    return $result
}

# Function to set network mode to 5G
set_network_mode() {
    local response=$(send_at_command "AT+QNWPREFCFG=\"mode_pref\",$NETWORK_MODE")
    
    if echo "$response" | grep -q "OK"; then
        return 0
    else
        log_message "Failed to set network mode: $response"
        return 1
    fi
}

# Function to set NR5G Mode
set_nr5g_mode() {
    local response=$(send_at_command "AT+QNWPREFCFG=\"nr5g_disable_mode\",$NR5G_MODE")

    if echo "$response" | grep -q "OK"; then
        return 0
    else
        log_message "Failed to set NR5G mode: $response"
        return 1
    fi
}

# Function to check current network mode
get_network_mode() {
    local response=$(send_at_command "AT+QNWPREFCFG=\"mode_pref\"")
    local mode=$(echo "$response" | grep "mode_pref" | cut -d',' -f2 | tr -d ' ')
    echo "$mode"
}

# Function to get current network technology
get_network_technology() {
    local response=$(send_at_command "AT+QNWINFO")
#    local tech=$(echo "$response" | grep "+QNWINFO:" | cut -d',' -f1 | cut -d'"' -f2)
#    local tech=$(echo "$response" | grep "+QNWINFO:" | cut -d',' -f1 | cut -d':' -f2 | tr -d '" '
    local tech=$(echo "$response" | grep "+QNWINFO:" | cut -d',' -f1 | cut -d':' -f2 | sed -e 's/^ *//' -e 's/ *$//' -e 's/^"//' -e 's/"$//')
    echo "$tech"
}

# Function to test connectivity
test_connectivity() {
    if ping -c 1 -W "$PING_TIMEOUT" "$PING_HOST" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to set cell lock
set_cell_lock() {
    log_message "Setting 5G Cell Lock Parameters (PCI:$FIVEG_PCI, ARFCN:$FIVEG_ARFCN, Band:$FIVEG_BAND)..."
    local response=$(send_at_command "$FIVEG_CELL_LOCK_COMMAND")
    
    if echo "$response" | grep -q "OK"; then
        log_message "Cell lock command sent successfully"
        return 0
    else
        log_message "Cell lock command failed: $response"
        return 1
    fi
}

# Function to get current PCC ARFCN
get_pcc_arfcn() {
    local response=$(send_at_command "AT+QCAINFO")
    local arfcn=$(echo "$response" | grep "PCC" | cut -d',' -f2 | tr -d ' ')
    echo "$arfcn"
}

# Function to reset modem connection
reset_modem_connection() {
    log_message "Resetting modem connection..."
    
    # Set network mode to 5G before reconnection
    set_network_mode
    sleep 2
    set_nr5g_mode
    sleep 2


    # Deactivate PDP context
    send_at_command "AT+CGACT=0,1" > /dev/null
    sleep 2
    
    # Reset network registration
    send_at_command "AT+COPS=2" > /dev/null
    sleep 5
    
    # Ensure 5G mode is still set after network reset
    set_network_mode
    sleep 2
    set_nr5g_mode
    sleep 2
    
    # Re-register to network with automatic operator selection
    send_at_command "AT+COPS=0" > /dev/null
    sleep 15  # Give more time for 5G registration
    
    # Verify network technology after registration
    local tech=$(get_network_technology)
    log_message "Connected to network technology: $tech"
    
    # Reactivate PDP context
    send_at_command "AT+CGACT=1,1" > /dev/null
    sleep 5
}

# Function to perform full reconnection sequence
perform_reconnection() {
    local attempt=1
    
    while [ $attempt -le $MAX_RECONNECT_ATTEMPTS ]; do
        log_message "Reconnection attempt $attempt of $MAX_RECONNECT_ATTEMPTS"
        
        # Check if modem is responsive
        if ! check_modem_responsive; then
            log_message "Modem not responsive, skipping this attempt"
            sleep 30
            attempt=$((attempt + 1))
            continue
        fi
        
        # Reset connection
        reset_modem_connection
        
        # Reapply cell lock
        set_cell_lock
        
        # Wait for network registration
        sleep 30
        
        # Test connectivity
        if test_connectivity; then
            log_message "Reconnection successful on attempt $attempt"
            connectivity_failures=0
            return 0
        fi
        
        attempt=$((attempt + 1))
        sleep 30
    done
    
    log_message "All reconnection attempts failed"
    return 1
}

# Function to check cell lock status
check_cell_lock() {
    local current_arfcn=$(get_pcc_arfcn)
    
    if [ -z "$current_arfcn" ]; then
        log_message "Unable to get current PCC ARFCN"
        return 1
    fi
    
    
    if [ "$FIVEG_ARFCN" = "$current_arfcn" ]; then
        return 0
    else
        log_message "Cell lock mismatch - Expected: $FIVEG_ARFCN, Current: $current_arfcn"
        return 1
    fi
}

# Function to display status
display_status() {
    local signal_quality=$(get_signal_quality)
    local network_status=$(get_network_status)
    local current_arfcn=$(get_pcc_arfcn)
    local network_tech=$(get_network_technology)
    local network_mode=$(get_network_mode)
    local connectivity_status="FAIL"
    
    if test_connectivity; then
        connectivity_status="OK"
    fi
    
    log_message "Status - Signal:$signal_quality, Network:$network_status, ARFCN:$current_arfcn, Tech:$network_tech, Mode:$network_mode, Connectivity:$connectivity_status, Failures:$connectivity_failures"
}

# Trap function for graceful shutdown
cleanup() {
    log_message "Script terminated by signal"
    exit 0
}

# Set up signal traps
trap cleanup INT TERM

# Do some debugging on values from the status variables

echo "Signal Quality: $(get_signal_quality)"
echo "Network Status: $(get_network_status)"
echo "  Current AFRN: $(get_pcc_arfcn)"
echo " Expected AFRN: $FIVEG_ARFCN"
echo "  Network Tech: $(get_network_technology)"
echo "  Network Mode: $(get_network_mode)"


# Pause before entering monitor

echo "Press Enter to continue..."
read

##########################################
# Main script starts here                #
##########################################

log_message "5G Modem Monitor Script Started"
log_message "Target Cell - PCI:$FIVEG_PCI, ARFCN:$FIVEG_ARFCN, Band:$FIVEG_BAND"

# Initial setup
if ! check_modem_responsive; then
    log_message "ERROR: Modem not responsive at startup"
    exit 1
fi

# Set initial network mode to 5G SA
log_message "Setting initial network mode to NR5G..."
set_network_mode

log_message "Setting intial NR5G mode to SA..."
set_nr5g_mode

# Set initial cell lock
set_cell_lock
sleep 30

# Verify we're connected to 5G
initial_tech=$(get_network_technology)
log_message "Initial network technology: $initial_tech"

log_message "Starting monitoring loop..."


# Main monitoring loop
while true; do
    
    # Display current status
    display_status
    
    # Check modem responsiveness
    if ! check_modem_responsive; then
        log_message "WARNING: Modem not responsive"
        sleep "$CHECK_INTERVAL"
        continue
    fi
    
    # Check cell lock status
    if ! check_cell_lock; then
        log_message "Cell lock lost, reapplying..."

        set_cell_lock
        sleep 30
    fi
    
    # Check if we're still on 5G
    current_tech=$(get_network_technology)
    if [ "$current_tech" != "5G" ] && [ "$current_tech" != "NR5G" ] && [ "$current_tech" != "FDD NR5G" ]; then
        log_message "Network technology changed to $current_tech, forcing back to 5G..."
        set_network_mode
        sleep 10
        set_nr5g_mode
        sleep 10
    fi
    
    # Check connectivity
    if ! test_connectivity; then
        connectivity_failures=$((connectivity_failures + 1))
        log_message "Connectivity test failed (failure $connectivity_failures of $CONNECTIVITY_FAILURES_THRESHOLD)"
        
        if [ $connectivity_failures -ge $CONNECTIVITY_FAILURES_THRESHOLD ]; then
            log_message "Connectivity failure threshold reached, initiating reconnection..."
            perform_reconnection
        fi
    else
        if [ $connectivity_failures -gt 0 ]; then
            log_message "Connectivity restored"
            connectivity_failures=0
        fi
    fi
    
    sleep "$CHECK_INTERVAL"
done
