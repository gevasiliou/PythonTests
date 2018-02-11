NR==FNR {
    map[$1] = $2
    re = re sep $1
    sep = "|"
    next
}
{
    head = ""
    tail = $0
    while ( match(tail,re) ) {
        head = head substr(tail,1,RSTART-1) map[substr(tail,RSTART,RLENGTH)]
        tail = substr(tail,RSTART+RLENGTH)
    }
    print head tail
}
