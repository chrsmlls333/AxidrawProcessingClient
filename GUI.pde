/*
  By Chris Eugene Mills

  Disorganized
*/

// Settings ////////////////////////////////////////////////////////////////////

boolean divertConsoleStream = true;

// Elements ////////////////////////////////////////////////////////////////////
//   Not all declared here
Accordion accordion;
Group queueGroup, queueModGroup, machineGroup, machineSettingsGroup, consoleGroup;

Println console;
Textarea consoleArea;
PrintStream original;
ByteArrayOutputStream consoleOutput;
String tempConsoleOut = "";

Textlabel zoomInfo;
Button loadButton, startButton, stopButton, pauseButton, applyQueueModButton, connectButton, applySettingsButton;
Toggle flipYToggle, flipXToggle;
Range queueModRange, penHeightsRange;
Slider penDownSpeedSlider, penUpSpeedSlider;
Slider drawingSpeedSlider, rapidSpeedSlider;

float[] settingsOnStart;


// USER INTERFACE Setup/Update /////////////////////////////////////////////////

void primaryWindowSetup(ControlP5 con) {
  zoomInfo = con.addTextlabel("label")
                .setText("Zoom")
                .setPosition(5,height-25)
                .setColorValue(0xff252525)
                .setFont(createFont("Source Code Pro", 20, true))
                ;

}


void primaryWindowUpdate(ControlP5 con) {
  //Update Zoom info
  zoomInfo.setText("x"+nf(scaleFactor, 1, 1));

}




