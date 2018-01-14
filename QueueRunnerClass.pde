/*
  By Chris Eugene Mills

  Simplified this part by only running when machine is connected. All tasks can
  be "sent" to machine if so, but not by this runner, which quits out.

*/



class QueueRunner {

  // SETTINGS //////////////////////////////////////////////////////////////////

  /*
    IMPORTANT
      Because the Axidraw and Processing Canvas have their origin in the Top-Left,
      this leaves us at odds with most drawing and CAM software.

      The below setting will invert the Y axis about the center of our paper,
      allowing drawings placed in the X,Y Quadrant of the planning program with
      origin at Bottom-Left to be drawn correctly on the Axidraw.
  */
  boolean flipXFix = false;
  boolean flipYFix = true;

  static final int framesPerGraphicsRefresh = 1;
  static final int framesPerPauseButtonCheck = 10;

  static final int msOverload = 30;
  //How many ms ahead of time to load next task, skips the canvas draw time but 
  //  gradually overfills buffer. Hacky, plz find workaround.

  static final int msRunonCommand = 0; //50;
  //How many ms until next commandtime, to skip draw and just send again.

  // VARIABLES /////////////////////////////////////////////////////////////////

  Machine axidrawMachine, dummy;
  ArrayDeque<GCommand> runQueue, drawQueue, doneQueue, backupQueue;

  boolean running, loading, drawing;

  boolean paused;
  boolean penDownAtPause;
  boolean lastPRGzero = true;


  PGraphics canvas, penCanvas;
  float[] penPosition; // location target
  boolean penDown;



  // CONSTRUCTOR ///////////////////////////////////////////////////////////////

  QueueRunner( Machine _machine, Machine _dummy )
  {
    //Initialize VARS
    axidrawMachine = _machine;
    dummy = _dummy;

    runQueue = new ArrayDeque<GCommand>();
    drawQueue = new ArrayDeque<GCommand>();
    doneQueue = new ArrayDeque<GCommand>();
    backupQueue = new ArrayDeque<GCommand>();

    resetVars();
  }

  private void resetVars()
  {
    running = false;
    paused = false;
    loading = false;
    drawing = false;

    runQueue.clear();
    drawQueue.clear();
    doneQueue.clear();

    penPosition = new float[]{0,0};
  }






  // QUEUE OPERATIONS //////////////////////////////////////////////////////////

  public void loadFile( ArrayDeque<GCommand> q ) {
    resetVars();

    dummy.connect(); // Reset dummy drawer

    backupQueue.clear();
    backupQueue = q;
    runQueue = backupQueue.clone();
    c_report("QUEUE: Size: " + runQueue.size());

    resetDrawing();
  }


  public void setFlipYFix( boolean set ) {
    flipYFix = set;
    resetDrawing();
  }

  public void setFlipXFix( boolean set ) {
    flipXFix = set;
    resetDrawing();
  }


  public int remaining() {
    return runQueue.size();
  }


  public int size() {
    return backupQueue.size();
  }





  public boolean start() {

    if (running) println("QUEUE: Can't restart until stopped!");

    else {
      if (axidrawMachine.isConnected() && backupQueue.size() > 0) {
        resetVars();
        runQueue = backupQueue.clone();
        resetDrawing();
        axidrawMachine.startEstimation();
        running = true;
        println("QUEUE: Started!");
      }
      else if ( backupQueue.size() == 0 ) println("QUEUE: Nothing to start!");

      else println("QUEUE: Can't start disconnected!");
    }

    return running;
  }

  public boolean stop() {

    if (running) {
      running = false;
      axidrawMachine.raisePen();
      println("QUEUE: Stopped!");
      axidrawMachine.endEstimation();
    }
    else println("QUEUE: Can't stop unstarted!");

    return running;
  }

  public boolean isRunning() {
    return running;
  }



  public boolean pause() {

    if (running)
    {
      if (!paused)
      {
        println("QUEUE: Paused");
        paused = true;

        //Handle pause penup
        if (axidrawMachine.queryPenUp() == 0) {
          penDownAtPause = true;
          axidrawMachine.raisePen();
        }
        if (axidrawMachine.queryPenUp() == 1) {
          penDownAtPause = false;
        }
      }

      else
      {
        println("QUEUE: Unpaused");
        paused = false;

        //Handle resume pen height
        if (penDownAtPause) {
          axidrawMachine.lowerPen();
        }

      }
    }
    return paused;
  }




// Processing/Sending Functions ////////////////////////////////////////////////

