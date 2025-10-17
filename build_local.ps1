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

# === GET ENVIRONMENT INFO ===
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$localTag  = "LocalBuild_$timestamp"

# === CLEAN-UP ===
Write-Host ":: Cleaning up previous builds..."
if (Test-Path "new_builds") {
    Remove-Item -Recurse -Force "new_builds"
    Write-Host ":: Removed new_builds folder"
}
Remove-Item "$baseExeName.exe","build.log" -ErrorAction SilentlyContinue

# === VERSIONING ===
$version = ""
if (Test-Path $versionTxt) {
    try {
        $version = (Get-Content $versionTxt | Select-String -Pattern '\d+\.\d+\.\d+' -AllMatches).Matches.Value | Select-Object -First 1
        Write-Host ":: Found existing version: $version"
    } catch {
        Write-Host ":: Warning: Could not parse version.txt, using timestamp fallback"
    }
}

if (-not $version) {
    $version = $timestamp
    Write-Host ":: Using fallback version: $version"
}

Set-Content -Path $versionTxt -Value "v$version" -Encoding UTF8
Set-Content -Path $versionDat -Value $version -Encoding UTF8

$versionedExe = "${baseExeName}_v$version.exe"
$versionedZip = "${baseExeName}_v$version.zip"

# === COMPILE AHK SCRIPT ===
Write-Host ":: Compiling AHK..."
$arguments = @("/in", $scriptName, "/out", "$baseExeName.exe", "/icon", $iconPath)
$process = Start-Process -FilePath $ahk2exePath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
if ($process.ExitCode -ne 0) {
    Write-Error "Ahk2Exe failed! Exit code: $($process.ExitCode)"
    Exit 1
}

if (Test-Path "$baseExeName.exe") {
    Copy-Item "$baseExeName.exe" "$versionedExe" -Force
    Write-Host ":: Compilation successful - $versionedExe"
} else {
    Write-Error "Compilation failed - no output file found."
    Exit 1
}

# === UPX COMPRESSION ===
if ((Test-Path $upxPath) -and (Test-Path $versionedExe)) {
    Write-Host ":: Compressing EXE with UPX..."
    & $upxPath --best --lzma $versionedExe
} else {
    Write-Host ":: UPX not found, skipping compression."
}

# === CREATE ZIP PACKAGE ===
Write-Host ":: Creating ZIP package..."
$toZip = @($versionedExe) + $extraAssets
if (Test-Path $mediaFolder) { $toZip += Get-ChildItem -Path $mediaFolder -Recurse -File | Select-Object -ExpandProperty FullName }
if (Test-Path $toolsFolder) { $toZip += Get-ChildItem -Path $toolsFolder -Recurse -File | Select-Object -ExpandProperty FullName }
$toZip = $toZip | Where-Object { Test-Path $_ }

Compress-Archive -Path $toZip -DestinationPath $versionedZip -Force
Write-Host ":: ZIP created - $versionedZip"

# === MOVE TO NEW_BUILDS FOLDER ===
$buildFolder = "new_builds"
if (-not (Test-Path $buildFolder)) { New-Item -ItemType Directory -Path $buildFolder | Out-Null }

foreach ($file in @($versionedExe, $versionedZip)) {
    if (Test-Path $file) {
        Move-Item $file -Destination $buildFolder -Force
        Write-Host ":: Moved $file to $buildFolder"
    } else {
        Write-Warning "File not found, skipping: $file"
    }
}

# === UPDATE CHANGELOG ===
$changelogEntry = "[${timestamp}] Built $versionedExe with version $version"
Add-Content -Path $changelogFile -Value $changelogEntry
Write-Host ":: Changelog updated - $changelogFile"

# === FINISHED ===
Write-Host ":: Build completed - version: $version"
Invoke-Item $buildFolder
