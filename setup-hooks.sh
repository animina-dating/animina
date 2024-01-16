#!/bin/sh

PRE_COMMIT_HOOK=".git/hooks/pre-commit"

# Create the pre-commit hook
cat > $PRE_COMMIT_HOOK <<EOF
#!/bin/sh

# Stash non-staged changes
git stash -q --keep-index

# Run mix format
mix format

# Add any formatting changes to the staging area
git add -u

# Run mix credo
echo "Running mix credo..."
mix credo --strict

# Check if Credo exited with a non-zero status (indicating issues)
if [ \$? -ne 0 ]; then
  echo "Credo found issues, commit aborted!"
  git stash pop -q
  exit 1
fi

# Unstash changes stashed earlier
git stash pop -q

# Exit with success
exit 0
EOF

# Make the hook executable
chmod +x $PRE_COMMIT_HOOK

echo "Pre-commit hook set up successfully."
