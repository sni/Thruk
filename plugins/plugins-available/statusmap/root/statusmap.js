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
  } else if(name) {
    // network leaf
    html += '<div class="tip-title">' + nodename + ': ' + name + '<\/div>'
  }
  html += '<div class="tip-text"><pre>';

  if(data.status != undefined) {
    html += 'Alias:   ' + data.alias + '<br \/>';
    html += 'Address: ' + data.address + '<br \/>';
    html += 'Status:  <span class="' + data.class + '">&nbsp;' + data.status + '&nbsp;<\/span> ' + data.duration + '<br \/>';
    html += 'Output:  ' + data.plugin_output + '<br \/>';
  }

  // with childs
  if(data.state_up != undefined && data.state_up + data.state_down + data.state_unreachable + data.state_pending > 1) {
    html += '<br \/>Child Hosts:<br \/>';
    html += '<span class="' + ((data.state_up > 0) ? "hostUP" : "") +                   '"> Up: <\/span>          ' + data.state_up + '<br \/>';
    html += '<span class="' + ((data.state_down > 0) ? "hostDOWN" : "") +               '"> Down: <\/span>        ' + data.state_down + '<br \/>';
    html += '<span class="' + ((data.state_unreachable > 0) ? "hostUNREACHABLE" : "") + '"> Unreachable: <\/span> ' + data.state_unreachable + '<br \/>';
    html += '<span class="' + ((data.state_pending > 0) ? "hostPENDING" : "") +         '"> Pending: <\/span>     ' + data.state_pending + '<br \/>';
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

                // reset page refresh
                setRefreshRate(refresh_rate);
                additionalParams.set('host', parent.id);
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
            var totalClass = '';
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


/* create and show a circle map */
var a;
function show_circle_map(id_to_show, w, h) {
    // distance between circles
    var levelDistance = 100;

    //RGraph.Plot.NodeTypes.implement({
    //  //This node type is used for plotting the pie charts
    //  'nodepie': function(node, canvas) {
    //    //Create new canvas instances.
    //    w = node.data.$dim*2;
    //    h = node.data.$dim*2;
    //    w = 100;
    //    h = 100;
    //    //var newCanvas            = document.createElement('canvas');
    //    //newCanvas.id             = "canvas_" + node.id;
    //    //newCanvas.style.width    = w + 'px';
    //    //newCanvas.style.height   = h + 'px';
    //    //newCanvas.style.left     = w*2 + 'px';
    //    //newCanvas.style.top      = h*2 + 'px';
    //    //newCanvas.style.position = 'relative';
    //    //newCanvas.style.zIndex   = 5000000;
    //    //document.getElementById('infovis').appendChild(newCanvas);
    //    //var canvas = new Canvas('piecanvas'+newCanvas.id, {
    //    //    //'injectInto': newCanvas.id,
    //    //    'injectInto': 'infovis',
    //    //    'width':  w,
    //    //    'height': h
    //    //});
    //
    //    var span = node.angleSpan, begin = span.begin, end = span.end;
    //    var polarNode = node.pos.getp(true);
    //    var polar = new Polar(polarNode.rho, begin);
    //    var p1coord = polar.getc(true);
    //    polar.theta = end;
    //    var p2coord = polar.getc(true);
    //
    //    var ctx = canvas.getCtx();
    //    ctx.beginPath();
    //    ctx.moveTo(0, 0);
    //    ctx.lineTo(p1coord.x, p1coord.y);
    //    ctx.moveTo(0, 0);
    //    ctx.lineTo(p2coord.x, p2coord.y);
    //    ctx.moveTo(0, 0);
    //    ctx.arc(0, 0, polarNode.rho, begin, end, false);
    //    ctx.fill();
    //  }
    //});


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
            //style.visibility = 'visible';
            style.cursor = 'pointer';
            style.height = '';
            style.width  = '';

            if(node._depth <= 1) {
                style.fontSize = '0.9em';
                style.color    = '#000000';
            }
            else if(node._depth <= 3){
                style.fontSize = '0.8em';
                style.color    = '#494949';
            }else {
                style.fontSize = '0px';
                style.height   = '10px';
                style.width    = '10px';
            }
            domElement.onmouseover = function (e){showTip((e||window.event), node)};

            if(node.name == '') {
                style.fontSize = '0px';
                style.height   = 2*node.data.$dim + 'px';
                style.width    = 2*node.data.$dim + 'px';

                var left = parseInt(style.left);
                var w = domElement.offsetWidth;
                style.left = (left - w / 2) + 'px';

                var top = parseInt(style.top);
                var h = domElement.offsetHeight;
                style.top = (top - h / 2) + 'px';
            } else {
                var left = parseInt(style.left);
                var w = domElement.offsetWidth;
                style.left = (left - w / 2) + 'px';
            }


        }
    });

    //load JSON data
    var tree = eval('(' + json + ')');
    rgraph.loadJSON(tree);
    rgraph.root = id_to_show;
    rgraph.compute();

    var nodes = new Hash(rgraph.graph.nodes);
    nodes.values().each(function(node) {
        if(node._depth >= 1) {
            h = new Hash(node.adjacencies);
            if(h.size() >= 5) {
                var removed = new Array();
                h.values().each(function(adj) {
                    if(adj.nodeTo._depth > node._depth) {
                        removed.push(adj.nodeTo);
                        rgraph.graph.removeNode(adj.nodeTo.id);
                    }
                    if(adj.nodeFrom._depth > node._depth) {
                        removed.push(adj.nodeFrom);
                        rgraph.graph.removeNode(adj.nodeFrom.id);
                    }
                });
                if(removed.size() > 0) {
                    var newNode = Object({
                        'id':     node.id + "_sum",
                        'name':   "",
                        'data': {
//                            '$type':            'nodepie',
                            '$dim':              removed.size()*2,
                            'clickid':           node.id,
                            'state_up':          node.data.state_up,
                            'state_down':        node.data.state_down,
                            'state_unreachable': node.data.state_unreachable,
                            'state_pending':     node.data.state_pending
                        }
//                        'adjacencies': removed
                    });
                    rgraph.graph.addAdjacence(node, newNode, {});
                }
            }
        }
    });

    rgraph.refresh();
}
