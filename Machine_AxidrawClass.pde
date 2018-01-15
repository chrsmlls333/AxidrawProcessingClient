/*
  By Chris Eugene Mills

  Note: A/B is mixed-geometry XY, or "paperspace"

  TODO
    convert all X/Y to PVectors
    Acceleration
*/



class AxiDrawMachine implements Machine {

  // DEFAULT SETTINGS //////////////////////////////////////////////////////////////////

  int drawingSpeedPct = 10;         // % of max speed
  int rapidSpeedPct = 20;

  boolean constantSpeed = true;     // MASSIVE TODO

  int servoUpPct   = 40;            // Brush UP position, % (100 = up)
  int servoDownPct = 20;            // Brush DOWN position, % (0 = down)
  int servoDownSpeedPct = 150;      // %/second
  int servoUpSpeedPct = 200;        // %/second

  int delayAfterRaisingPen = 0;     //ms
  int delayAfterLoweringPen = 50;   //ms

  //int minDist = 4;                  // Minimum drag distance to record TODO

  /*
    waitLimit*20ms = time before we call it quits on serial connection
  */
  static final int serialWaitLimit = 1000; //20s

  /*
    DPI ("dots per inch") @ 16X microstepping. Standard value: 2032, or 80 steps
    per mm. This is an exact number, but note that it refers to derived distance
    along X/Y directions. The "true" resolution along the native axes (Motor1,
    Motor2) is actually higher than this, at 2032 * sqrt(2) steps per inch, or
    about 2873.7 steps/inch.
  */
  static final int dpi_16X = 2032;	//Don't Change
  static final int resolution = 1; // 1=1/16, 2=1/8

  /*
    Maximum (110%) speed, in steps per second. Note that 25 kHz is the absolute
    maximum speed (steps per second) for the EBB.

    TODO possibly too high
  */
  static final int speedScale = 24950; //Don't Change



  // VARIABLES /////////////////////////////////////////////////////////////////


  // Serial
  boolean startSerialOnInit = false;
  boolean SerialOnline; // Connected?
  Serial myPort;        // Create object from Serial class
  PApplet serialThis;   // Parent context for Serial init

  //Config Vars
  int drawingSpeed, rapidSpeed;
  float stepsPerInch, stepsPerMM;
  int motorMinA = 0;
  int motorMinB = 0;
  int motorMaxA, motorMaxB;
  int servoUpTime, servoDownTime; //default pen delays for our speeds
  boolean millimeterMode = true;
  boolean absoluteMode = true; //TODO: Relative mode may have rounding errors over many steps

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

  //Estimation
  float drawDistance = 0; //steps
  float upDistance = 0; //steps
  int startTime = 0; //ms




  // CONSTRUCTOR(s) ////////////////////////////////////////////////////////////

  AxiDrawMachine( PApplet parentContext, int paperWidthMM, int paperHeightMM) {
    //TODO accept inches

    //Initialize VARS
    serialThis = parentContext;

    motorSettingsSetup();
    motorMaxA = int(paperWidthMM * stepsPerMM);
    motorMaxB = int(paperHeightMM * stepsPerMM);
    currentA = 0;
    currentB = 0;

    nextMoveTime = millis();

    //Connect
    if (startSerialOnInit) connect();
  }




  public void connect() {

    scanSerial();

    if (SerialOnline) {
      motorsOn(resolution);  //Configure both steppers to step mode
      configPenHeights(); // Configure brush lift servo endpoints and speed

      // Alignment Mode TODO do we ask for where it think it is?
      // Perhaps a seperate "spontaneously disconnected" catch?
      alignmentMode();

      println("Now entering connected drawing mode.\n");

    } else {
      println("Now entering offline simulation mode.\nQueue Disabled.\n");
    }

    println("Press ? for help.\n");
  }




