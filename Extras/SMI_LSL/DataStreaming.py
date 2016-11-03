#!/usr/bin/env python
# -*- coding: utf-8 -*-
# -----------------------------------------------------------------------
#
# (c) Copyright 1997-2013, SensoMotoric Instruments GmbH, Alto University
# 
# Permission  is  hereby granted,  free  of  charge,  to any  person  or
# organization  obtaining  a  copy  of  the  software  and  accompanying
# documentation  covered  by  this  license  (the  "Software")  to  use,
# reproduce,  display, distribute, execute,  and transmit  the Software,
# and  to  prepare derivative  works  of  the  Software, and  to  permit
# third-parties to whom the Software  is furnished to do so, all subject
# to the following:
# 
# The  copyright notices  in  the Software  and  this entire  statement,
# including the above license  grant, this restriction and the following
# disclaimer, must be  included in all copies of  the Software, in whole
# or  in part, and  all derivative  works of  the Software,  unless such
# copies   or   derivative   works   are   solely   in   the   form   of
# machine-executable  object   code  generated  by   a  source  language
# processor.
# 
# THE  SOFTWARE IS  PROVIDED  "AS  IS", WITHOUT  WARRANTY  OF ANY  KIND,
# EXPRESS OR  IMPLIED, INCLUDING  BUT NOT LIMITED  TO THE  WARRANTIES OF
# MERCHANTABILITY,   FITNESS  FOR  A   PARTICULAR  PURPOSE,   TITLE  AND
# NON-INFRINGEMENT. IN  NO EVENT SHALL  THE COPYRIGHT HOLDERS  OR ANYONE
# DISTRIBUTING  THE  SOFTWARE  BE   LIABLE  FOR  ANY  DAMAGES  OR  OTHER
# LIABILITY, WHETHER  IN CONTRACT, TORT OR OTHERWISE,  ARISING FROM, OUT
# OF OR IN CONNECTION WITH THE  SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# -----------------------------------------------------------------------

# REQUIRES PYTHON 2
# This script fetches data from the same machine in which iViewX is running.
# All packets received from iViewX are passed on to Lab Streaming Layer.

from iViewXAPI import  *            #iViewX library
from iViewXAPIReturnCodes import * 
import time
import pylsl as lsl

def marcoTime():
    return int(round(time.time() * 1000) - 1446909066675)

# ---------------------------------------------
# ---- connect to iViewX
# ---------------------------------------------

res = iViewXAPI.iV_Connect(c_char_p('127.0.0.1'), c_int(4444), c_char_p('127.0.0.1'), c_int(5555))
if res != 1:
    HandleError(res)
    exit(0)

res = iViewXAPI.iV_SetLogger(c_int(1), c_char_p("iViewXSDK_Python_lsl.txt"))
res = iViewXAPI.iV_GetSystemInfo(byref(systemData))
print "iV_GetSystemInfo: " + str(res)
samplingRate = round(systemData.samplerate)
print "Samplerate: " + str(samplingRate)
print "iViewX Version: " + str(systemData.iV_MajorVersion) + "." + str(systemData.iV_MinorVersion) + "." + str(systemData.iV_Buildnumber)
print "iViewX API Version: " + str(systemData.API_MajorVersion) + "." + str(systemData.API_MinorVersion) + "." + str(systemData.API_Buildnumber)

# ---------------------------------------------
# ---- constants / support
# ---------------------------------------------

# left eye mapped to -1, right to 1, unkown to 0
eyeDict = {'l': -1, 'L': -1, 'LEFT': -1, 'left': -1, 'Left': -1, 'r': 1, 'R': 1, 'RIGHT': 1, 'right': 1, 'Right': 1}
k_EyeUnknown = 0  # number of eye when unkown

# -- lsl constants --

k_nchans_raw = 13  # raw stream channels
k_nchans_event = 7  # event stream channels

k_chunkSize = 32  # size of chunks (using example given by lsl)
k_maxBuff = 30  # maximum buffer size in seconds

# ---------------------------------------------
# ---- lab streaming layer
# ---------------------------------------------

rawStream_info = lsl.StreamInfo('SMI_Raw', 'Gaze', k_nchans_raw, samplingRate, 'float32', 'smiraw500xa15')
eventStream_info = lsl.StreamInfo('SMI_Event', 'Event', k_nchans_event, samplingRate, 'float32', 'smievent500ds15')

# append meta-data
rawStream_info.desc().append_child_value("manufacturer", "SMI")
eventStream_info.desc().append_child_value("manufacturer", "SMI")
rawStream_info.desc().append_child_value("model", "RED")
eventStream_info.desc().append_child_value("model", "RED")
rawStream_info.desc().append_child_value("api", "iViewPythonLSL")
eventStream_info.desc().append_child_value("api", "iViewPythonLSL")

# -- RAW (GAZE) CHANNELS --

rawChannels = rawStream_info.desc().append_child("channels")
# Make sure order matches order in midas' node
for c in ["timestamp"]:
    rawChannels.append_child("channel")\
        .append_child_value("label", c)\
        .append_child_value("unit", "microseconds")\
        .append_child_value("type", "Gaze")

for c in ["leftGazeX", "leftGazeY"]:
    rawChannels.append_child("channel")\
        .append_child_value("label", c)\
        .append_child_value("unit", "pixels")\
        .append_child_value("type", "Gaze")