void secondaryWindowSetup(ControlP5 con) {

  // DATA //////////////////////////////////////////////////////////////////////

  // Reset
  settingsOnStart = new float[]{axidraw.servoDownPct,
                                axidraw.servoUpPct,
                                axidraw.servoDownSpeedPct,
                                axidraw.servoUpSpeedPct,
                                axidraw.drawingSpeedPct,
                                axidraw.rapidSpeedPct };

  // Console
  //https://forum.processing.org/one/topic/access-to-console-output.html
  if (divertConsoleStream) {
    original = System.out;
    consoleOutput = new ByteArrayOutputStream();
    PrintStream printStream = new PrintStream(consoleOutput);
    System.setOut(printStream);
    System.setErr(printStream);
  }



  // INTERFACE DECLARATION /////////////////////////////////////////////////////
  PFont largefont = createFont("Source Code Pro", 22, false);
  PFont font = createFont("Source Code Pro", 16, false);
  PFont smallfont = createFont("Source Code Pro", 13, false);



  queueGroup = con.addGroup("Queue Operations")
    // .setPosition(10,30)
    // .setSize(380, 160)
    .setBackgroundColor(color(255,50))
    .setBackgroundHeight(120)
    .setBarHeight(22)
    .setFont(largefont)
    //.disableCollapse()
    ;
    loadButton = con.addButton("Load GCode")
      .setId(11)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(180,20)
      .setSize(120, 30)
      .setFont(font)
      .setGroup(queueGroup)
      .setBroadcast(true)
      ;
    startButton = con.addButton("Start")
      .setId(12)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(20,20)
      .setSize(120, 30)
      .setFont(font)
      .setGroup(queueGroup)
      .setBroadcast(true)
      ;
    stopButton = con.addButton("Stop")
      .setId(13)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(180,20)
      .setSize(120, 30)
      .setFont(font)
      .setGroup(queueGroup)
      .setBroadcast(true)
      .hide()
      ;
    pauseButton = con.addButton("Pause")
      .setId(14)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(180,60)
      .setSize(120, 30)
      .setFont(font)
      .setGroup(queueGroup)
      .setBroadcast(true)
      .hide()
      ;
    flipYToggle = con.addToggle("Flip Y")
      .setId(15)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(180,60)
      .setSize(50,30)
      .setValue(qRunner.flipYFix)
      .setMode(ControlP5.SWITCH)
      .setFont(smallfont)
      .setGroup(queueGroup)
      .setBroadcast(true)
      ;
    flipXToggle = con.addToggle("Flip X")
      .setId(16)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(250,60)
      .setSize(50,30)
      .setValue(qRunner.flipXFix)
      .setMode(ControlP5.SWITCH)
      .setFont(smallfont)
      .setGroup(queueGroup)
      .setBroadcast(true)
      ;
  
  
  queueModGroup = con.addGroup("Queue Mods")
    .setBackgroundColor(color(255,50))
    .setBackgroundHeight(120)
    .setBarHeight(22)
    .setFont(largefont)
    ;
    queueModRange = con.addRange("Start + End")
      .setId(17)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(20, 20)
      .setSize(240, 30)
      .setHandleSize(15)
      .setRange(0,100)
      .setRangeValues(0,100)
      .setFont(smallfont)
      .setGroup(queueModGroup)
      .setBroadcast(true)
      ;
    applyQueueModButton = con.addButton("Apply Mod")
      .setId(18)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(20, 60)
      .setSize(120, 30)
      .setFont(font)
      .setGroup(queueModGroup)
      .setBroadcast(true)
      .hide()
      ;
      

  machineGroup = con.addGroup("Machine Controls")
    // .setPosition(10, 220)
    // .setSize(380, 400)
    .setBackgroundColor(color(255,50))
    .setBackgroundHeight(200)
    .setBarHeight(22)
    .setFont(largefont)
    // .disableCollapse()
    ;
    con.addButton("^")
      .setId(21)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(60,30)
      .setSize(40, 40)
      .setFont(font)
      .setGroup(machineGroup)
      .setBroadcast(true)
      ;
    con.addButton("v")
      .setId(22)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(60,110)
      .setSize(40, 40)
      .setFont(font)
      .setGroup(machineGroup)
      .setBroadcast(true)
      ;
    con.addButton("<")
      .setId(23)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(20,70)
      .setSize(40, 40)
      .setFont(font)
      .setGroup(machineGroup)
      .setBroadcast(true)
      ;
    con.addButton(">")
      .setId(24)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(100,70)
      .setSize(40, 40)
      .setFont(font)
      .setGroup(machineGroup)
      .setBroadcast(true)
      ;
    connectButton = con.addButton("Connect ->")
      .setId(25)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(180,20)
      .setSize(120, 30)
      .setFont(font)
      .setColorLabel(color(255,255,0))
      .setGroup(machineGroup)
      .setBroadcast(true)
      ;
    con.addButton("Alignment")
      .setId(26)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(180,60)
      .setSize(120, 30)
      .setFont(font)
      .setGroup(machineGroup)
      .setBroadcast(true)
      ;
    con.addButton("Go Home")
      .setId(27)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(180,100)
      .setSize(120, 30)
      .setFont(font)
      .setGroup(machineGroup)
      .setBroadcast(true)
      ;
    con.addButton("Toggle Pen")
      .setId(28)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(180,140)
      .setSize(120, 30)
      .setFont(font)
      .setGroup(machineGroup)
      .setBroadcast(true)
      ;



  machineSettingsGroup = con.addGroup("Machine Settings")
    // .setPosition(10, 220)
    // .setSize(380, 400)
    .setBackgroundColor(color(255,50))
    .setBackgroundHeight(300)
    .setBarHeight(22)
    .setFont(largefont)
    // .disableCollapse()
    ;
    penHeightsRange = con.addRange("Pen Low/High")
      .setId(31)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(20, 20)
      .setSize(240, 30)
      .setHandleSize(15)
      .setRange(0,100)
      .setRangeValues(axidraw.servoDownPct,axidraw.servoUpPct)
      .setFont(smallfont)
      .setGroup(machineSettingsGroup)
      .setBroadcast(true)
      // .setColorForeground(color(255,40))
      // .setColorBackground(color(255,40))
      ;
    penDownSpeedSlider = con.addSlider("Pen Dn (%/sec)")
      .setId(32)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(20, 60)
      .setSize(240, 30)
      .setHandleSize(20)
      .setRange(20,400)
      .setValue(axidraw.servoDownSpeedPct)
      .setFont(smallfont)
      .setGroup(machineSettingsGroup)
      .setBroadcast(true)
      ;
    penUpSpeedSlider = con.addSlider("Pen Up (%/sec)")
      .setId(33)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(20, 100)
      .setSize(240, 30)
      .setHandleSize(20)
      .setRange(20,400)
      .setValue(axidraw.servoUpSpeedPct)
      .setFont(smallfont)
      .setGroup(machineSettingsGroup)
      .setBroadcast(true)
      ;

    drawingSpeedSlider = con.addSlider(" Draw Speed (%)")
      .setId(34)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(20, 160)
      .setSize(240, 30)
      .setHandleSize(20)
      .setRange(1,100)
      .setValue(axidraw.drawingSpeedPct)
      .setFont(smallfont)
      .setGroup(machineSettingsGroup)
      .setBroadcast(true)
      ;
    rapidSpeedSlider = con.addSlider("Rapid Speed (%)")
      .setId(35)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(20, 200)
      .setSize(240, 30)
      .setHandleSize(20)
      .setRange(1,100)
      .setValue(axidraw.rapidSpeedPct)
      .setFont(smallfont)
      .setGroup(machineSettingsGroup)
      .setBroadcast(true)
      ;
    applySettingsButton = con.addButton("Apply")
      .setId(36)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(180,240)
      .setSize(120, 30)
      .setFont(font)
      .setGroup(machineSettingsGroup)
      .setBroadcast(true)
      .hide()
      ;
    con.addButton("Reset")
      .setId(37)
      .plugTo(this)
      .setBroadcast(false)
      .setPosition(20,240)
      .setSize(120, 30)
      .setFont(font)
      .setGroup(machineSettingsGroup)
      .setBroadcast(true)
      ;
      
      
  consoleGroup = con.addGroup("Console")
    // .setPosition(10, 220)
    // .setSize(380, 400)
    .setBackgroundColor(color(255,50))
    .setBackgroundHeight(300)
    .setBarHeight(22)
    .setFont(largefont)
    //.disableCollapse()
    ;
    consoleArea = con.addTextarea("txt")
      .setPosition(0, 0)
      .setSize(400, 300)
      .setFont(smallfont)
      .setLineHeight(14)
      .setColor(color(200))
      .setColorBackground(color(0, 100))
      .setColorForeground(color(255, 100))
      .setGroup(consoleGroup)
      ;



  accordion = con.addAccordion("acc")
    .setPosition(0,5)
    .setWidth(400)
    .setBackgroundColor(color(255,50))
    .setBarHeight(0)
    .addItem(queueGroup)
    .addItem(queueModGroup)
    .addItem(machineGroup)
    .addItem(machineSettingsGroup)
    .addItem(consoleGroup)
    .open(0,2,4)
    .setCollapseMode(Accordion.MULTI)
    ;


}



