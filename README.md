<h1 align='center'>Sunshine Virtual Monitor</h1>
<p align="center">
    Sunshine Virtual Monitor provides a way to automatically enable a <b>dedicated Virtual Display Monitor</b> for your Sunshine Streaming Sessions.<br>
    It deactivates all the other monitors while streaming and activate them back when the stream is finished.
</p>


# Table of Contents
- [Disclaimer](#disclaimer)
- [Setup](#setup)
    - [Virtual Display Driver](#virtual-display-driver)
    - [Multi Monitor Tool](#multi-monitor-tool)
    - [Windows Display Manager](#windows-display-manager)
    - [VSYNC Toggle](#vsync-toggle)
    - [Scripts Directory Files](#scripts-directory-files)
- [Sunshine Setup](#sunshine-setup)
    - [Option 1 - UI](#option-1---ui)
    - [Option 2 - Config File](#option-2---config-file)


## Disclaimer

> [!CAUTION]
> This should be considered **BETA** - it is working well for me, but at the time of writing this no one else has tested it so far.

While I'm pretty confident this will not break your computer, I don't know enough about Windows Drivers to be 100% sure.  Further, there is a **real risk** that your displays won't come back after a streaming sesion if there is some issue with Sunshine or the scripts - during development and testing I hit quite a few of those cases; I'm confident it shouldn't happen during normal operation anymore, but just in case it does, you can escape in a few ways:

- If your displays don't come back, but sunshine is still running, you can get back in the stream and fix things up:
    - Run this command from a privileged terminal to disable the virtual display.
    ```batch
    pnputil /disable-device /deviceid root\iddsampledriver
    ```

> [!NOTE]
> If you want to be extra secure you can try to bind this command to some key combination ahead of time (make sure it runs as admin).
>
> To do this, create a new shortcut on Desktop (`Right Click` > `New` > `Shortcut`) and copy/paste the command above (`pnputil /disable-device /deviceid root\iddsampledriver`) in the path box.
>
> Give it a name like `Disable Virtual Display Driver` and close the window. Now go to the file properties and click in the `Shortcut Key` area, then enter a combination of keys to create the shortcut. (e.g. `Ctrl` + `Alt` + `5`)
>
> Open the `Advanced...` box and check the `Run as administrator` checkbox.
>
> Save and close.

- If you can't access the sunshine stream for whatever reason, you can try a couple of things:
    - Open a Windows Terminal and run this command:
    ```batch
    DisplaySwitch 1
    ```

> [!NOTE]
> This should enable only your primary display, which should not be the virtual monitor, allowing you to fix things up.

-
    - Press `Windows + P` to get into the display selection dialogue, then press `Tab` + move around to select something different from the current setup. I recommend practicing this ahead of time if you want to go this route, just so you have an idea of what it feels like; in the broken case it should have the "second screen only" option pre-selected.
    
    - Connect another display to your computer - this will cause windows to try and apply a new configuration to the displays that should get signal on at least one of the real ones.
    
    - If you already have a second monitor, disconnect it - similar to the point above, might result in getting signal back.


## Setup

First, download the [latest release](https://github.com/Cynary/sunshine-virtual-monitor/releases/latest) (`.zip` file) and unzip it.


### Virtual Display Driver

Then, you'll need to add a virtual display to your computer.  You can follow the directions from [Virtual Display Driver](https://github.com/itsmikethetech/Virtual-Display-Driver?tab=readme-ov-file#virtual-display-driver) - afaict, this is the only way to get HDR support on a virtual monitor.  Note: while the driver and device will exist, they will be disabled while sunshine isn't being used.

Once you're done adding the device, make sure to disable it.  You can do this in device manager, or you can run the following command in an administrator terminal:

```batch
pnputil /disable-device /deviceid root\iddsampledriver
```


### Multi Monitor Tool

Then, you'll need to download [MultiMonitorTool](https://www.nirsoft.net/utils/multi_monitor_tool.html) - make sure to place the extracted files in the same directory as the scripts.  These scripts assume that the multi-monitor-tool in use is the 64-bit version - if you need the 32 bit version, you'll need to edit this line for the correct path:

```batch
$multitool = Join-Path -Path $filePath -ChildPath "multimonitortool-x64\MultiMonitorTool.exe"
```


### Windows Display Manager

The powershell scripts use a module called [`WindowsDisplayManager`](https://github.com/patrick-theprogrammer/WindowsDisplayManager) - you can install this by starting a privileged powershell, and running:

```batch
Install-Module -Name WindowsDisplayManager
```


### VSYNC Toggle

This is used to turn off / restore vsync when the stream starts/ends.

Just download [vsync-toggle](https://github.com/xanderfrangos/vsync-toggle/releases/latest) and put it in the same directory as the scripts.

### Scripts directory files

After the steps above, the scripts directory will look like this

LICENSE

multimonitortool-x64 (directory)

README.md

setup_sunvdm.ps1

teardown_sunvdm.ps1

vsynctoggle-1.1.0-x86_64.exe


## Sunshine Setup

In all the text below, replace `%PATH_TO_THIS_REPOSITORY%` with the full path to this repository.

> [!NOTE]
> The commands below will forward the scripts output to a file in this repository, named `sunvdm.log` - this is optional and can be removed if you don't care for logs / can be directed somewhere else.


### Option 1 - UI

In the sunshine UI navigate to Configuration, and go to the General Tab.

At the bottom, in the `Command Preparations` section, you will press the `+Add` button to add a new command, with the following setup:

In the first text box the `config.do_cmd` column, you will write:

```batch
cmd /C powershell.exe -executionpolicy bypass -windowstyle hidden -file "%PATH_TO_THIS_REPOSITORY%\setup_sunvdm.ps1" > "%PATH_TO_THIS_REPOSITORY%\sunvdm.log" 2>&1
```

In the second text box, the `config.undo_cmd` column, you will write:

```batch
cmd /C powershell.exe -executionpolicy bypass -windowstyle hidden -file "%PATH_TO_THIS_REPOSITORY%\teardown_sunvdm.ps1" >> "%PATH_TO_THIS_REPOSITORY%\sunvdm.log" 2>&1
```

> [!WARNING]
> Make sure to replace `%PATH_TO_THIS_REPOSITORY%` with the correct path to the folder containing the scripts.

> [!NOTE]
> You will also select the checkbox for `config.elevated` under the `config.run_as` column (we need to run as elevated in order to enable and disable the display device).


### Option 2 - Config File

You can set the following in your `sunshine.conf` config file:

```batch
global_prep_cmd = [{"do":"cmd /C powershell.exe -executionpolicy bypass -windowstyle hidden -file \"%PATH_TO_THIS_REPOSITORY%\\setup_sunvdm.ps1\" > \"%PATH_TO_THIS_REPOSITORY%\\sunvdm.log\" 2>&1","undo":"cmd /C powershell.exe -executionpolicy bypass -windowstyle hidden -file \"%PATH_TO_THIS_REPOSITORY%\\teardown_sunvdm.ps1\" >> \"%PATH_TO_THIS_REPOSITORY%\\sunvdm.log\" 2>&1","elevated":"true"}]
```

> [!NOTE]
> If you already have something in the `global_prep_cmd` that you setup, you should be savvy enough to know where/how to add this to the list.
