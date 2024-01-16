#!/bin/sh

PRE_COMMIT_HOOK=".git/hooks/pre-commit"

# Create the pre-commit hook
cat > $PRE_COMMIT_HOOK <<EOF
#!/bin/sh
git stash -q --keep-index
mix format
git add -u
git stash pop -q
exit 0
EOF

# Make the hook executable
chmod +x $PRE_COMMIT_HOOK

echo "Pre-commit hook set up successfully."
