#!/bin/bash

echo "🔧 Fixing corrupted Git repository..."
echo ""

# Backup current directory
BACKUP_DIR="$HOME/nalam-ai-backup-$(date +%Y%m%d_%H%M%S)"
echo "1. Creating backup at: $BACKUP_DIR"
cp -r /home/suraj/Documents/Work/nalam-ai "$BACKUP_DIR"
echo "   ✅ Backup created"
echo ""

# Navigate to project
cd /home/suraj/Documents/Work/nalam-ai

# Try to recover from remote
echo "2. Fetching fresh objects from remote..."
git fetch origin --all 2>/dev/null || echo "   ⚠️  Fetch had errors (expected)"
echo ""

# Remove corrupted objects and refs
echo "3. Cleaning up corrupted objects..."
rm -f .git/objects/24/0f62268d7e8ea99be270bb644186b7f46b697e
rm -f .git/objects/88/58f78603b87d3c3fc6fb9b9030aa3e54176407
rm -f .git/objects/e7/b804ed13d9908f5db8b8429c5eb8b256f17695
rm -f .git/refs/remotes/origin/HEAD
rm -f .git/refs/remotes/origin/temp
echo "   ✅ Removed corrupted objects"
echo ""

# Reset to remote main
echo "4. Resetting to remote main branch..."
git reset --hard origin/main 2>/dev/null || echo "   ⚠️  Reset had errors"
echo ""

# Verify
echo "5. Verifying repository..."
if git status &>/dev/null; then
    echo "   ✅ Repository is now functional!"
    echo ""
    echo "Current branch:"
    git branch --show-current
    echo ""
    echo "Latest commit:"
    git log -1 --oneline
else
    echo "   ❌ Still has issues. Use Plan B below."
fi

echo ""
echo "=========================================="
echo "If repository is still broken, use Plan B:"
echo "=========================================="
echo ""
echo "# Move current directory"
echo "mv /home/suraj/Documents/Work/nalam-ai /home/suraj/Documents/Work/nalam-ai-broken"
echo ""
echo "# Fresh clone"
echo "cd /home/suraj/Documents/Work"
echo "git clone https://github.com/innov8-tist/nalam-ai.git"
echo ""
echo "# Your backup is at: $BACKUP_DIR"
echo ""
