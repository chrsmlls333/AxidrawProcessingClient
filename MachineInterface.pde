/*
  By Chris Eugene Mills

  Private methods not allowed? Must be implemented on each unique class.
*/


interface Machine {

  public void connect();
  // private void motorSettingsSetup();
  public void clone(AxiDrawMachine _clone);

  // MODES and UTILS ///////////////////////////////////////////////////////////
  public void alignmentMode();
  public void setRelativeMode();
  public void setAbsoluteMode();
  public void setInchesMode();
  public void setMillimeterMode();

  // SHORTCUTS
  public void goHome();

  // ACCESS UTILITIES
  public int[] getPositionAB();
  public float[] getPositionUnits();
  public float getAMaxUnits();
  public float getBMaxUnits();
  public float[] getPositionPercent();
  public float[] getDestPercent();
  public float[] getRealPositionPercent();
  public int getNextMoveTime();
  public boolean isConnected();
  public boolean isAbsoluteMode();
  public boolean isPenDown();
  public boolean isRealPenDown();

  // TIMING/ESTIMATION
  public void startEstimation();
  public void endEstimation();

  // PRIVATE UTILITIES
  // private int unitsToSteps( float x );
  // private int mmToSteps( float x );
  // private int inToSteps( float x );
  // private float stepsToUnits( int x );
  // private float getDistance( float x1, float y1, float x2, float y2 );

  // MACHINE OPERATIONS ////////////////////////////////////////////////////////
  public void configPenSpeeds( int downSpeed, int upSpeed );
  public void configPenHeights( int downPct, int upPct );
  public void raisePen();
  public void raisePen( int penDelay );
  public void lowerPen();
  public void lowerPen( int penDelay );
  public void togglePen();

  // private void motorsOn( int stepperResolution )
  public void motorsOff();
  public void zero();
  public void configMotorSpeeds( int downPct, int upPct );
  public void move( float a, float b );
  public void moveRelativeUnits( float aD, float bD );
  public void moveRelativeAB( int aD, int bD );
  public void moveToPct( float aPct, float bPct );
  public void moveToUnits( float aLoc, float bLoc );
  public void moveToAB( int aLoc, int bLoc );

  // MACHINE SENDING ///////////////////////////////////////////////////////////
  // private boolean send( String str );
  // private boolean waitForOK();
  // private boolean waitLoop();

  // MACHINE QUERYING //////////////////////////////////////////////////////////
  // private String query( String send );
  public int queryPenUp();
  public int queryPRGButton();
  public int[] queryMotorMoving();
  public int queryBufferFull();
  public int[] queryMotorStep();

}