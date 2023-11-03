#! /bin/bash

declare -a SECTIONS
SECTIONS[1]="User commands"
SECTIONS[2]="System calls"
SECTIONS[3]="Library functions"
SECTIONS[4]="Special files"
SECTIONS[5]="File formats and filesystems"
SECTIONS[6]="Games"
SECTIONS[7]="Overview and miscellany section"
SECTIONS[8]="Administration and privileged commands"

KEY=$RANDOM

TDIR=$(mktemp -d --tmpdir yman-XXXXXXXX)

export CSS=$TDIR/man.css
cat > $CSS <<EOF
body{color:#f0f0f0;background-color:#4B4B4B}
h1{color:#33915C;}
h2{color:#A7BC10;}
b{color:#C27F98;}
i{color:#87889C;}
EOF

export FIFO=$TDIR/fifo
mkfifo $FIFO

trap "rm -rf $TDIR" EXIT

function show_man {
    echo -e "\f" >> $FIFO
    [[ $3 -eq 0 ]] && return
    page=$1
    [[ -n $3 ]] && page+="($3)"
    man -Hcat $page >> $FIFO
}
export -f show_man

exec 3<> $FIFO

# list for man pages
for s in {1..8}; do
    printf "s%s\n%s\n\n0\nBold\n" $s "${SECTIONS[$s]}"
    man -k -s $s . | sort | awk -v s="$s" '{printf("%s:s%s\n%s\n",NR,s,$1); for (i=4;i<=NF;i++) printf("%s ",$i); printf("\n%s\n\n",s)}'
done | yad --plug=$KEY --tabnum=1 --no-markup --use-interp --dclick-action="show_man" \
           --list --tree --column="Name" --column="tip:hd" --column="sec:hd" --column=@font@ --tooltip-column=2 &

# current man page
yad --plug=$KEY --tabnum=2 --html --user-style=$CSS <&3 &

# main window
yad --window-icon=help-browser --title="Manual page viewer" --width=1200 --height=950 --button=yad-close:1 \
    --paned --key=$KEY --orient=hor --splitter=350 --image=help-browser --text="<b>Manual Pages browser and viewer</b>" &
PID=$!

[[ -n $1 ]] && show_man $1

# mail loop
while kill -0 $PID &> /dev/null; do
    sleep 0.5
done
