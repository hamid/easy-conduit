#!/bin/bash
# Script version
SCRIPT_VERSION="1.1.4"

echo "Content-type: application/json"
echo ""

# Get conduit status
STATUS_OUTPUT=$(sudo /usr/local/bin/conduit status 2>&1)
STATUS_CLEAN=$(echo "$STATUS_OUTPUT" | sed 's/\x1b\[[0-9;]*m//g')

# Get conduit manager version (extract from banner or status output)
CONDUIT_VERSION=$(echo "$STATUS_CLEAN" | grep -i "CONDUIT MANAGER" | sed -n 's/.*MANAGER \(v[0-9.]*\).*/\1/p' | head -1)
[ -z "$CONDUIT_VERSION" ] && CONDUIT_VERSION="unknown"

# Parse current status
# Line 1: Status: Running (time)  |  Peak: X  |  Avg: X
# Line 2: Containers: X/X  Clients: X connected, X connecting
CONNECTED=$(echo "$STATUS_CLEAN" | awk 'NR==2 {for(i=1;i<=NF;i++) if($i=="connected,") print $(i-1)}')
CONNECTING=$(echo "$STATUS_CLEAN" | awk 'NR==2 {for(i=1;i<=NF;i++) if($i=="connecting") print $(i-1)}')
UPLOAD=$(echo "$STATUS_CLEAN" | awk '/Upload:/ {print $2}')
UPLOAD_UNIT=$(echo "$STATUS_CLEAN" | awk '/Upload:/ {print $3}')
DOWNLOAD=$(echo "$STATUS_CLEAN" | awk '/Download:/ {print $2}')
DOWNLOAD_UNIT=$(echo "$STATUS_CLEAN" | awk '/Download:/ {print $3}')
RUNNING_TIME=$(echo "$STATUS_CLEAN" | awk 'NR==1 {match($0, /\(([^)]+)\)/, arr); print arr[1]}')
PEAK=$(echo "$STATUS_CLEAN" | awk 'NR==1 {for(i=1;i<=NF;i++) if($i=="Peak:") print $(i+1)}')

# Set defaults for empty values
CONNECTED=${CONNECTED:-0}
CONNECTING=${CONNECTING:-0}
UPLOAD=${UPLOAD:-0}
UPLOAD_UNIT=${UPLOAD_UNIT:-MB}
DOWNLOAD=${DOWNLOAD:-0}
DOWNLOAD_UNIT=${DOWNLOAD_UNIT:-MB}
RUNNING_TIME=${RUNNING_TIME:-0s}
PEAK=${PEAK:-0}

# Get unique IPs count from cumulative_ips file
# Check if file exists first to avoid shell redirection errors
if [ -f /opt/conduit/traffic_stats/cumulative_ips ]; then
    UNIQUE_IPS=$(wc -l < /opt/conduit/traffic_stats/cumulative_ips 2>/dev/null || echo "0")
else
    UNIQUE_IPS=0
fi

# Get total IPs for percentage calculation
GEOIP_CACHE="/opt/conduit/traffic_stats/geoip_cache"
if [ -f "$GEOIP_CACHE" ]; then
    TOTAL_IPS=$(wc -l < "$GEOIP_CACHE" 2>/dev/null || echo "1")
else
    TOTAL_IPS=1
fi

# Count top countries from geoip_cache with percentages
TOP_COUNTRIES=$(awk -F'|' -v total="$TOTAL_IPS" '{
    country = $2;
    gsub(/^[ \t]+|[ \t]+$/, "", country);
    if (country == "Iran, Islamic Republic of") country = "Iran";
    count[country]++;
}
END {
    for (c in count) {
        percent = (count[c] / total) * 100;
        printf "%.1f %d %s\n", percent, count[c], c;
    }
}' "$GEOIP_CACHE" 2>/dev/null | sort -rn | head -10)

# Build JSON output
cat <<EOF
{
  "status": "running",
  "uptime": "$RUNNING_TIME",
  "clients": {
    "connected": $CONNECTED,
    "connecting": $CONNECTING,
    "total": $((CONNECTED + CONNECTING)),
    "unique_ips": $UNIQUE_IPS,
    "peak": $PEAK
  },
  "traffic": {
    "upload": "$UPLOAD $UPLOAD_UNIT",
    "download": "$DOWNLOAD $DOWNLOAD_UNIT"
  },
  "version": {
    "script": "$SCRIPT_VERSION",
    "conduit_manager": "$CONDUIT_VERSION"
  },
  "top_countries": [
EOF

# Add top countries as JSON array
echo "$TOP_COUNTRIES" | while IFS=' ' read -r percentage count country; do
    # Escape quotes in country names
    country_escaped=$(echo "$country" | sed 's/"/\\"/g')
    echo "    {\"country\": \"$country_escaped\", \"count\": $count, \"percentage\": $percentage},"
done | sed '$ s/,$//'

cat <<EOF

  ]
}
EOF
