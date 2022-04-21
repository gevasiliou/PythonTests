#grep -v '^[#].*' dpkg-l-gksu-files-only.log |while read -r l;do 
#echo "prepare to copy ${l##*/} to $l" && read -p "press any key to continue or control-c to abort";
#cp -i -v "${l##*/}" "$l";
#done
#above method abantoned; read-p does not work for some reason inside while read loop

mapfile -t -O1 gkf < <(grep -v '^[#].*' dpkg-l-gksu-files-only.log)
for l in "${gkf[@]}" ;do
printf "prepare to copy ${l##*/} to $l ";
read -p " - continue ? [y/n] ? :" an
[[ $an == "y" ]] && cp -i -v "${l##*/}" "$l" || echo "===========> skipping installation of $l <============";
done

printf "prepare to copy usr-share-menu-gksu to /usr/share/menu/gksu" && read -p " - continue ? [y/n] ? :" an
[[ $an == "y" ]] && cp -i -v usr-share-menu-gksu /usr/share/menu/gksu || echo "===========> skipping <============";

printf "prepare to copy gksudo to /usr/bin/gksudo " && read -p " - continue ? [y/n] ? :" an
[[ $an == "y" ]] && cp -i -v -P gksudo /usr/bin/gksudo || echo "===========> skipping <============";
