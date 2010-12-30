/* create tool tip content */
function makeHTMLFromData(name, data){
  var html = '';
  if(data.status != undefined) {
    // real host leaf
    html += '<div class="tip-title">Host: ' + name + '<\/div>'
  } else if(name) {
    // network leaf
    html += '<div class="tip-title">' + nodename + ': ' + name + '<\/div>'
  }
  html += '<div class="tip-text"><pre>';

  if(data.status != undefined) {
    if(data.alias.length         > 80) { data.alias         = data.alias.substr(0,80) + '...'; }
    if(data.address.length       > 80) { data.address       = data.address.substr(0,80) + '...'; }
    if(data.plugin_output.length > 80) { data.plugin_output = data.plugin_output.substr(0,80) + '...'; }
    html += 'Alias:   ' + data.alias + '<br \/>';
    html += 'Address: ' + data.address + '<br \/>';
    html += 'Status:  <span class="' + data.cssClass + '">&nbsp;' + data.status + '&nbsp;<\/span> ' + data.duration + '<br \/>';
    html += 'Output:  ' + data.plugin_output + '<br \/>';
  }

  // with childs
  if(data.status == undefined || (data.state_up + data.state_down + data.state_unreachable + data.state_pending > 1)) {
    html += '<br \/>Child Hosts:<br \/>';
    html += '<span class="' + ((data.state_up > 0) ? "hostUP" : "") +                   '"> Up: <\/span>          ' + data.state_up + '<br \/>';
    html += '<span class="' + ((data.state_down > 0) ? "hostDOWN" : "") +               '"> Down: <\/span>        ' + data.state_down + '<br \/>';
    html += '<span class="' + ((data.state_unreachable > 0) ? "hostUNREACHABLE" : "") + '"> Unreachable: <\/span> ' + data.state_unreachable + '<br \/>';
    html += '<span class="' + ((data.state_pending > 0) ? "hostPENDING" : "") +         '"> Pending: <\/span>     ' + data.state_pending + '<br \/>';
  }

  html += '<\/div><\/pre>';
  return html;
};


/* open a link */
function openLink(e, node) {
  // only open the link when clicked on a link
  if(e.target.tagName == 'A') {
    window.location = e.target.href;
  }
}

/* create and show tooltop */
function showTip(e, node) {

  tipOffsetX = 20;
  tipOffsetY = 20;

  var target = e.target ? e.target : e.srcElement;

  tip = document.getElementById('tooltip');

  //Add mousemove event handler
  addEvent(target, 'mousemove', function(e, win){
      //get mouse position
      win = win  || window;
      e   = e    || win.event;
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

  addEvent(target, 'mouseout', function(e, win){
    tip.style.display = 'none';
  });

  tip.innerHTML = makeHTMLFromData(node.name, node.data);
}

/* create and show a treemap */
function show_tree_map(id_to_show) {

    var levelsToShow = 1;
    if(id_to_show == 'rootid' && groupby == 'address') {
      levelsToShow = 2;
    }
    levelsToShow = levelsToShow + detail;

    // reset page refresh
    setRefreshRate(refresh_rate);
    additionalParams.set('host', id_to_show);

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
        },
        'onLeftClick': function(elem) {
            // hide tip
            tip = document.getElementById('tooltip');
            tip.style.display = 'none';

            show_tree_map(elem.parentNode.id);
            return false;
        }
    });
    var tm = new TM.Squarified({
        //The id of the treemap container
        rootId: 'infovis',
        //Set the max. depth to be shown for a subtree
        levelsToShow: levelsToShow,

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
          var total      = 0;
          var failed     = 0;
          var totalClass = '';
          if(head && node.data) {
            total  = node.data.state_up + node.data.state_down + node.data.state_unreachable + node.data.state_pending;
            failed = node.data.state_down + node.data.state_unreachable;
            totalClass = '';
          }

          if( node.data.alias != undefined ) {
            head.innerHTML = '<a href="'+ url_prefix +'thruk\/cgi-bin\/extinfo.cgi?type=1&amp;host=' + head.innerHTML + '">' + head.innerHTML + '<\/a>';
          }

          // calculate colour of node
          if(node.data.cssClass != undefined && node.data.cssClass != 'hostUP') {
              totalClass = node.data.cssClass;
          }
          else if(total == node.data.state_up) {
              totalClass = 'hostUP';
          }
          else if(total == node.data.state_down) {
              totalClass = 'hostDOWN';
          }
          else if(total == node.data.state_unreachable) {
              totalClass = 'hostUNREACHABLE';
          }
          else if(total == node.data.state_pending) {
              totalClass = 'hostPENDING';
          }
          else if(total > 0) {
              var perc = (failed /(total-node.data.state_pending))*100;
              if(failed == 0) {
                  totalClass = 'hostUP';
              }
                else if(perc > 75) {
                  totalClass = 'hostDOWN';
              }
              else {
                  totalClass = 'serviceWARNING';
              }
          }

          if(isLeaf && node.data.cssClass != undefined && head && failed == 0) {
            head.className = (head.className + " " + node.data.cssClass);
          }
          else if(isLeaf && head && node.data) {
            head.className = (head.className + " " + totalClass);
          }
          head.onmouseover = function (e){showTip((e||window.event), node)};
          head.onmouseup   = function (e){openLink((e||window.event), node)};
        }
    });

    var tree    = eval('(' + json + ')');
    var subtree = TreeUtil.getSubtree(tree, id_to_show);
    TreeUtil.prune(subtree, tm.config.levelsToShow);
    tm.loadJSON(subtree);

    return false;
}


