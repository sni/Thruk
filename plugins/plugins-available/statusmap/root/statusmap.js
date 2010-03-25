function addEvent(obj, type, fn) {
  if (obj.addEventListener)
    obj.addEventListener(type, fn, false);
  else
    obj.attachEvent('on' + type, fn);
};

function makeHTMLFromData(name, data){
  var html = '';

  if(data.status != undefined) {
    html += '<div class="tip-title">Host: ' + name + '<\/div>'
  } else {
    html += '<div class="tip-title">Network: ' + name + '<\/div>'
    html += '<div class="tip-text"><pre>';
    html += '<span class="' + ((data.state_up > 0) ? "hostUP" : "") +                   '"> Up: <\/span>          ' + data.state_up + '<br />';
    html += '<span class="' + ((data.state_down > 0) ? "hostDOWN" : "") +               '"> Down: <\/span>        ' + data.state_down + '<br />';
    html += '<span class="' + ((data.state_unreachable > 0) ? "hostUNREACHABLE" : "") + '"> Unreachable: <\/span> ' + data.state_unreachable + '<br />';
    html += '<span class="' + ((data.state_pending > 0) ? "hostPENDING" : "") +         '"> Pending: <\/span>     ' + data.state_pending + '<br />';
    html += '<\/div><\/pre>';
  }

  html += '<div class="tip-text"><pre>';
  if(data.status != undefined) {
    html += 'Alias:   ' + data.alias + '<br />';
    html += 'Address: ' + data.address + '<br />';
    html += 'Status:  <span class="' + data.class + '">&nbsp;' + data.status + '&nbsp;<\/span> ' + data.duration + '<br />';
    html += 'Output:  ' + data.plugin_output + '<br />';
  }
  html += '<\/div><\/pre>';
  return html;
};

function showTip(e, node) {

  tipOffsetX = 20;
  tipOffsetY = 20;

  tip = document.getElementById('tooltip');

  //Add mousemove event handler
  addEvent(e.target, 'mousemove', function(e, win){
      //get mouse position
      win = win  || window;
      e = e || win.event;
      var doc = win.document;
      doc = doc.html || doc.body;
      var page = {
          x: e.pageX || e.clientX + doc.scrollLeft,
          y: e.pageY || e.clientY + doc.scrollTop
      };
      tip.style.display = '';
      //get window dimensions
      win = {
          'height': document.body.clientHeight,
          'width': document.body.clientWidth
      };
      //get tooltip dimensions
      var obj = {
        'width': tip.offsetWidth,
        'height': tip.offsetHeight
      };
      //set tooltip position
      var style = tip.style, x = tipOffsetX, y = tipOffsetY;
      style.top = ((page.y + y + obj.height > win.height)?
          (page.y - obj.height - y) : page.y + y) + 'px';
      style.left = ((page.x + obj.width + x > win.width)?
          (page.x - obj.width - x) : page.x + x) + 'px';
  });

  addEvent(e.target, 'mouseout', function(e, win){
    tip.style.display = 'none';
  });


  tip.innerHTML = makeHTMLFromData(node.name, node.data);
}
