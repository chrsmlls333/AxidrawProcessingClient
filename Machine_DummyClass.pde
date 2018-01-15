/*
  By Chris Eugene Mills
*/



class DummyMachine implements Machine {


  // VARIABLES /////////////////////////////////////////////////////////////////

  //Cloned Vars
  int drawingSpeedPct, rapidSpeedPct;
  int resolution = 1;

  int servoUpPct, servoDownPct;
  int servoDownSpeedPct, servoUpSpeedPct;
  int delayAfterRaisingPen, delayAfterLoweringPen;

  int dpi_16X = 2032;
  int speedScale = 24950;

  //Config Vars
  int drawingSpeed, rapidSpeed;
  float stepsPerInch, stepsPerMM;
  static final int motorMinA = 0;
  static final int motorMinB = 0;
  int motorMaxA, motorMaxB;
  int servoUpTime, servoDownTime; //default pen delays for our speeds
  boolean millimeterMode = true;
  boolean absoluteMode = true;

  // Instant Status
  boolean penDown = false;
  int currentA = 0;  // Position of X on paper
  int currentB = 0;  // Position of Y on paper
  int lastPosition; // Record last encoded position for drawing

  // Next
  int moveDestA = -1;
  int moveDestB = -1;
  //Time we are allowed to begin the next movement
  //(i.e., when the current move will be complete).
  int nextMoveTime;

  //Drawing?
  PGraphics canvas;
  boolean lastPenDown_DrawingPath;
  int lastX_DrawingPath;
  int lastY_DrawingPath;
  boolean drawingMetric;

  //Estimation
  float drawDistance = 0; //steps
  float upDistance = 0; //steps
  int totalTime = 0; //ms


  // CONSTRUCTOR(s) ////////////////////////////////////////////////////////////

  DummyMachine( AxiDrawMachine _clone, PGraphics _canvas) {

    canvas = _canvas;

    //Mimic Partner Settings
    clone(_clone);

    nextMoveTime = millis();

    //Connect
    connect();
  }




  public void connect() {

    configPenHeights(); // Configure brush lift servo endpoints and speed

    alignmentMode();

    c_report("Dummy Machine Active.\n");
  }




  private void motorSettingsSetup() {

    if (resolution == 1 )
    {
      drawingSpeed = int(float(drawingSpeedPct) / 110.0 * speedScale);
      rapidSpeed = int(float(rapidSpeedPct) / 110.0 * speedScale);
      stepsPerInch = dpi_16X;	// Resolution along native motor axes (not XY)
    }
    else if (resolution == 2)
    {
      drawingSpeed = int( float(drawingSpeedPct) / 220.0 * speedScale);
      rapidSpeed = int(float(rapidSpeedPct) / 110.0 * speedScale);
      stepsPerInch = dpi_16X / 2.0;	// Resolution along native motor axes (not XY)
    }
    stepsPerMM = stepsPerInch / 25.4;

    //Constraints
    drawingSpeed = constrain(drawingSpeed, 200, speedScale);
    rapidSpeed = constrain(rapidSpeed, 200, speedScale);
  }


  public void clone( AxiDrawMachine clone ) {
    //Mimic Partner Settings
    motorMaxA = clone.motorMaxA;
    motorMaxB = clone.motorMaxB;
    currentA = clone.currentA;
    currentB = clone.currentB;

    drawingSpeedPct = clone.drawingSpeedPct;
    rapidSpeedPct = clone.rapidSpeedPct;
    resolution = clone.resolution;

    servoUpPct = clone.servoUpPct;
    servoDownPct = clone.servoDownPct;
    servoDownSpeedPct = clone.servoDownSpeedPct;
    servoUpSpeedPct = clone.servoUpSpeedPct;

    delayAfterRaisingPen = clone.delayAfterRaisingPen;
    delayAfterLoweringPen = clone.delayAfterLoweringPen;

    dpi_16X = clone.dpi_16X;
    speedScale = clone.speedScale;


    //Initialize VARS
    motorSettingsSetup();
  }



  // MODES and UTILS ///////////////////////////////////////////////////////////

  // MODES
  public void alignmentMode() {
    penDown = true; //make it raise no matter what.
    raisePen();
    zero();
    // println("TEMPORARY ALIGNMENT MODE -- Push to 'Home' position now");
  }


  public void setRelativeMode() {
    absoluteMode = false;
  }

  public void setAbsoluteMode() {
    absoluteMode = true;
  }


  public void setInchesMode() {
    millimeterMode = false;
  }

  public void setMillimeterMode() {
    millimeterMode = true;
  }





  // SHORTCUTS
  public void goHome() {
    // c_report("Going to Graceland...");
    raisePen();
    moveToAB(0, 0);
  }