boolean wasConnected = false;
boolean wasRunning = false;
boolean applyWasReady = false;
boolean applyQueueModWasReady = false;
void secondaryWindowUpdate(ControlP5 con) {

  //Connect Button
  if(axidraw.isConnected() != wasConnected) {
    if (axidraw.isConnected()) {
      connectButton.setColorLabel(color(0,255,0));
      connectButton.setLabel("Connected");
    } else {
      connectButton.setColorLabel(color(255,0,0));
      connectButton.setLabel("Reconnect ->");
    }
  }
  wasConnected = axidraw.isConnected();


  //Hide Machine Group and show Pause on queue start
  if (qRunner.isRunning() != wasRunning) {
    if (qRunner.isRunning()) {
      // machineGroup.close();
      accordion.close(1,2,3);
      queueModGroup.disableCollapse();
      machineGroup.disableCollapse();
      machineSettingsGroup.disableCollapse();
      pauseButton.show();
      stopButton.show();
      loadButton.hide();
      flipYToggle.hide();
      flipXToggle.hide();
    }
    else {
      // machineGroup.open();
      accordion.open(2);
      queueModGroup.enableCollapse();
      machineGroup.enableCollapse();
      machineSettingsGroup.enableCollapse();
      pauseButton.hide();
      stopButton.hide();
      loadButton.show();
      flipYToggle.show();
      flipXToggle.show();
    }
  }
  wasRunning = qRunner.isRunning();
  
  
  //Apply Queue Mod Button
  if (buttonApplyQueueModReady != applyQueueModWasReady) {
    if (buttonApplyQueueModReady) {
      applyQueueModButton.show();
    }
    else {
      applyQueueModButton.hide();
    }
  }
  applyQueueModWasReady = buttonApplyQueueModReady;
  

  //Apply Settings Button
  if (buttonApplyReady != applyWasReady) {
    if (buttonApplyReady) {
      applySettingsButton.show();
    }
    else {
      applySettingsButton.hide();
    }
  }
  applyWasReady = buttonApplyReady;


  //Console
  if (divertConsoleStream) {
     
    tempConsoleOut = consoleOutput.toString();
    if (tempConsoleOut.length() > 0) {
      
      //Filter out window movement notices
      String[] textsSplit = PApplet.split(tempConsoleOut, "(?<=\n)");
      for (int i = 0; i < textsSplit.length; i++) {
        if (!textsSplit[i].contains("__MOVE__")) {
          consoleArea.append(textsSplit[i]);
        }
      }
      
      //consoleArea.append(tempConsoleOut, 200);
      consoleArea.scroll(1);
      tempConsoleOut = "";
      consoleOutput.reset();
    }
  }

}



