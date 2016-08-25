import themidibus.*; //Import the library

MidiBus myBus; // The MidiBus
/*
 * A simple grid sequencer, launching several effects in rhythm.
 */

import de.voidplus.redis.*;

Redis redis;

float BPM = 30;
int[][] pattern = {
  {1, 0, 0, 1, 0, 0, 0, 1},
  {0, 1, 1, 0, 0, 0, 0, 0},
  {0, 1, 0, 0, 0, 0, 1, 0},
  {1, 0, 0, 0, 0, 0, 0, 0},
  {1, 0, 1, 0, 1, 0, 0, 0},
  {0, 1, 1, 0, 0, 1, 0, 0},
  {1, 0, 1, 0, 0, 0, 0, 0},
  {1, 1, 0, 0, 0, 0, 0, 0}
};

OPC opc;

// Grid coordinates
int gridX = 20;
int gridY = 20;
int gridSquareSize = 15;
int gridSquareSpacing = 20;

// Timing info
float rowsPerSecond = 2 * BPM / 60.0;
float rowDuration = 1.0 / rowsPerSecond;
float patternDuration = pattern.length / rowsPerSecond;

// LED array coordinates
int ledX = 400;
int ledY = 400;
int ledSpacing = 15;
int ledWidth = ledSpacing * 23;
int ledHeight = ledSpacing * 7;

// Images
PImage imgGreenDot;
PImage imgOrangeDot;
PImage imgPinkDot;
PImage imgPurpleDot;
PImage imgCheckers;
PImage imgGlass;
PImage[] dots;

// Timekeeping
long startTime, pauseTime;

void setup()
{
  size(200, 200);

  imgGreenDot = loadImage("greenDot.png");
  imgOrangeDot = loadImage("orangeDot.png");
  imgPinkDot = loadImage("pinkDot.png");
  imgPurpleDot = loadImage("purpleDot.png");
  imgCheckers = loadImage("checkers.png");
  imgGlass = loadImage("glass.jpeg");

  // Keep our multicolored dots in an array for easy access later
  dots = new PImage[] { imgOrangeDot, imgPurpleDot, imgPinkDot, imgGreenDot };

  // Connect to the local instance of fcserver. You can change this line to connect to another computer's fcserver
  opc = new OPC(this, "127.0.0.1", 7890);
  
  MidiBus.list();
  myBus = new MidiBus(this, "SmartPAD", "SmartPAD"); // Create a new MidiBus using the device names to select the Midi input and output devices respectively.
  myBus.sendControllerChange(0, 0, 90); // Send a controllerChange

  String pattern_string = "";
  for (int x=0; x < 8; x++){
    for (int y=0; y < 8; y++){
      pattern_string += pattern[x][y] + ",";
    }
  }
  
  redis = new Redis(this, "127.0.0.1", 6379);
  redis.setnx("pattern",pattern_string);
  
  readPattern();
  
  // Init timekeeping, start the pattern from the beginning
  startPattern();
}

void draw()
{
  background(0);

  long m = millis();
  if (pauseTime != 0) {
    // Advance startTime forward while paused, so we don't make any progress
    long delta = m - pauseTime;
    startTime += delta;
    pauseTime += delta;
  }

  float now = (m - startTime) * 1e-3;
  drawGrid(now);
}

void clearPattern()
{
  for (int row = 0; row < pattern.length; row++) {
    for (int col = 0; col < pattern[0].length; col++) {
      pattern[row][col] = 0;
    }
  }
}

void startPattern()
{
  startTime = millis();
  pauseTime = 0;
}

void pausePattern()
{
  if (pauseTime == 0) {
    // Pause by stopping the clock and remembering when to unpause at
    pauseTime = millis();
  } else {
    pauseTime = 0;
  }
}   

void mousePressed()
{
  int gx = (mouseX - gridX) / gridSquareSpacing;
  int gy = (mouseY - gridY) / gridSquareSpacing;
  if (gx >= 0 && gx < pattern[0].length && gy >= 0 && gy < pattern.length) {
    pattern[gy][gx] ^= 1;
  }
  writePattern();
}

void keyPressed()
{
  if (keyCode == DELETE) clearPattern();
  if (keyCode == BACKSPACE) clearPattern();
  if (keyCode == UP) startPattern();
  if (key == ' ') pausePattern();
}

void drawGrid(float now)
{
  int currentRow = int(rowsPerSecond * now) % pattern.length;
  blendMode(BLEND);

  for (int row = 0; row < pattern.length; row++) {
    for (int col = 0; col < pattern[0].length; col++) {
      fill(pattern[row][col] != 0 ? 190 : 64);
      rect(gridX + gridSquareSpacing * col, gridY + gridSquareSpacing * row, gridSquareSize, gridSquareSize);
    }
    
    if (row == currentRow) {
      // Highlight the current row
      fill(255, 255, 0, 32);
      rect(gridX, gridY + gridSquareSpacing * row,
        gridSquareSpacing * (pattern[0].length - 1) + gridSquareSize, gridSquareSize);
    }
  }
}

void noteOn(int channel, int pitch, int velocity) {
  // Receive a noteOn
  println();
  println("Note On:");
  println("--------");
  println("Channel:"+channel);
  println("Pitch:"+pitch);
  println("Velocity:"+velocity);
  println("address:"+pitch/16+" "+pitch %16);
  if (pattern[pitch / 16][pitch % 16] == 0){
    pattern[pitch / 16][pitch % 16] = 1;
    myBus.sendNoteOff(channel, pitch, 100);
  }
   else if (pattern[pitch / 16][pitch % 16] == 1){
    pattern[pitch / 16][pitch % 16] = 0;
    myBus.sendNoteOn(channel, pitch, 0);     
  }

  writePattern();
}

void writePattern(){
  String pattern_string = "";
  for (int x=0; x < 8; x++){
    for (int y=0; y < 8; y++){
      pattern_string += pattern[x][y] + ",";
    }
  }
  redis.set("pattern",pattern_string);
}

void readPattern(){
  String pattern_string = redis.get("pattern");
  println(pattern_string);
  int[] nums = int(split(pattern_string, ','));

  for (int x=0; x < 8; x++){
    for (int y=0; y < 8; y++){
      if (x+(y*8) > nums.length - 1){
        pattern[x][y] = 0;
      }else {
        pattern[x][y] = nums[x+(y*8)];
      }
    }
  }
}