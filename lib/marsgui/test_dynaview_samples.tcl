# Sample dynaforms

enum actor {
    JOE   "Joe Provenzano"
    BOB   "Bob Chamberlain"
    DAVE  "Dave Hanks"
    BRIAN "Brian Kahovec"
}

proc actorData {idict a} {
    set adata {
        JOE   { longname "Joe Provenzano"  income 100 }
        BOB   { longname "Bob Chamberlain" income 200 }
        DAVE  { longname "Dave Hanks"      income 300 }
        BRIAN { longname "Brian Kahovec"   income 400 }
    }

    if {[dict exists $adata $a]} {
        return [dict get $adata $a] 
    }

    return {}
}

enum nbhood {
    LC    "La Crescenta"
    LCF   "La Canada-Flintridge"
    PAS   "Pasadena"
    GLEN  "Glendale"
    SC    "Santa Clarita"
    SM    "San Marino"
}

enum frcgroup {
    BLUE BLUE
    BRIT BRIT
    OPFOR OPFOR
}

proc ownedgroup {a} {
    puts "ownedgroup <$a>"
    array set groups {
        JOE {J1 J2}
        BOB {B1 B2}
        DAVE {D1 D2}
        BRIAN { }
    }

    if {[info exists groups($a)]} {
        return $groups($a)
    }

    return ""
}

dynaform fieldtype alias actor   enum -listcmd {::actor names}

dynaform define cmderr {
    rcc "Actor:" -for a
    enum a -listcmd {::nonesuch names}
}

dynaform define ACTOR {
    rcc "Actor:" -for a
    actor a -loadcmd {::actorData}
    
    rcc "Long Name:" -for longname
    text longname -width 20

    rcc "Color:" -for color
    color color -context yes

    rcc "Income:" -for income
    text income -width 12
}

dynaform define AFTER1 {
    rcc "Time spec:" -for t1
    text t1 -width 12
}

dynaform define AFTER2 {
    layout ribbon

    label "After week" -for t1
    text t1 -tip "Time spec" -width 12
    label "this condition is met"
}

dynaform define AFTER3 {
    layout 2column
    text t1 -tip "Time spec" -width 12
}

dynaform define ASSIGN1 {
    rcc "Actor:" -for a
    enum a -listcmd {::actor names}
    label "assigns"

    rcc "Owned Group:" -for g
    enum g -listcmd {::ownedgroup $a}
    label "with"

    rcc "Personnel:" -for int1
    text int1 -width 8
}

dynaform define ASSIGN1A {
    rcc "Actor:" -for a
    enum a -listcmd {::actor names}
    label "assigns"

    rcc "Owned Group:" -for g
    enum g -listcmd {::ownedgroup $a}
    label "with"
    enum f -listcmd {::ownedgroup $a}
    label "exactly"
    c "test text"

    rcc "Personnel:" -for int1
    text int1 -width 8
    label "Test label"
}

dynaform define ASSIGN2 {
    layout ribbon

    enum a -tip "Actor" -listcmd {::actor names}
    enum g -tip "Owned Group" -listcmd {::ownedgroup $a}
    text int1 -tip "Personnel" -width 12
}

dynaform define ASSIGN3 {
    layout 2column

    enum a -tip "Actor" -listcmd {::actor names}
    enum g -tip "Owned Group" -listcmd {::ownedgroup $a}
    text int1 -tip "Personnel" -width 12
}


dynaform define CASH1 {
    rcc "Actor:" -for a
    enum     a   -listcmd {::actor names} 
    
    rcc "Comparison:" -for op1
    enumlong op1 -dictcmd {ecomparator deflist} -defvalue GT

    rcc "Value:" -for x1
    text x1 -defvalue 0.0
}

dynaform define CASH2 {
    layout ribbon

    label "The cash reserve"
    label "of actor" -for a
    enum     a   -tip "Actor"      -listcmd {::actor names} 
    label "is"
    enumlong op1 -tip "Comparison" -dictcmd {ecomparator deflist}
    label "value" -for x1
    text    x1  -tip "Value" 
}

dynaform define CASH3 {
    layout 2column
    enum     a   -tip "Actor"      -listcmd {::actor names} 
    enumlong op1 -tip "Comparison" -dictcmd {ecomparator deflist} 
    text    x1  -tip "Value" 
}

dynaform define CONTROL1 {
    rcc "Actor:" -for a
    enum a -listcmd {::actor names}

    rcc "Region:" -for text1
    selector text1 {
        case ALL  "All Neighborhoods" {}
        case SOME "These Neighborhoods" {
            rcc "Neighborhoods:" -for list1
            enumlonglist list1 \
                -width 30 \
                -stripe no \
                -showkeys no \
                -height 10 \
                -dictcmd {::nbhood deflist}
        }
    }
}