  // ACCESS UTILITIES

  public int[] getPositionAB() {
    return new int[]{ currentA, currentB };
  }

  public float[] getPositionUnits() {
    int[] temp = getPositionAB();
    return new float[]{ stepsToUnits(temp[0]), stepsToUnits(temp[1]) };
  }

  public float getAMaxUnits() {
    return stepsToUnits(motorMaxA);
  }

  public float getBMaxUnits() {
    return stepsToUnits(motorMaxB);
  }

  public float[] getPositionPercent() {
    int[] temp = getPositionAB();
    return new float[]{ temp[0] / float(motorMaxA - motorMinA),
                        temp[1] / float(motorMaxB - motorMinB) };
  }

  public float[] getDestPercent() {
    if (moveDestA == -1 || moveDestB == -1) return new float[]{ -1, -1 };
    else return new float[]{  moveDestA / float(motorMaxA - motorMinA),
                              moveDestB / float(motorMaxB - motorMinB) };
  }

  public float[] getRealPositionPercent() {
    int[] temp = queryMotorStep();
    return new float[]{ temp[2] / float(motorMaxA - motorMinA),
                        temp[3] / float(motorMaxB - motorMinB) };
  }

  public int getNextMoveTime() {
    return nextMoveTime - ceil(1000.0 / (frameRate/3.0));
    // Important correction-- Start next segment sooner than you might expect,
    // because of the relatively low framerate that the program runs at.
  }

  public boolean isConnected() {
    return true; //sneaky boiiii
  }

  public boolean isAbsoluteMode() {
    return absoluteMode;
  }

  public boolean isPenDown() {
    return penDown;
  }

  public boolean isRealPenDown() {
    return penDown;
  }



  // TIMING/ESTIMATION

  public void startEstimation( ) {
    drawDistance = 0; //steps
    upDistance = 0; //steps
    totalTime = 0; //ms
  }

  public void endEstimation( ) {
    float totalDistance = drawDistance + upDistance;
    String duration = String.format("%02dm%02ds",
                                    TimeUnit.MILLISECONDS.toMinutes(totalTime),
                                    TimeUnit.MILLISECONDS.toSeconds(totalTime) -
                                    TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS.toMinutes(totalTime))
                                  );

