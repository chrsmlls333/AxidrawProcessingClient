import processing.core.*; 
import processing.data.*; 
import processing.event.*; 
import processing.opengl.*; 

import penner.easing.*; 
import java.lang.reflect.*; 
import processing.serial.*; 
import java.util.*; 
import processing.pdf.*; 
import java.lang.Character; 
import java.util.*; 

import penner.easing.*; 

import java.util.HashMap; 
import java.util.ArrayList; 
import java.io.File; 
import java.io.BufferedReader; 
import java.io.PrintWriter; 
import java.io.InputStream; 
import java.io.OutputStream; 
import java.io.IOException; 

public class U4_Axidraw extends PApplet {

/*
  By Chris Eugene Mills

  Partly ripped from SimpleDirectDraw by Koblin, but the GCode import is original.
  Requires EBB firmware >=2.5.1

  Press '?' for help.

  GCODE FORMAT NOTES IN QUEUERUNNERCLASS.PDE
*/

// LIBRARIES ///////////////////////////////////////////////////////////////////




// CONFIG //////////////////////////////////////////////////////////////////////

String gCodeFilename = "2-Axidraw.ngc";
boolean letterSize = true;

boolean xyFix = true; //IMPORTANT, notes in QueueRunner Class




// VARS ////////////////////////////////////////////////////////////////////////

AxiDrawMachine axidraw;
PApplet serialThis = this; //hack TODO

QueueRunner qRunner;

PGraphics buffer, penLoc;
int bufferwidth, bufferheight;




// BEGIN ///////////////////////////////////////////////////////////////////////

public void setup() {
  // Setup Canvas
  
  surface.setResizable(true);
  
  frameRate(30);
  c_init(color(0), true, true);

  //Init Libraries


  // Paper Size
  if (letterSize) { //Letter Paper
    bufferwidth = 280;
    bufferheight = 216;
  } else { //A4 Paper
    bufferwidth = 297;
    bufferheight = 210;
  }

  // Draw Buffers
  buffer = createGraphics(bufferwidth*3, bufferheight*3);
  buffer.beginDraw();
  buffer.background(255);
  buffer.scale(3);
  buffer.endDraw();

  penLoc = createGraphics(bufferwidth*3, bufferheight*3);
  penLoc.beginDraw();
  penLoc.clear();
  buffer.scale(3);
  penLoc.endDraw();

  // MACHINE
  axidraw = new AxiDrawMachine(bufferwidth, bufferheight);

  // QUEUERUNNER
  qRunner = new QueueRunner(axidraw);
  qRunner.setXYFix(xyFix);
  qRunner.drawOn(buffer, penLoc);
  qRunner.load(gCodeFilename);
  //qRunner.start();

}




public void c_draw()
{
  qRunner.run();


  // Draw Plotter position, and preview
  qRunner.draw();

  // Draw buffer to canvas
  translate(20, 0);
  image(buffer, 0, 20, width-40, buffer.height*(width-40)/buffer.width);
  image(penLoc, 0, 20, width-40, penLoc.height*(width-40)/penLoc.width);

  // Interface Draw
  float interfaceTopY = buffer.height*(width-40)/buffer.width + 40;
  translate(0, interfaceTopY);
  noFill();
  strokeWeight(1);
  stroke(255);
  rect(0,0, width-40, max(0, height - (interfaceTopY + 20)));


}



// FUNCTIONS ///////////////////////////////////////////////////////////////////

public void reset() {
  setup();
}
/*
  By Chris Eugene Mills

  TODO
    convert all X/Y to PVectors
*/




class AxiDrawMachine {

  // SETTINGS //////////////////////////////////////////////////////////////////

  int drawingSpeedPct = 30;         // % of max speed
  int rapidSpeedPct = 40;
  int resolution = 1;               // 1=1/16, 2=1/8
  boolean constantSpeed = true;

  int servoUpPct   = 35;            // Brush UP position, % (100 = up)
  int servoDownPct = 16;            // Brush DOWN position, % (0 = down)
  int servoDownSpeed = 100;         // %/second
  int servoUpSpeed = 200;           // %/second

  boolean reverseMotorX = false;    //Don't change lest machine changes
  boolean reverseMotorY = false;    //Don't change lest machine changes

  int delayAfterRaisingPen = 0;     //ms
  int delayAfterLoweringPen = 50;   //ms

  //int minDist = 4;                  // Minimum drag distance to record TODO

  /*
    waitLimit*20ms = time before we call it quits on serial connection
  */
  int waitLimit = 1000;

  /*
    DPI ("dots per inch") @ 16X microstepping. Standard value: 2032, or 80 steps
    per mm. This is an exact number, but note that it refers to derived distance
    along X/Y directions. The "true" resolution along the native axes (Motor1,
    Motor2) is actually higher than this, at 2032 * sqrt(2) steps per inch, or
    about 2873.7 steps/inch.
  */
  int dpi_16X = 2032;	//Don't Change

  /*
    Maximum (110%) speed, in steps per second. Note that 25 kHz is the absolute
    maximum speed (steps per second) for the EBB.
  */
  int speedScale = 24950; //Don't Change



  // VARIABLES /////////////////////////////////////////////////////////////////


  // Serial
  boolean startSerialOnInit = true;
  boolean SerialOnline;
  Serial myPort;  // Create object from Serial class
  int val;        // Data received from the serial port

