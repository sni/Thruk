/////////////////////////////////////////////////////////////////////////////////////
//////////////////////NAGIOS NUVOLA STYLE CONFIGURATION//////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

// Web path of the nagios cgis files

var cgipath          	= "/thruk/cgi-bin/";

/////////////////////////////////////////////////////////////////////////////////////

// Choose between DTree Menu (100% free) or Apycom DHMTL Tree Menu (not free)
// If you want to use Apycom DHTML Tree Meny you need to download it from
// http://dhtml-menu.com/ and copy the script "apytmenu.js" into the folder
// called "side".

var treeType 		= "dtree"

/////////////////////////////////////////////////////////////////////////////////////

// If you have installed NagiosQL on your system you can give the web path to the
// admin front end to create an entry in the side bar menu

//var nagiosQLpath	= "/nagiosQL/";

/////////////////////////////////////////////////////////////////////////////////////

//If you want to change the Title of the Menus do it here
//If you leave a menu title blank the menu will not be visible
//Set the if default state is open for each menu

var homeMenuTitle	= "Home";
var homeMenuOpen	= true;

var monitMenuTitle	= "Monitoring";
var monitMenuOpen	= true;

var reportMenuTitle	= "Reporting";
var reportMenuOpen	= true;

var configMenuTitle	= "Configuration";
var configMenuOpen	= true;

/////////////////////////////////////////////////////////////////////////////////////
/////////////Copyright (c) 2005 Gael Martin (gael.pourriel@gmail.com)////////////////
/////////////////////////////////////////////////////////////////////////////////////
