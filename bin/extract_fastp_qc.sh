#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./extract_fastp_qc.sh /path/to/fastp_reports/ > fastp_qc_summary.tsv
#   ./extract_fastp_qc.sh /path/to/fastp_reports/*.html > fastp_qc_summary.tsv
#
# If you pass a directory, it will use *.html inside it.
# If you pass file paths/globs, it will use them directly.

# --- resolve inputs to a list of html files ---
files=()
if [[ $# -eq 0 ]]; then
  shopt -s nullglob
  files=( *.html )
elif [[ $# -eq 1 && -d "$1" ]]; then
  shopt -s nullglob
  files=( "$1"/*.html )
else
  files=( "$@" )
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "ERROR: No .html files found." >&2
  exit 1
fi

# Extract the 5th '>'-delimited field, then stop at '<' (matches your original approach).
extract_cell_text() {
  awk -F'>' '{print $5}' | awk -F'<' '{print $1}'
}

# Get the Nth match (1-based) for a pattern in a given file, after applying extract_cell_text.
nth_match() {
  local pattern="$1"
  local n="$2"
  local file="$3"
  grep -F "$pattern" "$file" 2>/dev/null | extract_cell_text | awk -v n="$n" 'NR==n {print; exit}'
}

# Extract the Nth match (1-based), then capture the percent inside parentheses, e.g. "(12.3%)" -> "12.3"
nth_paren_percent() {
  local pattern="$1"
  local n="$2"
  local file="$3"
  grep -F "$pattern" "$file" 2>/dev/null \
    | extract_cell_text \
    | awk -v n="$n" 'NR==n {print; exit}' \
    | awk -F'(' '{print $2}' \
    | awk -F'%' '{print $1}'
}

# Normalize counts like: 12.3M -> 12300000, 450K -> 450000, 987 -> 987
normalize_count() {
  local s="${1:-}"
  s="$(echo "$s" | tr -d ' ,\t\r\n')"  # strip commas/spaces
  [[ -z "$s" ]] && { echo ""; return; }

  echo "$s" | awk '
    BEGIN { IGNORECASE=1 }
    {
      v=$0
      suffix=""
      if (v ~ /[kKmM]$/) {
        suffix=substr(v, length(v), 1)
        v=substr(v, 1, length(v)-1)
      }

      # If unexpected characters are present, return unchanged.
      if (v == "" || v ~ /[^0-9.]/) { print $0; exit }

      mult=1
      if (suffix=="K" || suffix=="k") mult=1000
      if (suffix=="M" || suffix=="m") mult=1000000

      n = v + 0
      out = n * mult
      printf "%.0f\n", out
    }'
}

# --- header ---
printf "library_id\tsequencing_mode\tduplication_rate_pct\ttotal_reads_before_filtering\ttotal_reads_after_filtering\treads_too_short_pct\tlow_complexity_pct\tlow_quality_pct\tgc_content\tinsert_size_peak\n"

# --- extract per file ---
for f in "${files[@]}"; do
  [[ -f "$f" ]] || continue

  # Sample name: strip trailing .html and also strip .fastp.report
  base="$(basename "$f")"
  sample="${base%.html}"
  sample="${sample%.fastp.report}"

  # sequencing mode: take first extracted cell for "sequencing"
  sequencing_mode="$(nth_match "sequencing" 1 "$f")"

  # duplication rate: keep numeric part before '%'
  duplication_rate="$(
    grep -F "duplication rate" "$f" 2>/dev/null \
      | extract_cell_text \
      | awk -F'%' 'NR==1 {print $1; exit}'
  )"

  # total reads: before = 1st occurrence, after = 2nd occurrence
  total_before_raw="$(nth_match "total reads" 1 "$f")"
  total_after_raw="$(nth_match "total reads" 2 "$f")"
  total_before="$(normalize_count "$total_before_raw")"
  total_after="$(normalize_count "$total_after_raw")"

  # filtering breakdown (percent in parentheses)
  reads_too_short="$(nth_paren_percent "reads too short" 1 "$f")"
  low_complexity="$(nth_paren_percent "low complexity" 1 "$f")"

  # low quality: percent inside parentheses
  low_quality="$(
    grep -F "low quality" "$f" 2>/dev/null \
      | extract_cell_text \
      | awk 'NR==1 {print; exit}' \
      | awk -F'(' '{print $2}' \
      | awk -F'%' '{print $1}'
  )"

  # GC content: take 2nd occurrence (matches your NR%2==0 selection)
  gc_content="$(nth_match "GC content" 2 "$f")"

  # Insert size peak: first occurrence
  insert_size_peak="$(nth_match "Insert size peak" 1 "$f")"

  # Print row (empty fields will be empty cells)
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$sample" \
    "${sequencing_mode:-}" \
    "${duplication_rate:-}" \
    "${total_before:-}" \
    "${total_after:-}" \
    "${reads_too_short:-}" \
    "${low_complexity:-}" \
    "${low_quality:-}" \
    "${gc_content:-}" \
    "${insert_size_peak:-}"
done

