#grep -v '^[#].*' dpkg-l-gksu-files-only.log |while read -r l;do 
#echo "prepare to copy ${l##*/} to $l" && read -p "press any key to continue or control-c to abort";
#cp -i -v "${l##*/}" "$l";
#done
#above method abantoned; read-p does not work for some reason inside while read loop
mapfile -t -O1 gkf < <(grep -v '^[#].*' dpkg-l-gksu-files-only.log)
if [[ $1 == "--remove" ]]; then 
echo "remove option given";
for l in "${gkf[@]}" ;do
printf "prepare to remove $l ";
read -p " - continue ? [y/n] ? :" an
[[ $an == "y" ]] && rm -i -v "$l" || echo "===========> skipping removal of $l <============";
done
[ -d "/usr/share/doc/gksu" ] && rm -r -i -v /usr/share/doc/gksu;
[ -d "/usr/share/gksu" ] && rm -r -i -v /usr/share/gksu;
rm -i -v /usr/share/menu/gksu
rm -i -v /usr/bin/gksudo 
exit
fi

[ ! -d "/usr/share/doc/gksu" ] && mkdir /usr/share/doc/gksu && ls -all -d /usr/share/doc/gksu
[ ! -d "/usr/share/gksu" ] && mkdir /usr/share/gksu && ls -all -d /usr/share/gksu

for l in "${gkf[@]}" ;do
printf "prepare to copy ${l##*/} to $l ";
read -p " - continue ? [y/n] ? :" an
[[ $an == "y" ]] && cp -i -v "${l##*/}" "$l" || echo "===========> skipping installation of $l <============";
done

printf "prepare to copy usr-share-menu-gksu to /usr/share/menu/gksu" && read -p " - continue ? [y/n] ? :" an
[[ $an == "y" ]] && cp -i -v usr-share-menu-gksu /usr/share/menu/gksu || echo "===========> skipping <============";

printf "prepare to copy gksudo to /usr/bin/gksudo " && read -p " - continue ? [y/n] ? :" an
[[ $an == "y" ]] && cp -i -v -P gksudo /usr/bin/gksudo || echo "===========> skipping <============";

unset gkf
unset l

mkdir /usr/lib/libgksu
cp gksu-run-helper /usr/lib/libgksu/gksu-run-helper
cp libgksu2.so.0 /usr/lib/libgksu2.so.0
mkdir /usr/share/libgksu && mkdir /usr/share/libgksu/debian
cp gconf-defaults.libgksu-su /usr/share/libgksu/debian/gconf-defaults.libgksu-su 
cp gconf-defaults.libgksu-sudo /usr/share/libgksu/debian/gconf-defaults.libgksu-sudo
cp gksu.schemas /usr/share/gconf/schemas/gksu.schemas
cp libgksu2.so.0.0.2 /usr/lib/libgksu2.so.0.0.2
