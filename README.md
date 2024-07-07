# Sunshine Automatic Virtual Monitor

This repository stores and documents scripts for automatically setting up a virtual display monitor for sunshine, blacking out the host computer displays, and then tearing down the new screen, and undoing turning off the displays.

## Warning

This should be considered BETA - it is working well for me, but at the time of writing this no one else has tested it so far.

While I'm pretty confident this will not break your computer, I don't know enough about Windows Drivers to be 100% sure.  Further, there is a real risk that your displays won't come back after a streaming sesion if there is some issue with Sunshine or the scripts - during development and testing I hit quite a few of those cases; I'm confident it shouldn't happen during normal operation anymore, but just in case it does, you can escape in a few ways:

- If your displays don't come back, but sunshine is still running, you can get back in the stream and fix things up:
    - Disable the display device - you can run the command `pnputil /disable-device /deviceid root\iddsampledriver` from a privileged terminal.  If you want to be extra secure you can try to bind this to some key combination ahead of time (make sure it runs as admin).
- If you can't access the sunshine stream for whatever reason, you can try a couple of things:
    - Pres windows key + write "terminal" + press Enter + write "DisplaySwitch 1" + press Enter.  This should enable only your primary display, which should not be the virtual monitor, allowing you to fix things up.
    - Press windows + P to get into the display selection dialogue, then tab + move around to select something different from the current setup.  I recommend practicing this ahead of time if you want to go this route, just so you have an idea of what it feels like; in the broken case it should have the "second screen only" option pre-selected.
    - Connect another display to your computer - this will cause windows to try and apply a new configuration to the displays that should get signal on at least one of the real ones.
    - If you already have a second monitor, disconnect it - similar to the point above, might result in getting signal back.

## Dependencies

### Virtual Display Driver

First, you'll need to add a virtual display to your computer.  You can follow the directions at https://github.com/itsmikethetech/Virtual-Display-Driver - afaict, this is the only way to get HDR support on a virtual monitor.  Note: while the driver and device will exist, they will be disabled while sunshine isn't being used.

Once you're done adding the device, make sure to disable it.  You can do this in device manager, or you can run the following command in an administrator terminal:

```
pnputil /disable-device /deviceid root\iddsampledriver
```

Note: the resolutions supported by the driver are listed in a file called `options.txt`, and are read when the driver is setup.  This file has a decent collection of resolutions and refresh rates, but it might be fairly incomplete - in particular, it doesn't necessarily list many common phone resolutions, and it lacks higher refresh rates for resolutions other than 1080p.  I recommend going through your client devices and figuring out which resolutions and refresh rates they have, and adding those to the `options.txt` file (or making an `options.txt` file with only those resolutions so it's easier to navigate) before installing the driver.  If you need to add resolutions in the future, you would simply uninstall the driver, edit the `options.txt` file, and reinstall the driver - this is a relatively easy and quick process that is documented in the driver repository. I would also recommend setting up the supported resolutions in sunshine to match those of the `options.txt` file.

### Multi Monitor Tool

Then, you'll need to download multimonitortool at https://www.nirsoft.net/utils/multi_monitor_tool.html - make sure to place the extracted files in the same directory as the scripts.  These scripts assume that the multi-monitor-tool in use is the 64-bit version - if you need the 32 bit version, you'll need to edit this line for the correct path:

```
$multitool = Join-Path -Path $filePath -ChildPath "multimonitortool-x64\MultiMonitorTool.exe"
```

### Windows Display Manager

The powershell scripts use a module called `WindowsDisplayManager` (https://github.com/patrick-theprogrammer/WindowsDisplayManager) - you can install this by starting a privileged powershell, and running:

```
Install-Module -Name WindowsDisplayManager
```

## Sunshine Setup

In all the text below, replace `%PATH_TO_THIS_REPOSITORY%` with the full path to this repository.

Note that the commands below will forward the scripts output to a file in this repository, named `sunvdm.log` - this is optional and can be removed if you don't care for logs / can be directed somewhere else.

### UI

In the sunshine UI navigate to Configuration, and go to the General Tab.

At the bottom, in the `Command Preparations` section, you will press the `+Add` button to add a new command, with the following setup:

In the first text box the `config.do_cmd` column, you will write:

```
cmd /C powershell.exe -File %PATH_TO_THIS_REPOSITORY%\setup_sunvdm.ps1 %SUNSHINE_CLIENT_WIDTH% %SUNSHINE_CLIENT_HEIGHT% %SUNSHINE_CLIENT_FPS% %SUNSHINE_CLIENT_HDR% > %PATH_TO_THIS_REPOSITORY%\sunvdm.log 2>&1
```

In the second text box, the `config.undo_cmd` column, you will write:

```
cmd /C powershell.exe -File %PATH_TO_THIS_REPOSITORY%\teardown_sunvdm.ps1 >> %PATH_TO_THIS_REPOSITORY%\sunvdm.log 2>&1
```

You will also select the checkbox for `config.elevated` under the `config.run_as` column (we need to run as elevated in order to enable and disable the display device).

### Config File

You can set the following in your `sunshine.conf` config file:

```
global_prep_cmd = [{"do":"cmd /C powershell.exe -File %PATH_TO_THIS_REPOSITORY%\\setup_sunvdm.ps1 %SUNSHINE_CLIENT_WIDTH% %SUNSHINE_CLIENT_HEIGHT% %SUNSHINE_CLIENT_FPS% %SUNSHINE_CLIENT_HDR% > %PATH_TO_THIS_REPOSITORY%\\sunvdm.log 2>&1","undo":"cmd /C powershell.exe -File %PATH_TO_THIS_REPOSITORY%\\teardown_sunvdm.ps1 >> %PATH_TO_THIS_REPOSITORY%\\sunvdm.log 2>&1","elevated":"true"}]
```

If you already have something in the `global_prep_cmd` that you setup, you should be savvy enough to know where/how to add this to the list.
