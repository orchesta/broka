PORT=11211

# mc <host> <command>: sends one command and prints the reply without carriage returns
mc() {
  printf '%s\r\nquit\r\n' "$2" | nc "$1" "$PORT" | tr -d '\r'
}

# stat_of <host> <stats command> <name>: prints one STAT value
stat_of() {
  mc "$1" "$2" | awk -v k="$3" '$1 == "STAT" && $2 == k { print $3 }'
}