  public void run() {
    // Don't pester the machine so much?

    loopCheck();
    drawMarker();


    if (frameCount % framesPerGraphicsRefresh == 0)
    {
      updatePenPosition();
      updatePenDown();
      drawProgress();
    }
    if (frameCount % framesPerPauseButtonCheck == 0)
    {
      buttonCheck();
    }


  }


  private void buttonCheck() {
    if (running) {
      //Check if pause button
      if (axidrawMachine.queryPRGButton() == 1)
      {
        if (lastPRGzero) {
          println("QUEUE: Button Press!");
          pause();
        } else {
          c_report("QUEUE: Button Held!");
        }
        lastPRGzero = false;
        return;
      }
      else {
        //Debounce holding this button, must have a 0 inbetween presses.
        lastPRGzero = true;
      }
    }
  }


  private void loopCheck()
  {
    //Skip if refridgerator not running
    if (running)
    {
      //Check if disconnected
      if (!axidrawMachine.isConnected())
      {
        println("QUEUE: Machine Disconnected!");
        println("QUEUE: Stopped Running!");
        running = false;
        return;
        // Don't send any more commands. Queue needs a full restart.
      }

      if (!paused)
      {
        //If its not even our time yet don't pester the machine.
        if (millis() >= axidrawMachine.getNextMoveTime()-msOverload)
        {
          // Check if this is just gonna get backed up "in our usb cable."
          // if (machine.queryBufferFull() == 0)
          // {
            c_report("QUEUE: -->");
            next(); //Good to go!!

          // }
          // else c_report("QUEUE: xxx"); //Buffer Still Full!");
        }
        else c_report("QUEUE: ..."); //Not Ready!");
      }
    }

    return;
  }




  private void next() {

    if (runQueue.size() > 0) {

      GCommand command = runQueue.poll();
      activateGCodeCommand(command);
      drawQueue.add(command);

      //Shortmove do next
      if(msRunonCommand != 0) //Disable if 0
        if((axidrawMachine.getNextMoveTime() - millis()) < msRunonCommand) {
          println("                        repeat");
          next();
        }
    }

    //If we are out of options, stop queue. TODO remove this for live generative.
    else stop();

  }



  private boolean activateGCodeCommand( GCommand _command ) {
    return activateGCodeCommand( _command, axidrawMachine );
  }
  private boolean activateGCodeCommand( GCommand _command, Machine target ) {

    //No "if supported" checks here, already done in original parse

    //Get Command Data
    int lineNumber = _command.lineNumber;
    char set = _command.set;
    int command = _command.command;
    float feedrate = _command.feedrate;
    float x = _command.x;
    float y = _command.y;
    float z = _command.z;

    //Progress report
    if (!loading && !drawing)
      c_print("QUEUE: # " + nf(lineNumber,5) + " - " +
        nf((size()-remaining())/float(size())*100, 1, 1) + "%"); //Verbose-level

    // Filter out specific cases
    if ( set == 'G') {
      switch ( command ) {
        case 0:
        case 1:
          //TODO make this unique for G00/G01
          c_report("     : XYZ"); //Debug-level

          if (Float.isNaN(z))
          {
            // XY MOTION ///////////////////////////////////////////////////////
            boolean skipXFix = false;
            boolean skipYFix = false;


            // HANDLE NULL XY
            if (Float.isNaN(x) || Float.isNaN(y))
            {
              if (Float.isNaN(x) && Float.isNaN(y)) {
                c_report("     : No motion at all?!");
                return false;
              }

              if (target.isAbsoluteMode()) {
                // Absolute Mode
                // Send current state
                if (Float.isNaN(x)) {
                  x = target.getPositionUnits()[0];
                  skipXFix = true; //mark this as machine value, skip fix
                }
                if (Float.isNaN(y)) {
                  y = target.getPositionUnits()[1];
                  skipYFix = true; //mark this as machine value, skip fix
                }
              }
              else {
                // Relative Mode
                if (Float.isNaN(x)) x = 0;
                if (Float.isNaN(y)) y = 0;
              }
            }

            // X INVERSION FIX
            if (!skipXFix && flipXFix) {
              /*
                Invert about x=xMax/2, middle of page
              */
              float xMax = target.getAMaxUnits();
              x = (x - xMax) * -1;
            }

            // Y INVERSION FIX
            if (!skipYFix && flipYFix) {
              /*
                Invert about y=yMax/2, middle of page
              */
              float yMax = target.getBMaxUnits();
              y = (y - yMax) * -1;
            }



            //TODO Feedrate setting

            // SEND
            target.move(x, y);


          }

          else
          {
            //TODO Feedrate setting
            //TODO Height setting
            if (z == 0) {
              target.lowerPen();
            } else {
              target.raisePen();
            }
          }

          return true;
        case 4:
          c_report("     : Dwell!");
          //TODO implement this
          return false;
        case 20:
          c_report("     : Inches!");
          target.setInchesMode();
          return false;
        case 21:
          c_report("     : Metric!");
          target.setMillimeterMode();
          return false;
        case 28:
          c_report("     : Return to Home!");
          target.goHome();
          return false;
        case 90:
          c_report("     : Absolute Mode!");
          target.setAbsoluteMode();
          return false;
        case 91:
          c_report("     : Relative Mode!");
          target.setRelativeMode();
          return false;
        default:
          c_report("     : UNSUPPORTED G COMMAND");
          return false;
      }
    } else if (set == 'M') {
      switch ( command ) {
        case 2:
        case 30:
          c_report("     : END OF PROGRAM!");
          target.goHome();
          // if (running) running = false;
          return false;
        default:
          c_report("     : UNSUPPORTED M COMMAND");
          return false;
        }
    } else if (set == 'T') {
      c_report("     : UNSUPPORTED T COMMAND");
      return false;
    } else {
      c_report("     : NO COMMAND RECOGNIZED???");
      return false;
    }

  }






// Graphical functions /////////////////////////////////////////////////////////
  
  
  // Set which buffers to draw to
  public void drawOn( PGraphics canvas1, PGraphics canvas2 ) {
    canvas = canvas1;
    penCanvas = canvas2;
  }




