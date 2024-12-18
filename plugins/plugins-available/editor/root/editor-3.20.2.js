jQuery(document).ready(function() {
    jQuery('#container')
        .jstree({
            plugins: [ "themes", "search" ],
            core:    {
                animation: 0
            },
            themes: {
                theme : 'classic',
                dots  : true
            },
            search: {
                case_insensitive  : true,
                show_only_matches : true
            }
        })
        .on('changed.jstree', function (e, data) {
            // toggle folders on single click
            if(data.node.state.opened) {
                jQuery('#container').jstree('close_node', '#'+data.node.id);
            } else {
                jQuery('#container').jstree('open_node', '#'+data.node.id);
            }
        });
    jQuery('#editor_back_button').click(function() {
        _reset_local_editor();
        return false;
    });

    // initialize editor
    var editor = ace.edit("editor");
    editor.setTheme("ace/theme/clouds");
    editor.setOptions({
        enableLiveAutocompletion: true,
        showPrintMargin: false,
        readOnly: true
    });
    // update changed flag for tabs
    editor.on("change", function(e) {
        _check_changed_file(current_open_file);
    });
    jQuery('#editor').hide();

    jQuery("#remoteframe").on("load", function() {
        _load_remote_peer_ready();
    });

    _resize_editor_and_file_tree();

    // open previously open tabs
    var saved_tabs = readCookie('thruk_editor_tabs');
    if(saved_tabs) {
        var open = saved_tabs.split(/,/);
        jQuery(open).each(function(i, p) {
            _load_file(p);
        })
    }

    // load file from url
    if(window.location.hash != '#' && window.location.hash != '') {
        var file = window.location.hash.replace(/^#/,'');
        var tmp  = file.split(/:/);
        var line = 1;
        if(tmp.length == 2) {
            file = tmp[0];
            line = tmp[1];
        }
        _load_file(file, line);
        // replace history otherwise we have to press back twice
        var newhash = "#";
        if (history.replaceState) {
            history.replaceState({}, "", newhash);
        } else {
            window.location.replace(newhash);
        }
    }
});

function _activate_session(path) {
    var edit = editor_open_files[path];
    var editor = ace.edit("editor");
    editor.setSession(edit.session);
    current_open_file = path;

    jQuery("#tabs").find("SPAN.tabs").removeClass("active");

    // show matching action menu
    for(var key in editor_open_files) {
        var id = editor_open_files[key].tabId;
        if(key == path) {
            jQuery("#"+id).addClass("active");
            jQuery('.'+id+"-action").show();
        } else {
            jQuery('.'+id+"-action").hide();
        }
    }

    _reload_file_if_changed(path);
    _save_open_tabs();
}

// check current tab every 30 seconds
window.setInterval(function() {
    if(current_open_file) {
        _reload_file_if_changed(current_open_file);
    }
}, 30000);
function _reload_file_if_changed(path) {
    var edit = editor_open_files[path];
    if(!edit) {
        return;
    }

    // dont check more than every few seconds
    var now = Math.round(new Date().getTime()/1000);
    if(edit.lastCheck > now - 10) {
        return;
    }
    edit.lastCheck = now;

    // reload file if its unchanged but changed on server side
    if(!edit.changed) {
        jQuery.ajax({
            url: 'editor.cgi',
            data: {
                action:   'get_file',
                file:      path,
                CSRFtoken: CSRFtoken
            },
            type: 'POST',
            success: function(data) {
                // check if it has been closed meanwhile
                edit = editor_open_files[path];
                if(!edit) {
                    return;
                }
                edit.lastCheck = Math.round(new Date().getTime()/1000);
                if(data.md5 != edit.md5) {
                    edit.md5      = data.md5;
                    edit.origText = data.data;
                    edit.changed  = false;
                    edit.session.setValue(data.data);
                    _check_changed_file(path);
                }
            },
            error: function(jqXHR, textStatus, errorThrown) {
                ajax_xhr_error_logonly(jqXHR, textStatus, errorThrown);
            }
        });
    }
}

function _close_tab(path) {
    if(editor_open_files[path].changed) {
        if(!confirm("Discard unsaved changes?")) {
            return;
        }
    }
    panelId = editor_open_files[path].tabId;
    delete editor_open_files[path];
    jQuery("#"+panelId).remove();
    var openTabs = jQuery("#tabs").find("SPAN.tabs").length;
    jQuery("#tabs").find("SPAN.tabs").last().click();
    if(openTabs == 0) {
        var editor = ace.edit("editor");
        editor.setValue("");
        editor.setOptions({
            readOnly: true
        });
        jQuery('#editor').hide();
        current_open_file = "";
    }
    jQuery('.'+panelId+"-action").remove();
    // resize editor, tab bar may have shrinked
    _resize_editor_and_file_tree();
    _save_open_tabs();
}
function _check_changed_file(filename) {
    var edit = editor_open_files[filename];
    // may be undefined during opening a file
    if(edit) {
        if(edit.origText != edit.session.getValue()) {
            jQuery("#"+edit.tabId+" SPAN.file-changed").show();
            jQuery("#"+edit.tabId+" .js-tablink").css("font-style", "italic");
            edit.changed = true;
            jQuery('.js-saveicon').removeClass('disabled');
        } else {
            jQuery("#"+edit.tabId+" SPAN.file-changed").hide().text("*");
            jQuery("#"+edit.tabId+" .js-tablink").css("font-style", "");
            edit.changed = false;
            jQuery('.js-saveicon').addClass('disabled');
        }
    }

    // check if we have to prevent page unload
    var hasUnsaved = false;
    for(var key in editor_open_files) {
        if(editor_open_files[key].changed) {
            hasUnsaved = true;
        }
    }
    if(hasUnsaved) {
        jQuery(window).on('beforeunload', function(e) {
            return 'You have unsaved sessions. Are you sure to leave?';
        });
    } else {
        jQuery(window).off('beforeunload');
    }
}

var _resize_editor_and_file_tree = function() {
    var editor = ace.edit("editor");
    editor.resize();
}

window.onresize = _resize_editor_and_file_tree;

var editor_open_files = {};
var current_open_file = "";
var tabCounter = 0;
function _load_file(path, line) {
    if(!file_meta_data[path]) {
        return;
    }
    var syntax      = file_meta_data[path].syntax;
    var action_menu = file_meta_data[path].action;

    if(editor_open_files[path]) {
        // switch to that tab
        _activate_session(path);
        return;
    }
    // double check if that file is open now
    if(editor_open_files[path]) {
        return;
    }

    if(action_menu.length > 0) {
        jQuery('.menu-loading').hide();
        jQuery('#action_menu_table').append("<div class='no-hover menu-loading px-0'><hr><\/div><div class='no-hover menu-loading'><div class='spinner'><\/div>");
    }

    var mode = "ace/mode/plain_text";
    if(syntax != "") {
        mode = "ace/mode/"+syntax;
    }
    current_open_file = path;
    var session = ace.createEditSession("", mode);
    var editor = ace.edit("editor");
    editor.setSession(session);
    jQuery('#editor').show();
    var id = "tabs-" + tabCounter;
    var filename = path.replace(/^.*\//, '');
    editor_open_files[path] = {
        session  : session,
        md5      : "",
        origText : "",
        tabId    : id,
        changed  : false,
        filename : filename,
        lastCheck: Math.round(new Date().getTime()/1000)
    };

    var tab = '<span class="tabs active p-0 clickable" id="'+id+'" data-path="'+path+'" title="'+path+'" onmouseover="jQuery(this).find(\'.js-close-icon\').css(\'visibility\', \'visible\')" onmouseout="jQuery(this).find(\'.js-close-icon\').css(\'visibility\', \'hidden\')">'
             +'<span class="clickable inline-block p-2 js-tablink" onclick="_activate_session(this.parentElement.dataset.path)">'+filename+'<\/span>'
             +'<span class="file-changed"><div class="spinner"><\/div></span>'
             +'<i class="uil uil-times clickable hoverable ml-1 js-close-icon" style="visibility: hidden;" onclick="_close_tab(this.parentElement.dataset.path);"><\/i>'
             +'<\/span>';
    jQuery("#tabs").append(tab);

    tabCounter++;
    // resize editor, tab bar may have grown in height
    _resize_editor_and_file_tree();

    _save_open_tabs();

    jQuery('.action_menu').hide();
    jQuery.ajax({
        url: 'editor.cgi',
        data: {
            action:   'get_file',
            file:      path,
            CSRFtoken: CSRFtoken
        },
        type: 'POST',
        success: function(data) {
            _load_file_complete(path, syntax, data, line);
            if(action_menu.length > 0) {
                _load_action_menu(path, action_menu);
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            ajax_xhr_error_logonly(jqXHR, textStatus, errorThrown);
            jQuery('.menu-loading').remove();
        }
    });
}

function _load_file_complete(path, syntax, data, line) {
    var edit = editor_open_files[path];
    if(!edit) { return; }
    var editor = ace.edit("editor");
    editor.setSession(edit.session);
    edit.md5       = data.md5;
    edit.origText  = data.data;
    edit.changed   = false;
    edit.lastCheck = Math.round(new Date().getTime()/1000);
    editor.getSession().setValue(data.data);
    editor.setOptions({
        readOnly: false
    });
    if(line) {
        editor.gotoLine(Number(line));
    } else {
        editor.gotoLine(1);
    }

    _check_changed_file(path);
    _activate_session(path);
}

function _save_open_tabs() {
    var open = [];
    jQuery("#tabs").find("SPAN.tabs").each(function(i, el) {
        var id = jQuery(el).attr('id');
        for(var key in editor_open_files) {
            if(editor_open_files[key].tabId == id) {
                open.push(key);
                break;
            }
        }
    });
    cookieSave('thruk_editor_tabs', open.join(','));
}

function _load_action_menu(path, action_menu) {
    jQuery.ajax({
        url: 'editor.cgi',
        data: {
            action:      'get_action_menu',
            action_menu:  action_menu.join(','),
            CSRFtoken:    CSRFtoken
        },
        type: 'POST',
        success: function(data) {
            var edit = editor_open_files[path];
            if(!edit) {
                return;
            }

            var display = "none";
            if(path == current_open_file) {
                display = "";
            }
            jQuery('.menu-loading').remove();

            jQuery(data).each(function(i, el) {
                if(is_object(el) && el["err"]) {
                    jQuery('#action_menu_table').append("<div style='display:"+display+";' class='no-hover "+edit.tabId+"-action px-0'><hr><\/div>");
                    jQuery('#action_menu_table').append("<div style='display:"+display+";' class='no-hover textALERT text-center "+edit.tabId+"-action px-0'>failed to load menu<\/div>");
                    console.error(el["err"]);
                    return(true);
                }
                if(el == "-") {
                    jQuery('#action_menu_table').append("<div style='display:"+display+";' class='no-hover "+edit.tabId+"-action px-0'><hr><\/div>");
                    return(true);
                }
                var item = document.createElement('div');
                item.className = "clickable "+edit.tabId+"-action";
                item.style.display = display;
                jQuery('#action_menu_table').append(item);

                var link = document.createElement('a');
                if(el.icon) {
                    var span       = document.createElement('span');
                    span.className = "inline-block pr-0";
                    var img        = action_menu_icon(el.icon);
                    span.appendChild(img);
                    link.appendChild(span);
                }
                var label = document.createElement('span');
                label.innerHTML = el.label;
                link.appendChild(label);
                link.href       = replace_macros(el.action);

                /* apply other attributes */
                for(var key in el) {
                    if(key != "icon" && key != "action" && key != "label") {
                        link[key] = el[key];
                    }
                }

                item.appendChild(link);
                var extra_data = {
                    file: path,
                    current_data: function() {
                        var editor = ace.edit("editor");
                        return(editor.getSession().getValue());
                    }
                };
                var callback = function(data) {
                    var editor = ace.edit("editor");
                    editor.session.setOption("useWorker", false);
                    // clean current annotations
                    editor.getSession().setAnnotations([]);
                    if(data && data.rc != 0) {
                        // detect perl errors and add annotations
                        var matches = data.msg.match(/(.*) at .*? line (\d+)/);
                        if(matches) {
                            editor.getSession().setAnnotations([{
                              row:    Number(matches[2])-1,
                              column: 0,
                              text:   matches[1],
                              type:  "warning"
                            }]);
                        }
                    }
                }
                check_server_action(undefined, link, undefined, undefined, undefined, url_prefix + 'cgi-bin/editor.cgi?serveraction=1', extra_data, callback);
                return(true);
            });
        },
        error: function(jqXHR, textStatus, errorThrown) {
            ajax_xhr_error_logonly(jqXHR, textStatus, errorThrown);
            jQuery('.menu-loading').remove();
        }
    });
}

jQuery(window).bind("keydown", function(event) {
    if(event.ctrlKey || event.metaKey) {
        switch (String.fromCharCode(event.which).toLowerCase()) {
        case 's':
            event.preventDefault();
            _save_current_file();
            return false;
        case 'w':
            // this seems not to work in most browsers
            // but at least you can use ctrl+w on osx now and meta+w on win/linux
            event.preventDefault();
            if(current_open_file) {
                _close_tab(current_open_file);
            }
            try{event.preventDefault()}catch(ex){}
            return false;
        }
    }
    return true;
});

function _save_prompt_change_summary(path, submit_callback) {
    var has_prompt      = file_meta_data[path].has_save_prompt;
    if(!has_prompt) {
        return(submit_callback());
    }

    openModalWindowUrl('parts.cgi?part=_summary_prompt', function() {
        jQuery("#summary-dialog-form BUTTON.js-ok").one("click", function() {
            var text = jQuery("#summary-text").val();
            var desc = jQuery("#summary-desc").val();
            closeModalWindow();
            return(submit_callback(text, desc));
        });
    });

    return(true);
}

function _save_current_file(skipPrompt, extraData) {
    var path = current_open_file;
    if(!path) {
        return;
    }
    if(!editor_open_files[path]) {
        return;
    }
    var edit = editor_open_files[path];
    if(!edit.changed) {
        return;
    }
    var has_prompt = file_meta_data[path].has_save_prompt;

    if(has_prompt && !skipPrompt) {
        _save_prompt_change_summary(path, function(title, desc) {
            _save_current_file(true, {summary: title, summarydesc: desc});
        });
        return;
    }

    var editor    = ace.edit("editor");
    var savedText = editor.getSession().getValue();

    jQuery('.js-saveicon').find('DIV.spinner').css("display", "");
    jQuery('.js-saveicon').find('I').css("display", "none");

    // fetch current md5 to see if file has changed meanwhile
    jQuery.ajax({
        url: 'editor.cgi',
        data: {
            action:   'get_file',
            file:      path,
            CSRFtoken: CSRFtoken
        },
        type: 'POST',
        success: function(data) {
            if(data.md5 == edit.md5 || confirm("File has changed on server since we opened it. Really overwrite?")) {
                postdata = {
                    action:   'save_file',
                    file:      path,
                    data:      savedText,
                    CSRFtoken: CSRFtoken
                };
                if(extraData) {
                    for(var key in extraData) {
                        postdata[key] = extraData[key];
                    }
                }
                jQuery.ajax({
                    url:  'editor.cgi',
                    data:  postdata,
                    type: 'POST',
                    success: function(data) {
                        showMessageFromCookie(); // might contain failed post cmd output
                        if(data && data.err) {
                            set_save_error(data.err);
                            return;
                        }
                        editor_open_files[path].md5      = data.md5;
                        editor_open_files[path].origText = savedText;
                        _check_changed_file(path);
                        jQuery('.js-saveicon').removeClass("disabled");
                        jQuery('.js-saveicon').find('DIV.spinner').css("display", "none");
                        jQuery('.js-saveicon').find('I.fa-check').css("display", "");
                        window.setTimeout(function() {
                            jQuery('.js-saveicon').find('I.fa-save').css("display", "");
                            jQuery('.js-saveicon').find('I.fa-check').css("display", "none");
                            _check_changed_file(path);
                        }, 1000);
                    },
                    error: function(jqXHR, textStatus, errorThrown) {
                        var msg = thruk_xhr_error('save failed: ', '', textStatus, jqXHR, errorThrown);
                        set_save_error(msg);
                    }
                });
            } else {
                jQuery('.js-saveicon').find('DIV.spinner').css("display", "none");
                jQuery('.js-saveicon').find('I').css("display", "none");
                jQuery('.js-saveicon').find('I.fa-save').css("display", "");
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            var msg = thruk_xhr_error('save failed: ', '', textStatus, jqXHR, errorThrown);
            set_save_error(msg);
        }
    });
}

function set_save_error(msg) {
    showMessageFromCookie();
    jQuery('.js-saveicon').find('DIV.spinner').css("display", "none");
    jQuery('.js-saveicon').find('I').css("display", "none");
    jQuery('.js-saveicon').find('I.fa-save').css("display", "");
    jQuery('.js-saveicon').find('I.uil-exclamation').css("display", "").attr("title", msg);
}

function _tree_search(value) {
    if(value == "") {
        jQuery('#container').jstree('search', '');
        jQuery('#container').jstree('close_all');
        return;
    }
    jQuery('#container').jstree('open_all');
    jQuery('#container').jstree('search', value);
}

function _load_remote_peer(peer, thruk_url) {
    cookieSave('thruk_editor_tabs', '');
    jQuery('#editor_back_button').show();
    jQuery("#remoteframe").attr('src', 'proxy.cgi/'+peer+thruk_url+'cgi-bin/editor.cgi?minimal=2&hidetop=1&iframed=1');
    jQuery("#iframeloading").show();
    jQuery("#editor").hide();
}

function _load_remote_peer_ready() {
    jQuery("#localeditor").hide();
    jQuery("#remoteframe").show();
    jQuery("#iframeloading").hide();
}

function _load_local_editor() {
    if(window.parent && window.parent._reset_local_editor) {
        window.parent._reset_local_editor();
    }
}

function _reset_local_editor() {
    jQuery("#remoteframe").hide();
    jQuery("#iframeloading").hide();
    jQuery("#localeditor").show();
    jQuery("#editor").show();
    jQuery('#editor_back_button').hide();
    _save_open_tabs();
}
