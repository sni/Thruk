Thruk - Monitoring Webinterface
===============================

Thruk is a multibackend monitoring webinterface which currently
supports Naemon, Icinga, Shinken and Nagios as backend using the Livestatus
API. It is designed to be a 'dropin' replacement and covers the original
features plus adds additional enhancements for large installations, increased
usability and many usefull addons.

![Thruk Startpage](https://thruk.org/images/galleries/01_main-thumb.png "Thruk Startpage")
![Thruk Panorama](https://thruk.org/images/galleries/geomaps-thumb.png "Thruk Panorama")
[See more screenshots...](https://thruk.org/screenshots/)

Documentation
-------------
All documentation is under docs/

Support
-------

  * Ask a question on [Stack Overflow](https://stackoverflow.com/questions/tagged/thruk)
  * Discuss on the [Monitoring Portal](http://www.monitoring-portal.org/wbb/index.php?page=Board&boardID=106) (german / english).
  * Mailing list on [Google Groups](https://groups.google.com/group/thruk).
  * File a bug in [GitHub Issues](https://github.com/sni/Thruk/issues).
  * [Tweet](https://twitter.com/ThrukGUI/) us with other feedback.
  * Chat with developers on [IRC Freenode #thruk](irc://freenode.net/thruk) ([Webchat](http://webchat.freenode.net/?channels=thruk)).


Main Features / Advantages
--------------------------

  * Multiple backends
  * Faster while using less CPU
  * Displays live data, no delay between core and GUI
  * Clusterable, can be clustered over hosts
  * Business Process Addon
  * Advanced status filters
  * Extended logfile search
  * Multiple themes included
  * Excel export for status and logfiles
  * Adjustable side menu
  * Full expanded plugin commandline for easy testing
  * Save searches in personal bookmarks
  * Config Tool included
  * Mobile interface included
  * SLA Reports in PDF format
  * Recurring Downtimes
  * Fully Featured Dashboard
  * Independant from monitoring core, can be installed on remote host
  * Easy to extend with plugins

License
-------

Thruk is Copyright (c) 2009-2019 by Sven Nierlein and others.
This is free software; you can redistribute it and/or modify it under the
same terms as the Perl5 programming language system
itself:

a) the "Artistic License 1.0" as published by The Perl Foundation
   http://dev.perl.org/licenses/artistic.html

b) the GNU General Public License as published by the Free Software Foundation;
   either version 1 http://www.gnu.org/licenses/gpl-1.0.html
   or (at your option) any later version

`SPDX-License-Identifier: Artistic-1.0-Perl OR GPL-1.0-or-later`

Vendor specific libraries below ./root/thruk/vendor/ may have different
licenes. See THANKS file for details.
