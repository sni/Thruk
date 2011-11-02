#!/bin/bash

cd $(dirname $0)

objects=$(perl -I../lib -MMonitoring::Config::Object -e 'print join("|", @{$Monitoring::Config::Object::Types})')
perl -p0777i -e 's$// <objecttypes>(.*)// </objecttypes>$// <objecttypes>\n         "'$objects'"\n         // </objecttypes>$ims' ../root/ace/mode/monitoring_highlight_rules.js

objects=$(perl -I../lib -MMonitoring::Config::Object -e 'print join("\n", @{$Monitoring::Config::Object::Types})')

keywords=$(for obj in $objects; do perl -I../lib -MMonitoring::Config::Object -e '$o = Monitoring::Config::Object->new( type => '$obj'); print join("\n", keys %{$o->{default}})'; echo ""; done | sort -u)
keywords="name|register|use|"$(echo $keywords | tr ' ' '|')
perl -p0777i -e 's$// <objectattributes>(.*)// </objectattributes>$// <objectattributes>\n         "'$keywords'"\n         // </objectattributes>$ims' ../root/ace/mode/monitoring_highlight_rules.js
