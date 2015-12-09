# Usage

PeyeDF track the user's reading history, at the paragraph level. Currently it support manual marking of paragraphs by double and triple clicking. To mark a paragraph as "Interesting", double click. To mark it as "Critical" (red), triple click. Make sure "annotate" is enabled on the toolbar for this to work (which normally is, by default).

After some documents have been marked, the "Refinder" function shows the user's history fetched from dime. It can be opened from the toolbar or the `File` menu. Note that a document is added to this history only once it has been closed (this is because the refinder shows information from summary "ReadingEvents", which are sent on document close).

To see what data is pushed to DiMe, see the [wiki](https://github.com/HIIT/PeyeDF/wiki/Data-Format).

# Setup

PeyeDF can be installed like any app. After running, open the preferences window by click on PeyeDF > Preferences, or press command + comma ( **&#8984;** + **,** ). Make sure the DiMe preferences (username, password) are correct.

# Addional software

## Git submodules

The following GitHub projects are linked as git submodules. Please make sure you checkout the correct version in the submodule and that the deployment version of the submodule is correct (at the moment, 10.10)

[Alamofire version 3.1.3](https://github.com/Alamofire/Alamofire/releases/tag/3.1.3) - For easier DiMe API calls. The correct version should be already checked out as a submodule (in case it's not, do `git checkout tags/3.1.3` in the Alamofire subfolder).

## Embedded

The following GitHub projects are incorporated into PeyeDF (no additional download needed) and are listed here for reference. They were released under the MIT license.

[XCGLogger version 3.0](https://github.com/DaveWoodCom/XCGLogger/releases/tag/Version_3.0) - To output logs to terminal and files.

[Swifty JSON version 2.3.1](https://github.com/SwiftyJSON/SwiftyJSON/releases/tag/2.3.1) - To easily parse JSON **from** DiMe.
