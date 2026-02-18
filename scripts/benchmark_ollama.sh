#!/usr/bin/env bash
#
# Ollama Benchmark Matrix Runner
#
# Iterates over OLLAMA_NUM_PARALLEL values, restarts Ollama for each,
# and runs mix benchmark.ollama to produce per-configuration CSV results.
#
# Usage:
#   MODEL=qwen3-vl:8b OUTPUT_DIR=./benchmark_results/8b ./scripts/benchmark_ollama.sh
#   MODEL=qwen3-vl:4b OUTPUT_DIR=./benchmark_results/4b ./scripts/benchmark_ollama.sh
#
# Environment variables:
#   MODEL        - Ollama model to benchmark (default: qwen3-vl:8b)
#   OUTPUT_DIR   - Directory for CSV output (default: ./benchmark_results)
#   PARALLEL     - Comma-separated NUM_PARALLEL values (default: "1,2,4,8")
#   CONCURRENCY  - Comma-separated app concurrency levels (default: "1,2,4,6,8")
#   COUNT        - Number of test photos per run (default: 20)
#   WARMUP       - Warmup requests (default: 2)
#   TIMEOUT      - Per-request timeout in ms (default: 120000)
#   OLLAMA_URL   - Ollama base URL (default: http://localhost:11434/api)
#   GPU_MONITOR  - Set to "1" to enable GPU monitoring (default: off)

set -euo pipefail

MODEL="${MODEL:-qwen3-vl:8b}"
OUTPUT_DIR="${OUTPUT_DIR:-./benchmark_results}"
PARALLEL="${PARALLEL:-1,2,4,8}"
CONCURRENCY="${CONCURRENCY:-1,2,4,6,8}"
COUNT="${COUNT:-20}"
WARMUP="${WARMUP:-2}"
TIMEOUT="${TIMEOUT:-120000}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434/api}"
GPU_MONITOR="${GPU_MONITOR:-0}"

# Derive the health-check URL from the Ollama API URL
# e.g., http://localhost:11434/api -> http://localhost:11434/api/tags
HEALTH_URL="${OLLAMA_URL}/tags"

mkdir -p "$OUTPUT_DIR"

echo "═══════════════════════════════════════════════════════"
echo "  Ollama Benchmark Matrix"
echo "═══════════════════════════════════════════════════════"
echo "  Model:          $MODEL"
echo "  NUM_PARALLEL:   $PARALLEL"
echo "  Concurrency:    $CONCURRENCY"
echo "  Photos/run:     $COUNT"
echo "  Output:         $OUTPUT_DIR"
echo "  URL:            $OLLAMA_URL"
echo "═══════════════════════════════════════════════════════"
echo ""

# Build extra flags
EXTRA_FLAGS=""
if [ "$GPU_MONITOR" = "1" ]; then
  EXTRA_FLAGS="$EXTRA_FLAGS --gpu-monitor"
fi

IFS=',' read -ra NP_VALUES <<< "$PARALLEL"

for NP in "${NP_VALUES[@]}"; do
  NP=$(echo "$NP" | tr -d ' ')
  echo "───────────────────────────────────────────────────────"
  echo "  Starting Ollama with OLLAMA_NUM_PARALLEL=$NP"
  echo "───────────────────────────────────────────────────────"

  # Stop any running Ollama instance
  echo "  Stopping Ollama..."
  pkill -f "ollama serve" 2>/dev/null || true
  sleep 2

  # Double-check it's dead
  if pgrep -f "ollama serve" > /dev/null 2>&1; then
    echo "  Ollama still running, force killing..."
    pkill -9 -f "ollama serve" 2>/dev/null || true
    sleep 2
  fi

  # Start Ollama with the new NUM_PARALLEL value
  echo "  Starting Ollama with NUM_PARALLEL=$NP..."
  OLLAMA_NUM_PARALLEL="$NP" nohup ollama serve > "$OUTPUT_DIR/ollama_np${NP}.log" 2>&1 &
  OLLAMA_PID=$!
  echo "  Ollama PID: $OLLAMA_PID"

  # Wait for Ollama to be ready (poll /api/tags)
  echo "  Waiting for Ollama to be ready..."
  MAX_WAIT=60
  WAITED=0
  while ! curl -s "$HEALTH_URL" > /dev/null 2>&1; do
    sleep 1
    WAITED=$((WAITED + 1))
    if [ "$WAITED" -ge "$MAX_WAIT" ]; then
      echo "  ERROR: Ollama did not start within ${MAX_WAIT}s"
      echo "  Log tail:"
      tail -20 "$OUTPUT_DIR/ollama_np${NP}.log"
      exit 1
    fi
  done
  echo "  Ollama ready after ${WAITED}s"

  # Run the benchmark
  CSV_PATH="$OUTPUT_DIR/np${NP}.csv"
  echo "  Running benchmark -> $CSV_PATH"
  echo ""

  mix benchmark.ollama \
    --model "$MODEL" \
    --count "$COUNT" \
    --concurrency "$CONCURRENCY" \
    --warmup "$WARMUP" \
    --timeout "$TIMEOUT" \
    --url "$OLLAMA_URL" \
    --csv "$CSV_PATH" \
    $EXTRA_FLAGS

  echo ""
  echo "  Completed NUM_PARALLEL=$NP"
  echo ""
done

# Combine all CSVs into one file with a num_parallel column
COMBINED="$OUTPUT_DIR/benchmark_combined.csv"
echo "Combining results into $COMBINED..."

FIRST=true
for NP in "${NP_VALUES[@]}"; do
  NP=$(echo "$NP" | tr -d ' ')
  CSV="$OUTPUT_DIR/np${NP}.csv"

  if [ ! -f "$CSV" ]; then
    echo "  WARNING: $CSV not found, skipping"
    continue
  fi

  if [ "$FIRST" = true ]; then
    # Write header with num_parallel column
    head -1 "$CSV" | sed 's/^/num_parallel,/' > "$COMBINED"
    FIRST=false
  fi

  # Append data rows with num_parallel prefix
  tail -n +2 "$CSV" | sed "s/^/${NP},/" >> "$COMBINED"
done

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Benchmark complete!"
echo "  Combined results: $COMBINED"
echo "  Individual CSVs:  $OUTPUT_DIR/np*.csv"
echo "  Ollama logs:      $OUTPUT_DIR/ollama_np*.log"
echo "═══════════════════════════════════════════════════════"
