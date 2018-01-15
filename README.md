# Axidraw Processing Client

A control client for the Evil Mad Scientist Laboratories' Axidraw.

## Requirements

Untested on earlier than:
- Axidraw v3 plotter
- EBB firmware >=2.5.1
- Processing >=3.3.5


## Features

- GCode support (partial)
- Live position and progress feedback
- Preview with Zoom
- Flipping for standard XY coordinates to plotter coordinates.
- Efficiency calculation and time estimate.
- Settings testing (pen toggling, speed adjustments, etc)


## ToDo

- Press '?' for help.
- Settings persistence, loading and saving.
- Acceleration! <em>Help Wanted!</em>
- Smoothing lots of small movements. <em>Help Wanted!</em>
- UI refinements. Possible collapse to one window? Non-processing GUI Library?
- Queue modification, starting and ending at preset points in queue.
- Threading serial communications and/or canvas drawing. <em>Help Wanted!</em>
- Live GCode object queuing for generative performances.


## Reference Links

- Partly based off [SimpleDirectDraw by Koblin](https://github.com/koblin/AxiDrawProcessing2), but only the barebones.
- [EiBotBoard Command Doc](http://evil-mad.github.io/EggBot/ebb.html)


## GCode Format Specification

Accepts GCode with many limitations!

- Z axis accepts ONLY ZERO AND NON-ZERO as down and up. Height settings baked into variables. TODO add full Z support.
- Can not move in 3 dimensions at once. Z and XY motion must be in their own commands. This is standard to engraving.
- When planning your plot, position the model in the:
  - X,Y  Quadrant: Select flipYFix to true
  - <s>X,-Y Quadrant: Select xyFix to true</s>
- Script should end with a M30 command. This sends to home and tells the queue to stop waiting for more.
- Ignores distinction between G00 and G01, but still functions by default with rapid motion when in clearance plane, and normal motion when pen is down.
- Accepts units of Inches or Millimeters, but code must include G20 or G21.
- All commands should be on separate lines, with parts separated by spaces, and comments (surrounded by brackets). No colons/semicolons.


TODO:

- Z heights
- G0/G01 distinction
- Feedrates
- Dwell
- Arcs?
- File filters for unallowed characters.


