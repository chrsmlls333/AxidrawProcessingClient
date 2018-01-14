/*
  By Chris Eugene Mills

  My function framework etc. for recording pdfs, images, and imagesets (for vids).

  Do this in main .pde file
    Call in setup(),      c_init( color backgroundcolor, boolean debugmode, boolean verbosemode )
    Draw instead to,      c_draw()
    Call in keyPressed(), c_checkKey( char key )


  Key Commands

    1 - start/stop verbose mode
    2 - start/stop debug mode

    3 - save still image
    4 - save pdf
    5 - start/stop saving video

*/

import processing.pdf.*;
import processing.awt.PSurfaceAWT;
import com.jogamp.newt.opengl.GLWindow;

// Recording Vars //////////////////////////////////////////////////////////////

boolean recordPDF = false;
boolean recordVid = false;
boolean recordPic = false;
String vidStamp;

boolean c_debug = false;
boolean c_verbose = false;
color c_bg = color(128);



// Utilities ///////////////////////////////////////////////////////////////////

void c_init( color c, boolean v, boolean d) {
  c_bg = c;
  c_debug = d;
  c_verbose = v;
}

void draw() {
  background(c_bg);
  c_pre();
  c_draw();
  c_post();
}

void c_pre() {
  surface.setTitle(getTitleString( "AxiDraw GCode Client - "));
  if ( recordPDF ) {
    PGraphicsPDF pdf = (PGraphicsPDF) createGraphics(width, height, PDF, "pdf/"+timeStamp()+"-"+frameCount+"-output.pdf");
    beginRecord(pdf);
    println("started");
  }
}

void c_post() {
  if (recordPDF) {
    endRecord();
    recordPDF = false;
    println("Done PDF");
  }
  if (recordPic) {
    saveImage();
    recordPic = false;
    println("Done Image");
  }
  if (recordVid) {
    saveFrame("vid"+vidStamp+"/fr####.tga");
  }
}

boolean c_checkKey( char key ) {
  char k = str(key).toLowerCase().charAt(0);

  switch(k) {
    case '1':
      c_verbose = !c_verbose;
      println("Verbose: " + c_verbose);
      break;

    case '2':
      c_debug = !c_debug;
      println("Debug:   " + c_debug);
      break;

    case '3':
      recordPic = true;
      break;

    case '4':
      recordPDF = true;
      break;

    case '5':
      saveVideo();
      break;

    default:
      return false;
  }

  return true;
}




// Recording ///////////////////////////////////////////////////////////////////

void saveVideo() {
  if (!recordVid) {
    vidStamp = timeStamp();
    println("Video Folder:"+vidStamp);
  } else {
    println("Done Video");
  }

  recordVid = !recordVid;
}

void saveImage() {
  saveFrame("images/"+timeStamp()+"-####.png");
}




// Strings /////////////////////////////////////////////////////////////////////

String getTitleString() { return getTitleString(""); }
String getTitleString( String prefix ) {
  String title = prefix + int(frameRate) + " fps, Frame " + frameCount;
  return title;
}

String timeStamp() {
  String s = str(year())+nf(month(),2)+nf(day(),2)+"-"+nf(hour(),2)+nf(minute(),2)+nf(second(),2);
  return s;
}

void c_print( String s ) { //Verbose level
  if (c_verbose) println(s);
}

void c_report( String s ) { //Debug level
  if (c_debug) println(s);
}

void c_reportNONL( String s ) {
  if (c_debug) print(s);
}




// Math ////////////////////////////////////////////////////////////////////////

boolean coin() {
  if (random(1)>0.5) return true;
  else return false;
}

int coinInt() {
  if (random(1)>0.5) return 1;
  else return 0;
}

float randomGaussian( float amp ) {
  return randomGaussian() * amp;
}

float random() {
  return random(1);
}




// Other ///////////////////////////////////////////////////////////////////////

// renderer = either JAVA2D (default), P2D or P3D
public int[] getWindowLocation(String renderer) {
  if (renderer == P2D || renderer == P3D) {
    // Get OpenGL window
    com.jogamp.newt.opengl.GLWindow newtCanvas = (com.jogamp.newt.opengl.GLWindow) surface.getNative();
    // Return X/Y
    return new int[]{newtCanvas.getX(), newtCanvas.getY()};
  } else if (renderer == JAVA2D) {
    // Get JFrame window
    javax.swing.JFrame awtCanvas = (javax.swing.JFrame)((processing.awt.PSurfaceAWT.SmoothCanvas) surface.getNative()).getFrame();
    // Return X/Y
    return new int[]{awtCanvas.getX(), awtCanvas.getY()};
  }
  return new int[]{-1, -1};
}



// renderer = either JAVA2D (default), P2D or P3D
public void removeExitEvent(String renderer) {
  if (renderer == P2D || renderer == P3D) {
    // Get OpenGL window
    com.jogamp.newt.opengl.GLWindow newtCanvas = (com.jogamp.newt.opengl.GLWindow) surface.getNative();
    // Remove listeners added by Processing
    for (com.jogamp.newt.event.WindowListener l : newtCanvas.getWindowListeners())
      if (l.getClass().getName().startsWith("processing"))
        newtCanvas.removeWindowListener(l);
    // Set on close action to do nothing i.e. keep the window open
    newtCanvas.setDefaultCloseOperation(com.jogamp.nativewindow.WindowClosingProtocol.WindowClosingMode.DO_NOTHING_ON_CLOSE);
  } else if (renderer == JAVA2D) {
    javax.swing.JFrame awtCanvas = (javax.swing.JFrame)((processing.awt.PSurfaceAWT.SmoothCanvas) surface.getNative()).getFrame();
    //println(awtCanvas.getClass().getSimpleName());
    for (java.awt.event.WindowListener l : awtCanvas.getWindowListeners())
      awtCanvas.removeWindowListener(l);
    awtCanvas.setDefaultCloseOperation(javax.swing.JFrame.DO_NOTHING_ON_CLOSE);
  }
}