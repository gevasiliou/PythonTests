#!/bin/bash

set_default ()
{
    gconftool-2 --config-source xml:readwrite:/etc/gconf/gconf.xml.defaults --type bool --set /apps/gksu/$1 $2
}

set_mandatory ()
{
    gconftool-2 --config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory --type bool --set /apps/gksu/$1 $2
}

CONFFILE="/etc/gksu.conf"

if [ $# -ge 1 ]; then
    CONFFILE="$1"
fi

if [ ! -r "$CONFFILE" ]; then
    echo "$CONFFILE either does not exist or is not readable, aborting."
    exit 1
fi

value=$(grep ^force-grab $CONFFILE | head -n 1 | cut -d= -f2 | sed 's,#.*,,g' | tr -d '[:space:]' | tr A-Z a-z)
if [ -n "$value" ]; then
    if [[ $value = "yes" ]]; then
	set_mandatory force-grab true
    else
	echo "Parse error in $CONFFILE for key force-grab"
    fi
fi

for key in disable-grab sudo-mode prompt always-ask-password; do
    value=$(grep ^$key $CONFFILE | head -n 1 | cut -d= -f2 | sed 's,#.*,,g' | tr -d '[:space:]' | tr A-Z a-z)

    if [ -n "$value" ]; then
	if [[ $value = "yes" ]]; then
	    set_default $key true
	elif [[ $value = "no" ]]; then
	    set_default $key false
	else
	    echo "Parse error in $CONFFILE for key $key"
	fi
    fi
done
