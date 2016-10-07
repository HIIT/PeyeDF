#!/usr/bin/env python3

import time
import pylsl as lsl
import math

# Starts up a two channel "dummy" LSL stream that claims to be 500 Hz sampled
# SMI signal. Posts a random value every sample.

# Set sampling rate and sample interval
srate = 500.0
sinterval = 1 / srate

# Every second, alternate between these possible coordinates (x, y)
coords = [[400.0, 400.0], [400.0, 600.0], [400, 800]]

# Create a LSL stream named 'Dummy' with 2 channels of eye tracking (x and y)
N = 2
stream_eeg_info = lsl.StreamInfo('Dummy', 'EYE', N, srate, 'float32', 'uid001')
stream_eeg_outlet = lsl.StreamOutlet(stream_eeg_info, max_buffered=10)

# Start streaming
print('Streaming random data ...')
while True:
    i = math.floor(time.time() % 10 % 3)
    data = coords[i]
    stream_eeg_outlet.push_sample(data)
    time.sleep(sinterval)
