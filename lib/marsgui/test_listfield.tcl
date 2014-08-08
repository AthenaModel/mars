lappend auto_path ~/mars/lib
package require marsutil
package require marsgui

namespace import ::marsutil::*
namespace import ::marsgui::*

set choices {
    A "Take over Middle Earth."
    B "Eat lentils, cabbage, prunes, and anti-oxidants."
    C "Visit all European capitals within two weeks."
    D "Sell five-hundred jalopies to okies from Muscogee."
    E "Take control of Kabul and its environs."
    F "Read the New York City phone book from cover to cover."
    G "Grow alligators in the Podunk, New Jersey sewers."
    H "Throw a dead chupacabra in the local well."
    I "Persuade Jane Austen to come back as a zombie."
    J "Instigate a popular revolution in Tahiti."
    K "Declare Barstow, California the Dirt Flag Republic."
    L "Secede from the Union."
    M "Grow manzanita in the tall grass."
}

proc ChangeCmd {values} {
    puts "ChangeCmd: <$values>"
}

listfield .listf \
    -itemdict  $choices  \
    -changecmd ChangeCmd \
    -height    15 \
    -width     50

pack .listf -fill both

debugger new

