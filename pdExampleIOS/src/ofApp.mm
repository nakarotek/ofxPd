/*
 * Copyright (c) 2011 Dan Wilcox <danomatika@gmail.com>
 *
 * BSD Simplified License.
 * For information on usage and redistribution, and for a DISCLAIMER OF ALL
 * WARRANTIES, see the file, "LICENSE.txt," in this distribution.
 *
 * See https://github.com/danomatika/ofxPd for documentation
 *
 */
#include "ofApp.h"

//--------------------------------------------------------------
void ofApp::setup() {

	ofSetFrameRate(60);
	ofSetVerticalSync(true);
	ofBackground(127, 127, 127);
	//ofSetLogLevel(OF_LOG_VERBOSE);

	// double check where we are ...
	cout << ofFilePath::getCurrentWorkingDirectory() << endl;

	// register touch events
	ofRegisterTouchEvents(this);
	
	// initialize the accelerometer
	ofxAccelerometer.setup();
	
	// iOSAlerts will be sent to this
	ofxiOSAlerts.addListener(this);
	
	// set landscape
	//ofSetOrientation(OF_ORIENTATION_90_RIGHT;
	
	// the number if libpd ticks per buffer,
	// used to compute the audio buffer len: tpb * blocksize (always 64)
	int ticksPerBuffer = 8; // 8 * 64 = buffer len of 512

	// setup OF sound stream
	ofSoundStreamSetup(2, 1, this, 44100, ofxPd::blockSize()*ticksPerBuffer, 3);

	// setup Pd
	if(!pd.init(2, 1, 44100, ticksPerBuffer)) {
		OF_EXIT_APP(1);
	}

	midiChan = 1; // midi channels are 1-16

	// subscribe to receive source names
	pd.subscribe("toOF");
	pd.subscribe("env");

	// add message receiver, disables polling (see processEvents)
	pd.addReceiver(*this);   // automatically receives from all subscribed sources
	pd.ignore(*this, "env"); // don't receive from "env"
	//pd.ignore(*this);             // ignore all sources
	//pd.receive(*this, "toOF");	// receive only from "toOF"

	// add midi receiver
	pd.addMidiReceiver(*this);  // automatically receives from all channels
	//pd.ignoreMidi(*this, 1);     // ignore midi channel 1
	//pd.ignoreMidi(*this);        // ignore all channels
	//pd.receiveMidi(*this, 1);    // receive only from channel 1

	// add the data/pd folder to the search path
	pd.addToSearchPath("pd/abs");

	// audio processing on
	pd.start();

	// -----------------------------------------------------
	cout << endl << "BEGIN Patch Test" << endl;

	// open patch
	Patch patch = pd.openPatch("pd/test.pd");
	cout << patch << endl;

	// close patch
	pd.closePatch(patch);
	cout << patch << endl;

	// open patch
	patch = pd.openPatch("pd/test.pd");
	cout << patch << endl;

	cout << "FINISH Patch Test" << endl;

	// -----------------------------------------------------
	cout << endl << "BEGIN Message Test" << endl;

	// test basic atoms
	pd.sendBang("fromOF");
	pd.sendFloat("fromOF", 100);
	pd.sendSymbol("fromOF", "test string");

	// stream interface
	pd << Bang("fromOF")
	   << Float("fromOF", 100)
	   << Symbol("fromOF", "test string");

	// send a list
	pd.startMessage();
	pd.addFloat(1.23);
	pd.addSymbol("a symbol");
	pd.finishList("fromOF");

	// send a message to the $0 receiver ie $0-toOF
	pd.startMessage();
	pd.addFloat(1.23);
	pd.addSymbol("a symbol");
	pd.finishList(patch.dollarZeroStr()+"-fromOF");

	// send a list using the List object
	List testList;
	testList.addFloat(1.23);
	testList.addSymbol("sent from a List object");
	pd.sendList("fromOF", testList);
	pd.sendMessage("fromOF", "msg", testList);

	// stream interface for list
	pd << StartMessage() << 1.23 << "sent from a streamed list" << FinishList("fromOF");

	cout << "FINISH Message Test" << endl;

	// -----------------------------------------------------
	cout << endl << "BEGIN MIDI Test" << endl;

	// send functions
	pd.sendNoteOn(midiChan, 60);
	pd.sendControlChange(midiChan, 0, 64);
	pd.sendProgramChange(midiChan, 100);    // note: pgm num range is 1 - 128
	pd.sendPitchBend(midiChan, 2000);   // note: ofxPd uses -8192 - 8192 while [bendin] returns 0 - 16383,
										// so sending a val of 2000 gives 10192 in pd
	pd.sendAftertouch(midiChan, 100);
	pd.sendPolyAftertouch(midiChan, 64, 100);
	pd.sendMidiByte(0, 239);    // note: pd adds +2 to the port number from [midiin], [sysexin], & [realtimein]
	pd.sendSysex(0, 239);       // so sending to port 0 gives port 2 in pd
	pd.sendSysRealTime(0, 239);

	// stream
	pd << NoteOn(midiChan, 60) << ControlChange(midiChan, 100, 64)
	   << ProgramChange(midiChan, 100) << PitchBend(midiChan, 2000)
	   << Aftertouch(midiChan, 100) << PolyAftertouch(midiChan, 64, 100)
	   << StartMidi(0) << 239 << Finish()
	   << StartSysex(0) << 239 << Finish()
	   << StartSysRealTime(0) << 239 << Finish();

	cout << "FINISH MIDI Test" << endl;

	// -----------------------------------------------------
	cout << endl << "BEGIN Array Test" << endl;

	// array check length
	cout << "array1 len: " << pd.arraySize("array1") << endl;

	// read array
	std::vector<float> array1;
	pd.readArray("array1", array1);	// sets array to correct size
	cout << "array1 ";
	for(int i = 0; i < array1.size(); ++i)
		cout << array1[i] << " ";
	cout << endl;

	// write array
	for(int i = 0; i < array1.size(); ++i)
		array1[i] = i;
	pd.writeArray("array1", array1);

	// ready array
	pd.readArray("array1", array1);
	cout << "array1 ";
	for(int i = 0; i < array1.size(); ++i)
		cout << array1[i] << " ";
	cout << endl;

	// clear array
	pd.clearArray("array1", 10);

	// ready array
	pd.readArray("array1", array1);
	cout << "array1 ";
	for(int i = 0; i < array1.size(); ++i)
		cout << array1[i] << " ";
	cout << endl;

	cout << "FINISH Array Test" << endl;

	// -----------------------------------------------------
	cout << endl << "BEGIN PD Test" << endl;

	pd.sendSymbol("fromOF", "test");

	cout << "FINISH PD Test" << endl << endl;

	// -----------------------------------------------------
	cout << endl << "BEGIN Event Polling Test" << endl;

	// clear receivers, enable polling
	pd.clearReceivers();
	pd.clearMidiReceivers();

	pd.sendSymbol("fromOF", "test");
	processEvents(); // <-- manually poll for events

	// re-add receivers, disable polling
	pd.addReceiver(*this);
	pd.addMidiReceiver(*this);
	pd.ignore(*this, "env");

	cout << "FINISH Event Polling Test" << endl << endl;

	// -----------------------------------------------------
	cout << endl << "BEGIN Instance Test" << endl;

	// open 10 instances
	for(int i = 0; i < 10; ++i) {
		Patch p = pd.openPatch("pd/instance.pd");
		instances.push_back(p);
	}

	// send a hello bang to each instance individually using the dollarZero
	// to [r $0-instance] which should print the instance dollarZero unique id
	// and a unique random number
	for(int i = 0; i < instances.size(); ++i) {
		pd.sendBang(instances[i].dollarZeroStr()+"-instance");
	}

	// send a random float between 0 and 100
	for(int i = 0; i < instances.size(); ++i) {
		pd.sendFloat(instances[i].dollarZeroStr()+"-instance", int(ofRandom(0, 100)));
	}

	// send a symbol
	for(int i = 0; i < instances.size(); ++i) {
		pd.sendSymbol(instances[i].dollarZeroStr()+"-instance", "howdy dude");
	}

	// close all instances
	for(int i = 0; i < instances.size(); ++i) {
		pd.closePatch(instances[i]);
	}
	instances.clear();

	cout << "FINISH Instance Test" << endl;

	// -----------------------------------------------------
	// play a tone by sending a list
	// [list tone pitch 72 (
	pd.startMessage();
	pd.addSymbol("pitch");
	pd.addFloat(72);
	pd.finishList("tone");
	pd.sendBang("tone");

}

