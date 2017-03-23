shopt -s globstar
declare -A filelist=()
for file1 in **; do 
#printf '%s\n' "$file1"
filelist[$file1]=1
done
printf 'List: %s\n' "${!filelist[@]}"

while read -r exclude; do
  for file2 in $exclude; do
    echo "to unset: $file2"
    unset filelist[$file2]
  done
done < .testignore

printf 'Final List: %s\n' "${!filelist[@]}"