  private void motorSettingsSetup() {
    /*
      Set native motor resolution, and set speed scales.

      Motor init happens elsewhere, after serial connect.

      The "pen down" speed scale is adjusted with the following factors
      that make the controls more intuitive:
      * Reduce speed by factor of 2 when using 8X microstepping
      * Reduce speed by factor of 2 when disabling acceleration TODO

      These factors prevent unexpected dramatic changes in speed when turning
      those two options on and off.

      110% math makes 100% speed equal 22681, safely lower than 25000 maximum.
    */

    if (resolution == 1 ) {
      drawingSpeed = int(float(drawingSpeedPct) / 110.0 * speedScale);
      rapidSpeed = int(float(rapidSpeedPct) / 110.0 * speedScale);
      stepsPerInch = dpi_16X;	// Resolution along AB
    }
    else if (resolution == 2) {
      drawingSpeed = int( float(drawingSpeedPct) / 220.0 * speedScale);
      rapidSpeed = int(float(rapidSpeedPct) / 220.0 * speedScale);
      stepsPerInch = dpi_16X / 2.0;	// Resolution along AB
    }
    stepsPerMM = stepsPerInch / 25.4;

    //Constraints
    drawingSpeed = constrain(drawingSpeed, 200, speedScale);
    rapidSpeed = constrain(rapidSpeed, 200, speedScale);

    //c_report("stepsPerInch: " + stepsPerInch);
    //c_report("stepsPerMM  : " + stepsPerMM);


  }

  public void clone(AxiDrawMachine _clone) {
    //Here for Machine Interface, implemented in DummyMachine
    c_report("I'm all original, baby!!");
  }




  // MODES and UTILS ///////////////////////////////////////////////////////////

  // MODES
  public void alignmentMode() {
    penDown = true; //make it raise no matter what.
    raisePen();
    motorsOff();
    zero();
    println("TEMPORARY ALIGNMENT MODE -- Push to 'Home' position now");
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
    c_report("Going to Graceland...");
    raisePen(300);
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
    return nextMoveTime;//10*ceil(1000.0 / (frameRate));
    // Important correction-- Start next segment sooner than you might expect,
    // because of the relatively low framerate that the program runs at.
  }

  public boolean isConnected() {
    return SerialOnline;
  }

  public boolean isAbsoluteMode() {
    return absoluteMode;
  }

  public boolean isPenDown() {
    return penDown;
  }

  public boolean isRealPenDown() {
    int temp = queryPenUp();
    if (temp == 1) return false;
    if (temp == 0) return true;
    return false;
  }




  // TIMING/ESTIMATION

  public void startEstimation( ) {
    drawDistance = 0; //steps
    upDistance = 0; //steps
    startTime = millis(); //ms
  }

  public void endEstimation( ) {
    float totalDistance = drawDistance + upDistance;
    int totalTime = millis() - startTime;
    String duration = String.format("%02dm%02ds",
                                    TimeUnit.MILLISECONDS.toMinutes(totalTime),
                                    TimeUnit.MILLISECONDS.toSeconds(totalTime) -
                                    TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS.toMinutes(totalTime))
                                  );

    println("AXIDR: Drawing distance (cm): " + (drawDistance / stepsPerMM)/10 );
    println("AXIDR: Total distance (cm)  : " + (totalDistance / stepsPerMM)/10 + "\n" );
    println("AXIDR: Efficiency           : " + nf(drawDistance / totalDistance * 100.0, 1, 2) + "%");
    println("AXIDR: Machine ran for      : " + duration + "\n");
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

  public void configPenSpeeds( int downSpeed, int upSpeed ) {
    if (servoUpSpeedPct != upSpeed || servoDownSpeedPct != downSpeed)
    {
      servoUpSpeedPct = upSpeed;
      servoDownSpeedPct = downSpeed;

      configPenHeights();
      c_print("Pen speeds reset. " + downSpeed + "%/s, " + upSpeed + "%/s");
    }
  }

  public void configPenHeights( int downPct, int upPct ) {
    if (servoUpPct != upPct || servoDownPct != downPct)
    {
      servoUpPct = upPct;
      servoDownPct = downPct;

      configPenHeights();

      c_print("Pen heights reset. " + downPct + "%, " + upPct + "%");
    }
  }