  //Config Vars
  int drawingSpeed, rapidSpeed;
  float stepsPerInch, stepsPerMM;
  int motorMinX, motorMinY, motorMaxX, motorMaxY;
  int servoUpTime, servoDownTime; //default delay for our speeds
  boolean penDownAtPause = false;
  boolean millimeterMode = true;
  boolean absoluteMode = true; //TODO: Relative mode may have rounding errors over many steps

  // Instant Status
  boolean penDown = false;
  int motorX = 0;  // Position of X motor
  int motorY = 0;  // Position of Y motor
  int lastPosition; // Record last encoded position for drawing
  boolean paused = false;
  int xLocAtPause, yLocAtPause;

  // Next
  int moveDestX = -1;
  int moveDestY = -1;
  //Time we are allowed to begin the next movement
  //(i.e., when the current move will be complete).
  int nextMoveTime;




  // CONSTRUCTOR(s) ////////////////////////////////////////////////////////////

  AxiDrawMachine( int paperWidthMM, int paperHeightMM ) //TODO accept inches
  {
    //Initialize VARS
    motorSettingsSetup(resolution, paperWidthMM, paperHeightMM);

    nextMoveTime = millis();

    //Connect
    if (startSerialOnInit) connect();
  }




  public void connect()
  {
    scanSerial();

    if (SerialOnline) {
      motorsOn(resolution);  //Configure both steppers to step mode
      configPenHeights(); // Configure brush lift servo endpoints and speed

      // Alignment Mode TODO do we ask for where it think it is? Perhaps a seperate "spontaneously disconnected" catch?
      alignmentMode();

      println("Now entering connected drawing mode.\n");
      //redrawButtons(); //TODO
    } else {
      println("Now entering offline simulation mode.\n");
      //redrawButtons();
    }

    println("Press ? for help.\n");
  }




  private void motorSettingsSetup( int res, int paperWidthMM, int paperHeightMM ) {
    /*
      Set native motor resolution, and set speed scales.

      Motor init happens elsewhere, after serial connect.

      The "pen down" speed scale is adjusted with the following factors
      that make the controls more intuitive:
      * Reduce speed by factor of 2 when using 8X microstepping
      * Reduce speed by factor of 2 when disabling acceleration TODO

      These factors prevent unexpected dramatic changes in speed when turning
      those two options on and off.
    */
    if (res == 1 )
    {
      drawingSpeed = PApplet.parseInt(PApplet.parseFloat(drawingSpeedPct) / 110.0f * speedScale);
      rapidSpeed = PApplet.parseInt(PApplet.parseFloat(rapidSpeedPct) / 110.0f * speedScale);
      stepsPerInch = dpi_16X;	// Resolution along native motor axes (not XY)
    }
    else if (res == 2)
    {
      drawingSpeed = PApplet.parseInt( PApplet.parseFloat(drawingSpeedPct) / 220.0f * speedScale);
      rapidSpeed = PApplet.parseInt(PApplet.parseFloat(rapidSpeedPct) / 110.0f * speedScale);
      stepsPerInch = dpi_16X / 2.0f;	// Resolution along native motor axes (not XY)
    }
    stepsPerMM = stepsPerInch / 25.4f;
    //c_report("stepsPerInch: " + stepsPerInch);
    //c_report("stepsPerMM  : " + stepsPerMM);

    motorMinX = 0;
    motorMinY = 0;
    motorMaxX = PApplet.parseInt(paperWidthMM * stepsPerMM);
    motorMaxY = PApplet.parseInt(paperHeightMM * stepsPerMM);
    motorX = 0;
    motorY = 0;
  }




  // MODES and UTILS ///////////////////////////////////////////////////////////

