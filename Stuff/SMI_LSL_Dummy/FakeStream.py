# Must be run with python3 on windows (or linux? untested). Not mac because of bugs in lsl.
# Generates a fake lsl stream, sending data similar to what the eye tracker sends

import time
import pylsl as lsl
import random
import threading

global stop
stop = False

global time_of_start
time_of_start = time.time()


def microSsinceStart():
    return round((time.time() - time_of_start) * 1000000)


def randFakeDelay():
    return round(random.random() * (656216 - 86098) + 86098)

# -- lsl constants --

k_nchans_raw = 13  # raw stream channels
k_nchans_event = 6  # event stream channels

k_chunkSize = 32  # size of chunks (using example given by lsl)
k_maxBuff = 30  # maximum buffer size in seconds

# ---------------------------------------------
# ---- Fake raw data (replace -999 (timestamp) microSsinceStart())
# ---------------------------------------------
zero_raw = [-999, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

fake_raw1 = [-999, 0, 0, 4.389999866485596, 76.60700225830078, 75.18099975585938, 565.06201171875, 0, 0, 3.900000095367432, 22.23399925231934, 76.66799926757812, 584.8170166015625]
fake_raw2 = [-999, 1099, 880, 0, 97.51300048828125, 76.25900268554688, 552.0659790039062, 1099, 880, 0, 45.5800018310546, 78.98500061035156, 580.6119995117188]
fake_raw3 = [-999, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
fake_raw4 = [-999, 1005, 637, 3.960000038146973, 63.53300094604492, 66.552001953125, 565.0050048828125, 1005, 637, 3.950000047683716, 8.899999618530273, 66.98899841308594, 585.2890014648438]
global fake_raws
fake_raws = [fake_raw1, fake_raw2, fake_raw3, fake_raw4]

# ---------------------------------------------
# ---- Fake events (replace -999 (startTime) with microSsinceStart(), -888 (endTime) with microSsinceStart() + randFakeDelay(), -777 with duration ( -888 - (-999) )
# ---------------------------------------------

fake_event1 = [1, -999, 0, 0, 1181.130004882812, 753.5599975585938]
fake_event2 = [-1, -999, 0, 0, 1181.130004882812, 753.5599975585938]
fake_event3 = [1, -999, -888, -777, 1183.359985351562, 751.52001953125]
fake_event4 = [-1, -999, -888, -777, 1183.359985351562, 751.52001953125]
global fake_events
fake_events = [fake_event1, fake_event2, fake_event3, fake_event4]

# ---------------------------------------------
# ---- lab streaming layer
# ---------------------------------------------
samplingRate = 500
rawStream_info = lsl.StreamInfo('SMI_Raw', 'Gaze', k_nchans_raw, samplingRate, 'float32', 'smiraw500xa15')
eventStream_info = lsl.StreamInfo('SMI_Event', 'Event', k_nchans_event, samplingRate, 'float32', 'smievent500ds15')

# append meta-data
rawStream_info.desc().append_child_value("manufacturer", "SMI")
eventStream_info.desc().append_child_value("manufacturer", "SMI")
rawStream_info.desc().append_child_value("model", "RED")
eventStream_info.desc().append_child_value("model", "RED")
rawStream_info.desc().append_child_value("api", "FakeStream")
eventStream_info.desc().append_child_value("api", "FakeStream")

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

# ---------------------------------------------
# ---- lsl outlets
# ---------------------------------------------

rawOutlet = lsl.StreamOutlet(rawStream_info, k_chunkSize, k_maxBuff)
eventOutlet = lsl.StreamOutlet(eventStream_info, k_chunkSize, k_maxBuff)


def FakeSample():
    while not stop:
        fakeIndex = random.randint(0, 3)
        fakeSamp = fake_raws[fakeIndex]
        data = [None] * k_nchans_raw
        data[0] = microSsinceStart()
        data[1] = fakeSamp[1]
        data[2] = fakeSamp[2]
        data[3] = fakeSamp[3]
        data[4] = fakeSamp[4]
        data[5] = fakeSamp[5]
        data[6] = fakeSamp[6]
        data[7] = fakeSamp[7]
        data[8] = fakeSamp[8]
        data[9] = fakeSamp[9]
        data[10] = fakeSamp[10]
        data[11] = fakeSamp[11]
        data[12] = fakeSamp[12]
        rawOutlet.push_sample(data)
        
        time.sleep(0.002)  # note: minimum sleep on win seems to be 13ms


def FakeEvent():
    while not stop:
        fakeIndex = random.randint(0, 3)
        fakeEv = fake_events[fakeIndex]
        data = [None] * k_nchans_event
        data[0] = fakeEv[0]
        data[1] = microSsinceStart()
        if fakeEv[2] == -888:
            data[2] = data[1] + randFakeDelay()
            data[3] = data[2] - data[1]
        else:
            data[2] = fakeEv[2]
            data[3] = fakeEv[3]
        data[4] = fakeEv[4]
        data[5] = fakeEv[5]
        eventOutlet.push_sample(data)
        
        time.sleep(0.002)  # note: minimum sleep on win seems to be 13ms

# ---------------------------------------------
# ---- start FakeStream, loops until quit received
# ---------------------------------------------
sampleT = threading.Thread(target=FakeSample)
sampleT.start()
eventT = threading.Thread(target=FakeEvent)
eventT.start()

command = ''
while not command == 'q':
    command = raw_input('q=quit, l=send zeroes, f=send normal events: ')
    if command=='l':
        print('Sending zeroes in raw stream')
        fake_raws = [zero_raw, zero_raw, zero_raw, zero_raw]
    elif command=='f':
        print('Sending "normal" raw stream')
        fake_raws = [fake_raw1, fake_raw2, fake_raw3, fake_raw4]

stop = True

sampleT.join()
eventT.join()

print('Terminating... ')
