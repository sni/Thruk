***************************************************************************
            Nagios Nuvola Style (gael.pourriel@gmail.com)
***************************************************************************

This is a complete image pack and stylesheets for Nagios 2.0.
Icons are from the Nuvola KDE theme (http://www.icon-king.com/)

The side bar can be configured to use the DHTML Tree Menu from Apycom
http://dhtml-menu.com/ (trial version)
or the free replacement DTree which has been modified to look similar
http://www.destroydrop.com/javascripts/tree/

***************************************************************************
Notes:
***************************************************************************

DHTML Tree Menu source script is not bundle in this package, you will
need to go and download it from their web site and install it, only the
menu data is bundle with this package

DTree menu being open source, it's indeed bundle in this package

***************************************************************************


***************************************************************************
Install:
***************************************************************************

Just move the "html" folder into the HTML directory of Nagios
(usually /usr/local/share/nagios)

You may want to do a backup before. 

It should replace the "images" folder, as well as the "stylesheets" folder
and create a new folder called "side". The "index.html","main.html" and
"side.html" should also be replaced. Modify the permissions for the folders
and you should be ready. 

Id you use the DHTML Tree Menu dont forget to download it from Apycom

***************************************************************************


***************************************************************************
Configuration:
***************************************************************************

You can configure the Menu, edit the Javascript file called "config.js"
located at the HTML root

The first thing to do is to make sure the CGI-BIN web path is setup correctly

You can then change the menu title and set their default opening state.

If you mainly use Firefox to view your Nagios front end you may want to
change the "common.css" file so that tables looks better. Edit "common.css" 
in the stylesheet folder.

***************************************************************************
***************************************************************************


