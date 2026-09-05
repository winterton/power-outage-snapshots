# DTE outage snapshots

Every 15 minutes, a GitHub Action pulls the full `OutageAreas` layer from DTE's public ArcGIS
service and commits it as gzipped GeoJSON under `data/YYYY/MM/DD/`. The storm-mode table is
saved alongside.

Fields of note: `JOB_ID` (stable per outage — use it to track a job across snapshots),
`NUM_CUST`, `NUM_CUST_RESTORED`, `TOAL_CUST_AFFECTED`, `OFF_DTTM`, `EST_REP_DTTM`,
`CIRCUIT_EST_DTTM`, `EVENT_STATUS`, `DISPATCH_DTTM`, `DEV_TYPE_NAME`, `SERVICE_CENTER`.
`CREW_STATUS` is always null in the public feed. Polygons are DTE's estimate of the affected
customer area, not a physical outage footprint.

## Setup
1. Create a repo, push these files.
2. Actions → enable workflows. Run "Snapshot DTE outages" once manually to confirm.
3. Storage: a big storm day is ~1–3 MB compressed; a quiet day is a few hundred KB. Prune or
   roll up old days to a summary once a year if the repo gets heavy.

## Quick analysis
```bash
# customers-out timeline for one day
for f in data/2026/09/05/outages-*.geojson.gz; do
  printf '%s %s\n' "$(basename $f .geojson.gz | cut -d- -f2-)" "$(zcat $f | jq '[.features[].properties.NUM_CUST // 0] | add')"
done
```
