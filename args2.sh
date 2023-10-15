#!/bin/bash

# Initialize variables to store the option values
option1=false
option2=false
option3="not set"
option4="not set"

# Function to display usage information
usage() {
  echo "Usage: $0 [--option1] [--option2] [--option3 value] [--option4 value]"
  echo "  --option1  : Enable option 1"
  echo "  --option2  : Enable option 2"
  echo "  --option3  : Specify option 3 with a value"
  echo "  --option4  : Specify option 4 with a value"
  exit 1
}

# Process options and arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --option1) option1=true;shift ;;
    --option2) option2=true;shift ;;
    --option3) if [ -n "$2" ]; then option3="$2";shift 2; else echo "Option --option3 requires a value." >&2;fi;;
    --option4) if [ -n "$2" ]; then option4="$2";shift 2; else echo "Option --option4 requires a value." >&2;fi;;
    --help) usage;; # *) usage;;
    *) restparam+=$1;shift;;
  esac
done

# Now, you can use the $option1, $option2, $option3, and $option4 variables in your script.
echo "Option 1: $option1"
echo "Option 2: $option2"
echo "Option 3: $option3"
echo "Option 4: $option4"
echo "Rest arguments: $restparam"
echo "Non-option arguments: $@"

# shift moves to the left / discards the positional parameter.
# shift 2 moves/discards two pos parameters. Usefull for --option optionvalue synthax, since shift 2 will discard both the --option 
# and the optionvalue
