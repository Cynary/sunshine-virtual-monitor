Import-Module WindowsDisplayManager

# Might not work well if you have more than one GPU with displays attached. See https://github.com/patrick-theprogrammer/WindowsDisplayManager/issues/1
#
Write-Host "Removing the moonlight display."
pnputil /disable-device /deviceid root\iddsampledriver

$filePath = Split-Path $MyInvocation.MyCommand.source
$stateFile = Join-Path -Path $filePath -ChildPath "display_state.json"

# Try a couple of times, it can sometimes take a couple of tries.
#
$counter = 0
while (! $(WindowsDisplayManager\UpdateDisplaysFromFile -filePath $stateFile -disableNotSpecifiedDisplays -validate))
{
    ++$counter
    if ($counter -gt 4)
    {
        Throw "Failure restoring display state from file."
    }
    sleep 2
}

Write-Host "Successfully removed the moonlight display."
