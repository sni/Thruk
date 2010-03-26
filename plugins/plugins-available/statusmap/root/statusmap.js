/* add event to object */
function addEvent(obj, type, fn) {
  if (obj.addEventListener)
    obj.addEventListener(type, fn, false);
  else
    obj.attachEvent('on' + type, fn);
};

/* create tool tip content */
function makeHTMLFromData(name, data){
  var html = '';
  if(data.status != undefined) {
    // real host leaf
    html += '<div class="tip-title">Host: ' + name + '<\/div>'
    html += '<div class="tip-text"><pre>';
    html += 'Alias:   ' + data.alias + '<br />';
    html += 'Address: ' + data.address + '<br />';
    html += 'Status:  <span class="' + data.class + '">&nbsp;' + data.status + '&nbsp;<\/span> ' + data.duration + '<br />';
    html += 'Output:  ' + data.plugin_output + '<br />';
  } else {
    // network leaf
    html += '<div class="tip-title">Network: ' + name + '<\/div>'
    html += '<div class="tip-text"><pre>';
    html += '<span class="' + ((data.state_up > 0) ? "hostUP" : "") +                   '"> Up: <\/span>          ' + data.state_up + '<br />';
    html += '<span class="' + ((data.state_down > 0) ? "hostDOWN" : "") +               '"> Down: <\/span>        ' + data.state_down + '<br />';
    html += '<span class="' + ((data.state_unreachable > 0) ? "hostUNREACHABLE" : "") + '"> Unreachable: <\/span> ' + data.state_unreachable + '<br />';
    html += '<span class="' + ((data.state_pending > 0) ? "hostPENDING" : "") +         '"> Pending: <\/span>     ' + data.state_pending + '<br />';
    html += '<\/div><\/pre>';
  }

  html += '<\/div><\/pre>';
  return html;
};

/* create and show tooltop */
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

/* create and show a treemap */
function show_tree_map(id_to_show) {

    TM.Squarified.implement({
        'onRightClick': function() {
            // hide tip
            tip = document.getElementById('tooltip');
            tip.style.display = 'none';

            // build up new tree, otherwise we wont find our parent again
            var tree = eval('(' + json + ')');
            var parent = TreeUtil.getParent(tree, this.shownTree.id);
            if(parent) {
                show_tree_map(parent.id);
            }
            return false;
        }
    });
    var tm = new TM.Squarified({
        //The id of the treemap container
        rootId: 'infovis',
        //Set the max. depth to be shown for a subtree
        levelsToShow: 2,

        // space between divs
        offset: 4,

        //Add click handlers for
        //zooming the Treemap in and out
        addLeftClickHandler: true,
        addRightClickHandler: true,

        //When hovering a node highlight the nodes
        //between the root node and the hovered node. This
        //is done by adding the 'in-path' CSS class to each node.
        selectPathOnHover: true,

        // add host class for the host nodes
        onCreateElement:  function(content, node, isLeaf, head, body) {
          if(!node) {
            return;
          }
          if(isLeaf && node.data.class != undefined && head) {
            head.className = (head.className + " " + node.data.class);
          }
          else if(isLeaf && head && node.data) {
            var total  = node.data.state_up + node.data.state_down + node.data.state_unreachable;
            var failed = node.data.state_down + node.data.state_unreachable;
            var totalClass = 'hostUP';
            if(total > 0) {
                var perc   = Math.ceil(failed / total) * 100;
                if(failed == 0) {
                    totalClass = 'hostUP';
                }
                else if(perc > 75) {
                    totalClass = 'serviceWARNING';
                }
                else {
                    totalClass = 'hostDOWN';
                }
            }
            head.className = (head.className + " " + totalClass);
          }
          head.onmouseover = function (e){showTip((e||window.event), node)};
        },
        request: function(nodeId, level, onComplete){
            var tree    = eval('(' + json + ')');
            var subtree = TreeUtil.getSubtree(tree, nodeId);
            TreeUtil.prune(subtree, tm.config.levelsToShow);
            onComplete.onComplete(nodeId, subtree);

            // reset page refresh
            setRefreshRate(refresh_rate);
            additionalParams.set('host', nodeId);
        }
    });

    var tree    = eval('(' + json + ')');
    var subtree = TreeUtil.getSubtree(tree, id_to_show);
    TreeUtil.prune(subtree, tm.config.levelsToShow);
    tm.loadJSON(subtree);

    return false;
}