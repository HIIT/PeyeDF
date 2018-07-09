# PeyeDF

<p align="center">
  <a href="https://swift.org" target="_blank">
    <img src="https://img.shields.io/badge/swift-4.1-brightgreen.svg" alt="Swift 4.1">
  </a>
  <a href="https://travis-ci.org/HIIT/PeyeDF" target="_blank">
    <img src="https://travis-ci.org/HIIT/PeyeDF.svg" alt="Build status">
  </a>
  <a href="https://developer.apple.com/swift/" target="_blank">
    <img src="https://img.shields.io/badge/Platform-macOS-lightgray.svg" alt="For macOS">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-brightgreen.svg" alt="MIT License">
  </a>
</p>

PeyeDF is especially useful for researchers in reading and eye tracking. It supports multiple eye tracking protocols and is suitable for short and long-term research. It provides an integrated means for data collection using the DiMe personal data storage system. It is designed to collect data in the background without interfering with the reading experience, behaving like a modern lightweight PDF reader. Moreover, it supports annotations, tagging and collaborative work. A modular design allows the application to be easily modified, so that additional eye tracking protocols can be supported and controlled experiment can be designed

## Usage

PeyeDF track the user's reading history, at the paragraph level. Currently it support manual marking of paragraphs by double and triple clicking. To mark a paragraph as "Interesting", double click. To mark it as "Critical" (red), triple click. Make sure "annotate" is enabled on the toolbar for this to work (which normally is, by default).

After some documents have been marked, the "Refinder" function shows the user's history fetched from dime. It can be opened from the toolbar or the `File` menu. Note that a document is added to this history only once it has been closed (this is because the refinder shows information from summary "ReadingEvents", which are sent on document close).

To see what data is pushed to DiMe, see the [wiki](https://github.com/HIIT/PeyeDF/wiki/Data-Format).

[latest release](https://github.com/HIIT/PeyeDF/releases/latest)

## DiMe

PeyeDF requires DiMe for data storage and retrieval. DiMe is an
open-source Personal Data Storage (PDS) system that supports multiple
applications and data types [@symbiotic2016]. DiMe itself requires the
following software to be installed in order to be compiled.

-   Xcode[^1] or Command Line Tools [^2]

-   Java SE[^3] JDK version 8 or above

-   Node.js, downloadable from the web[^4] or via Homebrew[^5], if
    installed

[^1]: <https://itunes.apple.com/app/xcode/id497799835>

[^2]: `xcode-select --install`

[^3]: <http://www.oracle.com/technetwork/java/javase/downloads>

[^4]: <https://nodejs.org>

[^5]: `brew install node`

Once the required software is installed, DiMe should be compiled and
run. PeyeDF must then be configured to utilise DiMe using a predefined
user and password. The procedure to do so is detailed below and the
related code can be pasted into a Terminal (note that individual
commands are separated by '`;`' and otherwise each statement should be
written in a single line).

1.  Clone the open-source DiMe repository:
    `git clone --recursive https://github.com/HIIT/dime-server`

2.  Run DiMe:
    `cd dime-server; make run`

3.  DiMe is ready Once 'fi.hiit.dime.Application: Started' appears;
    first-time compilation may take a few minutes.

4.  Navigate to <http://localhost:8080> and create a user. For a test
    run, use Test1 as user and 123456 for password as these are the
    PeyeDF defaults.

5.  PeyeDF can now be started and should be fully functional. If a
    different user rather than the suggested Test1 was created during
    the previous step, navigate to PeyeDF Preferences, select the 'DiMe'
    tab and enter the chosen username and password.

Dime creates a `.dime` directory under the user's home. This directory
contains the full database; deleting this directory will reset DiMe. If
the directory is copied or moved to another machine an installation of
DiMe on that machine will be able to read the database (assuming that
username and password match). DiMe can also be installed on a (local)
network server so that it can be used by multiple users simultaneously.

## MIDAS

[MIDAS](https://github.com/bwrc/MIDAS) is a python framework for real-time computation of physiological data, which PeyeDF supports.

## Clone

PeyeDF requires its submodules in order to be compiled correctly

`git clone --recursive https://github.com/HIIT/PeyeDF.git`


### Sumobules update

To update the submodules after cloning, use:

`git submodule init && git submodule update`

## Setup

PeyeDF can be installed like any app. After running, open the preferences window by click on PeyeDF > Preferences, or press command + comma ( **&#8984;** + **,** -&#8997;- ). Make sure the DiMe preferences (username, password) are correct.

## Additional software

### Git submodules

The following GitHub projects are linked as git submodules.

[Alamofire version 3.3.0](https://github.com/Alamofire/Alamofire/releases/tag/3.3.0) - For easier DiMe API calls. The correct version should be already checked out as a submodule (in case it's not, do `git checkout tags/3.2.0` in the Alamofire subfolder).

### Embedded

The following GitHub projects are incorporated into PeyeDF (no additional download needed) and are listed here for reference. They were released under the MIT license.

[XCGLogger version 3.3](https://github.com/DaveWoodCom/XCGLogger/releases/tag/Version_3.3) - To output logs to terminal and files.

[Swifty JSON version 2.3.1](https://github.com/SwiftyJSON/SwiftyJSON/releases/tag/2.3.1) - To easily parse JSON **from** DiMe.
