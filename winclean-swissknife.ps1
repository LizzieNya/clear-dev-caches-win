# ======================================================================
# INTERACTIVE FULL CLEANUP – SAFE VERSION
# You decide what gets deleted (Y/N for each section)
# ======================================================================

function Ask-YesNo ($msg) {
    $ans = Read-Host "$msg (y/n)"
    return ($ans -match '^[Yy]')
}

Write-Host "`n=== INTERACTIVE CLEANUP ===`n"

# ---------------------- DEV CACHE ----------------------
if (Ask-YesNo "Delete developer caches and build artifacts (npm, pip, conda, docker, gradle, flutter, etc.)?") {
    Write-Host "`n--- Deleting developer caches ---`n"

    $targets = @(
      "$env:USERPROFILE\.cache",
      "$env:USERPROFILE\.npm",
      "$env:USERPROFILE\npm-cache",
      "$env:USERPROFILE\.bun",
      "$env:USERPROFILE\.gradle",
      "$env:USERPROFILE\.flutter",
      "$env:USERPROFILE\.m2",
      "$env:USERPROFILE\.matplotlib",
      "$env:USERPROFILE\.idea",
      "$env:USERPROFILE\.vs",
      "$env:USERPROFILE\.vs-kubernetes",
      "$env:USERPROFILE\.cursor",
      "$env:USERPROFILE\.ollama",
      "$env:USERPROFILE\.bito",
      "$env:USERPROFILE\.llama",
      "$env:USERPROFILE\.VirtualBox",
      "$env:USERPROFILE\.docker"
    )
    foreach ($path in $targets) {
        if (Test-Path $path) {
            Write-Host "Deleting $path"
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $path
        }
    }

    # LM Studio partial cleanup
    $lmPath = "$env:USERPROFILE\.lmstudio"
    if (Test-Path $lmPath) {
        Write-Host "`nCleaning LM Studio cache (keeping history & settings)"
        Get-ChildItem $lmPath -Force | ForEach-Object {
            if ($_.Name -notin @("history", "settings.json")) {
                Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # node_modules
    Write-Host "`nRemoving node_modules folders"
    Get-ChildItem -Path "$env:USERPROFILE" -Directory -Recurse -Force -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -eq "node_modules" } |
      ForEach-Object {
        Write-Host "Deleting $($_.FullName)"
        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
      }

    # package manager caches
    try { pip cache purge } catch {}
    try { conda clean --all -y } catch {}
    try { npm cache clean --force } catch {}

    # Multi-Python pip cache
    $pythons = Get-ChildItem -Path "$env:USERPROFILE" -Recurse -Filter "python.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    foreach ($py in $pythons) {
        Write-Host "Purging pip cache for $py"
        & $py -m pip cache purge 2>$null
    }
}

# ---------------------- WINDOWS TEMP ----------------------
if (Ask-YesNo "Clear Windows temp files and Prefetch?") {
    Write-Host "`n--- Deleting system temp files ---`n"
    Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:windir\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:windir\Prefetch\*" -Force -ErrorAction SilentlyContinue
}

# ---------------------- SEARCH INDEX ----------------------
if (Ask-YesNo "Rebuild Windows Search index (delete old index)?") {
    Write-Host "`n--- Rebuilding Search index ---`n"
    net stop wsearch
    Remove-Item "C:\ProgramData\Microsoft\Search\Data" -Recurse -Force -ErrorAction SilentlyContinue
    if (Ask-YesNo "Turn Search service back on after cleanup?") {
        net start wsearch
    } else {
        Write-Host "Leaving Search service disabled."
    }
}

# ---------------------- BROWSERS ----------------------
if (Ask-YesNo "Clear browser caches (keep sessions/logins)?") {
    Write-Host "`n--- Cleaning browser caches ---`n"

    # Chromium family
    $chromiumPaths = @(
      "$env:LocalAppData\Google\Chrome*",
      "$env:LocalAppData\Microsoft\Edge*",
      "$env:LocalAppData\BraveSoftware\Brave-Browser*",
      "$env:LocalAppData\Comet",
      "$env:LocalAppData\Incognition"
    )
    foreach ($base in $chromiumPaths) {
        Get-ChildItem -Path $base -Directory -Recurse -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -in @("Cache","GPUCache","Code Cache","ShaderCache","Media Cache") } |
          ForEach-Object {
            Write-Host "Clearing Chromium cache: $($_.FullName)"
            Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
          }
    }

    # Firefox family
    $firefoxPaths = @(
      "$env:AppData\Mozilla\Firefox\Profiles\*",
      "$env:LocalAppData\Mullvad Browser\Browser\TorBrowser\Data\Browser\profile.default",
      "$env:LocalAppData\Tor Browser\Browser\TorBrowser\Data\Browser\profile.default"
    )
    foreach ($p in $firefoxPaths) {
        if (Test-Path "$p\cache2") {
            Write-Host "Clearing Firefox cache: $p"
            Remove-Item "$p\cache2" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "`n✅ Cleanup finished. Restart is recommended.`n"
# ======================================================================
