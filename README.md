# TASmaniac (Ambidextro TAS tool)

This is a tool for creating tool assisted speedruns for the game Ambidextro. You need a copy of the base game to run this tool (you can buy it on [Steam](https://store.steampowered.com/app/3445580/Ambidextro/)).

## Installation

1. Download the latest version of TASmaniac from [here](https://github.com/FeldrinH/TASmaniac/archive/refs/heads/main.zip) and unpack the ZIP file to a folder of your choosing.
2. Locate the Ambidextro install on your computer. This folder should contain `Ambidextro.exe`, `Ambidextro.pck` and a few other files. On Windows when playing through Steam it is located at `C:\Program Files (x86)\Steam\steamapps\common\Ambidextro`.
4. Copy all the files from your Ambidextro install location and paste them in the folder where you unpacked TASmaniac. The final contents of the folder should look like this:  
![image](https://github.com/user-attachments/assets/6f1d954f-8478-480b-97c5-b65454e1286e)

You now have a working installation of TASmaniac. Double-click `launch_tasmaniac.bat` (Windows), `launch_tasmaniac.linux.sh` (Linux) or `launch_tasmaniac.macos.sh` (macOS) to launch it.

Note: macOS support is provisional. I implemented it by looking at the Ambidextro macOS bundle, but I have not tested it because I do not own a Mac. If you encounter any problems, feel free to open an issue.

## Updating

1. Download the latest version of TASmaniac from [here](https://github.com/FeldrinH/TASmaniac/archive/refs/heads/main.zip).
2. Unpack the ZIP file to the folder with your existing TASmaniac installation. If you get a prompt about replacing existing files then pick the option to replace all.

You should now have an updated installation of TASmaniac. You can check the installed TASmaniac version by launching it and looking at the bottom right corner (the first version is Ambidextro version, second is TASmaniac version).

## Usage

TASmaniac has the following features:

* Record inputs while playing a level and save them to a text file.
* Play back the text file to reproduce the exact same sequence of inputs.
* Disable randomization of quantum cubes. Quantum cubes always appear in their default locations.
* Slow down time to make tricky moves easier to execute.
* Show a timer that indicates active time spent in the level. The timer starts on first input.
* Show player info including remaining coyote time, position, and velocity.
* Visualize player and hazard collision shapes.

TASmaniac is operated from a small menu that appears in the top left corner of the game:  
![image](https://github.com/user-attachments/assets/cbc2b0cd-6691-4c10-8e3c-c49c901157e9)

The time scale setting allows you to slow down in-game time. 1.0 is normal speed, smaller time scale values make time run slower. E.g. a time scale of 0.25 means that the game is 4 times slower than normal.

The input file dropdown allows you to either record a new sequence of inputs or play back an existing recording.
To record or play back a sequence of inputs simply select the action from the dropdown and launch a level. The recording/playback will start automatically.

All recordings are saved in a `recordings` folder inside your TASmaniac install folder and are named based on the level and completion time.
A recording is saved only if you successfully complete a level.

## WebSocket server

It is possible to run TASmaniac as a WebSocket server. This allows you to send requests to play levels with a provided list of inputs from any programming language that has a WebSocket client.
The levels are played with uncapped FPS, to evaluate inputs as fast as possible.

To start the WebSocket server, run `launch_tasmaniac_server.bat` or the equivalent script for your operating system.

For an example of how to communicate with the server API, see [tas_server.py](tas_server.py). For an example of a simple automatic optimizer using the WebSocket server see [optimize.py](optimize.py).

## Existing TAS run

The inputs for the current TAS run can be found [here](https://docs.google.com/spreadsheets/d/1kA16tzJ-diouDjB213JCW4X9J4LKVxMMdmYSAMIR64Y/edit?gid=0#gid=0). If you want to contribute to it then contact me on the [Ambidextro Speedrunning Discord](https://discord.gg/q7cB2sSQZn).
