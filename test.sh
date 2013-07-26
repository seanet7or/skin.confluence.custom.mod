source "bashlib.sh"

	R="s|(control type=\"button\"[^#]*#"
	R+="(\s*<(?!font)[a-z][^#]*#)*"
	R+="\s*<font)>font13_title<"
	R+="|\1>font13<|g"
	XMLS=$(2>/dev/null grep -l 'font13_title' 720p/*)
	perlregex $XMLS "$R"