//--------------------------------------------------------------
void ofApp::update() {
	ofBackground(100, 100, 100);

	// update scope array from pd
	pd.readArray("scope", scopeArray);
}

//--------------------------------------------------------------
void ofApp::draw() {

	// draw scope
	ofSetColor(0, 255, 0);
	ofSetRectMode(OF_RECTMODE_CENTER);
	float x = 0, y = ofGetHeight()/2;
	float w = ofGetWidth() / (float) scopeArray.size(), h = ofGetHeight()/2;
	for(int i = 0; i < scopeArray.size()-1; ++i) {
		ofLine(x, y+scopeArray[i]*h, x+w, y+scopeArray[i+1]*h);
		x += w;
	}
}

//--------------------------------------------------------------
void ofApp::exit() {}

//--------------------------------------------------------------
void ofApp::keyPressed (int key) {

	switch(key) {

	case 'a':
		playTone(60);
		break;
	case 'w':
		playTone(61);
		break;
	case 's':
		playTone(62);
		break;
	case 'e':
		playTone(63);
		break;
	case 'd':
		playTone(64);
		break;
	case 'f':
		playTone(65);
		break;
	case 't':
		playTone(66);
		break;
	case 'g':
		playTone(67);
		break;
	case 'y':
		playTone(68);
		break;
	case 'h':
		playTone(69);
		break;
	case 'u':
		playTone(70);
		break;
	case 'j':
		playTone(71);
		break;
	case 'k':
		playTone(72);
		break;

	case ' ':
		if(pd.isReceiving(*this, "env")) {
			pd.ignore(*this, "env");
			cout << "ignoring env" << endl;
		}
		else {
			pd.receive(*this, "env");
			cout << "receiving from env" << endl;
		}
		break;

	default:
		break;
	}
}

