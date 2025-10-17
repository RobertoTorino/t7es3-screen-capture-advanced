#param(
#    [string]$Message = "Automated commit",
#    [ValidateSet("major","minor","patch")] [string]$Part = "patch"
#)

param(
    [string]$Message = "Automated commit",
    [ValidateSet("major", "minor", "patch")] [string]$Part = "",
    [switch]$Auto
)

Write-Host "=== T7ES3 Release Script ===" -ForegroundColor Cyan

# === Git LFS setup ===
git lfs install

# Track common build artifacts
git lfs track "*.zip"
git lfs track "*.wav"
git lfs track "*.exe"
git lfs track "*.dll"

# Stage .gitattributes if it changed
git add .gitattributes

# Only commit if there are changes
if (-not (git status --porcelain))
{
    Write-Host "No changes to commit."
}
else
{
    git add .
    git commit -m "$Message"
    git push
}

# === Version detection ===
$lastTag = git tag --list "v*" | Sort-Object { [version]($_ -replace '^v', '') } -Descending | Select-Object -First 1

if ($lastTag -match '^v(\d+)\.(\d+)\.(\d+)$')
{
    $major = [int]$matches[1]
    $minor = [int]$matches[2]
    $patch = [int]$matches[3]
}
else
{
    $major = 0; $minor = 0; $patch = 0
    $lastTag = "v0.0.0"
}

Write-Host "Last tag: $lastTag"

# Ask user which part to increment
$choice = Read-Host "Which part would you like to increment? (1=major, 2=minor, 3=patch, default=patch):"
switch ( $choice.ToLower())
{
    "major" {
        $major++; $minor = 0; $patch = 0
    }
    "1"     {
        $major++; $minor = 0; $patch = 0
    }
    "minor" {
        $minor++; $patch = 0
    }
    "2"     {
        $minor++; $patch = 0
    }
    "patch" {
        $patch++
    }
    "3"     {
        $patch++
    }
    default {
        $patch++
    }
}

# New semantic version
$newTag = "v$major.$minor.$patch"
Write-Host "Creating and pushing tag $newTag..."

# Tag and push
git tag $newTag
git push
git push origin $newTag

Write-Host "Committed and tagged as $newTag."

# === Update changelog automatically ===
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
$changelogPath = "changelog.txt"

# Get all commits since last tag
if ($lastTag -ne "v0.0.0")
{
    $commits = git log $lastTag..HEAD --pretty=format:"- %s"
}
else
{
    $commits = git log --pretty=format:"- %s"
}

# Build changelog entry
$changelogEntry = "[$timestamp] $newTag`n$commits`n"

# Append to changelog.txt
Add-Content -Path $changelogPath -Value $changelogEntry
Write-Host "Updated changelog.txt:"
Write-Host $changelogEntry

# Stage and push changelog
git add $changelogPath
git commit -m "Update changelog for $newTag"
git push

# === Update version.txt ===
$versionFile = "version.txt"
$versionInfo = "$newTag ($timestamp)"
Set-Content -Path $versionFile -Value $versionInfo
Write-Host "Updated version.txt: $versionInfo"

git add $versionFile
git commit -m "Update version file for $newTag"
git push

Write-Host "Release complete: $newTag"