  // MODES
  public void alignmentMode()
  {
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
  public void goHome()
  {
    c_report("Going to Graceland...");
    raisePen();
    moveToXY(0, 0);
  }




  // ACCESS UTILITIES

  public int[] getPositionXY() {
    return new int[]{ motorX, motorY };
  }

  public float[] getPositionUnits() {
    int[] temp = getPositionXY();
    return new float[]{ stepsToUnits(temp[0]), stepsToUnits(temp[1]) };
  }

  public float getYMaxUnits() {
    return stepsToUnits(motorMaxY);
  }

  public float[] getPositionPercent() {
    int[] temp = getPositionXY();
    return new float[]{ temp[0] / PApplet.parseFloat(motorMaxX - motorMinX),
                        temp[1] / PApplet.parseFloat(motorMaxY - motorMinY) };
  }

  public float[] getRealPositionPercent() {
    int[] temp = queryMotorStep();
    return new float[]{ temp[2] / PApplet.parseFloat(motorMaxX - motorMinX),
                        temp[3] / PApplet.parseFloat(motorMaxY - motorMinY) };
  }

  public int getNextMoveTime() {
    return nextMoveTime - ceil(1000.0f / (frameRate/3.0f));
    // Important correction-- Start next segment sooner than you might expect,
    // because of the relatively low framerate that the program runs at.
  }

  public boolean isConnected() {
    return SerialOnline;
  }
  
  public boolean isAbsoluteMode() {
    return absoluteMode;
  }




  // PRIVATE UTILITIES

  private int unitsToSteps( float x )
  {
    if (millimeterMode) return PApplet.parseInt(x * stepsPerMM);
    else return PApplet.parseInt(x * stepsPerInch);
  }

  private float stepsToUnits( int x )
  {
    if (millimeterMode) return (x / stepsPerMM);
    else return (x / stepsPerInch);
  }

  private float getDistance(float x1, float y1, float x2, float y2)
  {
    float xdiff = abs(x2 - x1);
    float ydiff = abs(y2 - y1);
    return sqrt(pow(xdiff, 2) + pow(ydiff, 2));
  }


  // MACHINE OPERATIONS //////////////////////////////////////////////////////////////////////////////

  private void motorsOn( int stepperResolution )
  {
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

    c_report("Motors activated.");
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

    motorX = 0;
    motorY = 0;

    moveDestX = -1;
    moveDestY = -1;

    // Command: CS<CR>
    // Response: OK<CR><NL>
    if (SerialOnline) send("CS");

    c_report("A{x}: " + motorX + "  B{-y}: " + motorY + "  --ZEROED");
  }




  public void configPenSpeeds( int downSpeed, int upSpeed )
  {
    if (servoUpSpeed != upSpeed || servoDownSpeed != downSpeed)
    {
      servoUpSpeed = upSpeed;
      servoDownSpeed = downSpeed;

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
    int dspeed = PApplet.parseInt(4.2f * servoDownSpeed);
    int uspeed = PApplet.parseInt(4.2f * servoUpSpeed);

    float dist = abs(servoUpPct - servoDownPct); //40
    servoDownTime = PApplet.parseInt(1000.0f * dist / servoDownSpeed); //Duration of movement;
    servoUpTime = PApplet.parseInt(1000.0f * dist / servoUpSpeed);

    if (SerialOnline)
    {
      send("SC,5," + str(low)); // Brush DOWN position
      send("SC,4," + str(high)); // Brush UP position
      // send("SC,10,65535\r"); // Set brush raising and lowering speed.
      send("SC,12," + str(dspeed)); // Set brush lowering speed.
      send("SC,11," + str(uspeed)); // Set brush raising speed.
    }

    c_report("--HEIGHTS RESET"); //TODO
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
      c_report("Raise Pen.");
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
      c_report("Lower Pen.");
    }
  }


  public void togglePen()
  {
    if (penDown) raisePen();
    else lowerPen();
    // myPort.write("SP,0\r"); // togglePen
    // penDown = !penDown;
  }




  /*
    Movement Method Cascade Tree
      Use move() to be managed by absoluteMode, and millimeterMode.
      Use *XY() for steps, *Units() for managed mm/inches,
        and *Relative*() for just that.
  */
  public void move(float x, float y)
  {
    //Unspecific, managed movement
    if (absoluteMode) moveToUnits(x, y);
    else moveRelativeUnits(x, y);
  }

  public void moveRelativeUnits(float xD, float yD)
  {
    // Change carriage position by (xDelta, yDelta), with XY limit checking, time management, etc.
    moveRelativeXY( unitsToSteps(xD), unitsToSteps(yD) );
  }

  public void moveRelativeXY(int xD, int yD)
  {
    // Change carriage position by (xDelta, yDelta), with XY limit checking, time management, etc.

    int xTemp = motorX + xD;
    int yTemp = motorY + yD;

    moveToXY(xTemp, yTemp);
  }

  public void moveToPct(float xPct, float yPct)
  {
    moveToXY( PApplet.parseInt(xPct*(motorMaxX - motorMinX)), PApplet.parseInt(yPct*(motorMaxY - motorMinY)) );
  }

  public void moveToUnits(float xLoc, float yLoc)
  {
    moveToXY( unitsToSteps(xLoc), unitsToSteps(yLoc) );
  }

  public void moveToXY(int xLoc, int yLoc)
  {
    moveDestX = xLoc;
    moveDestY = yLoc;

    moveToXY();
  }

  public void moveToXY()
  {
    //Set time
    int traveltime_ms, speed;

    // Absolute move in motor coordinates, with XY limit checking, time management, etc.
    // Use moveToXY(int xLoc, int yLoc) to set destinations.


    moveDestX = constrain(moveDestX, motorMinX, motorMaxX);
    moveDestY = constrain(moveDestY, motorMinY, motorMaxY);

    int xD = moveDestX - motorX;
    int yD = moveDestY - motorY;

    if ((xD != 0) || (yD != 0))
    {
      motorX = moveDestX;
      motorY = moveDestY;



      if (constantSpeed || !penDown)
      {
        if (penDown) speed = drawingSpeed;
        else speed = rapidSpeed;

        // int maxTravel = max(abs(xD), abs(yD)); //why longest side? OLD
        float maxTravel = getDistance( 0, 0, abs(xD), abs(yD) );
        traveltime_ms = floor( 1000.0f * maxTravel / speed );
        nextMoveTime = millis() + traveltime_ms;

        if (SerialOnline)
        {
          if (reverseMotorX) xD *= -1;
          if (reverseMotorY) yD *= -1;
          send("XM," + str(traveltime_ms) + "," + str(xD) + "," + str(yD));
        }
      }


      else {
        //TODO, but not native AM command, which is unreliable
        //SHOWTIME ACCELERATE BABY
      }


      // c_report("A{x}: " + motorX + "  B{-y}: " + motorY + "  --MoveTo");
    }
  }




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
      boolean ok = waitForOK();
      return ok;
    }
    else
    {
      //How did u call me?
      return false;
    }
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
          // c_report(s.replace("\n", "_").replace("\r", "_"));
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
    int warning = PApplet.parseInt(waitLimit/2);
    int st = millis();
    while (myPort.available() == 0 )
    {
      repeats++;
      delay(20);
      if (repeats == warning) {
        println("ERROR: May be disconnected. Please wait...");
        println(str((millis()-st)/1000.0f));
      }
      if (repeats >= waitLimit) {
        println("ERROR: Disconnected. Please reconnect Axidraw and press 'c'");
        println(str((millis()-st)/1000.0f));
        SerialOnline = false;
        return false;
      }
    }
    if (repeats>1) c_report("Waited:" + str(repeats*20) + " ms");

