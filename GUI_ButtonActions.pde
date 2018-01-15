/*
  By Chris Eugene Mills

*/


// Elements



// Button Pass-on ////////////////////////////////////////////////////////////

boolean buttonLoad=false;
boolean buttonStart=false;
boolean buttonStop=false;
boolean buttonPause=false;
boolean toggleYFlip=false;
boolean toggleYFlipValue=false;
boolean toggleXFlip=false;
boolean toggleXFlipValue=false;

boolean buttonApplyQueueModReady=false;
float tempQueueStart = -1;
float tempQueueEnd = -1;
boolean buttonApplyQueueModPushed=false;

boolean buttonUp=false;
boolean buttonDown=false;
boolean buttonLeft=false;
boolean buttonRight=false;

boolean buttonConnect=false;
boolean buttonPen=false;
boolean buttonAlignment=false;
boolean buttonHome=false;

int tempPenDown = -1;
int tempPenUp = -1;
int tempPenDownSpeed = -1;
int tempPenUpSpeed = -1;
int tempDrawingSpeed = -1;
int tempRapidSpeed = -1;

boolean buttonReset=false;
boolean buttonApplyReady = false;
boolean buttonApplyPushed = false;

boolean buttonHelp = false; //No button


/*
  Workaround, synchronizing calls to draw on main canvas, when this is called.

  Trigger these vars as true to trigger the associated action.
*/
void checkActions() {


  if (buttonLoad) {
    if (!qRunner.isRunning()) loadFile();
    buttonLoad = false;
  }
  if (buttonStart) {
    qRunner.start();
    buttonStart = false;
  }
  if (buttonStop) {
    qRunner.stop();
    buttonStop = false;
  }
  if (buttonPause) {
    qRunner.pause();
    buttonPause = false;
  }
  if (toggleYFlip) {
    qRunner.setFlipYFix(toggleYFlipValue);
    toggleYFlip = false;
  }
  if (toggleXFlip) {
    qRunner.setFlipXFix(toggleXFlipValue);
    toggleXFlip = false;
  }
  
  
  
  
  if (buttonApplyQueueModPushed) {

    if (!qRunner.isRunning())
    {
      if ( tempQueueStart != -1 && tempQueueEnd != -1)
        //TODO add mod code
      

      buttonApplyQueueModReady = false;
      tempQueueStart = -1;
      tempQueueEnd = -1;
    }

    buttonApplyQueueModPushed = false;
  }




  int buttonMoveMM = 10; //mm

  if (buttonUp) {
    if (!qRunner.isRunning()) axidraw.moveRelativeUnits(0, -buttonMoveMM);
    buttonUp = false;
  }
  if (buttonDown) {
    if (!qRunner.isRunning()) axidraw.moveRelativeUnits(0, buttonMoveMM);
    buttonDown = false;
  }
  if (buttonLeft) {
    if (!qRunner.isRunning()) axidraw.moveRelativeUnits(-buttonMoveMM, 0);
    buttonLeft = false;
  }
  if (buttonRight) {
    if (!qRunner.isRunning()) axidraw.moveRelativeUnits(buttonMoveMM, 0);
    buttonRight = false;
  }



  if (buttonConnect) {
    if (!qRunner.isRunning()) axidraw.connect();
    buttonConnect = false;
  }
  if (buttonPen) {
    if (!qRunner.isRunning()) axidraw.togglePen();
    buttonPen = false;
  }
  if (buttonAlignment) {
    if (!qRunner.isRunning()) axidraw.alignmentMode();
    buttonAlignment = false;
  }
  if (buttonHome) {
    if (!qRunner.isRunning()) axidraw.goHome();
    buttonHome = false;
  }




  if (buttonApplyPushed) {

    if (!qRunner.isRunning())
    {
      if ( tempPenDown != -1 && tempPenUp != -1)
        axidraw.configPenHeights( tempPenDown, tempPenUp );
      if ( tempPenDownSpeed != -1 && tempPenUpSpeed != -1)
        axidraw.configPenSpeeds( tempPenDownSpeed, tempPenUpSpeed );
      if ( tempDrawingSpeed != -1 && tempRapidSpeed != -1)
        axidraw.configMotorSpeeds( tempDrawingSpeed, tempRapidSpeed );
      dummy.clone(axidraw);

      buttonApplyReady = false;
      tempPenDown = -1;
      tempPenUp = -1;
      tempPenDownSpeed = -1;
      tempPenUpSpeed = -1;
      tempDrawingSpeed = -1;
      tempRapidSpeed = -1;
    }

    buttonApplyPushed = false;
  }


  if (buttonReset) {
    penHeightsRange.setRangeValues(settingsOnStart[0],settingsOnStart[1]);
    penDownSpeedSlider.setValue(settingsOnStart[2]);
    penUpSpeedSlider.setValue(settingsOnStart[3]);
    drawingSpeedSlider.setValue(settingsOnStart[4]);
    rapidSpeedSlider.setValue(settingsOnStart[5]);

    buttonReset = false;
  }



  if (buttonHelp) {
    printHelp();
    buttonHelp = false;
  }

}