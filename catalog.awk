# POSIX awk JSON reader for public-plugin catalog migration. No extra runtime.
# Preserve every unrelated value; validate the complete input before emitting it.
function bad() { failed = 1; exit 1 }
function ws() { while (substr(data, pos, 1) ~ /^[ \t\r\n]$/) pos++ }
function take(c) { ws(); if (substr(data, pos++, 1) != c) bad() }
function str(    start,c,e,h,n,i) {
    start = pos; take("\""); decoded = ""
    while (pos <= length(data)) {
        c = substr(data, pos++, 1)
        if (c == "\"") return substr(data, start, pos-start)
        if (c ~ /[[:cntrl:]]/) bad()
        if (c == "\\") {
            e = substr(data, pos++, 1)
            if (e == "u") {
                h = substr(data, pos, 4)
                if (length(h) != 4 || h ~ /[^0-9a-fA-F]/) bad()
                pos += 4; n = 0
                for (i=1; i<=4; i++) n = n*16 + index("0123456789abcdef", tolower(substr(h,i,1)))-1
                decoded = decoded (n > 0 && n < 128 ? sprintf("%c", n) : "?")
            } else {
                if (e == "" || index("\"\\/bfnrt", e) == 0) bad()
                decoded = decoded (index("\"\\/", e) > 0 ? e : "?")
            }
        } else decoded = decoded c
    }
    bad()
}
function val(context,depth,    c,start,token) {
    if (depth > 64) bad()
    ws(); c = substr(data,pos,1); start = pos
    if (c == "{") return obj(context,depth)
    if (c == "[") return arr(context,depth)
    if (c == "\"") return str()
    if (match(substr(data,pos), /^(true|false|null|-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?)/)) {
        token = substr(data,pos,RLENGTH); pos += RLENGTH; return token
    }
    bad()
}
function obj(context,depth,    start,key,keyname,item,out,sep,name_seen,plugins_seen) {
    ws(); start = pos; take("{"); out = "{"; sep = ""; ws()
    if (substr(data,pos,1) == "}") { pos++; return "{}" }
    while (1) {
        ws(); key = str(); keyname = decoded; take(":"); ws()
        if (keyname == "name" && (context == "root" || context == "plugin")) {
            if (name_seen++ || substr(data,pos,1) != "\"") bad()
            item = str()
            if (context == "root") catalog_name = decoded
            else entry_name = decoded
        } else if (action == "location" && context == "root" && keyname == "pluglayer") {
            item = obj("location",depth+1)
        } else if (context == "location" && keyname == "installLocation") {
            if (substr(data,pos,1) != "\"") bad()
            item = str(); location = decoded
        } else if (context == "root" && keyname == "version" && action == "version") {
            if (substr(data,pos,1) != "\"") bad()
            item = str(); manifest_version = decoded
        } else if (context == "plugin" && keyname == "source") {
            if (substr(data,pos,1) == "\"") { item = str(); entry_path = decoded }
            else item = obj("source",depth+1)
        } else if (context == "source" && keyname == "path") {
            if (substr(data,pos,1) != "\"") bad()
            item = str(); entry_path = decoded
        } else if (context == "plugin" && keyname == "version" && action == "canonical") {
            item = val("",depth+1); item = "\"" version "\""
        } else if (context == "root" && keyname == "plugins") {
            if (plugins_seen++ || substr(data,pos,1) != "[") bad()
            have_plugins = 1; item = arr("plugins",depth+1)
        } else item = val("",depth+1)
        out = out sep key ":" item; sep = ","; ws()
        if (substr(data,pos,1) == "}") { pos++; break }
        take(",")
    }
    return context == "root" || (context == "plugin" && action == "canonical") ? out "}" : substr(data,start,pos-start)
}
function arr(context,depth,    start,item,out,sep) {
    ws(); start = pos; take("["); out = "["; sep = ""; ws()
    if (substr(data,pos,1) == "]") { pos++; return "[]" }
    while (1) {
        if (context == "plugins") entry_name = ""
        ws()
        if (context == "plugins" && substr(data,pos,1) != "{") bad()
        item = val(context == "plugins" ? "plugin" : "",depth+1)
        if (context == "plugins") {
            count++
            if (entry_name == plugin) matched++
        }
        if (context != "plugins" || entry_name != plugin || action == "canonical") { out = out sep item; sep = "," }
        ws(); if (substr(data,pos,1) == "]") { pos++; break }; take(",")
    }
    return context == "plugins" ? out "]" : substr(data,start,pos-start)
}
{ data = data $0 "\n"; if (length(data) > 1048576) bad() }
END {
    if (failed) exit 1
    pos = 1; ws(); if (substr(data,pos,1) != "{") bad()
    result = obj("root",0); ws()
    if (pos <= length(data)) bad()
    if (action == "location") { print location; exit }
    if (action == "version") { if (manifest_version == "") bad(); print manifest_version; exit }
    if (!have_plugins || catalog_name == "") bad()
    if (action == "canonical") {
        if (catalog_name != "pluglayer" || count != 1 || matched != 1 || entry_path != expected_path) bad()
        print result; exit
    }
    if (action == "inspect") printf "%s %d %d\n", catalog_name, count, matched
    else if (matched) print result
    else printf "%s", data
}
