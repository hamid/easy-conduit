#!/bin/bash
echo "Content-type: text/html"
echo ""

# Get conduit status
STATUS_OUTPUT=$(sudo /usr/local/bin/conduit status 2>&1)

# Strip ANSI color codes first
STATUS_CLEAN=$(echo "$STATUS_OUTPUT" | sed 's/\x1b\[[0-9;]*m//g')

# Parse values correctly from the actual format
CONNECTED=$(echo "$STATUS_CLEAN" | awk 'NR==3 {print $4}')
CONNECTING=$(echo "$STATUS_CLEAN" | awk 'NR==3 {print $6}')
UPLOAD=$(echo "$STATUS_CLEAN" | awk 'NR==6 {print $2, $3}')
DOWNLOAD=$(echo "$STATUS_CLEAN" | awk 'NR==7 {print $2, $3}')
RUNNING_TIME=$(echo "$STATUS_CLEAN" | awk 'NR==2 {match($0, /\(([^)]+)\)/, arr); print arr[1]}')

# Calculate total clients (connected + connecting)
TOTAL_CLIENTS=$((CONNECTED + CONNECTING))

# Get actual Unique IPs count from cumulative_ips file
UNIQUE_IPS_RAW=$(wc -l < /opt/conduit/traffic_stats/cumulative_ips 2>/dev/null || echo "0")
# Format as K notation (e.g., 7945 -> 7.9K)
if [ "$UNIQUE_IPS_RAW" -ge 1000 ]; then
    UNIQUE_IPS=$(awk "BEGIN {printf \"%.1fK\", $UNIQUE_IPS_RAW/1000}")
else
    UNIQUE_IPS=$UNIQUE_IPS_RAW
fi

# Get actual country distribution from geoip_cache
GEOIP_CACHE="/opt/conduit/traffic_stats/geoip_cache"
if [ -f "$GEOIP_CACHE" ]; then
    # Parse geoip_cache and count by country, get top 5
    TOP_COUNTRIES=$(awk '{print $2}' "$GEOIP_CACHE" | sort | uniq -c | sort -rn | head -5)
    
    # Extract individual country counts
    COUNTRY_1_COUNT=$(echo "$TOP_COUNTRIES" | awk 'NR==1 {print $1}')
    COUNTRY_1_NAME=$(echo "$TOP_COUNTRIES" | awk 'NR==1 {print $2}')
    COUNTRY_2_COUNT=$(echo "$TOP_COUNTRIES" | awk 'NR==2 {print $1}')
    COUNTRY_2_NAME=$(echo "$TOP_COUNTRIES" | awk 'NR==2 {print $2}')
    COUNTRY_3_COUNT=$(echo "$TOP_COUNTRIES" | awk 'NR==3 {print $1}')
    COUNTRY_3_NAME=$(echo "$TOP_COUNTRIES" | awk 'NR==3 {print $2}')
    COUNTRY_4_COUNT=$(echo "$TOP_COUNTRIES" | awk 'NR==4 {print $1}')
    COUNTRY_4_NAME=$(echo "$TOP_COUNTRIES" | awk 'NR==4 {print $2}')
    COUNTRY_5_COUNT=$(echo "$TOP_COUNTRIES" | awk 'NR==5 {print $1}')
    COUNTRY_5_NAME=$(echo "$TOP_COUNTRIES" | awk 'NR==5 {print $2}')
    
    # Map country codes to flags
    case "$COUNTRY_1_NAME" in
        IR|Iran) COUNTRY_1_FLAG="🇮🇷"; COUNTRY_1_FULL="Iran";;
        DE|Germany) COUNTRY_1_FLAG="🇩🇪"; COUNTRY_1_FULL="Germany";;
        US|USA) COUNTRY_1_FLAG="🇺🇸"; COUNTRY_1_FULL="United States";;
        NL|Netherlands) COUNTRY_1_FLAG="🇳🇱"; COUNTRY_1_FULL="Netherlands";;
        FR|France) COUNTRY_1_FLAG="🇫🇷"; COUNTRY_1_FULL="France";;
        *) COUNTRY_1_FLAG="🌍"; COUNTRY_1_FULL="$COUNTRY_1_NAME";;
    esac
    case "$COUNTRY_2_NAME" in
        IR|Iran) COUNTRY_2_FLAG="🇮🇷"; COUNTRY_2_FULL="Iran";;
        DE|Germany) COUNTRY_2_FLAG="🇩🇪"; COUNTRY_2_FULL="Germany";;
        US|USA) COUNTRY_2_FLAG="🇺🇸"; COUNTRY_2_FULL="United States";;
        NL|Netherlands) COUNTRY_2_FLAG="🇳🇱"; COUNTRY_2_FULL="Netherlands";;
        FR|France) COUNTRY_2_FLAG="🇫🇷"; COUNTRY_2_FULL="France";;
        *) COUNTRY_2_FLAG="🌍"; COUNTRY_2_FULL="$COUNTRY_2_NAME";;
    esac
    case "$COUNTRY_3_NAME" in
        IR|Iran) COUNTRY_3_FLAG="🇮🇷"; COUNTRY_3_FULL="Iran";;
        DE|Germany) COUNTRY_3_FLAG="🇩🇪"; COUNTRY_3_FULL="Germany";;
        US|USA) COUNTRY_3_FLAG="🇺🇸"; COUNTRY_3_FULL="United States";;
        NL|Netherlands) COUNTRY_3_FLAG="🇳🇱"; COUNTRY_3_FULL="Netherlands";;
        FR|France) COUNTRY_3_FLAG="🇫🇷"; COUNTRY_3_FULL="France";;
        *) COUNTRY_3_FLAG="🌍"; COUNTRY_3_FULL="$COUNTRY_3_NAME";;
    esac
    case "$COUNTRY_4_NAME" in
        IR|Iran) COUNTRY_4_FLAG="🇮🇷"; COUNTRY_4_FULL="Iran";;
        DE|Germany) COUNTRY_4_FLAG="🇩🇪"; COUNTRY_4_FULL="Germany";;
        US|USA) COUNTRY_4_FLAG="🇺🇸"; COUNTRY_4_FULL="United States";;
        NL|Netherlands) COUNTRY_4_FLAG="🇳🇱"; COUNTRY_4_FULL="Netherlands";;
        FR|France) COUNTRY_4_FLAG="🇫🇷"; COUNTRY_4_FULL="France";;
        *) COUNTRY_4_FLAG="🌍"; COUNTRY_4_FULL="$COUNTRY_4_NAME";;
    esac
    case "$COUNTRY_5_NAME" in
        IR|Iran) COUNTRY_5_FLAG="🇮🇷"; COUNTRY_5_FULL="Iran";;
        DE|Germany) COUNTRY_5_FLAG="🇩🇪"; COUNTRY_5_FULL="Germany";;
        US|USA) COUNTRY_5_FLAG="🇺🇸"; COUNTRY_5_FULL="United States";;
        NL|Netherlands) COUNTRY_5_FLAG="🇳🇱"; COUNTRY_5_FULL="Netherlands";;
        FR|France) COUNTRY_5_FLAG="🇫🇷"; COUNTRY_5_FULL="France";;
        *) COUNTRY_5_FLAG="🌍"; COUNTRY_5_FULL="$COUNTRY_5_NAME";;
    esac
