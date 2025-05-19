# TASManiac (Ambidextro TAS tool)

This is a tool for creating tool assisted speedruns for the game Ambidextro. You need a copy of the base game to run this tool (you can buy it on [Steam](https://store.steampowered.com/app/3445580/Ambidextro/)).

## Installation

1. Download the latest version of TASmaniac from [here](https://github.com/FeldrinH/TASmaniac/archive/refs/heads/main.zip) and unpack the ZIP file to a folder of your choosing.
2. Locate the Ambidextro install on your computer. This folder should contain `Ambidextro.exe`, `Ambidextro.pck` and a few other files. On Windows when playing through Steam it is located at `C:\Program Files (x86)\Steam\steamapps\common\Ambidextro`.
4. Copy all the files from your Ambidextro install location and paste them in the folder where you unpacked TASmaniac.  
   The final contents of the folder should look like this:  
![image](https://github.com/user-attachments/assets/6f1d954f-8478-480b-97c5-b65454e1286e)

You now have a working installation of TASmaniac. Double-click `launch_tasmaniac.bat` (Windows) or `launch_tasmaniac.sh` (Linux) to launch it.

## Usage

TASmaniac has the following features:

* Record inputs while playing a level and save them to a text file.
* Play back the text file to reproduce the exact same sequence of inputs.
* Disable randomization of quantum cubes. Quantum cubes always appear in their default locations.
* Slow down time to make tricky moves easier to execute.
* Show a timer that indicates active time spent in the level. The timer starts on first input.

TASmaniac is operated from a small menu that appears in the top left corner of the game:
![image](https://github.com/user-attachments/assets/de3022c4-6711-493e-a78f-77ff525c1396)

The time scale setting allows you to slow down in-game time. 1.0 is normal speed, smaller time scale values make time run slower. E.g. a time scale of 0.25 means that the game is 4 times slower than normal.

The input file dropdown allows you to either record a new sequence of inputs or play back an existing recording.
To record or play back a sequence of inputs simply select the action from the dropdown and launch a level. The recording/playback will start automatically.

All recordings are saved in a `recordings` folder inside your TASmaniac install folder and are named based on the level and completion time.
A recording is saved only if you successfully complete a level.
