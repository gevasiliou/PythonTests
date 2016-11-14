#!/bin/bash
#    for dir in /home/gv/dir1/*/ ; do
#      echo $dir
#    done
    
#    for dir in /home/gv/dir1/* ; do
#      echo $dir
#    done

    for dir in $(ls /home/gv/dir1/*/) ; do
      echo $dir
    done