//--------------------------------------------------------------
void ofApp::touchDown(ofTouchEventArgs &touch) {
	// y pos changes pitch
	int pitch = (-1 * (touch.y/ofGetHeight()) + 1) * 127;
	playTone(pitch);
}

//--------------------------------------------------------------
void ofApp::touchMoved(ofTouchEventArgs &touch) {}

//--------------------------------------------------------------
void ofApp::touchUp(ofTouchEventArgs &touch) {}

//--------------------------------------------------------------
void ofApp::touchDoubleTap(ofTouchEventArgs &touch) {}

//--------------------------------------------------------------
void ofApp::touchCancelled(ofTouchEventArgs& args) {}

//--------------------------------------------------------------
void ofApp::lostFocus() {}

//--------------------------------------------------------------
void ofApp::gotFocus() {}

//--------------------------------------------------------------
void ofApp::gotMemoryWarning() {}

//--------------------------------------------------------------
void ofApp::deviceOrientationChanged(int newOrientation) {}

//--------------------------------------------------------------
void ofApp::audioReceived(float * input, int bufferSize, int nChannels) {
	pd.audioIn(input, bufferSize, nChannels);
}

//--------------------------------------------------------------
void ofApp::audioRequested(float * output, int bufferSize, int nChannels) {
	pd.audioOut(output, bufferSize, nChannels);
}

//--------------------------------------------------------------
void ofApp::print(const std::string& message) {
	cout << message << endl;
}

//--------------------------------------------------------------
void ofApp::receiveBang(const std::string& dest) {
	cout << "OF: bang " << dest << endl;
}

void ofApp::receiveFloat(const std::string& dest, float value) {
	cout << "OF: float " << dest << ": " << value << endl;
}

void ofApp::receiveSymbol(const std::string& dest, const std::string& symbol) {
	cout << "OF: symbol " << dest << ": " << symbol << endl;
}

void ofApp::receiveList(const std::string& dest, const List& list) {
	cout << "OF: list " << dest << ": ";

	// step through the list
	for(int i = 0; i < list.len(); ++i) {
		if(list.isFloat(i))
			cout << list.getFloat(i) << " ";
		else if(list.isSymbol(i))
			cout << list.getSymbol(i) << " ";
	}

	// you can also use the built in toString function or simply stream it out
	// cout << list.toString();
	// cout << list;

	// print an OSC-style type string
	cout << list.types() << endl;
}

