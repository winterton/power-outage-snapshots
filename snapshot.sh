#!/usr/bin/env bash
# Pull a full snapshot of DTE's OutageAreas layer as GeoJSON.
# Avoids `where` (DTE's WAF 403s it) by filtering on the layer's full extent instead.
set -euo pipefail
BASE="https://outagemap.serv.dteenergy.com/arcgis/rest/services/OMP/OutageLocations/MapServer"
EXTENT="-9391354,5134197,-9174147,5476370"
UA="dte-outage-snapshots (github actions)"
ts=$(date -u +%Y-%m-%dT%H%M%SZ)
day=$(date -u +%Y/%m/%d)
mkdir -p "data/$day"
out="data/$day/outages-$ts.geojson"
tmp=$(mktemp -d)

offset=0
while :; do
  f="$tmp/page-$offset.json"
  curl -sS --fail --retry 4 --retry-delay 5 -A "$UA" -o "$f" \
    "$BASE/2/query?geometry=$EXTENT&geometryType=esriGeometryEnvelope&inSR=102100&spatialRel=esriSpatialRelIntersects&outFields=*&outSR=4326&returnGeometry=true&f=geojson&resultOffset=$offset&resultRecordCount=1000"
  jq -e '.features' "$f" >/dev/null || { echo "bad page at offset $offset"; cat "$f" | head -c 500; exit 1; }
  n=$(jq '.features|length' "$f")
  more=$(jq -r '.exceededTransferLimit // false' "$f")
  offset=$((offset+n))
  [[ "$more" == "true" && $n -gt 0 ]] || break
done

jq -s '{type:"FeatureCollection", snapshot_utc:"'"$ts"'", features: map(.features[])}' "$tmp"/page-*.json > "$out"
gzip -9 "$out"
count=$(zcat "$out.gz" | jq '.features|length')
echo "$ts $count features -> $out.gz"

# storm-mode table, small enough to keep uncompressed alongside
curl -sS --fail -A "$UA" -o "data/$day/storm-modes-$ts.json" \
  "$BASE/3/query?objectIds=$(seq -s, 1 60)&outFields=*&returnGeometry=false&f=json" || true

# DTE's customer-facing map (Kubra): official deduplicated totals + per-ZIP counts. Two small files.
K="https://kubra.io"; INST="4fbb3ad3-e01d-4d71-9575-d453769c1171"; VIEW="8ed2824a-bd92-474e-a7c4-848b812b7f9b"
if state=$(curl -sS --fail -A "$UA" "$K/stormcenter/api/v1/stormcenters/$INST/views/$VIEW/currentState?preview=false"); then
  slug=$(echo "$state" | jq -r '.data.interval_generation_data')
  curl -sS --fail -A "$UA" -o "data/$day/kubra-summary-$ts.json"  "$K/$slug/public/summary-1/data.json" || true
  curl -sS --fail -A "$UA" -o "data/$day/kubra-zips-$ts.json"     "$K/$slug/public/thematic-2/thematic_areas.json" || true
  echo "kubra: $(jq -r '.summaryFileData.totals[0].total_cust_a.val' "data/$day/kubra-summary-$ts.json" 2>/dev/null) customers out"
fi