    return true;
  }


  // MACHINE QUERYING //////////////////////////////////////////////////////////

  private String query( String send )
  {
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

  public int queryPenUp()
  {
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
          int code = PApplet.parseInt(tokens[i+1]);
          if (code == 0  || code == 1 || code == 2)
            export[i] = code;
          else
            c_report("Serial Response Unrecognized");
        }
      } else {
        c_report("Serial Response Unrecognized");
      }
    }

    return export;
  }


  public int queryBufferFull()
  {
    // Command: QM<CR>
    // Response: QM,CommandStatus,Motor1Status,Motor2Status<NL><CR> --- and maybe fifo status?
    int[] export = queryMotorMoving();
    return export[3];
  }


  public int[] queryMotorStep()
  {
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
          int code = PApplet.parseInt(tokens[i]);
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
    int PortNumber = -1;
    String portName;
    String str1, str2;
    int j;

    int OpenPortList[];
    OpenPortList = new int[0];

    SerialOnline = false;
    boolean serialErr = false;


    // Close first
    // TODO test this
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

      println("=================================================================");
      println("=  \n=  I found "+PortCount+" serial ports, which are:");
      println(Serial.list());
      println();

      String  os=System.getProperty("os.name").toLowerCase();
      boolean isMacOs = os.startsWith("mac os x");
      boolean isWin = os.startsWith("win");

      if (isMacOs)
      {
        str1 = "/dev/tty.usbmodem";
        // Can change to be the name of the port you want, e.g., COM5.
        // The default value is "/dev/cu.usbmodem"; which works on Macs.

        str1 = str1.substring(0, 14);

        j = 0;
        while (j < PortCount) {
          str2 = Serial.list()[j].substring(0, 14);
          if (str1.equals(str2) == true)
            OpenPortList =  append(OpenPortList, j);

          j++;
        }
      }

      else if  (isWin)
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
          println("=  Serial port "+portName+" could not be activated. \n=  ");
        }

        if (portErr == false)
        {
          myPort.buffer(1);
          myPort.clear();
          println("=  Serial port "+portName+" found and activated. \n=  ");

          String inBuffer = "";

          myPort.write("v\r");  //Request version number
          delay(50);  // Delay for EBB to respond!

          while (myPort.available () > 0) {
            inBuffer = myPort.readString();
            if (inBuffer != null) {
              println("= Version Number: "+inBuffer);
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

              println("=  Serial port "+portName+" confirmed to have EBB. \n=  ");
            }
            else
            {
              myPort.clear();
              myPort.stop();
              println("=  Serial port "+portName+": No EBB detected. \n=  ");
            }
          }
        }
        j++;
      }
      println("=  ");
      println("=================================================================");
    }
  }

}
/*
  By Christopher Eugene Mills

  My function framework etc.

  Do this in main .pde file
    Call in setup(),      c_init( color backgroundcolor, boolean debugmode, boolean verbosemode )
    Draw instead to,      c_draw()
    Call in keyPressed(), c_checkKey( char key )

  Key Commands
    1 - start/stop verbose mode
    2 - start/stop debug mode
    v - start/stop saving video
    s - save still image
    p - save pdf

*/


//Recording

boolean recordPDF = false;
boolean recordVid = false;
boolean recordPic = false;
String vidStamp;
//
boolean c_debug = false;
boolean c_verbose = false;
int c_bg = color(128);

// Utilities

public void c_init( int c, boolean d, boolean v) {
  c_bg = c;
  c_debug = d;
  c_verbose = v;
}

public void draw() {
  background(c_bg);
  c_pre();
  c_draw();
  c_post();
}

public void c_pre() {
  surface.setTitle(getTitleString( "AxiDraw GCode Client - "));
  // if ( recordPDF ) {
  //   PGraphicsPDF pdf = (PGraphicsPDF) createGraphics(width, height, PDF, "pdf/"+timeStamp()+"-"+frameCount+"-output.pdf");
  //   beginRecord(pdf);
  //   println("started");
  // }
}

public void c_post() {
  // if (recordPDF) {
  //   endRecord();
  //   recordPDF = false;
  //   println("Done PDF");
  // }
  if (recordPic) {
    saveImage();
    recordPic = false;
    println("Done Image");
  }
  // if (recordVid) {
  //   saveFrame("vid"+vidStamp+"/fr####.tga");
  // }
}

public boolean c_checkKey( char key ) {
  char k = str(key).toLowerCase().charAt(0);

  switch(k) {
    // case 'v':
    //   saveVideo();
    //   break;
    case '3': //changed
      recordPic = true;
      break;
    // case 'p':
    //   recordPDF = true;
    //   break;
    case '1':
      c_verbose = !c_verbose;
      break;
    case '2':
      c_debug = !c_debug;
      break;
    default:
      return false;
  }

  return true;
}

// Recording

public void saveVideo() {
  if (!recordVid) {
    vidStamp = timeStamp();
    println("Video Folder:"+vidStamp);
  } else {
    println("Done Video");
  }

  recordVid = !recordVid;
}

public void saveImage() {
  saveFrame("images/"+timeStamp()+"-####.png");
}

// Strings

public String getTitleString() { return getTitleString(""); }
public String getTitleString( String prefix ) {
  String title = prefix + PApplet.parseInt(frameRate) + " fps, Frame " + frameCount;
  return title;
}