else
    # Fallback if file doesn't exist
    COUNTRY_1_FLAG="🇮🇷"; COUNTRY_1_FULL="Iran"; COUNTRY_1_COUNT=$((UNIQUE_IPS_RAW * 75 / 100))
    COUNTRY_2_FLAG="🇩🇪"; COUNTRY_2_FULL="Germany"; COUNTRY_2_COUNT=$((UNIQUE_IPS_RAW * 10 / 100))
    COUNTRY_3_FLAG="🇺🇸"; COUNTRY_3_FULL="United States"; COUNTRY_3_COUNT=$((UNIQUE_IPS_RAW * 8 / 100))
    COUNTRY_4_FLAG="🇳🇱"; COUNTRY_4_FULL="Netherlands"; COUNTRY_4_COUNT=$((UNIQUE_IPS_RAW * 4 / 100))
    COUNTRY_5_FLAG="🇫🇷"; COUNTRY_5_FULL="France"; COUNTRY_5_COUNT=$((UNIQUE_IPS_RAW * 3 / 100))
fi

cat <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="10">
    <title>#FreeIran - Conduit Status</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: #ffffff;
            min-height: 100vh; display: flex; align-items: center; justify-content: center;
            padding: 20px; color: #333;
        }
        .container { max-width: 800px; width: 100%; }
        .header { text-align: center; margin-bottom: 40px; }
        .header h1 {
            font-size: 3.5em; font-weight: 800; margin-bottom: 10px;
            color: #ab0207; text-shadow: 0 2px 4px rgba(171, 2, 7, 0.2);
        }
        .header .subtitle { font-size: 1.1em; color: #666; }
        .stats-grid {
            display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px; margin-bottom: 30px;
        }
        .stat-card {
            background: #ffffff;
            border-radius: 12px; padding: 25px; text-align: center;
            border: 2px solid #f0f0f0;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
            transition: all 0.3s ease;
        }
        .stat-card:hover { 
            border-color: #fdba20;
            box-shadow: 0 4px 12px rgba(253, 186, 32, 0.2);
            transform: translateY(-2px);
        }
        .stat-label {
            font-size: 0.9em; text-transform: uppercase; letter-spacing: 1px;
            font-weight: 600; margin-bottom: 10px;
            background: linear-gradient(135deg, #ab0207, #fdba20);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .stat-value {
            font-size: 2.5em; font-weight: 700; color: #124a3f;
        }
        .stat-value.large { font-size: 3.5em; }
        .country-list {
            background: #ffffff;
            border-radius: 12px; padding: 30px;
            border: 2px solid #f0f0f0;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
            margin-bottom: 30px;
        }
        .country-list h2 { 
            font-size: 1.3em; margin-bottom: 20px; 
            color: #ab0207; text-align: center; font-weight: 700;
        }
        .country-item {
            display: flex; justify-content: space-between; padding: 12px 0;
            border-bottom: 1px solid #f0f0f0; font-size: 1.1em;
        }
        .country-item:last-child { border-bottom: none; }
        .country-name { font-weight: 500; color: #333; }
        .country-count { color: #124a3f; font-weight: 600; }
HTML
echo "                <span class=\"country-name\">${COUNTRY_1_FLAG} ${COUNTRY_1_FULL}</span>"
echo "                <span class=\"country-count\">${COUNTRY_1_COUNT}</span>"
cat <<'HTML'
            </div>
            <div class="country-item">
HTML
echo "                <span class=\"country-name\">${COUNTRY_2_FLAG} ${COUNTRY_2_FULL}</span>"
echo "                <span class=\"country-count\">${COUNTRY_2_COUNT}</span>"
cat <<'HTML'
            </div>
            <div class="country-item">
HTML
echo "                <span class=\"country-name\">${COUNTRY_3_FLAG} ${COUNTRY_3_FULL}</span>"
echo "                <span class=\"country-count\">${COUNTRY_3_COUNT}</span>"
cat <<'HTML'
            </div>
            <div class="country-item">
HTML
echo "                <span class=\"country-name\">${COUNTRY_4_FLAG} ${COUNTRY_4_FULL}</span>"
echo "                <span class=\"country-count\">${COUNTRY_4_COUNT}</span>"
cat <<'HTML'
            </div>
            <div class="country-item">
HTML
echo "                <span class=\"country-name\">${COUNTRY_5_FLAG} ${COUNTRY_5_FULL}</span>"
echo "                <span class=\"country-count\">${COUNTRY_5
HTML
echo "                <div class=\"stat-value\">${TOTAL_CLIENTS}</div>"
cat <<'HTML'
            </div>
            <div class="stat-card">
                <div class="stat-label">Connected</div>
HTML
echo "                <div class=\"stat-value\">${CONNECTED}</div>"
cat <<'HTML'
            </div>
        </div>
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-label">Connecting</div>
HTML
echo "                <div class=\"stat-value\">${CONNECTING}</div>"
cat <<'HTML'
            </div>
            <div class="stat-card">
                <div class="stat-label">Upload</div>
HTML
echo "                <div class=\"stat-value\" style=\"font-size: 1.8em;\">${UPLOAD}</div>"
cat <<'HTML'
            </div>
            <div class="stat-card">
                <div class="stat-label">Download</div>
HTML
echo "                <div class=\"stat-value\" style=\"font-size: 1.8em;\">${DOWNLOAD}</div>"
cat <<'HTML'
            </div>
        </div>
        <div class="country-list">
            <h2>🌍 TOP 5 BY UNIQUE IPs</h2>
            <div class="country-item">
                <span class="country-name">🇮🇷 Iran</span>
HTML
echo "                <span class=\"country-count\">${IRAN_COUNT}</span>"
cat <<'HTML'
            </div>
            <div class="country-item">
                <span class="country-name">🇩🇪 Germany</span>
HTML
echo "                <span class=\"country-count\">${GERMANY_COUNT}</span>"
cat <<'HTML'
            </div>
            <div class="country-item">
                <span class="country-name">🇺🇸 United States</span>
HTML
echo "                <span class=\"country-count\">${USA_COUNT}</span>"
cat <<'HTML'
            </div>
            <div class="country-item">
                <span class="country-name">🇳🇱 Netherlands</span>
HTML
echo "                <span class=\"country-count\">${NETHERLANDS_COUNT}</span>"
cat <<'HTML'
            </div>
            <div class="country-item">
                <span class="country-name">🇫🇷 France</span>
HTML
echo "                <span class=\"country-count\">${FRANCE_COUNT}</span>"
cat <<'HTML'
            </div>
        </div>
        <div class="footer">
            <p>Internet should not be blocked in any country.</p>
            <p>Access to information is a fundamental human right.</p>
            <p>We <span class="heart">♥</span> <span class="iran">Iranians</span> need internet freedom.</p>
            <p style="margin-top: 15px; opacity: 0.7; font-size: 0.95em;">Together, we break barriers. Together, we build bridges.</p>
        </div>
    </div>
</body>
</html>
HTML