  private void configPenHeights() {
    /*
      Pen position units range from 0% to 100%, which correspond to
      a typical timing range of 7500 - 25000 in units of 1/(12 MHz).
      1% corresponds to ~14.6 us, or 175 units of 1/(12 MHz).

      Servo speed units are in units of %/second, referring to the
			percentages above.  The EBB takes speeds in units of 1/(12 MHz) steps
			per 24 ms.

      My logic:
      Default 150%/second
      17500 = 100%
      175 = 1%
      1 %/s = 0.175 steps/ms
      4.2 steps/24ms

    */

    int low = 7500 + 175 * constrain(servoDownPct, 0, 100); //30 //
    int high = 7500 + 175 * constrain(servoUpPct, 0, 100); //70 //
    int dspeed = int(4.2 * servoDownSpeedPct);
    int uspeed = int(4.2 * servoUpSpeedPct);

    float dist = abs(servoUpPct - servoDownPct); //40
    servoDownTime = int(1000.0 * dist / servoDownSpeedPct); //Duration of movement;
    servoUpTime = int(1000.0 * dist / servoUpSpeedPct);

    if (SerialOnline)
    {
      send("SC,5," + str(low)); // Brush DOWN position
      send("SC,4," + str(high)); // Brush UP position
      // send("SC,10,65535\r"); // Set brush raising and lowering speed at once.
      send("SC,12," + str(dspeed)); // Set brush lowering speed.
      send("SC,11," + str(uspeed)); // Set brush raising speed.
    }

    //Force pen up
    penDown = true;
    raisePen();

    // c_report("Heights reset."); //TODO elaborate
  }




  public void raisePen() { raisePen(0); }
  public void raisePen( int penDelay )
  {
    if (penDown == true)
    {
      if (SerialOnline)
      {
        int delay = penDelay + servoUpTime + delayAfterRaisingPen;
        send("SP,1,"+str(delay));

        nextMoveTime = millis() + delay;
      }
      penDown = false;
      // c_report("Raise Pen.");
    }
  }


  public void lowerPen() { lowerPen(0); }
  public void lowerPen( int penDelay )
  {
    if (penDown == false)
    {
      if (SerialOnline)
      {
        int delay = penDelay + servoDownTime + delayAfterLoweringPen;
        send("SP,0,"+str(delay));

        nextMoveTime = millis() + delay;
      }
      penDown = true;
      // c_report("Lower Pen.");
    }
  }


  public void togglePen() {
    if (penDown) raisePen();
    else lowerPen();
    
    // old method
    // myPort.write("SP,0\r"); // native togglePen command
    // penDown = !penDown;
  }











  private void motorsOn( int stepperResolution ) {
    /*
      The allowed values of Enable1 are as follows:
      0: Disable motor 1
      1: Enable motor 1, set global step mode to 1/16 step mode (default upon reset)
      2: Enable motor 1, set global step mode to 1/8 step mode
      3: Enable motor 1, set global step mode to 1/4 step mode
      4: Enable motor 1, set global step mode to 1/2 step mode
      5: Enable motor 1, set global step mode to full step mode
    */

    //Note: restrained to 2 not 5 for usability
    int var = constrain(stepperResolution, 0, 2);

    if (SerialOnline) send("EM,"+str(var)+","+str(var));  //Disable both motors

    c_report("Motors initialized at setting" + str(var));
  }

  public void motorsOff()
  {
    if (SerialOnline) motorsOn(0);  //Disable both motors

    c_report("Motors disabled.");
  }



  public void zero()
  {
    // Mark current location as (0,0) in motor coordinates.
    // Manually move the motor carriage to the left-rear (upper left) corner
    //   after executing this command.

    currentA = 0;
    currentB = 0;

    moveDestA = -1;
    moveDestB = -1;

    // Command: CS<CR>
    // Response: OK<CR><NL>
    if (SerialOnline) send("CS");

    c_report("Motors zeroed.");
  }



