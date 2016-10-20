now=$(pwd)
cd /usr/share/applications
for i in $( ls *.desktop); do
#executable=$(cat "$i" |grep -v 'TryExec' |grep 'Exec' |grep -Po '(?<=Exec=)[^ ]*')
executable=$(cat "$i" |grep -v 'TryExec' |grep 'Exec' |grep -Po '(?<=Exec=)[A-Za-z0-9]*+[ --0-9A-Za-z-a-zA-Z0-9]*')
echo item: $i , command: $executable
list+="$i $executable "
done
echo $list
#yad --list --column "A" --column "B" DataA1 DataB1 DataA2 DataB2
yad --list --column "Desktop File" --column "Exec Value" $list
cd $now
# grep -V means do not select lines containing TryExec (works like not operator)
# grep Exec means select lines containing Exec
# grep -Po gets part of the previous line. Operator ?<= means Look forward after the literal given expression Exec=
# [A-Za-z0-9] means match after Exec=, any character that bellongs in range A-Z or range a-z or range 0-9. 
# The asterisk works like a multiplier => multiple chars selection. if you ommit the * multiplier only one character will be selected after Exec=
# +[ --0-9A-Za-z-a-zA-Z0-9]* --> combine (plus) another set of chars that include either a space, or two dashes (literally), or one dash or chars in given ranges 
# 0-9A-Za-z are ranges. after a-z there is a single - = literally a dash. After this dash another range of a-zA-Z0-9.
# Also this works: grep -Po '(?<=Exec=)[A-Za-z0-9]*+[ --0-9A-Za-z]*'
# More over it seems that grep -Po can be further simplified to grep -Po '(?<=Exec=)[ --0-9A-Za-z]*'
# This is strange; in the beginning the simple greps did not return the required results .
# Above grep gets correct Exec all Exec entries from brasero.desktop: brasero %U, brasero --no-existing-session, brasero --image, etc
# and also gets correct Exec entries from xfce-mouse-settings: xfce4-mouse-settings or even simple exec entries like smtube from smtube.desktop. 
# With other words, get's correctly everything.

# yad is not working ok, due to the case that yad needs data in a very specific way (Data a1 Data b1) and we have a case more than one exec entries to belong in
# a single desktop file , mixing all things up