#!/bin/sh
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
exec tclsh8.5 "$0" ${1+"$@"}

package require marsgui

source isearch.tcl

#-------------------------------------------------------------------
# Text Editor widget

::marsgui::messageline .msgline
::marsgui::texteditor .editor            \
    -borderwidth    1                    \
    -relief         sunken               \
    -yscrollcommand [list .yscroll set]

ttk::scrollbar .yscroll \
    -command [list .editor yview]

grid .editor  -row 0 -column 0 -sticky nsew -padx 1 -pady 1
grid .yscroll -row 0 -column 1 -sticky ns -pady 1
grid .msgline -row 1 -column 0 -columnspan 2 -sticky ew

grid columnconfigure . 0 -weight 1
grid rowconfigure    . 0 -weight 1

.editor insert 1.0 {One thing was certain, that the white kitten had had
nothing to do with it: -- it was the black kitten's fault entirely. For the
white kitten had been having its face washed by the old cat for the last
quarter of an hour (and bearing it pretty well, considering); so you see
that it couldn't have had any hand in the mischief.

The way Dinah washed her children's faces was this: first she held the poor
thing down by its ear with one paw, and then with the other paw she rubbed
its face all over, the wrong way, beginning at the nose: and just now, as I
said, she was hard at work on the white kitten, which was lying quite still
and trying to purr -- no doubt feeling that it was all meant for its good.

But the black kitten had been finished with earlier in the afternoon, and
so, while Alice was sitting curled up in a corner of the great arm-chair,
half talking to herself and half asleep, the kitten had been having a grand
game of romps with the ball of worsted Alice had been trying to wind up,
and had been rolling it up and down till it had all come undone again; and
there it was, spread over the hearth-rug, all knots and tangles, with the
kitten running after its own tail in the middle.

One thing was certain, that the white kitten had had
nothing to do with it: -- it was the black kitten's fault entirely. For the
white kitten had been having its face washed by the old cat for the last
quarter of an hour (and bearing it pretty well, considering); so you see
that it couldn't have had any hand in the mischief.

The way Dinah washed her children's faces was this: first she held the poor
thing down by its ear with one paw, and then with the other paw she rubbed
its face all over, the wrong way, beginning at the nose: and just now, as I
said, she was hard at work on the white kitten, which was lying quite still
and trying to purr -- no doubt feeling that it was all meant for its good.

But the black kitten had been finished with earlier in the afternoon, and
so, while Alice was sitting curled up in a corner of the great arm-chair,
half talking to herself and half asleep, the kitten had been having a grand
game of romps with the ball of worsted Alice had been trying to wind up,
and had been rolling it up and down till it had all come undone again; and
there it was, spread over the hearth-rug, all knots and tangles, with the
kitten running after its own tail in the middle.

One thing was certain, that the white kitten had had
nothing to do with it: -- it was the black kitten's fault entirely. For the
white kitten had been having its face washed by the old cat for the last
quarter of an hour (and bearing it pretty well, considering); so you see
that it couldn't have had any hand in the mischief.

The way Dinah washed her children's faces was this: first she held the poor
thing down by its ear with one paw, and then with the other paw she rubbed
its face all over, the wrong way, beginning at the nose: and just now, as I
said, she was hard at work on the white kitten, which was lying quite still
and trying to purr -- no doubt feeling that it was all meant for its good.

But the black kitten had been finished with earlier in the afternoon, and
so, while Alice was sitting curled up in a corner of the great arm-chair,
half talking to herself and half asleep, the kitten had been having a grand
game of romps with the ball of worsted Alice had been trying to wind up,
and had been rolling it up and down till it had all come undone again; and
there it was, spread over the hearth-rug, all knots and tangles, with the
kitten running after its own tail in the middle.
}

.editor yview moveto 0
.editor mark set insert 1.0


::marsgui::isearch enable .editor
::marsgui::isearch logger .editor [list .msgline puts]

::marsgui::debugger new