This midas folder forwards fake data generated following the same structure in `SMI_LSL`

## Config
Depending on the network configuration, one may need files in one of the `cfg_*` folders. The cfg file has to stay in the same folder as the midas nodes and dispatcher.

## Running
`./autorun.py` to run all midas stuff in gnu screen

Manually, use these three commands in different terminal sessions:

	./node.py config.ini raw_eyestream
	./node.py config.ini event_eyestream
	./dispatcher.py config.ini dispatcher

## Retrieving
python example

	import requests
	addr = 'http://127.0.0.1:8085'
	reqx = '/raw_eyestream/data/{"channels":["rightGazeX", 	"rightGazeY"]}'
	resp = requests.get(addr + reqx)
	resp.text
