# Runs docker compose for the lab from the lab's directory.
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# Git Bash on Windows would otherwise rewrite container paths such as /scripts into Windows paths.
export MSYS_NO_PATHCONV=1
lab() { docker compose -f ../../install/compose.yml -f compose.yml "$@"; }
