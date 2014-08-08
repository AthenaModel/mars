package require marsgui
namespace import ::marsgui::*

debugger new

proc returncmd {text} {
    puts "-returncmd <$text>"
}

proc keycmd {char keysym} {
    if {![string is print -strict $char]} {
        set char "---"
    }
    puts "-key <$char> <$keysym>"
}

proc changecmd {text} {
    puts "-changecmd <$text>"
}

ttk::button .set \
    -text "Set!" \
    -command [list .ce set "Howdy!"]

ttk::button .clear \
    -text "Clear!" \
    -command [list .ce clear]

commandentry .ce \
    -clearbtn 1 \
    -keycmd keycmd \
    -returncmd returncmd \
    -changecmd changecmd

pack .set -side left
pack .clear -side right
pack .ce -padx 5 -pady 5



