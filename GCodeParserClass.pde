/*
  By Chris Eugene Mills

  Simplified this part by only running when machine is connected. All tasks can
  be "sent" to machine if so, but not by this runner, which quits out.

  TODO:
    Z heights
    G0/G01 distinction
    Feedrates
    Dwell
    Arcs?
    File filters for unallowed characters.

  Accepts GCode with many limitations!

    - Z axis accepts ONLY ZERO AND NON-ZERO as down and up. Height settings
      baked into variables. TODO add full Z support.

    - Can not move in 3 dimensions at once. Z and XY motion must be in their own
      commands. This is standard to engraving.

    - When planning your plot, position the model in the:
      - X,Y  Quadrant: Select flipYFix to true
      - X,-Y Quadrant: Select xyFix to true

    - Script should end with a M30 command. This sends to home and tells the
      queue to stop waiting for more.

    - Ignores distinction between G00 and G01, but still functions by default
      with rapid motion when in clearance plane, and normal motion when pen is
      down.

    - Accepts units of Inches or Millimeters, but code must include G20 or G21.

    - All commands should be on seperate lines, with parts seperated by spaces,
      and comments (surrounded by brackets). No colons/semicolons.
*/


class GCodeParser {

  // SETTINGS //////////////////////////////////////////////////////////////////




  // VARIABLES /////////////////////////////////////////////////////////////////

  ArrayList<GCommand> workingQueue;



  // CONSTRUCTOR ///////////////////////////////////////////////////////////////

  GCodeParser( String _gCodeFilename ) {
    workingQueue = parseGCode(_gCodeFilename);
  }




  // PUBLIC OPERATIONS /////////////////////////////////////////////////////////

  public int size() {
    return workingQueue.size();
  }

  public ArrayDeque<GCommand> export() {
    return new ArrayDeque<GCommand>(workingQueue);
  }



  // GCode IMPORT //////////////////////////////////////////////////////////////

  private ArrayList<GCommand> parseGCode( String _gCodeFilename ) {

    ArrayList<GCommand> queue = new ArrayList<GCommand>();

    //Log Setup
    final String errorLogFilename = "logs/import.log";
    // final String jsonFilename = "logs/export.json";

    PrintWriter log = createWriter(errorLogFilename);
    // JSONArray export = new JSONArray();
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

          if (line.contains("("))
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
                  // export.setJSONObject(export.size(), data.getJSON());
                }
              }
            }
          }
        }
      } //end while loop

      //Final Report
      String finale = "\n\nPARSE: FINISHED GCODE PARSE: \n" +
                      "PARSE: Error rate:  " + errors + "/" + lineNumber;
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
    // saveJSONArray(export, jsonFilename);

    return queue;
  }




  /*
    Mind that this may return an empty first array entry, ¯\_(ツ)_/¯
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
    int commandCode = int(command.substring(1));
    log.print("                    cmd rx: " + commandSet + "_" + commandCode + " - ");

    //Get Command Data
    int feedrate = -1;
    float x = Float.NaN;
    float y = Float.NaN;
    float z = Float.NaN;
    // float duration = Float.NaN; //TODO dwell

    if (pieces.length > 1) {
      for (int i = 1; i < pieces.length; i++) {
        String s = pieces[i].toUpperCase();
        char dataType = s.charAt(0);
        float data = float(s.substring(1));

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
            feedrate = int(data);
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
    } else if (commandSet == 'N') {
      log.println("LINE NUMBER, IGNORED");
    } else {
      log.println("NO COMMAND RECOGNIZED???");
      return null;
    }

    //Export
    if (specialExport != null) {
      return specialExport;
    } else {
      return new GCommand(lineNumber, commandSet, commandCode, x, y, z, feedrate);
    }
  }




  // GCODE EXPORT //////////////////////////////////////////////////////////////

  public void outputParsedGCodeFile() {
    final String gCodeOutFilename = "output/lastExport.nc";
    PrintWriter export = createWriter(gCodeOutFilename);

    for (GCommand g : workingQueue) {
      export.println(g.getGText());
    }

    export.flush();
    export.close();
  }




  // PREPROCESSORS /////////////////////////////////////////////////////////////

  // private ArrayList<ArrayList<GCommand>> splitQueueIntoDrawingLines( ArrayList<GCommand> queue ) {
  //
  //   ArrayList<ArrayList<GCommand>> groups = new ArrayList<ArrayList<GCommand>>();
  //   groups.add( new ArrayList<GCommand>() );
  //
  //   for (GCommand g : queue) {
  //
  //     groups.get(groups.size()-1).add(g);
  //     // println(g.getGText());
  //
  //     //Divide Groups after penup
  //     if(g.set == 'G') {
  //       if(g.command == 0 || g.command == 1) {
  //         if(!Float.isNaN(g.z) && g.z != 0) {
  //           groups.add( new ArrayList<GCommand>() );
  //           // println("NEW GROUP!");
  //         }
  //       }
  //     }
  //
  //   }
  //
  //   return groups;
  // }



  // public void cropToPaper( int paperWidthMM, int paperHeightMM ) {
  //
  //   //TODO check units, for now only import mm
  //   int paperWidth = paperWidthMM;
  //   int paperHeight = paperHeightMM;
  //
  //   ArrayList<ArrayList<GCommand>> lineGroups = splitQueueIntoDrawingLines(workingQueue);
  //
  //   for (ArrayList<GCommand> group : lineGroups) {
  //
  //     ArrayList<Boolean> status = new ArrayList<Boolean>();
  //     for (int i = 0; i < group.size(); i++) {
  //       GCommand comm = group.get(i);
  //       if(comm.x > paperWidth || comm.y > paperHeight || comm.x < 0 || comm.y < 0) {
  //         status.set(i,false);
  //       } else {
  //         status.set(i,true);
  //       }
  //       println(str(status.get(i)));
  //     }
  //
  //   }
  // }

}