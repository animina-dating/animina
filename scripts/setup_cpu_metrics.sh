#!/bin/bash
# Writes CPU model info to node_exporter textfile collector.
# Run once on each server (or via cron for updates).
#
# Usage: sudo bash scripts/setup_cpu_metrics.sh

TEXTFILE_DIR="/var/lib/prometheus/node-exporter"
PROM_FILE="$TEXTFILE_DIR/cpu_model.prom"

MODEL=$(grep -m1 "^model name" /proc/cpuinfo | cut -d: -f2 | xargs)

if [ -z "$MODEL" ]; then
  echo "Could not read CPU model from /proc/cpuinfo"
  exit 1
fi

CORE_COUNT=$(grep -c "^processor" /proc/cpuinfo)

cat > "$PROM_FILE" <<EOF
# HELP node_cpu_model_info CPU model from /proc/cpuinfo
# TYPE node_cpu_model_info gauge
node_cpu_model_info{model_name="$MODEL",cores="$CORE_COUNT"} 1
EOF

echo "Written to $PROM_FILE:"
cat "$PROM_FILE"
