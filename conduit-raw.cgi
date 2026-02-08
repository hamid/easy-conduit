#!/bin/bash
echo "Content-type: application/json"
echo ""

# Get conduit status
STATUS_OUTPUT=$(sudo /usr/local/bin/conduit status 2>&1)
STATUS_CLEAN=$(echo "$STATUS_OUTPUT" | sed 's/\x1b\[[0-9;]*m//g')

# Parse current status
CONNECTED=$(echo "$STATUS_CLEAN" | awk 'NR==3 {print $4}')
CONNECTING=$(echo "$STATUS_CLEAN" | awk 'NR==3 {print $6}')
UPLOAD=$(echo "$STATUS_CLEAN" | awk 'NR==6 {print $2}')
UPLOAD_UNIT=$(echo "$STATUS_CLEAN" | awk 'NR==6 {print $3}')
DOWNLOAD=$(echo "$STATUS_CLEAN" | awk 'NR==7 {print $2}')
DOWNLOAD_UNIT=$(echo "$STATUS_CLEAN" | awk 'NR==7 {print $3}')
RUNNING_TIME=$(echo "$STATUS_CLEAN" | awk 'NR==2 {match($0, /\(([^)]+)\)/, arr); print arr[1]}')
PEAK=$(echo "$STATUS_CLEAN" | awk 'NR==2 {print $6}')

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
UNIQUE_IPS=$(wc -l < /opt/conduit/traffic_stats/cumulative_ips 2>/dev/null || echo "0")

# Count top countries from geoip_cache
TOP_COUNTRIES=$(awk -F'|' '{
    country = $2;
    gsub(/^[ \t]+|[ \t]+$/, "", country);
    if (country == "Iran, Islamic Republic of") country = "Iran";
    count[country]++;
}
END {
    for (c in count) {
        print count[c], c;
    }
}' /opt/conduit/traffic_stats/geoip_cache 2>/dev/null | sort -rn | head -10)

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
  "top_countries": [
EOF

# Add top countries as JSON array
echo "$TOP_COUNTRIES" | while IFS=' ' read -r count country; do
    # Escape quotes in country names
    country_escaped=$(echo "$country" | sed 's/"/\\"/g')
    echo "    {\"country\": \"$country_escaped\", \"count\": $count},"
done | sed '$ s/,$//'

cat <<EOF

  ]
}
EOF
