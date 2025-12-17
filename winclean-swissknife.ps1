# ======================================================================
# INTERACTIVE FULL CLEANUP – SAFE VERSION WITH GUI + PIXELDRAIN BACKUP
# You decide what gets deleted via checkboxes. Optional backup upload.
# ======================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ---------------------- HELPERS ----------------------
function Ask-YesNo ($msg) {
    $ans = Read-Host "$msg (y/n)"
    return ($ans -match '^[Yy]')
}

function New-BackupZip {
    param(
        [string[]] $PathsToArchive,
        [string]   $WorkDir
    )
    if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir | Out-Null }
    $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $zipPath   = Join-Path $WorkDir "cleanup-backup-$timestamp.zip"
    # Filter to existing paths to avoid Compress-Archive errors
    $existing = $PathsToArchive | Where-Object { Test-Path $_ }
    if (-not $existing) { return $null }
    try {
        Compress-Archive -Path $existing -DestinationPath $zipPath -CompressionLevel Optimal -Force
        return $zipPath
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to create ZIP: $($_.Exception.Message)","Backup error",
            [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return $null
    }
}

function Upload-Pixeldrain {
    param(
        [string] $FilePath,
        [string] $ApiKey  # optional; if blank uploads anonymously
    )
    if (-not (Test-Path $FilePath)) { return $null }

    $uri     = "https://pixeldrain.com/api/file"
    $headers = @{}
    if ($ApiKey) {
        $token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$ApiKey"))
        $headers["Authorization"] = "Basic $token"
    }

    try {
        $resp = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Form @{ file = Get-Item $FilePath }
        return $resp
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Pixeldrain upload failed: $($_.Exception.Message)","Upload error",
            [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return $null
    }
}

function Save-BackupMetadata {
    param(
        [object] $Response,
        [string] $ZipPath
    )
    if (-not $Response) { return }
    $meta = [PSCustomObject]@{
        uploaded_at = (Get-Date)
        zip_path    = $ZipPath
        pixeldrain  = $Response
    }
    $metaPath = [IO.Path]::ChangeExtension($ZipPath, ".pixeldrain.json")
    $meta | ConvertTo-Json -Depth 6 | Set-Content -Path $metaPath -Encoding UTF8
}

# ---------------------- TARGET SETS ----------------------
function Get-DevCacheTargets {
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

    # node_modules folders
    $nodeModules = Get-ChildItem -Path "$env:USERPROFILE" -Directory -Recurse -Force -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -eq "node_modules" } |
      Select-Object -ExpandProperty FullName
    $targets += $nodeModules

    return $targets
}

function Get-WindowsTempTargets {
    return @(
        "$env:TEMP\*",
        "$env:windir\Temp\*",
        "$env:windir\Prefetch\*"
    )
}

function Get-SearchIndexTargets {
    return @("C:\ProgramData\Microsoft\Search\Data")
}

function Get-BrowserCacheTargets {
    $chromiumPaths = @(
      "$env:LocalAppData\Google\Chrome*",
      "$env:LocalAppData\Microsoft\Edge*",
      "$env:LocalAppData\BraveSoftware\Brave-Browser*",
      "$env:LocalAppData\Comet",
      "$env:LocalAppData\Incognition"
    )
    $chromiumCache = foreach ($base in $chromiumPaths) {
        Get-ChildItem -Path $base -Directory -Recurse -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -in @("Cache","GPUCache","Code Cache","ShaderCache","Media Cache") } |
          Select-Object -ExpandProperty FullName
    }

    $firefoxPaths = @(
      "$env:AppData\Mozilla\Firefox\Profiles\*",
      "$env:LocalAppData\Mullvad Browser\Browser\TorBrowser\Data\Browser\profile.default",
      "$env:LocalAppData\Tor Browser\Browser\TorBrowser\Data\Browser\profile.default"
    )
    $firefoxCache = foreach ($p in $firefoxPaths) {
        if (Test-Path "$p\cache2") { "$p\cache2" }
    }

    return @($chromiumCache + $firefoxCache)
}

