# -----------------------------------------------------------------------
#
# (c) Copyright 1997-2013, SensoMotoric Instruments GmbH
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

#!/usr/bin/env python
# -*- coding: utf-8 -*-
from iViewXAPI import  *            #iViewX library
from iViewXAPIReturnCodes import * 

# ---------------------------------------------
#---- constants / support
# ---------------------------------------------

# left eye mapped to -1, right to 1, unkown to 0
eyeDict = {'l': -1, 'L': -1, 'r': 1, 'R': 1}

k_EyeUnknown

# ---------------------------------------------
#---- connect to iViewX
# ---------------------------------------------

res = iViewXAPI.iV_SetLogger(c_int(1), c_char_p("iViewXSDK_Python_SimpleExperiment.txt"))
res = iViewXAPI.iV_Connect(c_char_p('127.0.0.1'), c_int(4444), c_char_p('127.0.0.1'), c_int(5555))
if res != 1:
    HandleError(res)
    exit(0)

res = iViewXAPI.iV_GetSystemInfo(byref(systemData))
print "iV_GetSystemInfo: " + str(res)
print "Samplerate: " + str(systemData.samplerate)
print "iViewX Version: " + str(systemData.iV_MajorVersion) + "." + str(systemData.iV_MinorVersion) + "." + str(systemData.iV_Buildnumber)
print "iViewX API Version: " + str(systemData.API_MajorVersion) + "." + str(systemData.API_MinorVersion) + "." + str(systemData.API_Buildnumber)


# ---------------------------------------------
#---- configure and start calibration
# ---------------------------------------------

calibrationData = CCalibration(5, 1, 0, 0, 1, 250, 220, 2, 20, b"")

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


# ---------------------------------------------
#---- define the callback functions
# ---------------------------------------------

def SampleCallback(sample):
    print " Gaze Data - Timestamp " + str(sample.timestamp) + " Gaze " + str(sample.leftEye.gazeX) + " " + str(sample.leftEye.gazeY) + "\n"
    return 0

def EventCallback(event):
    print " Event: " + str(event.positionX) + " " + str(event.positionY) + "\n"
    return 0


CMPFUNC = WINFUNCTYPE(c_int, CSample)
smp_func = CMPFUNC(SampleCallback)
sampleCB = False

CMPFUNC = WINFUNCTYPE(c_int, CEvent)
event_func = CMPFUNC(EventCallback)
eventCB = False


# ---------------------------------------------
#---- start DataStreaming
# ---------------------------------------------
command = 0

while (command != 'q'):
    command = raw_input("waiting for input - press 's' and 'Enter' to start DataStreaming \n\
                  - press 'q' and 'Enter' to quit DataStreaming \n")
    
    if (command == 's'):
		res = iViewXAPI.iV_SetSampleCallback(smp_func)
		sampleCB = True
		res = iViewXAPI.iV_SetEventCallback(event_func)
		eventCB = True


# ---------------------------------------------
#---- stop recording and disconnect from iViewX
# ---------------------------------------------

res = iViewXAPI.iV_Disconnect()
