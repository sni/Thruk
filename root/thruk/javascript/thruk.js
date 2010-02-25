
var prefPaneState = 0;
var refreshPage   = 1;

/* toggle the visibility of the preferences pane */
function togglePreferencePane(theme, state) {
  var pane = document.getElementById('pref_pane');
  var img  = document.getElementById('pref_pane_button');
  if(state == 0) { prefPaneState = 1; }
  if(state == 1) { prefPaneState = 0; }
  if(prefPaneState == 0) {
    pane.style.visibility = "visible";
    img.style.visibility  = "visible";
    prefPaneState = 1;
  }
  else {
    pane.style.visibility = "hidden";
    img.style.visibility  = "hidden";
    prefPaneState = 0;
  }
}

/* save settings in a cookie */
function prefSubmit(url, current_theme) {
  var sel         = document.getElementById('pref_theme')
  var now         = new Date();
  var expires     = new Date(now.getTime() + (10*365*86400*1000)); // let the cookie expire in 10 years
  if(current_theme != sel.value) {
    document.cookie = "thruk_theme="+sel.value + "; path=/; expires=" + expires.toGMTString() + ";";
    window.status   = "thruk preferences saved";
    window.location = url;
  }
}

/* page refresh rate */
function setRefreshRate(rate) {
  var obj = document.getElementById('refresh_rate');
  if(!rate || refreshPage == 0) {
    obj.innerHTML = "This page will not refresh automatically";
  }
  else {
    obj.innerHTML = "<span id='refresh_rate'>Update in "+rate+" seconds <input type='button' value='stop' onClick='stopRefresh()'></span>";
    if(rate == 0) {
      window.location.reload(true);
    }
    if(rate > 0) {
      newRate = rate - 1;
      setTimeout("setRefreshRate(newRate)", 1000);
    }
  }
}
function stopRefresh() {
  refreshPage = 0;
  setRefreshRate(0);
}


function button_over(button)
{
   button.style.borderColor = "#555555";
}

function button_out(button)
{
   button.style.borderColor = "#999999";
}