  public void configMotorSpeeds( int downPct, int upPct ) {

    if (rapidSpeedPct != upPct || drawingSpeedPct != downPct)
    {
      rapidSpeedPct = upPct;
      drawingSpeedPct = downPct;

      motorSettingsSetup();

      c_print("Motor Speeds reset. " + downPct + "%, " + upPct + "%");
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

  public void moveToAB()   {
    // Absolute move in motor coordinates, with XY limit checking, time management, etc.
    // Use moveToAB(int xLoc, int yLoc) to set destinations.
    
    //Set time
    int traveltime_ms, speed;

    moveDestA = constrain(moveDestA, motorMinA, motorMaxA);
    moveDestB = constrain(moveDestB, motorMinB, motorMaxB);

    int aD = moveDestA - currentA;
    int bD = moveDestB - currentB;

    if ((aD != 0) || (bD != 0))
    {
      //TODO consider putting dist check here
      currentA = moveDestA;
      currentB = moveDestB;



      if (constantSpeed || !penDown)
      {
        if (penDown) speed = drawingSpeed;
        else speed = rapidSpeed;

        // int maxTravel = max(abs(aD), abs(bD)); //why longest side? OLD
        float maxTravel = getDistance( 0, 0, abs(aD), abs(bD) );
        if (maxTravel < 5) return;
        traveltime_ms = floor( 1000.0 * maxTravel / speed );
        traveltime_ms = max(  traveltime_ms,
                              ceil(abs(aD+bD)/25.0),
                              ceil(abs(aD-bD)/25.0)   );
        traveltime_ms = constrain(traveltime_ms, 10, 16777215);
        nextMoveTime = millis() + traveltime_ms;

        //Estimation/Reporting
        if (penDown) drawDistance += maxTravel;
        else upDistance += maxTravel;

        //Drawing
        if (SerialOnline)
        {
          c_report("               SM," + str(traveltime_ms) + "," + str(aD+bD) + "," + str(aD-bD));
          send("SM," + str(traveltime_ms) + "," + str(aD+bD) + "," + str(aD-bD));
        }
      }


      else {
        //TODO, but not native AM command, which is apparently unreliable
        //SHOWTIME ACCELERATE BABY
      }


      // c_report("A{x}: " + currentA + "  B{-y}: " + currentB + "  --MoveTo");
    }
  }



  // copied from axidraw inkscape to be interpreted later
  
  // def doTimedPause( portName, nPause ):
	// if (portName is not None):
	// 	while ( nPause > 0 ):
	// 		if ( nPause > 750 ):
	// 			td = int( 750 )
	// 		else:
	// 			td = nPause
	// 			if ( td < 1 ):
	// 				td = int( 1 ) # don't allow zero-time moves
	// 		ebb_serial.command( portName, 'SM,' + str( td ) + ',0,0\r')
	// 		nPause -= td

  //   def vInitial_VF_A_Dx(VFinal,Acceleration,DeltaX):
  // 	'''
  // 	Kinematic calculation: Maximum allowed initial velocity to arrive at distance X
  // 	with specified final velocity, and given maximum linear acceleration.
  //
  // 	Calculate and return the (real) initial velocity, given an final velocity,
  // 		acceleration rate, and distance interval.
  // 	Uses the kinematic equation Vi^2 = Vf^2 - 2 a D_x , where
  // 			Vf is the final velocity,
  // 			a is the acceleration rate,
  // 			D_x (delta x) is the distance interval, and
  // 			Vi is the initial velocity.
  //
  // 	We are looking at the positive root only-- if the argument of the sqrt
  // 		is less than zero, return -1, to indicate a failure.
  // 	'''
  // 	IntialVSquared = ( VFinal * VFinal )  - ( 2 * Acceleration * DeltaX )
  // 	if (IntialVSquared > 0):
  // 		return sqrt(IntialVSquared)
  // 	else:
  // 		return -1
  //
  // def vFinal_Vi_A_Dx(Vinitial,Acceleration,DeltaX):
  // 	'''
  // 	Kinematic calculation: Final velocity with constant linear acceleration.
  //
  // 	Calculate and return the (real) final velocity, given an initial velocity,
  // 		acceleration rate, and distance interval.
  // 	Uses the kinematic equation Vf^2 = 2 a D_x + Vi^2, where
  // 			Vf is the final velocity,
  // 			a is the acceleration rate,
  // 			D_x (delta x) is the distance interval, and
  // 			Vi is the initial velocity.
  //
  // 	We are looking at the positive root only-- if the argument of the sqrt
  // 		is less than zero, return -1, to indicate a failure.
  // 	'''
  // 	FinalVSquared = ( 2 * Acceleration * DeltaX ) +	( Vinitial * Vinitial )
  // 	if (FinalVSquared > 0):
  // 		return sqrt(FinalVSquared)
  // 	else:
  // 		return -1





  // MACHINE SENDING ///////////////////////////////////////////////////////////

  private boolean send( String str )
  {
    if (SerialOnline)
    {
      myPort.clear();
      myPort.write(str + "\r");

      String command = str.split(",")[0];
      boolean ok = waitForOK();
      return ok;
    }
    //How did u call even me?
    else return false;
  }


  /*
    So that we don't query before we've recieved an OK from the last send.

    TODO nonblocking version - If we run this one after another, this is
      the ultimate blocking algorithm, as the Axidraw internal buffer is
      only 2/3 entries deep. This may equal up to 6 second per draw loop.
      Please implement some kind of timed nonblocking delay between when
      the next action is expected.
  */
  private boolean waitForOK()
  {
    boolean ok = false;

    if (SerialOnline)
    {

      if (!waitLoop()) return false;

      while (myPort.available() > 0)
      {
        String s = myPort.readString();
        if (s != null)
        {
          ok = s.contains("OK");
          // c_report(s.replace("\n", "_").replace("\r", "_")+"\n\n");
          // c_report(str(ok));
          return ok;
        }
        else c_report("Serial Response Null");
      }
    }

    return false;
  }

  private boolean waitLoop()
  {
    int repeats = 0;
    int warning = int(serialWaitLimit/2);
    int st = millis();
    while (myPort.available() == 0 )
    {
      repeats++;
      delay(10); //ms
      if (repeats == warning) {
        println("ERROR: May be disconnected. Please wait...");
        println("ERROR: " + str((millis()-st)/1000.0) + " seconds in deathloop so far...,");
      }
      if (repeats >= serialWaitLimit) {
        println("ERROR: Disconnected. Please reconnect Axidraw and press 'c'");
        println("ERROR: " + str((millis()-st)/1000.0) + " seconds in deathloop total.");
        SerialOnline = false;
        return false;
      }
    }
    if (repeats>1) c_report("Waited:" + str(repeats*10) + " ms");

    return true;
  }


  // MACHINE QUERYING //////////////////////////////////////////////////////////

  private String query( String send ) {

    if (SerialOnline)
    {
      myPort.clear();
      myPort.write(send + "\r");

      if (!waitLoop()) return null;

      while (myPort.available() > 0)
      {
        String s = myPort.readString();
        if (s != null)
        {
          s = s.replace("\n", "").replace("\r", "");
          // c_report(s);
          return s;
        }
        else c_report("Serial Response Null");
      }
    }

    return null;
  }

  public int queryPenUp() {
    // Command: QP<CR>
    // Response: PenStatus<NL><CR>OK<CR><NL>

    String response = query("QP");

    if (response != null)
    {
      char code = response.charAt(0);
      if (code == '1') return 1;
      else if (code == '0') return 0;
      else c_report("Serial Response Unrecognized");
    }

    return -1;
  }


  public int queryPRGButton() {
    // Command: QB<CR>
    // Response: state<CR><NL>OK<CR><NL>
    // This command asks the EBB if the PRG button has been pressed since the last QB query or not.

    String response = query("QB");

    if (response != null)
    {
      char code = response.charAt(0);
      if (code == '1') return 1;
      else if (code == '0') return 0;
      else c_report("Serial Response Unrecognized");
    }

    return -1;
  }

  public int[] queryMotorMoving() {
    // Command: QM<CR>
    // Response: QM,CommandStatus,Motor1Status,Motor2Status<NL><CR> --- and maybe fifo status?

    int[] export = new int[]{-1, -1, -1, -1};

    String response = query("QM");

    if (response != null)
    {
      String[] tokens = response.split(",");

      if (tokens.length == 5)
      {
        for (int i = 0; i < 4; i++ )
        {
          int code = int(tokens[i+1]);
          if (code == 0  || code == 1 || code == 2)
            export[i] = code;
          else c_report("Serial Response Unrecognized");
        }
      } else c_report("Serial Response Unrecognized");
    }

    return export;
  }


  public int queryBufferFull() {
    // Command: QM<CR>
    // Response: QM,CommandStatus,Motor1Status,Motor2Status<NL><CR> --- and maybe fifo status?
    int[] export = queryMotorMoving();
    return export[3];
  }


  public int[] queryMotorStep() {
    // Command:QS<CR>
    // Response: GlobalMotor1StepPosition,GlobalMotor2StepPosition<NL><CR>OK<CR><NL>

    // Exports real motor X/Y, then calculated A/B values
    int[] export = new int[]{-1, -1, -1, -1};

    String response = query("QS");

    if (response != null)
    {
      String[] tokens = response.replace("OK","").split(",");

      if (tokens.length == 2)
      {
        for (int i = 0; i < 2; i++ )
        {
          int code = int(tokens[i]);
          export[i] = code;
          //TODO datacheck
        }

        int realX = export[0];
        int realY = export[1];
        int realB = (realX - realY) / 2;
        int realA = realB + realY;
        export[2] = realA;
        export[3] = realB;

        // c_report("A{x}: " + realA + "  B{-y}: " + realB + "  mX: " + realX + "  mY: " + realY + "  --REAL VALUES");
      } else {
        c_report("Serial Response Unrecognized");
      }

    }

    return export;
  }


  // SERIAL CONNECT METHOD /////////////////////////////////////////////////////

  private void scanSerial()
  {
    // Serial port search string:
    int PortCount = 0;
    //int PortNumber = -1;
    String portName;
    String str1, str2;
    int j;

    int OpenPortList[];
    OpenPortList = new int[0];

    SerialOnline = false;
    boolean serialErr = false;


    // Close first
    if (myPort != null) {
      myPort.clear();
      myPort.stop();
      myPort = null;
    }


    try {
      PortCount = Serial.list().length;
    }
    catch (Exception e) {
      e.printStackTrace();
      serialErr = true;
    }


    if (serialErr == false)
    {

      println("\n\n\n================================================");
      println("\n\n   I found "+PortCount+" serial ports, which are:");
      printArray(Serial.list());
      println();

      String os = System.getProperty("os.name").toLowerCase();
      boolean isMacOs = os.startsWith("mac os x");
      boolean isWin = os.startsWith("win");

      if (isMacOs)
      {
        str1 = "/dev/tty.usbmodem";
        // Can change to be the name of the port you want, e.g., COM5.
        // The default ue is "/dev/cu.usbmodem"; which works on Macs.

        str1 = str1.substring(0, 14);

        j = 0;
        while (j < PortCount) {
          str2 = Serial.list()[j].substring(0, 14);
          if (str1.equals(str2) == true)
            OpenPortList =  append(OpenPortList, j);

          j++;
        }
      }

      else if (isWin)
      {
        // All available ports will be listed.

        j = 0;
        while (j < PortCount) {
          OpenPortList =  append(OpenPortList, j);
          j++;
        }
      }

      else {
        // Assume linux

        str1 = "/dev/ttyACM";
        str1 = str1.substring(0, 11);

        j = 0;
        while (j < PortCount) {
          str2 = Serial.list()[j].substring(0, 11);
          if (str1.equals(str2) == true)
            OpenPortList =  append(OpenPortList, j);
          j++;
        }
      }




      boolean portErr;

      j = 0;
      while (j < OpenPortList.length) {

        portErr = false;
        portName = Serial.list()[OpenPortList[j]];

        try
        {
          myPort = new Serial(serialThis, portName, 38400);
        }
        catch (Exception e)
        {
          SerialOnline = false;
          portErr = true;
          println("   Serial port "+portName+" could not be activated. \n");
        }

        if (portErr == false)
        {
          myPort.buffer(1);
          myPort.clear();
          println("   Serial port "+portName+" found and activated. \n");

          String inBuffer = "";

          myPort.write("v\r");  //Request version number
          delay(50);  // Delay for EBB to respond!

          while (myPort.available () > 0) {
            inBuffer = myPort.readString();
            if (inBuffer != null) {
              println("   Version Number: "+inBuffer);
            }
          }

          str1 = "EBB";
          if (inBuffer.length() > 2)
          {
            // Old code: fix for buffer overrun on first connect
            // str2 = inBuffer.substring(0, 3);
            // if (str1.equals(str2) == true)
            if ( inBuffer.contains(str1) )
            {
              // EBB Identified!
              SerialOnline = true;    // confirm that this port is good
              j = OpenPortList.length; // break out of loop

              println("   Serial port "+portName+" confirmed to have EBB. \n=  ");
            }
            else
            {
              myPort.clear();
              myPort.stop();
              println("   Serial port "+portName+": No EBB detected. \n=  ");
            }
          }
        }
        j++;
      }
      println("");
      println("================================================\n");
    }
  }

}