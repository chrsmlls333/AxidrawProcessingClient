/*
  By Chris Eugene Mills
*/



static final int[] supportedGCommands = new int[]{0, 1, 20, 21, 28, 90, 91};
static final int[] supportedMCommands = new int[]{2, 30};

class GCommand {

  // VARIABLES /////////////////////////////////////////////////////////////////

  public char set = '?';
  public int command = -1;
  public int lineNumber = -1;
  public int feedrate = -1;
  public int duration = -1;
  public float x = Float.NaN;
  public float y = Float.NaN;
  public float z = Float.NaN;
  public boolean supported = false;



  // CONSTRUCTOR ///////////////////////////////////////////////////////////////

  GCommand( char _set, int _command ) {
    set = Character.toUpperCase( _set );
    command = _command;
    supported = checkValidity( _set, _command );
  }

  GCommand( int line, char _set, int _command ) {
    lineNumber = line;
    set = Character.toUpperCase( _set );
    command = _command;
    supported = checkValidity( _set, _command );
  }

  GCommand( char _set, int _command, float _x, float _y) {
    x = _x;
    y = _y;
    set = Character.toUpperCase( _set );
    command = _command;
    supported = checkValidity( _set, _command );
  }

  GCommand( int line, char _set, int _command, float _x, float _y) {
    lineNumber = line;
    x = _x;
    y = _y;
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

  GCommand( int line, char _set, int _command, float _x, float _y, float _z) {
    lineNumber = line;
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

  GCommand( int line, char _set, int _command, float _x, float _y, float _z, int _feedrate) {
    lineNumber = line;
    feedrate = _feedrate;
    x = _x;
    y = _y;
    z = _z;
    set = Character.toUpperCase( _set );
    command = _command;
    supported = checkValidity( _set, _command );
  }


  // ///////////////////////////////////////////////////////////////////////////

  private boolean checkValidity( char _set, int _command ) {
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

  private boolean matchIntArray(int[] arr, int targetValue) {

  	for(int s: arr){
  		if(s == targetValue) return true;
  	}
  	return false;
  }

  public JSONObject getJSON() {

    JSONObject json = new JSONObject();
    if (lineNumber != -1) json.setInt("lineNumber", lineNumber);
    json.setString("commandSet", str(set));
    json.setInt("commandCode", command);
    json.setBoolean("supported", supported);

    JSONObject data = new JSONObject();
    if (!Float.isNaN(x)) data.setFloat("x", x);
    if (!Float.isNaN(y)) data.setFloat("y", y);
    if (!Float.isNaN(z)) data.setFloat("z", z);
    if (feedrate != -1) data.setFloat("feedrate", feedrate);
    if (duration != -1) data.setFloat("duration", duration);
    json.setJSONObject("data", data);

    return json;
  }

  public String getGText() {

    String line = "";

    if(supported) {
      line += str(set);
      line += str(command) + " ";

      if (!Float.isNaN(x)) line += "X" + str(x) + " ";
      if (!Float.isNaN(y)) line += "Y" + str(y) + " ";
      if (!Float.isNaN(z)) line += "Z" + str(z) + " ";
      if (feedrate != -1) line += "F" + str(feedrate) + " ";
      if (duration != -1) line += "P" + str(duration) + " ";
    } else {
      line += "( unsupported command: "+str(set)+str(command)+" )";
    }

    return line;
  }
}