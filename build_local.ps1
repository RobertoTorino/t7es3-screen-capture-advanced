# === CONFIG ===
$baseExeName    = "t7es3sca"
$scriptName     = "t7es3sca.ahk"
$ahk2exePath    = "ahk\Compiler\Ahk2Exe.exe"
$upxPath        = "upx\upx.exe"
$mediaFolder    = "t7es3_media"
$iconPath       = "t7es3_media\default.ico"
$iniPath        = "t7es3.ini"
$licensePath    = "LICENSE"
$readmePath     = "README.txt"
$toolsFolder    = "t7es3_tools"
$versionTxt     = "version.txt"
$versionDat     = "version.dat"
$changelogFile  = "changelog.txt"
$extraAssets    = @($readmePath, $iniPath, $licensePath, $versionTxt, $versionDat)

# === CLEAN-UP ===
Write-Host ":: Cleaning up previous builds..."
if (Test-Path "new_builds") {
    Remove-Item -Recurse -Force "new_builds"
    Write-Host ":: Removed new_builds folder"
}

# === VERSIONING ===
$version = ""

# Try to read version.txt
if (Test-Path $versionTxt) {
    try {
        $version = (Get-Content $versionTxt | Select-String -Pattern '\d+\.\d+\.\d+' -AllMatches).Matches.Value | Select-Object -First 1
        Write-Host ":: Found existing version: $version"
    } catch {
        Write-Host ":: Warning: Could not parse version.txt, using timestamp fallback"
    }
}

# Fallback to timestamp if no version detected
if (-not $version) {
    $version = (Get-Date -Format "yyyyMMdd_HHmmss")
    Write-Host ":: Using fallback version: $version"
}

# Write version.txt (human-readable for About dialog)
Set-Content -Path $versionTxt -Value "v$version" -Encoding UTF8

# Write version.dat (fallback for embedded About dialog)
Set-Content -Path $versionDat -Value $version -Encoding UTF8

# Versioned filenames
$versionedExe = "${baseExeName}_v$version.exe"
$versionedZip = "${baseExeName}_v$version.zip"
Write-Host ":: Versioned output: $versionedExe / $versionedZip"

# === CLEANUP OLD FILES ===
Remove-Item "$baseExeName.exe", $versionedExe, $versionedZip, "build.log" -ErrorAction SilentlyContinue

# === COMPILE AHK SCRIPT ===
Write-Host ":: Compiling AHK script..."
$arguments = @("/in", $scriptName, "/out", "$baseExeName.exe", "/icon", $iconPath)
$process = Start-Process -FilePath $ahk2exePath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
if ($process.ExitCode -ne 0) {
    Write-Error "Ahk2Exe failed! Exit code: $($process.ExitCode)"
    Exit 1
}

# Copy output to versioned EXE
if (Test-Path "$baseExeName.exe") {
    Copy-Item "$baseExeName.exe" "$versionedExe" -Force
    Write-Host ":: Compilation successful _ $versionedExe"
} else {
    Write-Error "Compilation failed - no output file found."
    Exit 1
}

# === UPX COMPRESSION ===
if (Test-Path $upxPath) {
    Write-Host ":: Compressing EXE with UPX..."
    & $upxPath --best --lzma $versionedExe
} else {
    Write-Host ":: UPX not found, skipping compression."
}

# === CREATE ZIP PACKAGE ===
Write-Host ":: Creating ZIP package..."
$toZip = @($versionedExe) + $extraAssets

if (Test-Path $mediaFolder) {
    $toZip += Get-ChildItem -Path $mediaFolder -Recurse -File | Select-Object -ExpandProperty FullName
}

if (Test-Path $toolsFolder) {
    $toZip += Get-ChildItem -Path $toolsFolder -Recurse -File | Select-Object -ExpandProperty FullName
}

Compress-Archive -Path $toZip -DestinationPath $versionedZip -Force
Write-Host ":: ZIP created _ $versionedZip"

# === MOVE TO NEW_BUILDS FOLDER ===
$buildFolder = "new_builds"
if (-not (Test-Path $buildFolder)) {
    New-Item -ItemType Directory -Path $buildFolder | Out-Null
}

foreach ($file in @($versionedExe, $versionedZip)) {
    if (Test-Path $file) {
        Move-Item $file -Destination $buildFolder -Force
        Write-Host ":: Moved $file to $buildFolder"
    } else {
        Write-Warning "File missing: $file"
    }
}

# === UPDATE CHANGELOG ===
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$changelogEntry = "[${timestamp}] Built $versionedExe with version $version"
Add-Content -Path $changelogFile -Value $changelogEntry
Write-Host ":: Changelog updated _ $changelogFile"

# === FINISHED ===
Write-Host ":: Build complete - version: $version"
Invoke-Item $buildFolder