void ofApp::receiveMessage(const std::string& dest, const std::string& msg, const List& list) {
	cout << "OF: message " << dest << ": " << msg << " " << list.toString() << list.types() << endl;
}

//--------------------------------------------------------------
void ofApp::receiveNoteOn(const int channel, const int pitch, const int velocity) {
	cout << "OF MIDI: note on: " << channel << " " << pitch << " " << velocity << endl;
}

void ofApp::receiveControlChange(const int channel, const int controller, const int value) {
	cout << "OF MIDI: control change: " << channel << " " << controller << " " << value << endl;
}

// note: pgm nums are 1-128 to match pd
void ofApp::receiveProgramChange(const int channel, const int value) {
	cout << "OF MIDI: program change: " << channel << " " << value << endl;
}

void ofApp::receivePitchBend(const int channel, const int value) {
	cout << "OF MIDI: pitch bend: " << channel << " " << value << endl;
}

void ofApp::receiveAftertouch(const int channel, const int value) {
	cout << "OF MIDI: aftertouch: " << channel << " " << value << endl;
}

void ofApp::receivePolyAftertouch(const int channel, const int pitch, const int value) {
	cout << "OF MIDI: poly aftertouch: " << channel << " " << pitch << " " << value << endl;
}

// note: pd adds +2 to the port num, so sending to port 3 in pd to [midiout],
//       shows up at port 1 in ofxPd
void ofApp::receiveMidiByte(const int port, const int byte) {
	cout << "OF MIDI: midi byte: " << port << " " << byte << endl;
}

//--------------------------------------------------------------
void ofApp::processEvents() {

	cout << "Number of waiting messages: " << pd.numMessages() << endl;

	while(pd.numMessages() > 0) {
		Message& msg = pd.nextMessage();

		switch(msg.type) {

		case pd::PRINT:
			cout << "OF: " << msg.symbol << endl;
			break;

			// events
		case pd::BANG:
			cout << "OF: bang " << msg.dest << endl;
			break;
		case pd::FLOAT:
			cout << "OF: float " << msg.dest << ": " << msg.num << endl;
			break;
		case pd::SYMBOL:
			cout << "OF: symbol " << msg.dest << ": " << msg.symbol << endl;
			break;
		case pd::LIST:
			cout << "OF: list " << msg.list << msg.list.types() << endl;
			break;
		case pd::MESSAGE:
			cout << "OF: message " << msg.dest << ": " << msg.symbol << " "
			     << msg.list << msg.list.types() << endl;
			break;

			// midi
		case pd::NOTE_ON:
			cout << "OF MIDI: note on: " << msg.channel << " "
			     << msg.pitch << " " << msg.velocity << endl;
			break;
		case pd::CONTROL_CHANGE:
			cout << "OF MIDI: control change: " << msg.channel
			     << " " << msg.controller << " " << msg.value << endl;
			break;
		case pd::PROGRAM_CHANGE:
			cout << "OF MIDI: program change: " << msg.channel << " "
			     << msg.value << endl;
			break;
		case pd::PITCH_BEND:
			cout << "OF MIDI: pitch bend: " << msg.channel << " "
			     << msg.value << endl;
			break;
		case pd::AFTERTOUCH:
			cout << "OF MIDI: aftertouch: " << msg.channel << " "
			     << msg.value << endl;
			break;
		case pd::POLY_AFTERTOUCH:
			cout << "OF MIDI: poly aftertouch: " << msg.channel << " "
			     << msg.pitch << " " << msg.value << endl;
			break;
		case pd::BYTE:
			cout << "OF MIDI: midi byte: " << msg.port << " 0x"
			     << hex << (int) msg.byte << dec << endl;
			break;

		case pd::NONE:
			cout << "OF: NONE ... empty message" << endl;
			break;
		}
	}
}

//--------------------------------------------------------------
void ofApp::playTone(int pitch) {
	pd << StartMessage() << "pitch" << pitch << FinishList("tone") << Bang("tone");
}