# ---------------------- MAIN CLEAN LOGIC ----------------------
function Run-Cleanup {
    param(
        [bool]   $DoDevCaches,
        [bool]   $DoWindowsTemp,
        [bool]   $DoSearchIndex,
        [bool]   $RestartSearchService,
        [bool]   $DoBrowserCaches,
        [bool]   $DoBackup,
        [string] $PixeldrainKey
    )

    $allTargets = @()

    if ($DoDevCaches)    { $allTargets += Get-DevCacheTargets }
    if ($DoWindowsTemp)  { $allTargets += Get-WindowsTempTargets }
    if ($DoSearchIndex)  { $allTargets += Get-SearchIndexTargets }
    if ($DoBrowserCaches){ $allTargets += Get-BrowserCacheTargets }

    $backupZip = $null
    if ($DoBackup -and $allTargets.Count -gt 0) {
        $backupZip = New-BackupZip -PathsToArchive $allTargets -WorkDir "$env:TEMP\winclean-backups"
        if ($backupZip) {
            $resp = Upload-Pixeldrain -FilePath $backupZip -ApiKey $PixeldrainKey
            Save-BackupMetadata -Response $resp -ZipPath $backupZip
            if ($resp) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Backup uploaded. ID: $($resp.id)`nLink: $($resp.link)`nMetadata saved next to ZIP.",
                    "Backup uploaded",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
            }
        }
    }

    # --- Delete sections ---
    if ($DoDevCaches) {
        Write-Host "`n--- Deleting developer caches ---`n"
        foreach ($path in (Get-DevCacheTargets)) {
            if (Test-Path $path) {
                Write-Host "Deleting $path"
                Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        try { pip cache purge } catch {}
        try { conda clean --all -y } catch {}
        try { npm cache clean --force } catch {}
        $pythons = Get-ChildItem -Path "$env:USERPROFILE" -Recurse -Filter "python.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        foreach ($py in $pythons) {
            Write-Host "Purging pip cache for $py"
            & $py -m pip cache purge 2>$null
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
    }

    if ($DoWindowsTemp) {
        Write-Host "`n--- Deleting system temp files ---`n"
        Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:windir\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:windir\Prefetch\*" -Force -ErrorAction SilentlyContinue
    }

    if ($DoSearchIndex) {
        Write-Host "`n--- Rebuilding Search index ---`n"
        net stop wsearch | Out-Null
        Remove-Item "C:\ProgramData\Microsoft\Search\Data" -Recurse -Force -ErrorAction SilentlyContinue
        if ($RestartSearchService) {
            net start wsearch | Out-Null
        } else {
            Write-Host "Leaving Search service disabled."
        }
    }

    if ($DoBrowserCaches) {
        Write-Host "`n--- Cleaning browser caches ---`n"
        # Chromium
        foreach ($base in @(
          "$env:LocalAppData\Google\Chrome*",
          "$env:LocalAppData\Microsoft\Edge*",
          "$env:LocalAppData\BraveSoftware\Brave-Browser*",
          "$env:LocalAppData\Comet",
          "$env:LocalAppData\Incognition"
        )) {
            Get-ChildItem -Path $base -Directory -Recurse -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -in @("Cache","GPUCache","Code Cache","ShaderCache","Media Cache") } |
              ForEach-Object {
                Write-Host "Clearing Chromium cache: $($_.FullName)"
                Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
              }
        }
        # Firefox family
        foreach ($p in @(
          "$env:AppData\Mozilla\Firefox\Profiles\*",
          "$env:LocalAppData\Mullvad Browser\Browser\TorBrowser\Data\Browser\profile.default",
          "$env:LocalAppData\Tor Browser\Browser\TorBrowser\Data\Browser\profile.default"
        )) {
            if (Test-Path "$p\cache2") {
                Write-Host "Clearing Firefox cache: $p"
                Remove-Item "$p\cache2" -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    [System.Windows.Forms.MessageBox]::Show("✅ Cleanup finished. Restart is recommended.","Done",
        [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
}

# ---------------------- GUI ----------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Windows Dev Cleaner"
$form.Size = New-Object System.Drawing.Size(460,380)
$form.StartPosition = "CenterScreen"

$y = 20
function Add-Checkbox([string]$text,[int]$yPos,[bool]$default=$true) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $text
    $cb.AutoSize = $true
    $cb.Location = New-Object System.Drawing.Point(20,$yPos)
    $cb.Checked = $default
    $form.Controls.Add($cb)
    return $cb
}

$cbDevCaches    = Add-Checkbox "Developer caches & build artifacts (npm/pip/conda/docker/gradle/flutter/etc.)" $y; $y+=25
$cbWindowsTemp  = Add-Checkbox "Windows temp files & Prefetch" $y; $y+=25
$cbSearchIndex  = Add-Checkbox "Rebuild Windows Search index (stop + delete index)" $y; $y+=25
$cbSearchRestart= Add-Checkbox "Turn Search service back on after cleanup" $y $true; $y+=25
$cbBrowserCache = Add-Checkbox "Browser caches (Chromium + Firefox family)" $y; $y+=25

$cbBackup       = Add-Checkbox "Create ZIP backup and upload to Pixeldrain before deleting" $y $false; $y+=30

$lblKey = New-Object System.Windows.Forms.Label
$lblKey.Text = "Pixeldrain API key (leave blank for anonymous upload):"
$lblKey.AutoSize = $true
$lblKey.Location = New-Object System.Drawing.Point(20,$y)
$form.Controls.Add($lblKey); $y+=20

$txtKey = New-Object System.Windows.Forms.TextBox
$txtKey.Width = 380
$txtKey.Location = New-Object System.Drawing.Point(20,$y)
$txtKey.UseSystemPasswordChar = $true
$form.Controls.Add($txtKey); $y+=40

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Run Cleanup"
$btnRun.Width = 120
$btnRun.Location = New-Object System.Drawing.Point(20,$y)
$form.Controls.Add($btnRun)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancel"
$btnCancel.Width = 100
$btnCancel.Location = New-Object System.Drawing.Point(160,$y)
$form.Controls.Add($btnCancel)

$btnCancel.Add_Click({ $form.Close() })
$btnRun.Add_Click({
    $form.Enabled = $false
    Run-Cleanup `
        -DoDevCaches    $cbDevCaches.Checked `
        -DoWindowsTemp  $cbWindowsTemp.Checked `
        -DoSearchIndex  $cbSearchIndex.Checked `
        -RestartSearchService $cbSearchRestart.Checked `
        -DoBrowserCaches $cbBrowserCache.Checked `
        -DoBackup       $cbBackup.Checked `
        -PixeldrainKey  $txtKey.Text
    $form.Enabled = $true
})

[void]$form.ShowDialog()
# ======================================================================