public String timeStamp() {
  String s = str(year())+nf(month(),2)+nf(day(),2)+"-"+nf(hour(),2)+nf(minute(),2)+nf(second(),2);
  return s;
}

public void c_print( String s ) {
  if (c_verbose) println(s);
}

public void c_report( String s ) {
  if (c_debug) println(s);
}

public void c_reportNONL( String s ) {
  if (c_debug) print(s);
}

// Math

public boolean coin() {
  if (random(1)>0.5f) return true;
  else return false;
}

public int coinInt() {
  if (random(1)>0.5f) return 1;
  else return 0;
}

public float randomGaussian( float amp ) {
  return randomGaussian() * amp;
}

public float random() {
  return random(1);
}


//void reset() {
//  setup();
//}
/*
  By Chris Eugene Mills
*/



int[] supportedGCommands = new int[]{0, 1, 20, 21, 28, 90, 91};
int[] supportedMCommands = new int[]{2, 30};

class GCommand {

  // VARIABLES /////////////////////////////////////////////////////////////////

  public char set = '?';
  public int command = -1;
  public int feedrate = -1;
  public int duration = -1;
  public float x = Float.NaN;
  public float y = Float.NaN;
  public float z = Float.NaN;
  public boolean supported = false;


  // CONSTRUCTOR ///////////////////////////////////////////////////////////////

  GCommand( char _set, int _command) {
    set = Character.toUpperCase( _set );
    command = _command;
    supported = checkValidity( _set, _command );
  }

  GCommand( char _set, int _command, float _x, float _y, float _z) {
    x = _x;
    y = _y;
    z = _z;
    set = Character.toUpperCase( _set );
    command = _command;
    supported = checkValidity( _set, _command );
  }

  GCommand( char _set, int _command, float _x, float _y, float _z, int _feedrate) {
    feedrate = _feedrate;
    x = _x;
    y = _y;
    z = _z;
    set = Character.toUpperCase( _set );
    command = _command;
    supported = checkValidity( _set, _command );
  }


  // ///////////////////////////////////////////////////////////////////////////

  private boolean checkValidity( char _set, int _command )
  {
    //TODO LOOSE!! Only detects command code, not validity of data

    switch ( _set ) {
      case 'G':
        return matchIntArray(supportedGCommands, _command);
      case 'M':
        return matchIntArray(supportedMCommands, _command);
      case 'T':
        return false;
      default:
        return false;
    }
  }

  private boolean matchIntArray(int[] arr, int targetValue)
  {
  	for(int s: arr){
  		if(s == targetValue) return true;
  	}
  	return false;
  }

  public JSONObject getJSON()
  {
    JSONObject json = new JSONObject();
    json.setString("commandSet", str(set));
    json.setInt("commandCode", command);
    json.setBoolean("supported", supported);

    JSONObject data = new JSONObject();
    if (Float.isNaN(x)) data.setFloat("x", x);
    if (Float.isNaN(y)) data.setFloat("y", y);
    if (Float.isNaN(z)) data.setFloat("z", z);
    if (feedrate != -1) data.setFloat("feedrate", feedrate);
    if (duration != -1) data.setFloat("duration", duration);
    json.setJSONObject("data", data);

    return json;
  }
}
/*
  By Chris Eugene Mills
*/

// INTERACTION /////////////////////////////////////////////////////////////////

/*
  By Christopher Eugene Mills

  All keyboard and mouse interaction
*/

public void mousePressed() {
  if (mouseButton == LEFT) {
    // reset();
  } else if (mouseButton == RIGHT) {
  } else if (mouseButton == CENTER) {
  }
}

public void mouseReleased() {
  if (mouseButton == LEFT) {

  } else if (mouseButton == RIGHT) {
    //
  } else if (mouseButton == CENTER) {
    //
  }
}


boolean keyup = false;  //Hold prevention
boolean keydown = false;
boolean keyleft = false;
boolean keyright = false;
public void keyPressed() {
  if (key != CODED) {
    char k = str(key).toLowerCase().charAt(0);
    if ( !c_checkKey(k) ) {
      switch(k) {
        case 'r':
          //reset();
          break;
        case 'c':
          if (!qRunner.isRunning()) axidraw.connect();
          break;
        case 'd':
          if (!qRunner.isRunning()) axidraw.togglePen();
          break;
        case 'z': //zero
          if (!qRunner.isRunning()) axidraw.alignmentMode();
          break;
        case 'h':
          if (!qRunner.isRunning()) axidraw.goHome();
          break;
        case 'q':
          qRunner.stop();
          break;
        case 's':
          qRunner.start();
          break;
        case 'p':
          qRunner.pause();
          break;
        case ' ':
          // axidraw.pause();
          if (!qRunner.isRunning()) {
            axidraw.moveToPct(random(1), random(1));
            printArray(axidraw.getPositionPercent());
          }

          break;
        case '/':
        case '?':
          //help
          println("\nHELPME--WRITEME");
          println("Key Commands:\n  c: (re)Connect\n  d: Toggle Pen\n  z: Alignment Mode\n  h: Go Home\n  q: Query Buffer State\n  s: Start Queue\n  p: Pause/Unpause Queue\n  Arrows: Move 1cm manually");
          break;
      }
    }
  } else {
    int movementSize = 10; //mm
    switch(keyCode) {
      case UP:
        if (!keyup) {
          keyup = true;
          axidraw.moveRelativeUnits(0, -movementSize);
        }
        break;
      case DOWN:
        if (!keydown) {
          keydown = true;
          axidraw.moveRelativeUnits(0, movementSize);
        }
        break;
      case LEFT:
        if (!keyleft) {
          keyleft = true;
          axidraw.moveRelativeUnits(-movementSize, 0);
        }
        break;
      case RIGHT:
        if (!keyright) {
          keyright = true;
          axidraw.moveRelativeUnits(movementSize, 0);
        }
        break;
    }
  }
}

