#!/bin/ash

# Test DNS lookup for validation of network connectivity
# Usage: ./test_dns.sh

# Configuration
DNS_HOST="facebook.com"
DNS_SERVERS="1.1.1.1 9.9.9.9 208.67.222.222" # Cloudflare, QUAD9, and OpenDNS
DEBUG=0

# Function to test connectivity using multiple DNS servers (OpenWrt compatible)
test_connectivity() {
    local success_count=0
    local total_count=0

    # Test each DNS server
    for dns_server in $DNS_SERVERS; do
        total_count=$((total_count + 1))
        if nslookup "$DNS_HOST" "$dns_server" > /dev/null 2>&1; then
            success_count=$((success_count + 1))
            [ "$DEBUG" = "1" ] && echo "DEBUG: DNS lookup succeeded for $DNS_HOST using $dns_server"
        else
            [ "$DEBUG" = "1" ] && echo "DEBUG: DNS lookup failed for $DNS_HOST using $dns_server"
        fi
    done

    # Require at least 2 out of 3 servers to succeed
    local required_successes=$((total_count - 1))  # Allow 1 failure

    if [ $success_count -ge $required_successes ]; then
        [ "$DEBUG" = "1" ] && echo "DEBUG: Connectivity test PASSED ($success_count/$total_count servers reachable)"
        return 0  # Success
    else
        [ "$DEBUG" = "1" ] && echo "DEBUG: Connectivity test FAILED ($success_count/$total_count servers reachable)"
        return 1  # Failure
    fi
}



# Call the connectivity test and check results
if test_connectivity; then
    echo "Internet connectivity: OK"
    [ "$DEBUG" = "1" ] && echo "DEBUG: All connectivity checks passed"
else
    echo "Internet connectivity: FAILED"
    [ "$DEBUG" = "1" ] && echo "DEBUG: Connectivity test failed - check network connection"
fi
