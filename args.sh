#!/bin/bash
flag_c="false"
flag_d="false"
while getopts ":a:-f::cd" opt; do ##the use of -f allows to entet args either in -f or even in --f.Though long names like --full are not supported.
  case $opt in
    a ) arg_a="$OPTARG" ;;
    f ) arg_f="$OPTARG" ;; 
    c ) flag_c="true" ;;
    d ) flag_d="true" ;; 
    \?) echo "Invalid option: -$OPTARG" >&2
      exit 1;;
    :) echo "Option -$OPTARG requires an argument." >&2
      exit 1;;
  esac
done
shift $((OPTIND - 1))
echo "option a: $arg_a"
echo "option f: $arg_f"
echo "option c: $flag_c"
echo "option d: $flag_d"
echo "options not parsed by getopts:" $@
# You can now use $arg_a, $arg_b, $flag_c, and $flag_d in your script.

## Usage: ./args.sh -a one -f two -c -d
## -c and -d requires no arguments. Those could be -v for "verbose enable". 
## getopts does not accept long option names like --file, only -f or --f 