    println("DUMMY: Drawing distance (cm): " + (drawDistance / stepsPerMM)/10 );
    println("DUMMY: Total distance (cm)  : " + (totalDistance / stepsPerMM)/10 );
    println("DUMMY: Efficiency           : " + nf(drawDistance / totalDistance * 100.0, 1, 2) + "%");
    println("DUMMY: Total time           : " + duration + "\n");
  }


  // PRIVATE UTILITIES

  private int unitsToSteps( float x ) {
    if (millimeterMode) return mmToSteps(x);
    else return inToSteps(x);
  }

  private int mmToSteps( float x ) {
    return int(x * stepsPerMM);
  }

  private int inToSteps( float x ) {
    return int(x * stepsPerInch);
  }

  private float stepsToUnits( int x ) {
    if (millimeterMode) return (x / stepsPerMM);
    else return (x / stepsPerInch);
  }

  private float getDistance(float x1, float y1, float x2, float y2) {
    float xdiff = abs(x2 - x1);
    float ydiff = abs(y2 - y1);
    return sqrt(pow(xdiff, 2) + pow(ydiff, 2));
  }


  // MACHINE OPERATIONS //////////////////////////////////////////////////////////////////////////////


  public void configPenSpeeds( int downSpeed, int upSpeed )
  {
    if (servoUpSpeedPct != upSpeed || servoDownSpeedPct != downSpeed)
    {
      servoUpSpeedPct = upSpeed;
      servoDownSpeedPct = downSpeed;

      configPenHeights();
    }
  }

  public void configPenHeights( int downPct, int upPct )
  {
    if (servoUpPct != upPct || servoDownPct != downPct)
    {
      servoUpPct = upPct;
      servoDownPct = downPct;

      configPenHeights();
    }
  }

  private void configPenHeights()
  {
    int low = 7500 + 175 * constrain(servoDownPct, 0, 100); //30 //
    int high = 7500 + 175 * constrain(servoUpPct, 0, 100); //70 //
    int dspeed = int(4.2 * servoDownSpeedPct);
    int uspeed = int(4.2 * servoUpSpeedPct);

    float dist = abs(servoUpPct - servoDownPct); //40
    servoDownTime = int(1000.0 * dist / servoDownSpeedPct); //Duration of movement;
    servoUpTime = int(1000.0 * dist / servoUpSpeedPct);

    // c_report("Heights reset.");
  }




  public void raisePen() { raisePen(0); }
  public void raisePen( int penDelay ) {

    if (penDown == true)
    {
      int delay = penDelay + servoUpTime + delayAfterRaisingPen;
      nextMoveTime = millis() + delay;
      totalTime += delay;

      penDown = false;
      //c_report("Raise Pen.");
    }
  }


  public void lowerPen() { lowerPen(0); }
  public void lowerPen( int penDelay ) {

    if (penDown == false)
    {
      int delay = penDelay + servoDownTime + delayAfterLoweringPen;
      nextMoveTime = millis() + delay;
      totalTime += delay;

      penDown = true;
      //c_report("Lower Pen.");
    }
  }


  public void togglePen() {

    if (penDown) raisePen();
    else lowerPen();
    // myPort.write("SP,0\r"); // togglePen
    // penDown = !penDown;
  }







  private void motorsOn( int stepperResolution ) {
    //
  }

  public void motorsOff() {
    //
  }


  public void zero() {
    currentA = 0;
    currentB = 0;

    moveDestA = -1;
    moveDestB = -1;

    // c_report("Motors zeroed.");
  }



  public void configMotorSpeeds( int downPct, int upPct ) {

    if (rapidSpeedPct != upPct || drawingSpeedPct != downPct)
    {
      rapidSpeedPct = upPct;
      drawingSpeedPct = downPct;

      motorSettingsSetup();
    }
  }




  /*
    Movement Method Cascade Tree
      Use move() to be managed by absoluteMode, and millimeterMode.
      Use *XY() for steps, *Units() for managed mm/inches,
        and *Relative*() for just that.
  */
  public void move(float a, float b) {

    //Unspecific, managed movement
    if (absoluteMode) moveToUnits(a, b);
    else moveRelativeUnits(a, b);
  }

  public void moveRelativeUnits(float aD, float bD) {

    // Change carriage position by (xDelta, yDelta), with XY limit checking, time management, etc.
    moveRelativeAB( unitsToSteps(aD), unitsToSteps(bD) );
  }

  public void moveRelativeAB(int aD, int bD) {

    // Change carriage position by (xDelta, yDelta), with XY limit checking, time management, etc.

    int aTemp = currentA + aD;
    int bTemp = currentB + bD;

    moveToAB(aTemp, bTemp);
  }

  public void moveToPct(float aPct, float bPct) {
    moveToAB( int(aPct*(motorMaxA - motorMinA)), int(bPct*(motorMaxB - motorMinB)) );
  }

  public void moveToUnits(float aLoc, float bLoc) {
    moveToAB( unitsToSteps(aLoc), unitsToSteps(bLoc) );
  }

  public void moveToAB(int aLoc, int bLoc) {

    moveDestA = aLoc;
    moveDestB = bLoc;

    moveToAB();
  }

  public void moveToAB() {

    //Set time
    int traveltime_ms, speed;

    moveDestA = constrain(moveDestA, motorMinA, motorMaxA);
    moveDestB = constrain(moveDestB, motorMinB, motorMaxB);

    float[] start = getPositionPercent();
    float[] end = getDestPercent();

    // println("PenDown " + penDown);
    // printArray(start);
    // printArray(end);

    int aD = moveDestA - currentA;
    int bD = moveDestB - currentB;

    if ((aD != 0) || (bD != 0))
    {
      currentA = moveDestA;
      currentB = moveDestB;

      if (penDown) speed = drawingSpeed;
      else speed = rapidSpeed;


      float maxTravel = getDistance( 0, 0, abs(aD), abs(bD) );
      traveltime_ms = floor( 1000.0 * maxTravel / speed );
      nextMoveTime = millis() + traveltime_ms;
      totalTime += traveltime_ms;

      //Estimating Distance
      if (penDown) drawDistance += maxTravel;
      else upDistance += maxTravel;

      //DRAWING!!
      if (penDown) canvas.line( start[0]*canvas.width, start[1]*canvas.height,
                                end[0]*canvas.width, end[1]*canvas.height );

      // c_report("A{x}: " + currentA + "  B{-y}: " + currentB + "  --MoveTo");
    }





  }



  // MACHINE QUERYING //////////////////////////////////////////////////////////


  public int queryPenUp() {
    if (penDown) return 0;
    else return 1;
  }


  public int queryPRGButton() {
    return 0;
  }

  public int[] queryMotorMoving() {
    int[] export = new int[]{0, 0, 0, 0};
    return export;
  }


  public int queryBufferFull() {
    return 0;
  }


  public int[] queryMotorStep() {

    int[] export = new int[]{-1, -1, -1, -1};

    export[0] = currentA + currentB;
    export[1] = currentA - currentB;
    export[2] = currentA;
    export[3] = currentB;

    return export;
  }


}