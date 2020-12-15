Ext.EventManager.on(document, 'keydown', function(evt, t) {
    // pass through on input form fields
    if(evt.target && (evt.target.tagName.toLowerCase() == "input" || evt.target.tagName.toLowerCase() == "textarea")) {
        return;
    }

    var key = evt.getKey();
    /* disable backspace on body to prevent accidentally leaving the page */
    if(key == evt.BACKSPACE) {
        evt.preventDefault();
        return false;
    }

    return;
});

// needs to be keydown, keyup is only fired once when key is hold down
Ext.EventManager.on(document, 'keydown', function(evt, t) {
    // pass through on input form fields
    if(evt.target && (evt.target.tagName.toLowerCase() == "input" || evt.target.tagName.toLowerCase() == "textarea")) {
        return;
    }

    var key = evt.getKey();

    // move selected icons
    if(TP.moveIcons && TP.moveIcons[0]) {
        var pos = TP.moveIcons[0].getPosition();
        if(key == evt.UP)       { evt.preventDefault(); TP.moveIcons[0].setPosition(pos[0], pos[1]-1); }
        if(key == evt.DOWN)     { evt.preventDefault(); TP.moveIcons[0].setPosition(pos[0], pos[1]+1); }
        if(key == evt.RIGHT)    { evt.preventDefault(); TP.moveIcons[0].setPosition(pos[0]+1, pos[1]); }
        if(key == evt.LEFT)     { evt.preventDefault(); TP.moveIcons[0].setPosition(pos[0]-1, pos[1]); }
        if(key == evt.BACKSPACE || key == evt.DELETE) {
            var num = TP.moveIcons.length;
            Ext.Msg.confirm('Delete '+num+' icons?', 'Do you really want to remove all '+num+' selected icons?', function(button) {
                if (button === 'yes') {
                    var panels = TP.moveIcons;
                    TP.moveIcons = undefined;
                    Ext.Array.each(panels, function(p, i) {
                        p.destroy();
                    });
                }
            });
        }
        if(key == evt.ESC) {
            TP.resetMoveIcons();
        }
    }

    // move icon when settings window is open
    if(TP.iconSettingsWindow) {
        var layout = Ext.getCmp('layoutForm');
        if(layout) {
            var form = layout.getForm();
            if(key == evt.UP)       { evt.preventDefault(); form.setValues({y: Number(form.getValues().y)-1}); };
            if(key == evt.DOWN)     { evt.preventDefault(); form.setValues({y: Number(form.getValues().y)+1}); };
            if(key == evt.RIGHT)    { evt.preventDefault(); form.setValues({x: Number(form.getValues().x)+1}); };
            if(key == evt.LEFT)     { evt.preventDefault(); form.setValues({x: Number(form.getValues().x)-1}); };
        }
    }

    // toggle map controls on space
    if(key == evt.SPACE) {
        var tabbar = Ext.getCmp('tabbar');
        var tab    = tabbar.getActiveTab();
        if(!tab.map) { return; }
        if(tab.lockButton.hasCls('unlocked')) {
            tab.disableMapControls();
        } else {
            tab.enableMapControls();
        }
    }
});
