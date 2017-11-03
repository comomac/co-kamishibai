Co-Kamishibai
=========================
> pronounce Ko-kami-shi-bye

Mini multi-platform web server for reading manga or comic on any browser. Works on low memory device and small/old browser such as Kindle web Opera mini if used over the internet.  

Code was written back in 2013, only recently I've cleaned up and upload to the web. Please don't judge it too harshly.  

This is written before the Kamishibai.

Installation:
--------------------------
Mac OS X:  
1. Install [MacPorts](http://www.macports.org/)  
2. sudo port install ruby19 rb-rubygems gd2  
3. sudo gem1.9 install co-kamishibai
  
Linux (Ubuntu/Debian):  
1. sudo apt-get install ruby1.9.1-full rubygems libgd2-xpm libgd2-xpm-dev  
2. sudo gem install co-kamishibai
  
Configuration:
--------------------------
Config file is written in JSON format. The config file will be located at ~/etc/kamishibai.conf. The config file can also manually selected by appending the config path after the program.  
  
Start:  
--------------------------
co-kamishibai.rb [config_file.conf]
  
File Format:
--------------------------
Only CBZ is supported and it should be zero compressed zip file. This will reduce the burden on the system when reading as well as making the experience more responsive. The file name will determind how it will be organized by the program.

Tested with:
--------------------------
Server:  
Mac OS X (10.8)  
Linux (Ubuntu 12.04)  

Client:  
Mac OS X 10.8 with Firefox 21, Chrome 27 and Safari 6  
iPad mini iOS6 with Safari and Chrome  
Nexus 7 with Chrome and Firefox  
Kindle Experimental Browser