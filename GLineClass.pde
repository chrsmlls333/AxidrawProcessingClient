/*
  By Chris Eugene Mills
  
  For live drawing. NOT IMPLEMENTED YET. 
*/



class GLine {

  // VARIABLES /////////////////////////////////////////////////////////////////

  public PVector[] points;
  public String units;

  public float penFeedrate = Float.NaN;
  public float feedrate = Float.NaN;

  public float penUp = 100; //TODO
  public float penDown = 0; //TODO

  // CONSTRUCTOR ///////////////////////////////////////////////////////////////

  GLine(PVector[] p) {
    points = p;
    units = "mm";
  }

  GLine(PVector[] p, String u) {
    points = p;
    units = u;
  }

  GLine(float x1, float y1, float x2, float y2) {
    points = new PVector[]{ new PVector(x1,y1), new PVector(x2,y2)};
    units = "mm";
  }


  // ///////////////////////////////////////////////////////////////////////////

  public ArrayList<GCommand> exportGCommands() {

    ArrayList<GCommand> array = new ArrayList<GCommand>();

    array.add( new GCommand('G', 0, points[0].x, points[0].y) ); //GOTO
    array.add( new GCommand('G', 1, Float.NaN, Float.NaN, penDown) ); //Down
    for (int i = 1; i < points.length; i++) {
      array.add( new GCommand('G', 1, points[i].x, points[i].y) ); //Draw
    }
    array.add( new GCommand('G', 1, Float.NaN, Float.NaN, penUp) ); //Up

    for (int i = 0; i < array.size(); i++) {
      println(array.get(i).getGText());
    }

    return array;
  }

}