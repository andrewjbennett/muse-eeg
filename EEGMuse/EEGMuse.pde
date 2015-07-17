/*
 * Muse raw EEG brainwave visualiser
 * Written in Processing 2.2.1
 * by Andrew Bennett (andrewb@cse.unsw.edu.au)
 * 
 * How to run:
 * 1) Run muse-io, with the dsp output set, specifying a UDP port
 * eg: ./muse-io --device 00:06:66:69:4F:8B --50hz --dsp --osc "osc.udp://localhost:5000"
 * where --device is your Muse's mac address
 *
 * 2) Run this script with Processing
 * 
 * 3) Enjoy :)
 */

// Import the required packages for OSC interfacing
import oscP5.*;
import netP5.*;

// set up the OSC stuff
OscP5 oscP5;
NetAddress myRemoteLocation;

int mutex = 0;

// Number of data channels
int numChannels = 4;

// Some globals: current X position where we're drawing data; width of the lines we're drawing
int currentPosition = 0;
int drawWidth = 1;

// The names of the waves, in any order
String waves[] = {
  "alpha", "beta", "gamma", "delta", "theta"
};
int numBuckets = waves.length;

// Store the current data as it comes in. lastPos contains the n-1th data point, and values contains the nth.
float lastPos[][] = new float[numBuckets][numChannels];
float values[][] = new float[numBuckets][numChannels];

float eegLast[] = new float[numChannels];
float eegValues[] = new float[numChannels];

// Set up the program
void setup() {
  // Specify the screen size
  size(displayWidth, displayHeight);

  // Set up the OSC stuff
  oscP5 = new OscP5(this, 5000);
  myRemoteLocation = new NetAddress("127.0.0.1", 5000);

  // Set the background color of the screen
  background(0);

  // Specify that we're in HSB color mode
  colorMode(HSB);

  frameRate(120);

  noLoop();
}

int currentlyDrawing = 0;
// This function gets called every time any OSC message comes in.
// Within the function, we can check if a given message matches the one we're after, and react accordingly.
// This is in contrast to other OSC interfaces, which set up handlers for each type of message that can come in.
// I'm not sure whether this is possible to do in Processing with the current libraries.
void oscEvent(OscMessage theOscMessage) {


  if (theOscMessage.checkAddrPattern("/muse/eeg") == true) {
    if (theOscMessage.checkTypetag("ffff")) {
      for (int i=0; i<numChannels; i++) {
        eegValues[i] = theOscMessage.get(i).floatValue();
      }
      drawEEG();
    }
  }

  // For each type of wave [alpha, beta, ...]
  for (int curWave = 0; curWave < waves.length; curWave++) {
    // If the wave matches the DSP data for that wave
    if (theOscMessage.checkAddrPattern("/muse/dsp/elements/" + waves[curWave]) == true) {
      // Make sure that we have the type tag right: ffff means four floats, which is what we'll get when the Muse is set to preset 10.
      if (theOscMessage.checkTypetag("ffff")) {
        // For each of the channels of data (4, in preset 10)
        for (int i=0; i<numChannels; i++) {
          // Store the current data point in the array
          values[curWave][i] = theOscMessage.get(i).floatValue();
        }
      }
    }
    if (theOscMessage.checkAddrPattern("/muse/dsp/elements/" + waves[0]) == true) {
      redraw();
    }
  }
}

float currentEEGPosition = 0;

int currentlyDrawingEEG = 0;

void drawEEG() {

  if (currentlyDrawingEEG == 0) {
    currentlyDrawingEEG = 1;
    
    // reset the background
    fill(0);
    noStroke();
    rect(currentEEGPosition, 0, drawWidth*5, height);


    float top, bottom;
    for (int curChannel = 0; curChannel < numChannels; curChannel++) {

      top = map(curChannel, 0, numChannels, height, 30);
      bottom = map(curChannel+1, 0, numChannels, height, 30);
      
     /* fill(curChannel*20+100);
      noStroke();
      
      rect(currentEEGPosition, bottom, drawWidth*5, 150);*/

      fill(255);
      stroke(255);
      
      println(eegValues[curChannel]);
      line(currentEEGPosition, map(eegLast[curChannel], 700, 900, top-30, bottom), currentEEGPosition+drawWidth, map(eegValues[curChannel], 700, 900, top-30, bottom));
      eegLast[curChannel] = eegValues[curChannel];
    }
    currentEEGPosition+=drawWidth;
    currentEEGPosition %= width;

    currentlyDrawingEEG = 0;
  }
}

// This is where we actually draw the graphics onto the screen
// This function takes the data from the global array, and draws each of the data points on the screen,
// wrapping around as the screen gets filled.
// Each wave is drawn in a different color, and it also displays the names of the waves with their current values [scaled from 0-1 to 0-100], for each channel.
void draw() {
    currentlyDrawing = 1;


    // Set the fill color to black, and turn off strokes
    fill(0);
    noStroke();
    // Draw a rectangle to cover the background in black, before overwriting the wave data
    rect(currentPosition, 0, drawWidth*5, height);

    // The top and bottom position of where we're going to draw
    float top, bottom;

    // For each channel:
    for (int curChannel = 0; curChannel < numChannels; curChannel++) {

      // Specify the boundaries of where we're drawing
      top = map(curChannel*2, 0, numChannels*2, height, 30);
      bottom = map(curChannel*2+1, 0, numChannels*2, height, 30);

      // Draw a rectangle to clear where the text about each waveform is going to be
      fill(0);
      noStroke();
      rect(0, bottom-30, width, 30);

      // For each of the buckets / wave types:
      for (int i=0; i<numBuckets; i++) {

        // Specify the color for this wavetype
        int c = color(255/7.0*i, 255, 255);

        // Create the text, talking about the waveform with its values
        fill(c);
        textAlign(TOP, LEFT);
        text(waves[i] + "(" + str(int(values[i][curChannel]*100)) + ")", 15+i*100, bottom-15);

        // Draw the line of the waveform
        stroke(c);
        line(currentPosition, map(lastPos[i][curChannel], 0, 1, top-30, bottom), currentPosition+drawWidth, map(values[i][curChannel], 0, 1, top-30, bottom));

        // Update where we came from, for drawing the next line
        lastPos[i][curChannel] = values[i][curChannel];
      }
    }

    // Update the current x position across the page, and wrap around when we hit the end
    currentPosition+=drawWidth;
    currentPosition %= width;

    currentlyDrawing = 0;
}

