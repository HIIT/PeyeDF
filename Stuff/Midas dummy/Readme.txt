This is a simple test which uses midas (https://github.com/bwrc/midas).

It starts a dummy eye tracking lsl stream that simply generates three different eye tracking locations at (400,400) (400,600) (400,800) coordinates on screen. The stream consists of two channels, one for x and one for y coordinates. The position changes approximately every 5 seconds.

The midas node simply forwards this data so it can accessed in xcode using midas’s rest api.

== RUNNING ==
./sample_eyestream.py                                in one terminal and
./node_example.py config.ini node_example	         in another and
./dispatcher_example.py config.ini dispatcher        in another


== RETRIEVING - PYTHON ==
import requests
addr = 'http://127.0.0.1:8080'
reqx = '/sample_eyestream/data/{"channels":["x", "y"]}'
resp = requests.get(addr + reqx)
resp.text
