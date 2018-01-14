/*
  By Chris Eugene Mills

  Based off an example by Andreas Schlegel, 2016
*/

import javax.swing.JFrame;
import processing.awt.PSurfaceAWT;
import com.jogamp.newt.opengl.GLWindow;

class ControlFrame extends PApplet {

  int w, h;
  PApplet parent;
  ControlP5 cp5;
  String windowTitle;
  boolean visible = true;

  public ControlFrame(PApplet _parent, int _w, int _h, String _name) {
    super();
    parent = _parent;
    w=_w;
    h=_h;
    windowTitle = _name;
    PApplet.runSketch(new String[]{this.getClass().getName()}, this);
  }

  public void settings() {
    size(w, h, JAVA2D);
  }

  public void setup() {
    surface.setTitle(windowTitle);
    removeExitEvent(JAVA2D);

    cp5 = new ControlP5(this);
    cp5.enableShortcuts();

  }

  void draw() {
    background(bg);

    /*
      TODO This window is already drawing when I want to add control elements, making
      something in CP5 crap out, give a delay, and research later:
      https://forum.processing.org/one/topic/controlp5-and-java-util-concurrentmodificationexception.html
    */
    if (frameCount == 1) delay(1000);



  }

  // public void controlEvent(ControlEvent theEvent) {
  //
  // }

  // INTERACTION ///////////////////////////////////////////////////////////////
  // Use our button variables, as we are in another thread, and therefore these
  // direct calls could kill. Replicating the interaction in KeyInteraction.pde
  // for our second window.


  void keyPressed(KeyEvent e) {
    parent.keyPressed(e);
  }



  // PUBLIC ACCESS /////////////////////////////////////////////////////////////

  public void setLocation( int x, int y ) {
    surface.setLocation(x, y);
  }
  
  public void setResizable( boolean set ) {
    surface.setResizable(set);
  }

  public void openClose() {
    visible = !visible;
    surface.setVisible(visible);
  }

  public int[] getCanvasSize() {
    return new int[]{width, height};
  }

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
    } else return new int[]{-1, -1};

  }



  // ADAPT WINDOW //////////////////////////////////////////////////////////////

  @Override void exit() {
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



}