for c in ["leftDiam", "leftEyePositionX", "leftEyePositionY", "leftEyePositionZ", "rightGazeX", "rightGazeY", "rightDiam", "rightEyePositionX", "rightEyePositionY", "rightEyePositionZ"]:
    rawChannels.append_child("channel")\
        .append_child_value("label", c)\
        .append_child_value("unit", "millimetres")\
        .append_child_value("type", "Gaze")
		
# -- EVENT CHANNELS --

eventChannels = eventStream_info.desc().append_child("channels")
# Make sure order matches order in midas' node
for c in ["eye"]:
    eventChannels.append_child("channel")\
        .append_child_value("label", c)\
        .append_child_value("unit", "index")\
        .append_child_value("type", "Event")

for c in ["startTime", "endTime", "duration"]:
    eventChannels.append_child("channel")\
        .append_child_value("label", c)\
        .append_child_value("unit", "microseconds")\
        .append_child_value("type", "Event")

for c in ["positionX", "positionY"]:
    eventChannels.append_child("channel")\
        .append_child_value("label", c)\
        .append_child_value("unit", "pixels")\
        .append_child_value("type", "Event")

for c in ["marcotime"]:
    eventChannels.append_child("channel")\
        .append_child_value("label", c)\
        .append_child_value("unit", "milliseconds")\
        .append_child_value("type", "Event")

# ---------------------------------------------
# ---- lsl outlets
# ---------------------------------------------

rawOutlet = lsl.StreamOutlet(rawStream_info, k_chunkSize, k_maxBuff)
eventOutlet = lsl.StreamOutlet(eventStream_info, k_chunkSize, k_maxBuff)

# ---------------------------------------------
# ---- configure and start calibration
# ---------------------------------------------
minAccuracy = 1.0
accLX = 1000
accLY = 1000
accRX = 1000
accRY = 1000
inkey = "x"

while (accLX > minAccuracy or accLY > minAccuracy or accRX > minAccuracy or accRY > minAccuracy) and inkey != "s":

	displayDevice = 1
	calibrationData = CCalibration(9, 1, displayDevice, 0, 1, 250, 220, 2, 20, b"")

	res = iViewXAPI.iV_SetupCalibration(byref(calibrationData))
	print "iV_SetupCalibration " + str(res)

	res = iViewXAPI.iV_Calibrate()
	print "iV_Calibrate " + str(res)

	res = iViewXAPI.iV_Validate()
	print "iV_Validate " + str(res)

	res = iViewXAPI.iV_GetAccuracy(byref(accuracyData), 0)
	print "iV_GetAccuracy " + str(res)
	print "deviationXLeft " + str(accuracyData.deviationLX) + " deviationYLeft " + str(accuracyData.deviationLY)
	print "deviationXRight " + str(accuracyData.deviationRX) + " deviationYRight " + str(accuracyData.deviationRY)
	
	accLX = accuracyData.deviationLX
	accLY = accuracyData.deviationLY
	accRX = accuracyData.deviationRX
	accRY = accuracyData.deviationRY
	
	if accLX > minAccuracy or accLY > minAccuracy or accRX > minAccuracy or accRY > minAccuracy:
		print("One or more accuracies were above " + str(minAccuracy))
		inkey = raw_input('Enter to continue, or s + enter to skip: ')

# ---------------------------------------------
# ---- define the callback functions. Also see the enum and string arrays in PeyeConstants for input/output formats.
# ---------------------------------------------

def SampleCallback(sample):
    data = [None] * k_nchans_raw
    data[0] = sample.timestamp
    data[1] = sample.leftEye.gazeX
    data[2] = sample.leftEye.gazeY
    data[3] = sample.leftEye.diam
    data[4] = sample.leftEye.eyePositionX
    data[5] = sample.leftEye.eyePositionY
    data[6] = sample.leftEye.eyePositionZ
    data[7] = sample.rightEye.gazeX
    data[8] = sample.rightEye.gazeY
    data[9] = sample.rightEye.diam
    data[10] = sample.rightEye.eyePositionX
    data[11] = sample.rightEye.eyePositionY
    data[12] = sample.rightEye.eyePositionZ
    rawOutlet.push_sample(data)
    
    return 0


def EventCallback(event):
    data = [None] * k_nchans_event
    data[0] = eyeDict[event.eye]
    data[1] = event.startTime
    data[2] = event.endTime
    data[3] = event.duration
    data[4] = event.positionX
    data[5] = event.positionY
    data[6] = marcoTime()
    eventOutlet.push_sample(data)
    
    return 0


CMPFUNC = WINFUNCTYPE(c_int, CSample)
smp_func = CMPFUNC(SampleCallback)
sampleCB = False

CMPFUNC = WINFUNCTYPE(c_int, CEvent)
event_func = CMPFUNC(EventCallback)
eventCB = False

# ---------------------------------------------
# ---- start DataStreaming, loops until q is entered
# ---------------------------------------------
res = iViewXAPI.iV_SetSampleCallback(smp_func)
sampleCB = True
res = iViewXAPI.iV_SetEventCallback(event_func)
eventCB = True

command = ''
while not command == 'q':
    command = raw_input('Enter q+enter to quit: ')

print('Terminating... ')
sampleCB = False
eventCB = False


# ---------------------------------------------
# ---- stop recording and disconnect from iViewX
# ---------------------------------------------

res = iViewXAPI.iV_Disconnect()
