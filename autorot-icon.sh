#!/bin/bash
#yad --notification --command="./autorot.sh"
function greet {
yad --text="Hello!"	
}
export -f greet

yad --notification --command="bash -c greet"

