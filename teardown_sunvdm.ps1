Import-Module WindowsDisplayManager

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass


# + Choose the exact name of the Virtual Monitor to allow different versions without breaking the script.
$vdd_name = (
    Get-PnpDevice -Class Display | 
    Where-Object {
        $_.FriendlyName -like "*idd*" -or
        $_.FriendlyName -like "*mtt*" -or
        $_.FriendlyName -like "Virtual Display*"
    })[0].FriendlyName

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
