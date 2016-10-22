#!/bin/bash
# assign some items to start with

items=( "How much wood would a woodchuck chuck," "if a wooodchuck could chuck wood?" "brasero.desktop" "brasero --no-existing-session" )

# append some items
#items+=( "$zenlist"* )

yad --list --title='A single-column List' --width=600 --height=450 \
       --column='Spaces are allowed within "q u o t e s"' --column="Column B" "${items[@]}"

yad --form --width=800 --height=500 --center --field="Search 1" --field="Search2" \
	--field="Results:CB" --button="select:0" 
