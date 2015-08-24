Under heavy development, only able to open PDFs and select paragraphs (to debug future eye tracking detection) for now.

Data passed to DiMe in the wiki: https://github.com/HIIT/PeyeDF/wiki/Data-Format 

# Addional software

## Git submodules

The following GitHub projects are linked as git submodules. Please make sure you checkout the correct version in the submodule and that the deployment version of the submodule is correct (at the moment, 10.10)

[Alamofire version 1.3.1](https://github.com/Alamofire/Alamofire/releases/tag/1.3.1) - For easier DiMe API calls. Remember to checkout the correct version from the submodule (git checkout cf8127a135e9e9a298a85f3e0e3b93739f822ef6) and to select the correct deployment version in the subproject (10.10).

## Embedded

The following GitHub projects are incorporated into JustUsed (no additional download needed) and are listed here for reference. They were released under the MIT license.

[XCGLogger version 2.2](https://github.com/DaveWoodCom/XCGLogger/releases/tag/Version_2.2) - To output logs to terminal and files.

[Swifty JSON version 2.2.0](https://github.com/SwiftyJSON/SwiftyJSON/releases/tag/2.2.0) - To easily parse JSON **from** DiMe.
