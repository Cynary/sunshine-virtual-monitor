Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

Import-Module WindowsDisplayManager

# ----------------------------
# helpers: env-first parsing
# ----------------------------
function Get-Int($envName, $argIndex) {
    $v = [Environment]::GetEnvironmentVariable($envName)
    if ($v) { return [int]$v }
    if ($args.Length -gt $argIndex) { return [int]$args[$argIndex] }
    Throw "missing $envName"
}

function Get-Bool($envName, $argIndex) {
    $v = [Environment]::GetEnvironmentVariable($envName)
    if ($v) { return $v -match '^(1|true|yes)$' }
    if ($args.Length -gt $argIndex) { return $args[$argIndex] -match '^(1|true|yes)$' }
    return $false
}

# ----------------------------
# sunshine parameters
# ----------------------------
$width        = Get-Int  "SUNSHINE_CLIENT_WIDTH"  0
$height       = Get-Int  "SUNSHINE_CLIENT_HEIGHT" 1
$refresh_rate = Get-Int  "SUNSHINE_CLIENT_FPS"    2
$hdr          = Get-Bool "SUNSHINE_CLIENT_HDR"    3
$hdr_string   = if ($hdr) { "on" } else { "off" }

Write-Host "sunshine params: ${width}x${height}@${refresh_rate} hdr=${hdr_string}"

# ----------------------------
# paths / tools
# ----------------------------
$filePath = Split-Path $MyInvocation.MyCommand.Source
$displayStateFile = Join-Path $filePath "display_state.json"
$stateFile        = Join-Path $filePath "state.json"
$vsynctool        = Join-Path $filePath "vsynctoggle-1.1.0-x86_64.exe"
$multitool        = Join-Path $filePath "multimonitortool-x64\MultiMonitorTool.exe"
$option_file_path = "C:\IddSampleDriver\option.txt"
# --- patch VDD driver XML with requested resolution if missing ---
$driverConfig = "C:\VirtualDisplayDriver\vdd_settings.xml"
# load XML
[xml]$xml = Get-Content $driverConfig

# ----------------------------
# snapshot current state
# ----------------------------
$state = @{ vsync = & $vsynctool status }
if ($state.vsync -like "*default*") { $state.vsync = "default" }
ConvertTo-Json $state | Out-File $stateFile

$initial_displays = WindowsDisplayManager\GetAllPotentialDisplays
if (!(WindowsDisplayManager\SaveDisplaysToFile -displays $initial_displays -filePath $displayStateFile)) {
    Throw "failed to save initial display state"
}

& $vsynctool off

# ----------------------------
# find virtual display device
# ----------------------------
$vdd_name = (
    Get-PnpDevice -Class Display |
    Where-Object {
        $_.FriendlyName -like "*idd*" -or
        $_.FriendlyName -like "*mtt*" -or
        $_.FriendlyName -like "Virtual Display*"
    }
)[0].FriendlyName

if (-not $vdd_name) {
    Throw "virtual display device not found"
}

# check if resolution exists
$resFound = $xml.vdd_settings.resolutions.resolution | Where-Object {
    $_.width -eq $width -and $_.height -eq $height -and $_.refresh -eq $refresh_rate
}

if (-not $resFound) {
    Write-Host "Resolution $width x $height @$refresh_rate not in driver XML. Adding it..."
    
    # create new <resolution> node
    $newRes = $xml.CreateElement("resolution")
    $wNode = $xml.CreateElement("width"); $wNode.InnerText = $width; $newRes.AppendChild($wNode) > $null
    $hNode = $xml.CreateElement("height"); $hNode.InnerText = $height; $newRes.AppendChild($hNode) > $null
    $rNode = $xml.CreateElement("refresh"); $rNode.InnerText = $refresh_rate; $newRes.AppendChild($rNode) > $null

    # append it
    $xml.vdd_settings.resolutions.AppendChild($newRes) > $null

    # save back
    $xml.Save($driverConfig)
    Write-Host "Driver XML patched, restarting Virtual Display Driver..."

    # restart driver service (change service name if yours differs)
    Get-PnpDevice -FriendlyName $vdd_name | Disable-PnpDevice -Confirm:$false

    Write-Host "Driver restarted, XML changes applied."
}

# ----------------------------
# ensure option.txt contains mode
# ----------------------------
if (!(Test-Path $option_file_path)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $option_file_path) | Out-Null
    Set-Content -Path $option_file_path -Value "1"
}

$option_to_check = "$width, $height, $refresh_rate"
if ((Get-Content $option_file_path) -notcontains $option_to_check) {
    Add-Content -Path $option_file_path -Value $option_to_check
}

Write-Host "setting up virtual display ${width}x${height}@${refresh_rate} hdr ${hdr_string}"

# ----------------------------
# enable virtual display
# ----------------------------
Get-PnpDevice -FriendlyName $vdd_name | Enable-PnpDevice -Confirm:$false

# ---------------------------
# display convergence loop
# ---------------------------
$retries = 0
while ($true) {
    $displays = WindowsDisplayManager\GetAllPotentialDisplays

    $virtual = $displays | Where-Object { $_.source.description -eq $vdd_name } | Select-Object -First 1

    if (-not $virtual) { Throw "virtual display vanished" }

    # refresh active displays each iteration
    $active = $displays | Where-Object { $_.active }

    # done if only virtual
    if ($virtual.active -and $active.Count -le 2) { break }

    # ensure virtual display is primary
    & $multitool /enable $virtual.source.name
    & $multitool /setprimary $virtual.source.name

    # disable any extra displays
    $extra = $active | Where-Object { $_.source.name -ne $virtual.source.name }
    foreach ($d in $extra) {
        # try { $d.SetResolution(1,1,$d.CurrentRefreshRate) } catch {}
        Write-Host "disabling $d"
        & $multitool /disable $d.source.name
    }

    Start-Sleep -Milliseconds 300

    if ($retries++ -ge 40) { Throw "failed to converge display topology safely" }
}

Write-Host "sunshine display diable complete"

# ----------------------------
# set virtual resolution LAST
# ----------------------------
$virtual.SetResolution($width, $height, $refresh_rate)

# ----------------------------
# hdr toggle (windowsdisplaymanager hack)
# ----------------------------
$displays = WindowsDisplayManager\GetAllPotentialDisplays
$hdr_host = WindowsDisplayManager\GetRefreshedDisplay($displays[0])

if ($hdr_host.hdrInfo.hdrSupported) {
    if ($hdr) {
        $i = 0
        while (-not $hdr_host.hdrInfo.hdrEnabled) {
            $hdr_host.EnableHdr() | Out-Null
            if ($i++ -ge 50) { Throw "failed to enable hdr" }
            Start-Sleep -Milliseconds 200
            $hdr_host = WindowsDisplayManager\GetRefreshedDisplay($displays[0])
        }
    } else {
        $i = 0
        while ($hdr_host.hdrInfo.hdrEnabled) {
            $hdr_host.DisableHdr() | Out-Null
            if ($i++ -ge 50) { Throw "failed to disable hdr" }
            Start-Sleep -Milliseconds 200
            $hdr_host = WindowsDisplayManager\GetRefreshedDisplay($displays[0])
        }
    }
}

Write-Host "sunshine display setup complete (rdp intact)"
