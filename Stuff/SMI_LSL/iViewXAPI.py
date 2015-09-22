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
# iViewXAPI.py
#
# Demonstrates features of iView API 
# Defines structures 
# Loads in iViewXAPI.dll
# This script shows how to set up an experiment with Python 2.7.1 (with ctypes Library) 


from ctypes import *


#===========================
#		Struct Definition
#===========================

class CSystem(Structure):
	_fields_ = [("samplerate", c_int),
	("iV_MajorVersion", c_int),
	("iV_MinorVersion", c_int),
	("iV_Buildnumber", c_int),
	("API_MajorVersion", c_int),
	("API_MinorVersion", c_int),
	("API_Buildnumber", c_int),
	("iV_ETDevice", c_int)]

class CCalibration(Structure):
	_fields_ = [("method", c_int),
	("visualization", c_int),
	("displayDevice", c_int),
	("speed", c_int),
	("autoAccept", c_int),
	("foregroundBrightness", c_int),
	("backgroundBrightness", c_int),
	("targetShape", c_int),
	("targetSize", c_int),
	("targetFilename", c_char * 256)]

class CEye(Structure):
	_fields_ = [("gazeX", c_double),
	("gazeY", c_double),
	("diam", c_double),
	("eyePositionX", c_double),
	("eyePositionY", c_double),
	("eyePositionZ", c_double)]

class CSample(Structure):
	_fields_ = [("timestamp", c_longlong),
	("leftEye", CEye),
	("rightEye", CEye),
	("planeNumber", c_int)]

class CEvent(Structure):
	_fields_ = [("eventType", c_char),
	("eye", c_char),
	("startTime", c_longlong),
	("endTime", c_longlong),
	("duration", c_longlong),
	("positionX", c_double),
	("positionY", c_double)]

class CAccuracy(Structure):
	_fields_ = [("deviationLX",c_double),
				("deviationLY",c_double),				
				("deviationRX",c_double),
				("deviationRY",c_double)]
				
				
#===========================
#		Loading iViewX.dll 
#===========================

iViewXAPI = windll.LoadLibrary("iViewXAPI.dll")


#===========================
#		Initializing Structs
#===========================

systemData = CSystem(0, 0, 0, 0, 0, 0, 0, 0)
calibrationData = CCalibration(5, 1, 0, 0, 1, 20, 239, 1, 15, b"")
leftEye = CEye(0,0,0)
rightEye = CEye(0,0,0)
sampleData = CSample(0,leftEye,rightEye,0)
eventData = CEvent('F', 'L', 0, 0, 0, 0, 0)
accuracyData = CAccuracy(0,0,0,0)


