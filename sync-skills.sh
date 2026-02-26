#!/bin/bash

# Sync custom skills to global skills directory
# This script creates symlinks for all skills in ./skills to $HOME/.agents/skills

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
GLOBAL_SKILLS_DIR="$HOME/.agents/skills"

# Check if skills directory exists
if [ ! -d "$SKILLS_DIR" ]; then
	echo "Error: Skills directory not found at $SKILLS_DIR"
	exit 1
fi

# Create global skills directory if it doesn't exist
if [ ! -d "$GLOBAL_SKILLS_DIR" ]; then
	echo "Creating global skills directory at $GLOBAL_SKILLS_DIR"
	mkdir -p "$GLOBAL_SKILLS_DIR"
fi

echo "Syncing skills from $SKILLS_DIR to $GLOBAL_SKILLS_DIR"
echo ""

# Loop through each skill and create symlink
for skill in "$SKILLS_DIR"/*; do
	if [ -d "$skill" ]; then
		skill_name=$(basename "$skill")
		target="$GLOBAL_SKILLS_DIR/$skill_name"

		# Create or update symlink
		ln -sf "$skill" "$target"
		echo "✓ Linked: $skill_name"
	fi
done

echo ""
echo "Done! Skills synced to global directory."
echo ""
echo "Current skills in $GLOBAL_SKILLS_DIR:"
ls -1 "$GLOBAL_SKILLS_DIR"