/* create and show a circle map */
function show_circle_map(id_to_show, w, h) {
    // distance between circles
    var levelDistance = 150;

    //Create a new canvas instance.
    var canvas = new Canvas('mycanvas', {
        //Where to append the canvas widget
        'injectInto': 'infovis',
        'width': w,
        'height': h,

        //Optional: create a background canvas and plot
        //concentric circles in it.
        'backgroundCanvas': {
            'styles': {
                'strokeStyle': '#CCCCCC'
            },

            'impl': {
                'init': function(){},
                'plot': function(canvas, ctx){
                    var times = 6, d = levelDistance;
                    var pi2 = Math.PI * 2;
                    for (var i = 1; i <= times; i++) {
                        ctx.beginPath();
                        ctx.arc(0, 0, i * d, 0, pi2, true);
                        ctx.stroke();
                        ctx.closePath();
                    }
                }
            }
        }
    });

    var rgraph = new RGraph(canvas, {
        levelDistance: levelDistance,
        duration: 700,
        fps: 40,

        Node: { //Set Node and Edge colors.
            overridable: true
        },
        Edge: {
            color: '#333333'
        },

        onBeforeCompute: function(node) {
            // reset page refresh
            setRefreshRate(refresh_rate);
            additionalParams.set('host', node.id);
        },

        //Add the name of the node in the correponding label
        //and a click handler to move the graph.
        //This method is called once, on label creation.
        onCreateLabel: function(domElement, node){
            domElement.innerHTML = node.name;
            if(node.data.clickid) {
                domElement.onclick = function(){
                    rgraph.onClick(node.data.clickid);
                };
            }
            else {
                domElement.onclick = function(){
                    rgraph.onClick(node.id);
                };
            }
        },
        //Change some label dom properties.
        //This method is called each time a label is plotted.
        onPlaceLabel: function(domElement, node){
            var style = domElement.style;
            style.cursor = 'pointer';
            style.height = '';
            style.width  = '';

            if(node._depth <= 1) {
                style.fontSize = '0.9em';
                style.color    = '#000000';
            }
            else if(node._depth < 2){
                style.fontSize = '0.8em';
                style.color    = '#494949';
            }else {
                style.fontSize = '0px';
                style.height   = '10px';
                style.width    = '10px';
            }
            domElement.onmouseover = function (e){showTip((e||window.event), node)};
        }
    });

    //load JSON data
    var tree = eval('(' + json + ')');
    rgraph.loadJSON(tree);
    rgraph.refresh();
}



/* create and show a hypertree map */
function show_hypertree_map(id_to_show, w, h) {
  levelDistance = 100;

    //Create a new canvas instance.
    var canvas = new Canvas('mycanvas', {
        //Where to append the canvas widget
        'injectInto': 'infovis',
        'width':  w,
        'height': h,

        //Optional: create a background canvas and plot
        //concentric circles in it.
        'backgroundCanvas': {
            'styles': {
                'strokeStyle': '#CCCCCC'
            },

            'impl': {
                'init': function(){},
                'plot': function(canvas, ctx){
                    var times = 6, d = levelDistance;
                    var pi2 = Math.PI * 2;
                    for (var i = 1; i <= times; i++) {
                        ctx.beginPath();
                        ctx.arc(0, 0, i * d, 0, pi2, true);
                        ctx.stroke();
                        ctx.closePath();
                    }
                }
            }
        }
    });


  var ht = new Hypertree(canvas, {
    Node: {
      overridable: true,
      type: 'circle',
      color: '#ccb',
      lineWidth: 1,
      height: 5,
      width: 5,
      dim: 7,
      transform: true
    },
    Edge: {
      overridable: true,
      type: 'hyperline',
      color: '#ccb',
      lineWidth: 1
    },
    duration: 1500,
    fps: 40,
    transition: Trans.Quart.easeInOut,
    clearCanvas: true,
    withLabels: true,


    onCreateLabel: function(domElement, node){
        domElement.innerHTML = node.name;
        if(node.data.clickid) {
            domElement.onclick = function(){
                ht.onClick(node.data.clickid);
            };
        }
        else {
            domElement.onclick = function(){
                ht.onClick(node.id);
            };
        }
    },
    //Change some label dom properties.
    //This method is called each time a label is plotted.
    onPlaceLabel: function(domElement, node){
        var style = domElement.style;
        //style.visibility = 'visible';
        style.cursor = 'pointer';
        style.height = '';
        style.width  = '';

        if(node._depth <= 1) {
            style.fontSize = '0.9em';
            style.color    = '#000000';
        }
        else if(node._depth < 2){
            style.fontSize = '0.8em';
            style.color    = '#494949';
        }else {
            style.fontSize = '0px';
            style.height   = '10px';
            style.width    = '10px';
        }
        domElement.onmouseover = function (e){showTip((e||window.event), node)};
    }
  });

    var tree = eval('(' + json + ')');
    ht.loadJSON(tree);
    ht.root = id_to_show;
    ht.compute();
    ht.refresh();
}