  public void drawMarker() {

    // Position Target Layer /////////////////////

    final float sec = 3.0; //seconds per rotation

    penCanvas.beginDraw();
      penCanvas.clear();

      penCanvas.stroke(255,0,0);
      penCanvas.strokeWeight(1);

      int x = int(penCanvas.width*penPosition[0]);
      int y = int(penCanvas.height*penPosition[1]);

      penCanvas.translate(x, y);
      penCanvas.scale(2);
      if (x == 0 && y == 0) penCanvas.ellipse(0,0, 38, 38);
      if(!running) penCanvas.rotate((millis() % (sec*1000)) * TWO_PI / (sec*1000));
      if (penDown) {
        penCanvas.line(-10, 0, 10, 0);
        penCanvas.line(0, -10, 0, 10);
      } else {
        penCanvas.line(-12,  0,-6, 0);
        penCanvas.line(  6,  0,12, 0);
        penCanvas.line(  0,-12, 0,-6);
        penCanvas.line(  0,  6, 0,12);
      }

    penCanvas.endDraw();
  }



  public float[] updatePenPosition() {
    if (axidrawMachine.isConnected()) penPosition = axidrawMachine.getRealPositionPercent();
    else penPosition = axidrawMachine.getPositionPercent();
    return penPosition;
  }

  public boolean updatePenDown() {
    if (axidrawMachine.isConnected()) penDown = axidrawMachine.isRealPenDown();
    else penDown = axidrawMachine.isPenDown();
    return penDown;
  }




  private void resetDrawing() {
    loading = true; //Disable live drawing
    dummy.startEstimation();

    println("\nQUEUE: Reset Drawing");

    drawQueue = backupQueue.clone();

    canvas.beginDraw();
    canvas.clear();
    canvas.stroke(0);
    canvas.strokeWeight(3);
    canvas.strokeCap(SQUARE);

    while (drawQueue.size() > 0)
    {
      GCommand command = drawQueue.poll();
      activateGCodeCommand( command, dummy );
    }

    canvas.endDraw();

    println("QUEUE: Finished Drawing\n");
    delay(20);

    dummy.endEstimation();
    loading = false; //Enable live drawing
  }




  private void drawProgress() {

    //Don't try and draw progress when we are doing a master preview
    if (drawQueue.size() > 0 && !loading) {

      drawing = true;
      canvas.beginDraw();

      canvas.stroke(255,0,0);
      canvas.strokeWeight(4);
      canvas.strokeCap(SQUARE);

      while (drawQueue.size() > 0)
      {
        GCommand command = drawQueue.poll();
        c_report("QUEUE: Draw");
        activateGCodeCommand( command, dummy );
        doneQueue.add(command);
      }

      canvas.endDraw();
      drawing = false;
    }
  }



}