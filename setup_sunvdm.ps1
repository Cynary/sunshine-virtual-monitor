Import-Module WindowsDisplayManager

# Snapshot the current display state so we can restore it after the session.
#
if ($args.Length -lt 4)
{
    Throw "Incorrect number of args: should pass WIDTH HEIGHT REFRESH_RATE HDR{0|1}"
}

$filePath = Split-Path $MyInvocation.MyCommand.source
$stateFile = Join-Path -Path $filePath -ChildPath "display_state.json"

$initial_displays = WindowsDisplayManager\GetAllPotentialDisplays
if (! $(WindowsDisplayManager\SaveDisplaysToFile -displays $initial_displays -filePath $stateFile))
{
    Throw "Failure saving initial display state to file."
}

$width = [int]$args[0]
$height = [int]$args[1]
$refresh_rate = [int]$args[2]
$hdr = $args[3] -eq "true"
$hdr_string = if($hdr) { "on" } else { "off" }
Write-Host "Setting up a moonlight monitor with $($width)x$($height)@$($refresh_rate) with hdr $($hdr_string)"

Write-Host "Enabling the virtual display."
pnputil /enable-device /deviceid root\iddsampledriver

$displays = WindowsDisplayManager\GetAllPotentialDisplays
$multitool = Join-Path -Path $filePath -ChildPath "multimonitortool-x64\MultiMonitorTool.exe"

# Find the virtual display.
#
foreach ($display in $displays)
{
    if ($display.source.description -eq "IddSampleDriver Device HDR")
    {
        $vdDisplay = $display
    }
}

# First make sure the new virtual display is enabled, primary, and fully setup.
#
Write-Host "Setting up the virtual display."
& $multitool /enable $vdDisplay.source.name
& $multitool /setprimary $vdDisplay.source.name
$vdDisplay.SetResolution($width,$height,$refresh_rate)

# Now disable the other displays.
#
Write-Host "Disabling all other displays."
foreach ($display in $displays)
{
    if ($display.source.description -ne "IddSampleDriver Device HDR")
    {
        & $multitool /disable $display.source.name
    }
}

# This is a bit of a hack - due to https://github.com/patrick-theprogrammer/WindowsDisplayManager/issues/1 and https://github.com/patrick-theprogrammer/WindowsDisplayManager/issues/2, the HDR controls for the virtual display are actually in the first display via WindowsDisplayManager; it's also the reason we needed a different tool to enable/disable the displays despite iterating through the output of WindowsDisplayManager.
#
if($hdr)
{
    $displays[0].EnableHdr()
}
else
{
    $displays[0].DisableHdr()
}