public void keyReleased()
{
  if (key == CODED)
  {
    switch(keyCode) {
      case UP:
        keyup = false;
        break;
      case DOWN:
        keydown = false;
        break;
      case LEFT:
        keyleft = false;
        break;
      case RIGHT:
        keyright = false;
        break;
    }
  }
}
/*
  By Chris Eugene Mills

  Simplified this part by only running when machine is connected. All tasks can
  be "sent" to machine if so, but not by this runner, which quits out.

  TODO:
    Hardier disconnection sensing

  Accepts GCode with many limitations!

    - Z axis accepts only true/false, non-zero/zero. Height settings baked into
      variables. TODO add full Z support.

    - Can not move in 3 dimensions at once. Z and XY motion must be in their own
      commands.

    - When planning your plot, position the model in the X,-Y quadrant, so that
      origin is at the top left of the drawing. TODO options here.

    - Script must end with a M30 command.

    - Ignores distinction between G00 and G01, but still functions by default
      with rapid motion when in clearance plane, and normal motion when pen is
      down.

    - Accepts units of Inches or Millimeters, but code must include G20 or G21.

    - All commands should be on seperate lines, with parts seperated by spaces,
      and comments (surrounded by brackets). No colons/semicolons.
*/




class QueueRunner {

  // SETTINGS //////////////////////////////////////////////////////////////////

  /*
    IMPORTANT
      Because the Axidraw and Processing Canvas have their origin in the Top-Left,
      this leaves us at odds with most drawing and CAM software.

      The below setting will invert the Y axis, allowing drawings placed in the
      X,-Y Quadrant of the planning program with origin at Top-Left to be drawn
      correctly on the Axidraw.

      TODO change this to XY, inverting about YMax
  */
  boolean xyFix = true;


  // VARIABLES /////////////////////////////////////////////////////////////////

  AxiDrawMachine machine;
  ArrayDeque<GCommand> runQueue, drawQueue, doneQueue, backupQueue;

  boolean running;
  int runEveryNFrames = 7;
  int drawEveryNFrames = 3;

  boolean paused;
  boolean penDownAtPause;
  int xLocAtPause, yLocAtPause;
  int indexDone;    // Index in to-do list of last action performed
  int indexDrawn;   // Index in to-do list of last to-do element drawn to screen

  PGraphics canvas, penCanvas;
  float[] penPosition;
  boolean lastPenDown_DrawingPath;
  int lastX_DrawingPath;
  int lastY_DrawingPath;




  // CONSTRUCTOR ///////////////////////////////////////////////////////////////

  QueueRunner( AxiDrawMachine _machine )
  {
    //Initialize VARS
    machine = _machine;

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

    doneQueue.clear();
    indexDone = -1;    // Index in to-do list of last action performed
    indexDrawn = -1;   // Index in to-do list of last to-do element drawn to screen

    penPosition = new float[]{0,0};
  }






  // QUEUE OPERATIONS //////////////////////////////////////////////////////////

  public void load( String _gCodeFilename ) {

    // runQueue.addAll(parseGCode(_gCodeFilename));
    backupQueue = parseGCode(_gCodeFilename);
    runQueue = backupQueue.clone();
    // c_report("QUEUE: Size: " + runQueue.size());

    resetVars();

    //Load queue for master drawing
    drawQueue = backupQueue.clone();
    resetDrawing();
  }

  public int size() {
    return runQueue.size();
  }





  public boolean setXYFix( boolean b ) {
    xyFix = b;
    return xyFix;
  }




  public boolean start()
  {
    if (machine.isConnected() && backupQueue.size() > 0) {
      runQueue = backupQueue.clone();
      resetVars();
      running = true;
      println("QUEUE: Started!");
    }
    else if ( backupQueue.size() == 0 ) println("QUEUE: Nothing to start!");

    else println("QUEUE: Can't start disconnected!");

    return running;
  }

  public boolean stop()
  {
    if (running) {
      running = false;

      println("QUEUE: Stopped!");
    }
    else println("QUEUE: Can't stop unstarted!");

    return running;
  }

  public boolean isRunning() {
    return running;
  }



  public boolean pause()
  {
    if (running)
    {
      if (paused)
      {
        c_report("QUEUE: Unpaused");
        paused = false;
        //TODO handle resume pen height
      }

      else
      {
        c_report("QUEUE: Paused");
        paused = true;
        //TODO handle pause penup
      }
    }
    return paused;
  }




// Processing/Sending Functions ////////////////////////////////////////////////

  public void run()
  {
    // Don't pester the machine so much?
    if (frameCount % runEveryNFrames == 0)
    {
      loopCheck();
    }
    if (frameCount % drawEveryNFrames == 0)
    {
      updatePenPosition();
    }
  }

