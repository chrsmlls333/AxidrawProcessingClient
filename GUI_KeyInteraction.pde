/*
  By Christopher Eugene Mills

  All keyboard and mouse interaction, but not the code, just triggers.
*/

// INTERACTION /////////////////////////////////////////////////////////////////



void mousePressed() {
  if (mouseButton == LEFT) {
    // reset();
  } else if (mouseButton == RIGHT) {
  } else if (mouseButton == CENTER) {
  }
}

void mouseReleased() {
  if (mouseButton == LEFT) {

  } else if (mouseButton == RIGHT) {
    //
  } else if (mouseButton == CENTER) {
    //
  }
}

void mouseClicked(MouseEvent e) {
  if (mouseButton == LEFT) {
    if (e.getCount() == 2) {
      resetView();
    }
  } else if (mouseButton == RIGHT) {
    //
  } else if (mouseButton == CENTER) {
    resetView();
  }
}




void mouseDragged(MouseEvent e) {
  mouseDragPan();
}


void mouseWheel(MouseEvent e) {
  mouseWheelZoom(e);
}






public void keyPressed(KeyEvent e) {
  char keyChar = e.getKey();
  int keyCode = e.getKeyCode();
  if (keyChar != CODED) {
    char k = str(keyChar).toLowerCase().charAt(0);
    if ( !c_checkKey(k) ) { //If Chris_Utils hasn't used it.
      switch(k) {
        case 'r':
          //reset();
          break;
        case 'c':
          buttonConnect=true;
          break;
        case 'd':
          buttonPen=true;
          break;
        case 'z': //zero
          buttonAlignment=true;
          break;
        case 'h':
          buttonHome=true;
          break;
        case 'q':
          buttonStop=true;
          break;
        case 's':
          buttonStart=true;
          break;
        case 'p':
          buttonPause=true;
          break;
        case 'l':
          buttonLoad=true;
          break;
        case 'g':
          gridOn = !gridOn;
          break;
        case ' ':

          GLine g = new GLine(new PVector[]{
            new PVector(random(0,5000),random(0,5000)),
            new PVector(random(0,5000),random(0,5000)),
            new PVector(random(0,5000),random(0,5000)),
            new PVector(random(0,5000),random(0,5000)),
            new PVector(random(0,5000),random(0,5000)),
            new PVector(random(0,5000),random(0,5000))
            });
          g.exportGCommands();
          break;
        case '/':
        case '?':
          buttonHelp=true;
          break;
      }
    }
  } else {
    int buttonMoveMM = 10; //mm
    switch(keyCode) {
      case UP:

          buttonUp = true;

        break;
      case DOWN:

          buttonDown = true;

        break;
      case LEFT:

          buttonLeft = true;

        break;
      case RIGHT:

          buttonRight = true;

        break;
    }
  }
}