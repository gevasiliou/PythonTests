#curl --silent 'http://www.promitheies.gr/mailHistory/showHtml?uuid=87a7d35aa0544df7b7a595efcdddd8f8' |egrep '[Σσ]υσσω|ΣΥΣΣΩ|ΜΠΑΤ|[Μμ]πατ|UPS' |perl -pe 's/>/>\n/g' |egrep -v '<u.*>|</a>' |sed 's/<a href="//g' |perl -pe 's/" style=.*>\n/ /g'
echo "Tender Info Engine"
[[ -z $1 ]] && echo "pass me a valid tender info url" && exit 1
u="$1"
echo "URL to search tenders:  $1"
keys="[Σσ]υσσω|ΣΥΣΣΩ|ΜΠΑΤ|[Μμ]πατ|[Uu][Pp][Ss]|[φΦ]ορτ|[αΑ]νορ|[Σσ]υστ[^ηήΗ]"
read -e -p "Enter Regex Search Pattern (or press enter to use default keys):  " -i "$keys" keys
echo "keys to search : $keys"

echo "Starting"
curl --silent "$u" |egrep "$keys" |perl -pe 's/>/>\n/g' |egrep -v '<u.*>|</a>' |sed 's/<a href="//g' |perl -pe 's/" style=.*>\n/\n/g'
echo "Finished"
exit 0