  private void loopCheck()
  {
    //Skip if refridgerator not running
    if (running && !paused)
    {
      //Check if disconnected
      if (!machine.isConnected())
      {
        println("QUEUE: Machine Disconnected!");
        println("QUEUE: Stopped Running!");
        running = false;
        return;
        // Don't send any more commands. needs a full restart.
      }

      //Check if pause button
      else if (machine.queryPRGButton() == 1)
      {
        println("QUEUE: Paused by button!");
        pause(); //TODO debounce holding this button
        return;
      }

      else
      {
        //If its not even our time yet don't pester the machine.
        if (millis() >= machine.getNextMoveTime())
        {
          //Check if this is just gonna get backed up "in our usb cable."
          if (machine.queryBufferFull() == 0)
          {
            // c_report("QUEUE: GOOO!");
            next(); //Good to go!!
          }
          else c_report("QUEUE: Buffer Still Full!");
        }
        else c_report("QUEUE: Not Ready!");
      }
    }

    else if (running && paused) {

      //Wait for hardware unpause
      if (machine.queryPRGButton() == 1)
      {
        println("QUEUE: unPaused by button!");
        pause();
      }
    }

    return;
  }




  private void next() {

    if (runQueue.size() > 0)
    {
      GCommand command = runQueue.poll();
      boolean drawMe = activateGCodeCommand(command);

      if (drawMe) {

      }


    }

    //If we are out of options, stop queue.
    else stop();

  }



  // returns if it is a "drawable" command, and therefore if it should pass on.
  private boolean activateGCodeCommand( GCommand _command ) {

    //No "if supported" checks, already done in parse

    //Get Command Data
    char set = _command.set;
    int command = _command.command;
    float feedrate = _command.feedrate;
    float x = _command.x;
    float y = _command.y;
    float z = _command.z;


    // Filter out specific cases
    if ( set == 'G') {
      switch ( command ) {
        case 0:
        case 1:
          //TODO make this unique for G00/G01
          c_report("QUEUE: XYZ Motion!");

          if (z == -1)
          {
            // XY MOTION ///////////////////////////////////////////////////////

            // HANDLE NULL XY
            if (x == -1 || y == -1) {
              if (x == -1 && y == -1) {
                c_report("QUEUE: No motion at all?!");
                return false;
              }

              if (machine.isAbsoluteMode()) {
                // Absolute Mode
                // Send current state
                if (x == -1) x = machine.getPositionUnits()[0];
                if (y == -1) y = machine.getPositionUnits()[1];
              }
              else {
                // Relative Mode
                if (x == -1) x = 0;
                if (y == -1) y = 0;
              }
            }


            // Y INVERSION FIX

            if (xyFix) {
              /*
                //TODO invert about YMax
                float yMax = getYMaxUnits();
                y = (y - yMax) * -1;
              */
              y *= -1;
            }

            //TODO Feedrate setting

            // SEND
            machine.move(x, y);
          }

          else
          {
            //TODO Feedrate setting
            //TODO Height setting
            if (z == 0) {
              machine.lowerPen();
            } else {
              machine.raisePen();
            }
          }

          return true;
        case 4:
          c_report("Dwell!");
          //TODO implement this
          return false;
        case 20:
          c_report("Inches!");
          machine.setInchesMode();
          return false;
        case 21:
          c_report("Metric!");
          machine.setMillimeterMode();
          return false;
        case 28:
          c_report("Return to Home!");
          machine.goHome();
          return false;
        case 90:
          c_report("Absolute Mode!");
          machine.setAbsoluteMode();
          return false;
        case 91:
          c_report("Relative Mode!");
          machine.setRelativeMode();
          return false;
        default:
          c_report("UNSUPPORTED G COMMAND");
          return false;
      }
    } else if (set == 'M') {
      switch ( command ) {
        case 2:
        case 30:
          c_report("END OF PROGRAM!");
          machine.goHome();
          return false;
        default:
          c_report("UNSUPPORTED M COMMAND");
          return false;
        }
    } else if (set == 'T') {
      c_report("UNSUPPORTED T COMMAND");
      return false;
    } else {
      c_report("NO COMMAND RECOGNIZED???");
      return false;
    }

  }






// Graphical functions /////////////////////////////////////////////////////////

  public void drawOn( PGraphics canvas1, PGraphics canvas2 )
  {
    canvas = canvas1;
    penCanvas = canvas2;
  }

  public float[] updatePenPosition() {
    if (machine.isConnected()) penPosition = machine.getRealPositionPercent();
    else penPosition = machine.getPositionPercent();
    return penPosition;
  }

  public void draw()
  {

    // Position Target Layer ///////////////////////////////////////////////////

    // updatePenPosition(); // Updated elsewhere

    penCanvas.beginDraw();
    penCanvas.clear();

    penCanvas.stroke(255,0,0);
    penCanvas.translate(penCanvas.width*penPosition[0],
                        penCanvas.height*penPosition[1]);
    penCanvas.line(-10, 0, 10, 0);
    penCanvas.line(0, -10, 0, 10);
    penCanvas.endDraw();

  }

  private void resetDrawing()
  {
    canvas.beginDraw();
    canvas.stroke(0);
    canvas.ellipse( canvas.width/2, canvas.height/2,
                    canvas.width/2, canvas.height/2 );
    // TODO real drawing function
    canvas.endDraw();
  }

  private void drawProgress()
  {
    canvas.beginDraw();
    canvas.stroke(0);
    canvas.ellipse( canvas.width/2, canvas.height/2,
                    canvas.width/2, canvas.height/2 );
    // TODO real drawing function
    canvas.endDraw();

  }


  // GCode IMPORT //////////////////////////////////////////////////////////////

