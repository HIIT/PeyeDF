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
# -*- coding: utf-8 -*-

from iViewXAPI import  * 
import time 

fsample = open('sample.txt','w')
fevent  = open('event.txt','w') 

@WINFUNCTYPE(None, CSample)
def sample_callback(sample):
    fsample.write('{timestamp} {left_gazeX} {left_gazeY}\n'.format(
        timestamp=sample.timestamp, 
        left_gazeX=sample.leftEye.gazeX, 
        left_gazeY=sample.leftEye.gazeY))

     
@WINFUNCTYPE(None, CEvent)  
def event_callback(event):
    fevent.write('{fixstart} {eye} {duration} {posX} {posY}\n'.format(
        fixstart=event.startTime,
        eye=event.eye,
        duration=event.duration, 
        posX=event.positionX,
        posY=event.positionY))   

res = iViewXAPI.iV_Connect(c_char_p('127.0.0.1'), c_int(4444), c_char_p('127.0.0.1'), c_int(5555))

# calibrate
iViewXAPI.iV_SetupCalibration(byref(calibrationData)) 
iViewXAPI.iV_Calibrate()

# set callbacks
res = iViewXAPI.iV_SetSampleCallback(sample_callback)
res = iViewXAPI.iV_SetEventCallback(event_callback)


print('Recording for 10 seconds...\n')
starttime = time.time()
while time.time()-starttime<10:
    time.sleep(0.001) # do something
   

print('Finished \n')
iViewXAPI.iV_Disconnect()
fsample.close()
fevent.close()

		