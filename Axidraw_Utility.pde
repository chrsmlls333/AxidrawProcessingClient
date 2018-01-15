/*
  By Chris Eugene Mills

  Partly based off SimpleDirectDraw by Koblin, but the GCode import and drawing
  is original.

  Requires:
    EBB firmware >=2.5.1
    Processing >=3.3.5

  GCODE FORMAT NOTES IN QUEUERUNNERCLASS.PDE
  
*/

// LIBRARIES ///////////////////////////////////////////////////////////////////

import controlP5.*;
import processing.serial.*;

import java.io.*;
import java.util.*;
import java.lang.Character;
import java.lang.reflect.*;
import java.util.concurrent.TimeUnit;



// CONFIG //////////////////////////////////////////////////////////////////////

// Letter/A4
static final boolean customMode = false;
static final boolean letterSize = true;

// UI Size
// windowMult*paperWidthMM = canvas width
static final int windowMult = 4;




// VARS ////////////////////////////////////////////////////////////////////////

// Machines, runners
AxiDrawMachine axidraw;
DummyMachine dummy;
QueueRunner qRunner;

// Drawing, sizes
PGraphics buffer, penLoc, grid;
int bufferwidth, bufferheight;
boolean gridOn = true;


// User Interface
ControlFrame partner;
ControlP5 cp5;

// Fixes windowlocation sensing/setting discrepancies. OS-specific.
int yWindowOffset = 26;
color bg = color(37);





// BEGIN ///////////////////////////////////////////////////////////////////////

void settings() {
  // Setup Canvas ////
  size(900, 900, P2D);
  smooth();
}

void setup() {

  // Setup Canvas ///////////////
  frameRate(120);
  c_init(255, true, false);


  // Paper Size in MM //////////////
  if (letterSize) {
    //Letter Paper
    bufferwidth = 280;
    bufferheight = 216;
  } else {
    //A4 Paper
    bufferwidth = 297;
    bufferheight = 210;
  }

  if (customMode) {
    // Notebook = 200x120
    // 16x9 = 280x157
    bufferwidth = 200;
    bufferheight = 120;
  }



  // Match canvas size
  surface.setSize(bufferwidth*windowMult, bufferheight*windowMult);
  surface.setResizable(false);
  surface.setLocation(100,100);



  // Draw Buffers //////////////////////////////////////////
  grid = createGraphics(bufferwidth*windowMult, bufferheight*windowMult);
  grid.noSmooth();
  grid.beginDraw();
  grid.clear();
  grid.stroke(0, 25);
  for (int i = 0; i < grid.width; i += (10*windowMult)) {
    grid.line(i, 0, i, grid.height);
    grid.line(0, i, grid.width, i);
  }
  grid.endDraw();

  buffer = createGraphics(bufferwidth*15, bufferheight*15);
  buffer.beginDraw();
  buffer.clear();
  buffer.endDraw();

  penLoc = createGraphics(bufferwidth*4, bufferheight*4);
  penLoc.beginDraw();
  penLoc.clear();
  penLoc.endDraw();



  // MACHINES ///////////////////////////////////////////////////
  axidraw = new AxiDrawMachine(this, bufferwidth, bufferheight);
  dummy = new DummyMachine(axidraw, buffer);



  // QUEUERUNNER ////////////////////////////////////////////
  qRunner = new QueueRunner(axidraw, dummy);
  qRunner.drawOn(buffer, penLoc);



  // Control Frame //////////////////
  partner = new ControlFrame(this, 400, bufferheight*windowMult, "Controls");
  partner.setResizable(true);
  thread("matchPartnerWindowLoop"); // Match windows in background

  // ControlP5 /////////////////
  cp5 = new ControlP5(this);
  cp5.enableShortcuts();
  primaryWindowSetup(cp5);
  secondaryWindowSetup(partner.cp5);



  //
  //
  //Connect to Machine
  axidraw.connect();
}








void c_draw() {


  // Run queue, draw Plotter position, and preview
  qRunner.run();


  // Draw buffer to canvas
  pushMatrix();

    // Mouse Zoom
    translate(translateX, translateY);
    scale(scaleFactor);

    if (gridOn) image(grid, 0, 0, width, (grid.height*width/grid.width));
    image(buffer, 0, 0, width, (buffer.height*width/buffer.width));
    image(penLoc, 0, 0, width, (penLoc.height*width/penLoc.width));

  popMatrix();


  //Line to demarcate headerbar on Windows 10
  stroke(bg);
  noFill();
  strokeWeight(2);
  line(0, 0, width, 0);


  // Interface Draw
  primaryWindowUpdate(cp5);
  secondaryWindowUpdate(partner.cp5);
  checkActions(); //All method interaction routed through here
}



// GCODE ENTRY /////////////////////////////////////////////////////////////////


void loadFile() {
  if (!qRunner.isRunning())
    selectInput("Select a file to process:", "fileSelected");
}

void fileSelected(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel.");
  } else {
    println("INPUT: " + selection.getAbsolutePath());
    GCodeParser parser = new GCodeParser(selection.getAbsolutePath());
    parser.outputParsedGCodeFile();
    qRunner.loadFile(parser.export());
  }
}



// SYSTEM FUNCTIONS ///////////////////////////////////////////////////////////////////

// void reset() {
//   setup();
// }


//TODO
void printHelp () {
  println("");
}