Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

Import-Module WindowsDisplayManager

$filePath = Split-Path $MyInvocation.MyCommand.source
$displayStateFile = Join-Path -Path $filePath -ChildPath "display_state.json"
$stateFile = Join-Path -Path $filePath -ChildPath "state.json"
$vsynctool = Join-Path -Path $filePath -ChildPath "vsynctoggle-1.1.0-x86_64.exe"
$multitool = Join-Path -Path $filePath -ChildPath "multimonitortool-x64\MultiMonitorTool.exe"

# + Choose the exact name of the Virtual Monitor to allow different versions without breaking the script.
$vdd_name = (
    Get-PnpDevice -Class Display |
    Where-Object {
        $_.FriendlyName -like "*idd*" -or
        $_.FriendlyName -like "*mtt*" -or
        $_.FriendlyName -like "Virtual Display*"
    } |
    Select-Object -First 1).FriendlyName

# Try a couple of times, it can sometimes take a couple of tries.
# Might not work well if you have more than one GPU with displays attached. See https://github.com/patrick-theprogrammer/WindowsDisplayManager/issues/1
#
function Restore-Displays($tries) {
    if (-not (Test-Path $displayStateFile)) { return $false }
    for ($i = 0; $i -lt $tries; $i++) {
        if ($i -gt 0) { Start-Sleep -Seconds 2 }
        try {
            if (WindowsDisplayManager\UpdateDisplaysFromFile -filePath $displayStateFile -disableNotSpecifiedDisplays -validate) { return $true }
        } catch {
            Write-Host "WARNING: restore attempt failed: $_"
        }
    }
    return $false
}

if (-not (Test-Path $displayStateFile)) {
    Write-Host "WARNING: $displayStateFile not found, cannot restore the saved display state"
}

if (Test-Path $stateFile) {
    try { & $vsynctool (Get-Content -Raw $stateFile | ConvertFrom-Json).vsync } catch { Write-Host "WARNING: could not restore vsync: $_" }
} else {
    Write-Host "WARNING: $stateFile not found, vsync left untouched"
}

if ($vdd_name) {
    Write-Host "Removing the moonlight display."
    Get-PnpDevice -FriendlyName $vdd_name | Disable-PnpDevice -Confirm:$false
    if ((Get-PnpDevice -FriendlyName $vdd_name).Status -eq "OK") { Write-Host "WARNING: the moonlight display is still enabled" }
} else {
    Write-Host "WARNING: virtual display device not found, nothing to remove"
}

# Remove the virtual display before restoring. WindowsDisplayManager matches
# sources and targets by id without the adapter id: with the virtual display
# still enabled, restoring can put the physical displays in duplicate mode on a
# single source, and Windows then saves that layout for the next sessions.
#
if (Restore-Displays 5) {
    Write-Host "Successfully removed the moonlight display."
} else {
    # Last resort: never leave the machine without an active display.
    Write-Host "WARNING: failure restoring display state from file, enabling every display"
    foreach ($d in (WindowsDisplayManager\GetAllPotentialDisplays | Where-Object { -not $_.active })) {
        & $multitool /enable $d.source.name
    }
    Start-Sleep -Seconds 2
    $active = @(WindowsDisplayManager\GetAllPotentialDisplays | Where-Object { $_.active })
    Write-Host "active displays after fallback: $($active.source.name -join ', ')"
}