dynaform define CONTROL1B {
    rcc "Actor:" -for a
    enum a -listcmd {::actor names}

    rcc "Region:" -for text1
    selector text1 {
        case ALL  "All Neighborhoods" {}
        case SOME "These Neighborhoods" {
            rcc "Neighborhoods:" -for list1
            # Use a enumlist instead of a enumlonglist
            enumlist list1 \
                -width   10 \
                -stripe  no \
                -height  6  \
                -listcmd {::nbhood names}
        }
    }
}
dynaform define CONTROL2 {
    layout ribbon

    label "Actor" -for a
    enum a -tip "Actor" -listcmd {::actor names}

    label "is in control of" -for text1
    selector text1 -tip "Region" {
        case ALL  "All" {
            label "neighborhoods."
        }
        case SOME "These" {
            label "neighborhoods:" -for list1 
            enumlonglist list1 -tip "Neighborhoods" \
                -width 30 \
                -dictcmd {::nbhood deflist}
        }
    }
}

dynaform define CONTROL3 {
    layout 2column
    enum a -tip "Actor" -listcmd {::actor names}

    selector text1 -tip "Region" {
        case ALL  "All Neighborhoods" {}
        case SOME "These Neighborhoods" {
            enumlonglist list1 -tip "Neighborhoods" \
                -width 30 \
                -dictcmd {::nbhood deflist}
        }
    }
}

dynaform define CONTROL4 {
    layout ncolumn

    rcc "Actor:" -for a
    enum a -listcmd {::actor names}
    label "is in control of"

    rcc "Region:" -for text1
    selector text1 {
        case ALL  "All neighborhoods" { }
        case SOME "These neighborhoods" {
            rc "" -span 2
            enumlonglist list1 \
                -width 30 \
                -dictcmd {::nbhood deflist}
        }
    }
}

dynaform define NBHOOD {
    rcc "Neighborhood:" -for n
    enum n -listcmd {::nbhood names}

    rcc "Long Name:"
    disp long_name -textcmd {$entity_ longname $n}
}

dynaform define testform1 {
    rcc "Entity ID:" -for entity_id
    text entity_id -context yes

    rcc "Entity Type:" -for entity_type
    selector entity_type {
        case HUMAN "Human Being" {
            rcc "Name:" -for name
            text name -tip "Name" -width 20

            rcc "Home Town:" -for town
            enumlong town -dict {
                la "Los Angeles"
                nyc "New York City"
                no "New Orleans"
            }
            
            label "Home World:" -for world
            enumlong world -dict {
                earth "Earth"
                mars  "Mars"
                venus "Venus"
            }
        }

        case ROBOT "Mechanical Being" {
            rcc "Brand Name:" -for brand
            enumlong brand -dict {
                usr "US Robots"
                ibm "IBM"
                hp  "Hewlett-Packard"
            }

            rcc "Robot Type:" -for prod_type
            selector prod_type {
                case PROTO "Prototype" {
                    rcc "Unit Name:" -for name
                    text name -width 20
                }

                case PROD "Production" {
                    rcc "Model Name:" -for model
                    text model -width 10
                    label "Serial Number:" -for serial
                    text serial -width 10
                }
            }
        }
    }
}

dynaform define testform2 {
    layout 2column

    selector entity_type -tip "Entity Type" {
        case HUMAN "Human Being" {
            text name -tip "Name" -width 20

            enumlong town -tip "Home Town" -dict {
                la "Los Angeles"
                nyc "New York City"
                no "New Orleans"
            }
            
            enumlong world -tip "Home World" -dict {
                earth "Earth"
                mars  "Mars"
                venus "Venus"
            }
        }

        case ROBOT "Mechanical Being" {
            enumlong brand -tip "Brand Name" -dict {
                usr "US Robots"
                ibm "IBM"
                hp  "Hewlett-Packard"
            }

            selector prod_type -tip "Robot Type" {
                case PROTO "Prototype" {
                    text name -tip "Unit Name" -width 20
                }

                case PROD "Production" {
                    text model  -tip "Model Name" -width 10
                    text serial -tip "Serial Number" -width 10
                }
            }
        }
    }
}

dynaform define attrit {
    rcc "Personnel:" -for personnel
    text personnel -width 8

    rcc "Involved Group:" -for g1
    enum g1 -listcmd {::frcgroup names}

    when {$g1 ne ""} {
        rcc "Involved Group:" -for g2
        enum g2 -listcmd {::frcgroup names}
    }
}

dynaform define MULTI {
    rcc "IDs" -for ids
    multi ids -table foo -key id

    rcc "Value" -for value
    text value -width 12
}

dynaform fieldtype alias key key -db ::rdb
dynaform define KEY {
    key id -table foo -keys bar
}

dynaform fieldtype alias sat range -datatype ::qsat -showsymbols yes

dynaform define SAT {
    rcc "Satisfaction:" -for sat0
    sat sat0 -resetvalue -20.0 -showreset yes
}


# Test of selector -listcmd


proc selectorValues {a} {
    if {$a eq "JOE"} {
        return [list A B C D E]
    } elseif {$a ne ""} {
        return [list A B C]
    } else {
        return ""
    }
}

dynaform define selectorTest {
    rcc "Actor:" -for a
    enum a -listcmd {::actor names}

    rcc "Actions:" -for actions
    selector actions -listcmd {::selectorValues $a} {
        case A "Action A" { rcc "Parm for:" ; label "Action A" }
        case B "Action B" { rcc "Parm for:" ; label "Action B" }
        case C "Action C" { rcc "Parm for:" ; label "Action C" }
        case D "Action D" { rcc "Parm for:" ; label "Action D" }
        case E "Action E" { rcc "Parm for:" ; label "Action E" }
    }

}