public void controlEvent(ControlEvent theEvent) {
  // c_report(theEvent.getController().getName());
  // theEvent.getController().getValue()
  // theEvent.getController().getArrayValue(0)
  switch (theEvent.getController().getId()) {

    case 11:
    buttonLoad=true;
    break;
    case 12:
    buttonStart=true;
    break;
    case 13:
    buttonStop=true;
    break;
    case 14:
    buttonPause=true;
    break;
    case 15:
    toggleYFlip=true;
    toggleYFlipValue=flipYToggle.getBooleanValue();
    break;
    case 16:
    toggleXFlip=true;
    toggleXFlipValue=flipXToggle.getBooleanValue();
    break;
    
    
    case 17:
    buttonApplyQueueModReady=true;
    tempQueueStart = theEvent.getController().getArrayValue(0);
    tempQueueEnd = theEvent.getController().getArrayValue(1);
    break;
    case 18:
    buttonApplyQueueModPushed=true;
    break;


    case 21:
    buttonUp=true;
    break;
    case 22:
    buttonDown=true;
    break;
    case 23:
    buttonLeft=true;
    break;
    case 24:
    buttonRight=true;
    break;
    case 25:
    buttonConnect=true;
    break;
    case 26:
    buttonAlignment=true;
    break;
    case 27:
    buttonHome=true;
    break;
    case 28:
    buttonPen=true;
    break;

    //Must be fetched in pairs so we don't send any bad values.
    case 31:
    buttonApplyReady=true;
    tempPenDown = (int)theEvent.getController().getArrayValue(0);
    tempPenUp = (int)theEvent.getController().getArrayValue(1);
    break;
    case 32:
    buttonApplyReady=true;
    tempPenDownSpeed = (int)penDownSpeedSlider.getValue();
    tempPenUpSpeed = (int)penUpSpeedSlider.getValue();
    break;
    case 33:
    buttonApplyReady=true;
    tempPenDownSpeed = (int)penDownSpeedSlider.getValue();
    tempPenUpSpeed = (int)penUpSpeedSlider.getValue();
    break;
    case 34:
    buttonApplyReady=true;
    tempDrawingSpeed = (int)drawingSpeedSlider.getValue();
    tempRapidSpeed = (int)rapidSpeedSlider.getValue();
    break;
    case 35:
    buttonApplyReady=true;
    tempDrawingSpeed = (int)drawingSpeedSlider.getValue();
    tempRapidSpeed = (int)rapidSpeedSlider.getValue();
    break;
    case 36:
    buttonApplyPushed=true;
    break;
    case 37:
    buttonReset=true;
    break;
    

  }
}





// Window Matching Thread //////////////////////////////////////////////////////

void matchPartnerWindowLoop() {
  boolean running = true;
  while (running) {
    delay(20);
    try {
      matchPartnerWindow();
    } catch (NullPointerException e) {
      // e.printStackTrace();
      running = false;
    } catch (RuntimeException e) {
      // e.printStackTrace();
      running = false;
    }

  }
}


void matchPartnerWindow() {
  int[] loc = getWindowLocation(P2D);
  partner.setLocation( loc[0] - (10 + partner.getCanvasSize()[0]),
                       loc[1] - yWindowOffset );
}





// ZOOM FUNCTIONS //////////////////////////////////////////////////////////////

// Zooming Feature
float scaleFactor = 1.0;
float translateX = 0.0;
float translateY = 0.0;

void mouseDragPan() {
  //Viewport Pan
  translateX += mouseX - pmouseX;
  translateY += mouseY - pmouseY;
  //Constraints
  translateX = constrain(translateX, -(scaleFactor-1)*width, 0 );
  translateY = constrain(translateY, -(scaleFactor-1)*height, 0 );
}

void mouseWheelZoom(MouseEvent e) {
  //Viewport Zoom
  translateX -= mouseX;
  translateY -= mouseY;
    float rate = 1.07;
    float delta = e.getCount() < 0 ? rate
                : e.getCount() > 0 ? 1.0/rate
                : 1.0;
    float scaleNew = scaleFactor * delta;
    scaleNew = constrain(scaleNew, 1, 15); //Constraints
    translateX *= scaleNew / scaleFactor;
    translateY *= scaleNew / scaleFactor;

    scaleFactor = scaleNew;
  translateX += mouseX;
  translateY += mouseY;

  //Constraints
  translateX = constrain(translateX, -(scaleFactor-1)*width, 0 );
  translateY = constrain(translateY, -(scaleFactor-1)*height, 0 );
}

void resetView() {
  //Viewport Reset
  scaleFactor = 1;
  translateX = 0.0;
  translateY = 0.0;
}