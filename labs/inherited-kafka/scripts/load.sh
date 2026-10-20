#!/usr/bin/env bash
# Produces RATE equity ticks per second, keyed by symbol, to market.ticks.equities until stopped.
set -euo pipefail

BOOT="${BOOTSTRAP:-kafka-1:29092,kafka-2:29092,kafka-3:29092}"
RATE="${RATE:-40}"
# symbol:venue, enough of them that every one of the topic's twelve partitions takes ticks
instruments=(AAPL:XNAS MSFT:XNAS NVDA:XNAS AMZN:XNAS GOOGL:XNAS META:XNAS TSLA:XNAS AVGO:XNAS ADBE:XNAS CSCO:XNAS
  JPM:XNYS V:XNYS JNJ:XNYS PG:XNYS XOM:XNYS KO:XNYS DIS:XNYS IBM:XNYS GS:XNYS CAT:XNYS
  ASML:XAMS SAP:XETR SIE:XETR ALV:XETR DTE:XETR MC:XPAR TTE:XPAR OR:XPAR SAN:XPAR AIR:XPAR
  NESN:XSWX NOVN:XSWX ROG:XSWX SHEL:XLON HSBA:XLON AZN:XLON ULVR:XLON BP:XLON 7203:XTKS 6758:XTKS)

generate() {
  while true; do
    now=$(date +%s)
    for ((i = 0; i < RATE; i++)); do
      pick=${instruments[$((RANDOM % ${#instruments[@]}))]}
      symbol=${pick%%:*}
      bid=$((RANDOM % 90000 + 1000))
      printf '%s|{"symbol":"%s","venue":"%s","bid":%d.%02d,"ask":%d.%02d,"ts":%s000}\n' \
        "$symbol" "$symbol" "${pick##*:}" $((bid / 100)) $((bid % 100)) $(((bid + 3) / 100)) $(((bid + 3) % 100)) "$now"
    done
    sleep 1
  done
}

generate | /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server "$BOOT" --topic market.ticks.equities \
  --property parse.key=true --property key.separator='|' --producer-property linger.ms=5
