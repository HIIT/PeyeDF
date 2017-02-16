# Contents of folder

- `dmg`: Used to create a distributable dmg that can also be signed.
- `Images`: Original formats (Autodesk Graphic) of icons and other images used in PeyeDF
- `Questions`: Files related to the Questions target of PeyeDF, used to run controlled experiments
- `SMI_Midas`: Midas node and dispatcher that takes data from SMI_LSL (and dummy) and makes it available in a midas dispatcher
- `SMI_LSL`: `DataStreaming.py`Contains what's needed to stream eye tracker data from eye tracker into lsl (to be run on eye tracker laptop)
- `SMI_LSL_Dummy`: Creates a fake output which corresponds to what SMI_LSL outputs from eye tracker
- `Pupil_plugins`: Plugins for the pupil labs capture software. Includes a surface tracker that maps fixations to surfaces (in addition to gaze points). These should be placed in `~/pupil_capture_settings/plugins/`
- `pupil_surface_tracker.patch`: Difference between the defalt surface tracker provided by pupil labs and the modified version that includes fixations (for future reference).