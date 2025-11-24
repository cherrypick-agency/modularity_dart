#!/bin/bash
# Setup git hooks for auto-formatting

echo "Setting up git hooks..."

# Copy pre-commit hook
cp .githooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

echo "✓ Git hooks installed successfully!"
echo "Dart files will be automatically formatted before each commit."
