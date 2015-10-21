Under heavy development, only able to open PDFs and select paragraphs (to debug future eye tracking detection) for now.

Data passed to DiMe in the wiki: https://github.com/HIIT/PeyeDF/wiki/Data-Format 

# Addional software

## Git submodules

The following GitHub projects are linked as git submodules. Please make sure you checkout the correct version in the submodule and that the deployment version of the submodule is correct (at the moment, 10.10)

[Alamofire version 2.0.1](https://github.com/Alamofire/Alamofire/releases/tag/2.0.1) - For easier DiMe API calls. The correct version should be already checked out as a submodule (in case it's not, do `git checkout tags/2.0.1` in the Alamofire subfolder).

## Embedded

The following GitHub projects are incorporated into PeyeDF (no additional download needed) and are listed here for reference. They were released under the MIT license.

[XCGLogger version 3.0](https://github.com/DaveWoodCom/XCGLogger/releases/tag/Version_3.0) - To output logs to terminal and files.

[Swifty JSON version 2.3.0](https://github.com/SwiftyJSON/SwiftyJSON/releases/tag/2.3.0) - To easily parse JSON **from** DiMe.
