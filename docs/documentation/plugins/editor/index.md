## Editor Thruk Plugin

This plugin allows you to edit text files.

![Thruk Editor Plugin](preview.png "Thruk Editor Plugin")

## Installation

Assuming you are using OMD (omdistro.org).
All steps have to be done as site user:

    %> cd etc/thruk/plugins-enabled/
    %> git clone https://github.com/sni/thruk-plugin-editor.git editor
    %> omd reload apache

You now have a new menu item under System -> Editor.

In order to edit text files, you have to define which files to edit. Create a
new file:

`~/etc/thruk/thruk_local.d/editor.conf`.

For example:

    <editor>
      name   = Menu Local
      groups = Admins,Superadmins

      <files>
        folder = etc/thruk/
        filter = menu_local\.conf$
        syntax = perl
        action = perl_editor_menu

        # hooks which will be executed before or after saving a single file.
        #pre_save_cmd        =
        #post_save_cmd       = ./examples/config_tool_git_checkin
        #show_summary_prompt = 1   # enable/disable summary prompt if hooks are set
      </files>
    </editor>

    <action_menu_actions>
      perlsyntax   = /usr/bin/perl -Mstrict -wc
    </action_menu_actions>

You have to reload the apache to activate changes
from the `thruk_local.d` folder.


## Authorization

Authorization can be done either by using the `groups` item like in the example
above or by putting the edit sections in a Group block like:

    <Group Admins>
      <editor>
        name   = Business Process
        <files>
          folder = /etc/thruk/bp/
          filter = \.pm$
          syntax = perl
        </files>
      </editor>
    </Group>


## Syntax Highlighting

Available syntax highlighting modes are listed as mode-* files in
https://github.com/sni/thruk-plugin-editor/tree/master/root/ace-builds/src-min-noconflict

Common syntax modes are:

  - sh
  - perl
  - python
  - ini
  - naemon
  - nagios


## Actions

Then lets create a custom action for a syntax check. Create a new file:

`~/etc/thruk/action_menus/perl_editor_menu.json`.

With this content:

    [
      "-",
      {"icon":"fa-spell-check",
       "label":"Syntax Check",
       "action":"server://perlsyntax/$TMPFILENAME$"
      },
    ]

## Action Scripts / Hooks

The action scripts can do anything, ex.: do a syntax check or activate changes
somewhere. The output is displayed as a popup to the user. The colour depends
on the exit code of the script. `0` is green, everything else is red.

A `pre_save_cmd` script exiting other than 0 will cancel the current save attempt.

### Macros

The editor plugin provides some extra macros.

  - `$FILENAME$` contains the path to the open (unsaved) file.
  - `$TMPFILENAME$` contains the path to a temporary file with the
     current (unsaved) content changes. Use this macro for syntax checks or similar.

### Environment

The editor plugin provides some extra environment variables when running
pre/post hook scripts. Use those variables ex.: to automatically create git commits.

  - `$THRUK_EDITOR_FILENAME` same as `$FILENAME$` in macros.
  - `$THRUK_EDITOR_TMPFILENAME` same as `$TMPFILENAME$` in macros (only available in pre script).
  - `$THRUK_EDITOR_STAGE` can be either 'pre' or 'post'.
  - `$THRUK_SUMMARY_MESSAGE` set from user input (popup on save).
  - `$THRUK_SUMMARY_DETAILS` set from user input (popup on save).
