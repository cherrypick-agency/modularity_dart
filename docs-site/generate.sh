#!/usr/bin/env bash
# Generate VitePress docs-site content from workspace sources.
# Requires: `dartdoc_vitepress` (recommended: `dart pub global activate dartdoc_vitepress`)
# Outputs (generated, not committed): guide/modularity_workspace/, api/, .vitepress/generated/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Always run from repo root so `--workspace-docs` can find `pubspec.yaml`.
cd "$REPO_ROOT"

EXCLUDE_PACKAGES='complex_app,complex_mobx,example,example_auto_route,example_bloc,example_go_router,example_riverpod,modularity_injectable_example,test_utils'
GEN_ARGS=(
  --format vitepress
  --workspace-docs
  --exclude-packages "$EXCLUDE_PACKAGES"
  --output docs-site
)

echo "📝 Generating docs-site content..."

DARTDOC_VITEPRESS_DEFAULT="/Users/belief/dev/projects/dartdoc_modern/bin/dartdoc_vitepress.dart"

if [ -n "${DARTDOC_VITEPRESS:-}" ]; then
  if [ ! -f "$DARTDOC_VITEPRESS" ]; then
    echo "❌ DARTDOC_VITEPRESS points to a missing file:"
    echo "   $DARTDOC_VITEPRESS"
    exit 1
  fi

  dart run "$DARTDOC_VITEPRESS" "${GEN_ARGS[@]}"
elif [ -f "$DARTDOC_VITEPRESS_DEFAULT" ]; then
  dart run "$DARTDOC_VITEPRESS_DEFAULT" "${GEN_ARGS[@]}"
elif command -v dartdoc_vitepress >/dev/null 2>&1; then
  dartdoc_vitepress "${GEN_ARGS[@]}"
else
  echo "❌ dartdoc_vitepress is not installed or not found."
  echo "   Expected at: $DARTDOC_VITEPRESS_DEFAULT"
  echo "   Or install globally with:"
  echo "   dart pub global activate dartdoc_vitepress"
  exit 1
fi

echo "✅ Docs generated successfully"
