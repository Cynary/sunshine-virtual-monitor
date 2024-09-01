Import-Module WindowsDisplayManager

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Snapshot the current display state so we can restore it after the session.
#
if ($args.Length -lt 4)
{
    Throw "Incorrect number of args: should pass WIDTH HEIGHT REFRESH_RATE HDR{0|1} VDD_NAME"
}

$filePath = Split-Path $MyInvocation.MyCommand.source
$displayStateFile = Join-Path -Path $filePath -ChildPath "display_state.json"
$stateFile = Join-Path -Path $filePath -ChildPath "state.json"
$vsynctool = Join-Path -Path $filePath -ChildPath "vsynctoggle-1.1.0-x86_64.exe"
$state = @{ 'vsync' = & $vsynctool status }

$initial_displays = WindowsDisplayManager\GetAllPotentialDisplays
if (! $(WindowsDisplayManager\SaveDisplaysToFile -displays $initial_displays -filePath $displayStateFile))
{
    Throw "Failure saving initial display state to file."
}

ConvertTo-Json $state | Out-File -FilePath $stateFile

& $vsynctool off

$width = [int]$args[0]
$height = [int]$args[1]
$refresh_rate = [int]$args[2]
$hdr = $args[3] -eq "true"
$hdr_string = if($hdr) { "on" } else { "off" }
$vdd_name = if ($args[3] -ne "true" -and $args[3] -ne "false") { $args[3] } else { $args[4] }
Write-Host "Setting up a moonlight monitor with $($width)x$($height)@$($refresh_rate) with hdr $($hdr_string)"

Write-Host "Enabling the virtual display."
Get-PnpDevice -FriendlyName $vdd_name | Enable-PnpDevice -Confirm:$false

$displays = WindowsDisplayManager\GetAllPotentialDisplays
$multitool = Join-Path -Path $filePath -ChildPath "multimonitortool-x64\MultiMonitorTool.exe"

# Find the virtual display.
#
foreach ($display in $displays)
{
    if ($display.source.description -eq $vdd_name)
    {
        $vdDisplay = $display
    }
}

$other_displays = $displays | Where-Object {$_.source.description -ne $vdd_name}

# First make sure the new virtual display is enabled, primary, and fully setup.
#
Write-Host "Setting up the virtual display and disabling other displays."

# This is probably optional, but running it prior to getting the refreshed status just in case of weirdness.
#
& $multitool /enable $vdDisplay.source.name
& $multitool /setprimary $vdDisplay.source.name

# Now disable the other displays.
$retries = 0
Write-Host "Disabling all other displays."
$names = $other_displays | ForEach-Object { $_.source.name }
while(($other_displays | ForEach-Object {WindowsDisplayManager\GetRefreshedDisplay($_)} | Where-Object {$_.active}).Length -gt 0)
{
    # Important to set the monitor as primary before removing other displays since windows doesn't allow disabling the current primary display.
    #
    & $multitool /enable $vdDisplay.source.name
    & $multitool /setprimary $vdDisplay.source.name
    & $multitool /disable $names

    if($retries++ -eq 100)
    {
        Throw "Failed to disable all other displays."
    }
}

# Important to set resolution once all other displays are gone, or windows can change the resolution when the display config changes.
#
$vdDisplay.SetResolution($width,$height,$refresh_rate)

if ($vdDisplay.source.description -eq $vdd_name -and ${WindowsDisplayManager\GetRefreshedDisplay($displays[0]).hdrInfo.hdrSupported})
{
    # This is a bit of a hack - due to https://github.com/patrick-theprogrammer/WindowsDisplayManager/issues/1 and https://github.com/patrick-theprogrammer/WindowsDisplayManager/issues/2, the HDR controls for the virtual display are actually in the first display via WindowsDisplayManager; it's also the reason we needed a different tool to enable/disable the displays despite iterating through the output of WindowsDisplayManager.
    #
    if($hdr)
    {
        $retries = 0
        while(!($display = WindowsDisplayManager\GetRefreshedDisplay($displays[0])).hdrInfo.hdrEnabled)
        {
            $display.EnableHdr()
            if($retries++ -eq 100)
            {
                Throw "Failed to enable HDR."
            }
        }
    }
    else
    {
        $retries = 0
        while(($display = WindowsDisplayManager\GetRefreshedDisplay($displays[0])).hdrInfo.hdrEnabled)
        {
            $display.DisableHdr()
            if($retries++ -eq 100)
            {
                Throw "Failed to disable HDR."
            }
        }
    }
}