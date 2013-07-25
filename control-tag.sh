CONTROL=$1
TAG=$2
MISSING=$(grep -z -Po "control type=\"$CONTROL\".*\n(\s*(<[a-z]|</[va]).*\n)*\s*</control" 720p/* | grep -v "<$TAG[ >]" | grep "control type" | wc -l)
echo "$MISSING without tag."
grep -z -Po "control type=\"$CONTROL\".*\n(\s*(<[a-z]|</[va]).*\n)*\s*</control" 720p/* | grep "<$TAG[ >]" | sed 's|^\s*||' | sort | uniq -c

