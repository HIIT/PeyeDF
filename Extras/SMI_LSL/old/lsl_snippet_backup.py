import time
import pylsl as lsl
import math

# Script for setting up lsl stream sending data belonging to the SMI RED500 eye tracker.

# -- Constants --
k_srate = 500  # sampling rate
k_nchans_raw = 3  # raw stream channels
k_nchans_event = 3  # event stream channels

k_chunkSize = 32  # size of chunks (using example given by lsl)
k_maxBuff = 30  # maximum buffer size in seconds

rawStream_info = lsl.StreamInfo('SMI_Raw', 'Gaze', k_nchans_raw, k_srate, 'float32', 'smiraw500xa15')
eventStream_info = lsl.StreamInfo('SMI_Event', 'Event', k_nchans_event, k_srate, 'float32', 'smievent500ds15')

# append some meta-data
rawStream_info.desc().append_child_value("manufacturer", "SMI")
eventStream_info.desc().append_child_value("manufacturer", "SMI")
rawStream_info.desc().append_child_value("model", "RED")
eventStream_info.desc().append_child_value("model", "RED")
rawStream_info.desc().append_child_value("api", "iViewPythonLSL")
eventStream_info.desc().append_child_value("api", "iViewPythonLSL")

# -- RAW (GAZE) CHANNELS --
rawChannels = rawStream_info.desc().append_child("channels")
for c in ["Raw_left_x", "Raw_right_x", "___ETCETCETC___"]:
    rawChannels.append_child("channel")\
        .append_child_value("label", c)\
        .append_child_value("unit", "___PIXELS?___")\
        .append_child_value("type", "Gaze")
# unixtime channel for raw
rawChannels.append_child("channel")\
    .append_child_value("label", "unixtime")\
    .append_child_value("unit", "milliseconds")\
    .append_child_value("type", "Time")

# -- EVENT CHANNELS --

eventChannels = eventStream_info.desc().append_child("channels")
for c in ["Fixation_left_x", "Fixation_right_x", "___ETCETCETC___"]:
    eventChannels.append_child("channel")\
        .append_child_value("label", c)\
        .append_child_value("unit", "___NORM?___")\
        .append_child_value("type", "Event")
# unixtime channel for raw
eventChannels.append_child("channel")\
    .append_child_value("label", "unixtime")\
    .append_child_value("unit", "milliseconds")\
    .append_child_value("type", "Time")

#___ Add unix time channels to both streams ( round(time.time() * 1000) )

# -- OUTLETS --

rawOutlet = lsl.StreamOutlet(rawStream_info, k_chunkSize, k_maxBuff)
eventOutlet = lsl.StreamOutlet(eventStream_info, k_chunkSize, k_maxBuff)

# Start streaming
    stamp = local_clock()
    # now send it and wait for a bit
    outlet.push_sample(mysample, stamp)
    