  private ArrayDeque<GCommand> parseGCode( String _gCodeFilename )
  {
    ArrayDeque<GCommand> queue = new ArrayDeque<GCommand>();

    //Log Setup
    String errorLogFilename = "data/import.log";
    String jsonFilename = "data/export.json";
    PrintWriter log = createWriter(errorLogFilename);
    JSONArray export = new JSONArray();
    int lineNumber = 0;
    int errors = 0;

    //Reader Setup
    BufferedReader reader = null;
    reader = createReader(_gCodeFilename);
    if (reader != null) {

      //Reader RUN!
      String line = "";
      while (line != null) {
        try {
          line = reader.readLine();
        } catch (IOException e) {
          e.printStackTrace();
          log.println(e);
          line = null;
        }
        if (line != null) {
          //Normal Read
          lineNumber++;
          log.println( nf(lineNumber,5) + ": " + line);

          if (line.charAt(0) == '(')
          {
            //Comment line
          }
          else
          {
            // Deal with multiple commands per line
            String[] cmds = splitMultiCommandLine(line, log);
            for (int i = 0; i < cmds.length; i++ )
            {
              GCommand data = processGCodeCommand( cmds[i], lineNumber, log );

              if (data == null)
              {
                log.println("--------processGCodeCommand ERROR - RETURNED NULL----------");
              }
              else
              {
                if (data.supported == false)
                {
                  errors++;
                  log.println("--------------------UNHANDLED COMMAND----------------------");
                }
                else
                {
                  //Normal Operation, add to Queue
                  queue.add(data);
                  export.setJSONObject(export.size(), data.getJSON());
                }
              }
            }
          }
        }
      } //end while loop

      //Final Report
      String finale = "\nQUEUE: FINISHED GCODE PARSE: \n" +
                      "QUEUE: Error rate:  " + errors + "/" + lineNumber;
      log.println(finale);
      println(finale);

    }

    //Cleanup
    try {
      reader.close();
    } catch (IOException e) {
      e.printStackTrace();
      log.println(e);
    }
    log.flush();
    log.close();

    //Export JSON array of understood commands
    saveJSONArray(export, jsonFilename);

    return queue;
  }




  /*
    Mind that this may return an empty first array entry, \u00af\_(\u30c4)_/\u00af
  */
  private String[] splitMultiCommandLine (String line, PrintWriter log) {
    String[] pieces = line.split("(?=[gGmMtT])");
    return pieces;
  }




  /*
    Returns:
      null = critical failure
      'GCommand.supported = false' = just unsupported, skip cmd later
      'GCommand.supported = true' = confirmed
  */
  private GCommand processGCodeCommand( String line, int lineNumber, PrintWriter log ) {
    String[] pieces = line.split("\\s");

    //Get Command Code
    String command = pieces[0].toUpperCase();
    char commandSet = command.charAt(0);
    int commandCode = PApplet.parseInt(command.substring(1));
    log.print("                    cmd rx: " + commandSet + "_" + commandCode + " - ");

    //Get Command Data
    float feedrate = -1;
    float x = -1;
    float y = -1;
    float z = -1;
    // float duration = null; //TODO dwell

    if (pieces.length > 1) {
      for (int i = 1; i < pieces.length; i++) {
        String s = pieces[i].toUpperCase();
        char dataType = s.charAt(0);
        float data = PApplet.parseFloat(s.substring(1));

        switch (dataType) {
          case 'X':
            x = data;
            break;
          case 'Y':
            y = data;
            break;
          case 'Z':
            z = data;
            break;
          case 'F':
            feedrate = data;
            break;
        }
      }
    }

    // Filter out specific cases
    GCommand specialExport = null;
    if ( commandSet == 'G') {
      switch ( commandCode ) {
        case 0:
          log.println("Rapid Motion!");
          break;
        case 1:
          log.println("Normal Motion!");
          break;
        case 2:
          log.println("Arc Clockwise! UNSUPPORTED");
          break;
        case 3:
          log.println("Arc Counterclockwise! UNSUPPORTED");
          break;
        case 4:
          log.println("Dwell! IGNORED FOR NOW"); //TODO implement this
          break;
        case 17:
          log.println("XY Plane! IGNORED");
          break;
        case 18:
          log.println("ZX Plane! WHO DO U THINK WE ARE");
          break;
        case 19:
          log.println("YZ Plane! WHO DO U THINK WE ARE");
          break;
        case 20:
          log.println("Inches!");
          break;
        case 21:
          log.println("Metric!");
          break;
        case 28:
          log.println("Return to Home!");
          break;
        case 90:
          log.println("Absolute Mode!");
          break;
        case 91:
          log.println("Relative Mode!");
          break;
        default:
          log.println("UNSUPPORTED G COMMAND");
          break;
      }
    } else if (commandSet == 'M') {
      switch ( commandCode ) {
        case 2:
        case 30:
          log.println("END OF PROGRAM!");
          break;
        case 6:
          log.println("ALL TOOL COMMANDS UNSUPPORTED");
          break;
        default:
          log.println("UNSUPPORTED M COMMAND");
          break;
        }
    } else if (commandSet == 'T') {
      log.println("UNSUPPORTED T COMMAND");
    } else {
      log.println("NO COMMAND RECOGNIZED???");
      return null;
    }

    //Export
    if (specialExport != null) {
      return specialExport;
    } else {
      return new GCommand(commandSet, commandCode, x, y, z, feedrate);
    }
  }









}
  public void settings() {  size(900, 900, P2D);  noSmooth(); }
  static public void main(String[] passedArgs) {
    String[] appletArgs = new String[] { "U4_Axidraw" };
    if (passedArgs != null) {
      PApplet.main(concat(appletArgs, passedArgs));
    } else {
      PApplet.main(appletArgs);
    }
  }
}
