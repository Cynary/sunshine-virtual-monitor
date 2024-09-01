Import-Module WindowsDisplayManager

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

if ($args.Length -lt 1)
{
    Throw "Incorrect number of args: should pass VDD_NAME"
}

$vdd_name = $args[0]

# Might not work well if you have more than one GPU with displays attached. See https://github.com/patrick-theprogrammer/WindowsDisplayManager/issues/1
#
Write-Host "Removing the moonlight display."
Get-PnpDevice -FriendlyName $vdd_name | Disable-PnpDevice -Confirm:$false

$filePath = Split-Path $MyInvocation.MyCommand.source
$displayStateFile = Join-Path -Path $filePath -ChildPath "display_state.json"
$stateFile = Join-Path -Path $filePath -ChildPath "state.json"
$vsynctool = Join-Path -Path $filePath -ChildPath "vsynctoggle-1.1.0-x86_64.exe"
& $vsynctool (Get-Content -Raw $stateFile | ConvertFrom-Json).vsync

# Try a couple of times, it can sometimes take a couple of tries.
#
$counter = 0
while (! $(WindowsDisplayManager\UpdateDisplaysFromFile -filePath $displayStateFile -disableNotSpecifiedDisplays -validate))
{
    ++$counter
    if ($counter -gt 4)
    {
        Throw "Failure restoring display state from file."
    }
    sleep 2
}

Write-Host "Successfully removed the moonlight display."
