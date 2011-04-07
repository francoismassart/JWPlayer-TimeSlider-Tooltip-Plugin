:: This is a simple script that compiles the plugin using the free Flex SDK on Windows.
:: Learn more at http://developer.longtailvideo.com/trac/wiki/PluginsCompiling

SET FLEXPATH="C:\Program Files\flex_sdk_3.5"

:: Compiling with the com source folder...
:: %FLEXPATH%\bin\mxmlc .\TimeSliderTooltipPlugin.as -sp .\ -o .\timeslidertooltipplugin.swf -use-network=false

:: Compiling without embedding the com source folder (Better?)
%FLEXPATH%\bin\mxmlc .\TimeSliderTooltipPlugin.as -sp .\ -o .\timeslidertooltipplugin.swf -library-path+=..\..\lib -load-externs ..\..\lib\jwplayer-5-classes.xml -use-network=false
