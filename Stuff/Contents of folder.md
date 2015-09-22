# Contents of folder

- `sample_*.txt`: raw outputs taken from this pipeline: `eye tracker > lsl > midas > xcode > text file`
- `SMI_LSL`: `DataStreaming.py`Contains what's needed to stream eye tracker data from eye tracker into lsl (to be run on eye tracker laptop)
- `SMI_LSL_Dummy`: Creates a fake output which corresponds to what SMI_LSL outputs from eye tracker
- `SMI_Midas`: Midas node and dispatcher that takes data from SMI_LSL (and dummy) and makes it available in a midas dispatcher
- `Icons`: Original format (idraw) of icons used in PeyeDF