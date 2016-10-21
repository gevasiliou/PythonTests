#!/bin/bash
# assign some items to start with
items=( "How much wood would a woodchuck chuck," "if a wooodchuck could chuck wood?" )

# append some items
#items+=( "$zenlist"* )

zenity --list --title='A single-column List' --width=600 --height=450 \
       --column='Spaces are allowed within "q u o t e s"' --column="Column B" "${items[@]}"