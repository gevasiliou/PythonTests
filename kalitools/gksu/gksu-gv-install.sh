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


#Bellow files belong to package libgksu and are required libraries for gksu to run correctly.
[ ! -d "/usr/lib/libgksu" ] && mkdir /usr/lib/libgksu
[ ! -d "/usr/share/libgksu" ] && mkdir /usr/share/libgksu
[ ! -d "/usr/share/libgksu/debian" ] && mkdir /usr/share/libgksu/debian

cp gksu-run-helper /usr/lib/libgksu/gksu-run-helper
cp libgksu2.so.0 /usr/lib/libgksu2.so.0
cp gconf-defaults.libgksu-su /usr/share/libgksu/debian/gconf-defaults.libgksu-su 
cp gconf-defaults.libgksu-sudo /usr/share/libgksu/debian/gconf-defaults.libgksu-sudo
cp gksu.schemas /usr/share/gconf/schemas/gksu.schemas
cp libgksu2.so.0.0.2 /usr/lib/libgksu2.so.0.0.2
cp libgnome-keyring.so.0 /usr/lib/x86_64-linux-gnu/libgnome-keyring.so.0
cp libgconf-2.so.4 /usr/lib/x86_64-linux-gnu/libgconf-2.so.4
cp gksu-properties.ui /usr/share/libgksu/gksu-properties.ui
cp gksu-properties /usr/bin/gksu-properties 
cp README.Debian /usr/share/doc/libgksu2-0/README.Debian
cp gksu.png /usr/share/pixmaps/gksu.png
cp gksu-properties.1.gz /usr/share/man/man1/gksu-properties.1.gz

