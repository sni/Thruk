
var prefPaneState = 0;

/* toggle the visibility of the preferences pane */
function togglePreferencePane(theme, state) {
  var pane = document.getElementById('pref_pane');
  var img  = document.getElementById('pref_pane_button');
  if(state == 0) { prefPaneState = 1; }
  if(state == 1) { prefPaneState = 0; }
  if(prefPaneState == 0) {
    pane.style.visibility = "visible";
    prefPaneState = 1;
	img.src = "/thruk/themes/"+theme+"/images/icon_minimize.gif";
  }
  else {
    pane.style.visibility = "hidden";
    prefPaneState = 0;
	img.src = "/thruk/themes/"+theme+"/images/icon_maximize.gif";
  }
}

/* save settings in a cookie */
function prefSubmit(url) {
    var sel 		= document.getElementById('pref_theme')
	var now 		= new Date();
	var expires 	= new Date(now.getTime() + (10*365*86400*1000)); // let the cookie expire in 10 years
	document.cookie = "thruk_theme="+sel.value + "; path=/; expires=" + expires.toGMTString() + ";";
	window.status 	= "thruk preferences saved";
	window.location = url;
}
