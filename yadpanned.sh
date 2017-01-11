#!/bin/bash

yad --plug=12345 --tabnum=1 --text="first tab with text" &> res1 &
yad --plug=12345 --tabnum=2 --text="second tab" --entry &> res2 &
yad --notebook --key=12345 --tab="Tab 1" --tab="Tab 2"
