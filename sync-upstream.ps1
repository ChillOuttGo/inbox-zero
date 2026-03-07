# Sync Inbox Zero Fork with Upstream
# Created: March 7, 2026
# Upstream: https://github.com/elie222/inbox-zero
# Fork: https://github.com/ChillOuttGo/inbox-zero

param(
    [switch]$Auto,           # Skip confirmation prompt
    [switch]$DryRun,         # Show changes without merging
    [switch]$Force           # Force push even if conflicts exist
)

$ErrorActionPreference = "Stop"

# Configuration
$repoPath = "C:\Users\user\techzone\Aegis Core\aegis\tools\utilities\inbox-zero"
$upstreamRepo = "https://github.com/elie222/inbox-zero.git"
$upstreamBranch = "main"

function Write-Header {
    param([string]$Text)
    Write-Host "`n╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  $($Text.PadRight(53))" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Text)
    Write-Host "✅ $Text" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Text)
    Write-Host "⚠️  $Text" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Text)
    Write-Host "❌ $Text" -ForegroundColor Red
}

function Write-Info {
    param([string]$Text)
    Write-Host "ℹ️  $Text" -ForegroundColor Cyan
}

# Check if repo exists
if (-not (Test-Path $repoPath)) {
    Write-Error-Custom "Repository not found at: $repoPath"
    Write-Info "Please clone the fork first:"
    Write-Host "  git clone https://github.com/ChillOuttGo/inbox-zero.git `"$repoPath`"" -ForegroundColor Gray
    exit 1
}

Write-Header "Syncing Inbox Zero Fork with Upstream"

# Navigate to repo
Push-Location $repoPath

try {
    # Check if we're in a git repo
    $gitCheck = git rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Not a git repository!"
        exit 1
    }

    # Check current branch
    $currentBranch = git branch --show-current
    Write-Info "Current branch: $currentBranch"

    if ($currentBranch -ne "main") {
        Write-Warning "You're not on the main branch!"
        $switch = Read-Host "Switch to main branch? (y/n)"
        if ($switch -eq 'y') {
            git checkout main
            if ($LASTEXITCODE -ne 0) {
                Write-Error-Custom "Failed to switch to main branch"
                exit 1
            }
        } else {
            Write-Error-Custom "Sync must be done on main branch"
            exit 1
        }
    }

    # Check for uncommitted changes
    $status = git status --porcelain
    if ($status) {
        Write-Warning "You have uncommitted changes:"
        git status --short
        $stash = Read-Host "`nStash changes? (y/n)"
        if ($stash -eq 'y') {
            git stash push -m "Auto-stash before upstream sync $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
            Write-Success "Changes stashed"
        } else {
            Write-Error-Custom "Please commit or stash changes before syncing"
            exit 1
        }
    }

    # Check if upstream remote exists
    $remotes = git remote
    if ($remotes -notcontains "upstream") {
        Write-Warning "Upstream remote not configured"
        Write-Info "Adding upstream remote..."
        git remote add upstream $upstreamRepo
        Write-Success "Upstream remote added"
    }

    # Fetch upstream changes
    Write-Info "Fetching upstream changes..."
    git fetch upstream
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Failed to fetch upstream"
        exit 1
    }
    Write-Success "Fetched upstream"

    # Check how many commits behind
    $behindCount = git rev-list --count HEAD..upstream/$upstreamBranch 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Failed to compare with upstream"
        exit 1
    }

    if ($behindCount -eq 0) {
        Write-Success "Already up to date with upstream! 🎉"
        exit 0
    }

    # Show what will be merged
    Write-Warning "Your fork is $behindCount commits behind upstream"
    Write-Host "`nNew commits from upstream:" -ForegroundColor Cyan
    git log --oneline --graph --decorate HEAD..upstream/$upstreamBranch

    # Dry run mode
    if ($DryRun) {
        Write-Info "DRY RUN MODE - No changes will be made"
        Write-Host "`nTo apply these changes, run without -DryRun flag" -ForegroundColor Yellow
        exit 0
    }

    # Confirm merge
    if (-not $Auto) {
        Write-Host ""
        $confirm = Read-Host "Merge these $behindCount commits into your fork? (y/n)"
        if ($confirm -ne 'y') {
            Write-Warning "Sync cancelled by user"
            exit 0
        }
    }

    # Merge upstream changes
    Write-Info "Merging upstream/$upstreamBranch..."
    git merge upstream/$upstreamBranch --no-edit

    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Merge failed! Conflicts detected."
        Write-Warning "Please resolve conflicts manually:"
        Write-Host "  1. Fix conflicts in VS Code" -ForegroundColor Gray
        Write-Host "  2. git add ." -ForegroundColor Gray
        Write-Host "  3. git commit -m 'chore: resolve merge conflicts from upstream'" -ForegroundColor Gray
        Write-Host "  4. git push origin main" -ForegroundColor Gray
        exit 1
    }

    Write-Success "Merged successfully"

    # Push to origin
    Write-Info "Pushing to origin..."
    if ($Force) {
        git push origin main --force
    } else {
        git push origin main
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Push failed!"
        Write-Warning "Your local repo is updated but not pushed to GitHub"
        Write-Info "Try pushing manually: git push origin main"
        exit 1
    }

    Write-Success "Successfully synced with upstream! 🎉"
    Write-Host "`nLatest commit:" -ForegroundColor Cyan
    git log -1 --oneline

    Write-Host "`n📊 Summary:" -ForegroundColor Cyan
    Write-Host "  • Merged: $behindCount commits" -ForegroundColor Gray
    Write-Host "  • Branch: $currentBranch" -ForegroundColor Gray
    Write-Host "  • Upstream: $upstreamRepo" -ForegroundColor Gray
    Write-Host "  • Status: ✅ Synced" -ForegroundColor Green

} catch {
    Write-Error-Custom "An error occurred: $_"
    exit 1
} finally {
    Pop-Location
}
