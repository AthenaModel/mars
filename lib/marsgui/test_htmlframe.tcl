# Prototype, code to use tkhtml3 as a form.

lappend auto_path ~/mars/lib

package require marsutil
package require marsgui

namespace import marsutil::* marsgui::*

# FIRST, create a dictionary of the fields and their values.

set fdict {
    a             JOE
    longname      "Joe Pro"
    supports      TEAM
    income        50  
}

# NEXT, create the HTML widget
htmlframe .hv -styles {
    .error {
        color:   red;
    }
    .hidden { display: none }
    .normal { 
        color:   black;
    }
}

pack .hv -fill both -expand yes

# NEXT, create a number of labels; they will represent our field widgets.

enum actors {
    JOE JOE
    BOB BOB
    WILL WILL
    DAVE DAVE
    TEAM TEAM
}

snit::integer rincome -min 0 -max 1000

textfield .hv.a
textfield .hv.longname
enumfield .hv.supports -enumtype ::actors 
rangefield .hv.income -type ::rincome

dict for {field text} $fdict {
    .hv.$field set $text
}

# NEXT, layout the fields.

set layouts(table) {
    <h3> Sample Data Entry Form</h3>
    <form>
    <table>
    <tr>
    <td><b><label for="a">Actor:</label></b></td>
    <td><input name="a" type="text" size=10></td>
    </tr>
    
    <tr id="longname">
    <td><b>Long Name:</b></td>
    <td><input name="longname" type="text" size="40"></td>
    </tr>
    
    <tr id="supports">
    <td><b>Supports:</b></td>
    <td><input name="supports" type="enum"></td>
    </tr>
    
    <tr id="income">
    <td><b>Income:</b></td>
    <td><input name="income" type="range"></td>
    </tr>
    
    </table> 
    </form>
}

set layouts(flow) {
    <form>
    <span id="a" class="normal">
    <b>Actor</b> <input name="a" type="text" size=10>,
    </span>
    
    <span id="longname" class="normal">
    <b>also known as</b> <input name="longname" type="text" size="20">,
    </span>
    
    <span id="supports" class="normal">
    <b>supports</b> <input name="supports" type="enum">
    </span>
    
    <span id="income" class="normal">
    <b>and has an income of</b> <input name="income" type="range"> <b>$/week.</b>
    </span>
    </form>

}

bind all <F1> [list debugger new]


if {[llength $argv] > 0} {
    set layout [lindex $argv 0]
} else {
    set layout table
}

.hv layout $layouts($layout)
