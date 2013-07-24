source "bashlib.sh"

	R="s|(control type=\"label\"[^#]*#"
	R+="(\s*<(?!font)[a-z][^#]*#)*"
	R+="\s*<font)>font12_title<"
	R+="|\1>font13<|g"
	XMLS=$(2>/dev/null grep -l 'font12_title' 720p/*)
	perlregex $XMLS "$R"
