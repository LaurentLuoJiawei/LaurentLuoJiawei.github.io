#!/usr/bin/env bash
# search_dj_params.sh
#
# Search a locally checked-out Data-Juicer repository for configuration and
# CLI parameters related to memory protection / batch control.
#
# Usage:
#   bash search_dj_params.sh [REPO_DIR]
#
# REPO_DIR defaults to the current working directory if not provided.
#
# The script searches for the following keywords:
#   batch_size, read_batch_size, block_size, target_max_block_size,
#   prefetch_batches, streaming, streaming_read
#
# Output:
#   Colored grep output (file:line:match) grouped by keyword.

set -euo pipefail

REPO_DIR="${1:-$PWD}"

if [ ! -d "$REPO_DIR" ]; then
  echo "ERROR: directory not found: $REPO_DIR" >&2
  exit 1
fi

# Color codes (disabled when stdout is not a terminal)
if [ -t 1 ]; then
  BOLD='\033[1m'
  CYAN='\033[0;36m'
  RESET='\033[0m'
else
  BOLD=''
  CYAN=''
  RESET=''
fi

KEYWORDS=(
  batch_size
  read_batch_size
  block_size
  target_max_block_size
  prefetch_batches
  streaming
  streaming_read
)

echo -e "${BOLD}Data-Juicer parameter search${RESET}"
echo -e "Repository : ${CYAN}${REPO_DIR}${RESET}"
echo -e "Keywords   : ${KEYWORDS[*]}"
echo ""

found_any=0

for kw in "${KEYWORDS[@]}"; do
  echo -e "${BOLD}=== ${kw} ===${RESET}"

  # Search Python files
  results_py=$(grep -rn \
    --include='*.py' \
    -e "${kw}" \
    "$REPO_DIR" 2>/dev/null || true)

  # Search YAML config files
  results_yaml=$(grep -rn \
    --include='*.yaml' \
    --include='*.yml' \
    -e "${kw}" \
    "$REPO_DIR" 2>/dev/null || true)

  combined="${results_py}"$'\n'"${results_yaml}"
  # Remove blank lines
  combined=$(echo "$combined" | grep -v '^$' || true)

  if [ -z "$combined" ]; then
    echo "  (no matches)"
  else
    echo "$combined" | sed 's/^/  /'
    found_any=1
  fi

  echo ""
done

if [ "$found_any" -eq 0 ]; then
  echo "No matches found. Make sure REPO_DIR points to a valid Data-Juicer clone."
  echo "  Clone with: git clone https://github.com/modelscope/data-juicer"
  exit 1
fi

echo -e "${BOLD}Done.${RESET}"
