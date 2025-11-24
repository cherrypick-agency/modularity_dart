#!/bin/bash

# Exit on error
set -e

# Directory for combined coverage
OUTPUT_DIR="coverage"
mkdir -p "$OUTPUT_DIR"
LCOV_INFO="$OUTPUT_DIR/lcov.info"
HTML_REPORT="$OUTPUT_DIR/html"

# Clear previous report
rm -f "$LCOV_INFO"
rm -rf "$HTML_REPORT"

echo "🔍 Locating coverage files..."

# Create a temporary file to hold the merged data
touch "$LCOV_INFO"

# Loop through all packages to find lcov.info files
find packages -name "lcov.info" | while read -r file; do
    echo "Processing $file..."
    pkg_dir=$(dirname $(dirname "$file"))
    # Rewrite paths so they are relative to the root
    sed "s|^SF:lib/|SF:$pkg_dir/lib/|g" "$file" >> "$LCOV_INFO"
done

echo "✅ Merged coverage data into $LCOV_INFO"

# --- Calculate Coverage Percentage ---
echo "🧮 Calculating coverage percentage..."

# Extract Lines Found (LF) and Lines Hit (LH)
# We sum up all LF and LH values from the merged lcov.info
total_lines=$(grep -o "LF:[0-9]*" "$LCOV_INFO" | cut -d: -f2 | awk '{s+=$1} END {print s}')
covered_lines=$(grep -o "LH:[0-9]*" "$LCOV_INFO" | cut -d: -f2 | awk '{s+=$1} END {print s}')

if [ -z "$total_lines" ] || [ "$total_lines" -eq 0 ]; then
    percent=0
else
    # Calculate percentage with 1 decimal place
    percent=$(awk "BEGIN {printf \"%.1f\", $covered_lines * 100 / $total_lines}")
fi

echo "📈 Total Coverage: $percent% ($covered_lines/$total_lines lines)"

# --- Update README.md ---
echo "📝 Updating README.md..."

# Determine color based on percentage
if (( $(echo "$percent < 50" | bc -l) )); then
  color="red"
elif (( $(echo "$percent < 80" | bc -l) )); then
  color="yellow"
else
  color="brightgreen"
fi

# Construct the new badge line
# We use %25 for the % symbol in the URL
new_badge="![coverage](https://img.shields.io/badge/coverage-${percent}%25-${color})"

# Replace the existing badge line in README.md
# MacOS sed requires an empty string for -i extension, Linux does not.
# We try to detect OS or use a compatible way (perl is often more consistent for this).

if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|^!\[coverage\].*|$new_badge|" README.md
else
    sed -i "s|^!\[coverage\].*|$new_badge|" README.md
fi

echo "✅ README.md updated with coverage: $percent%"

# --- Generate HTML Report ---

# Check if lcov is installed
if ! command -v genhtml &> /dev/null; then
    echo "⚠️  'genhtml' is not installed. Skipping HTML report generation."
    echo "👉 Install it using: brew install lcov"
else
    echo "📊 Generating HTML report..."
    genhtml "$LCOV_INFO" -o "$HTML_REPORT" --ignore-errors empty
    echo "🎉 Report generated successfully!"
    echo "👉 Opening $HTML_REPORT/index.html..."
    open "$HTML_REPORT/index.html"
fi
