Description
-----------
The C256 Tracker is a music sequencing application written for the C256 Foenix retro computer.

Language is Assembly.
You will need the tass-64 assembler to compile this code.
Go to https://sourceforge.net/projects/tass64/ to get it.

I'm currently using version *64tass Turbo Assembler Macro V1.54.1900*

The model I'm using is RAD Tracker https://www.3eality.com/productions/reality-adlib-tracker.
The C256 Tracker is only able to play version **1.1** RAD files. 

Special Keys:
-------------
 - `<enter>`: start playing the song from the beggining
 - `<ctrl><enter>`: start playing from current position in pattern
 - `<=>`: next pattern
 - `<->`: previous pattern
 - `<;>`: slow down (this uses the BPM algorithm, not the Speed parameter)
 - `<'>`: speed up (this uses the BPM algorithm, not the Speed parameter)
 - `<ctrl><l>`: read SD Card for files. In the menu, use up-arrow/down-arrow to navigate. <enter> to select a file.
 - `<[>`: Previous Instrument
 - `<]>`: Next Instrument
 - `<qwertyuio and 23-567-9>`: play notes high
 - `<zxcvbnm and >`: play nodes low

Todo List
---------
 * Implementation of RAD version 2.0.
 * Creating and Editing files.
 * Some effects are still not implemented.
 * Writing to SD Card.

You will need the C256 Foenix IDE to code and debug: https://github.com/Trinity-11/FoenixIDE.

Finally, this code was updated for Rev C4 of the C256 Foenix board.   The application is only able to load files from FAT16 SD Cards at this time.

![C256 Tracker Screenshot](/c256-track-screenshot.png)

Cheers!

Dan
