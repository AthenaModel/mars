#-----------------------------------------------------------------------
# TITLE:
#    order_set.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsutil(n): Order Set Class
#
#    order_set(n) is a base class whose instances collect order 
#    order classes into sets for introspection purposes.  The collection
#    provides the following services:
#
#    * A "define" command for defining order classes in the set.
#    * Queries to get the names of the defined orders.
#    * Queries to get an order class given the order name.
#    * A factor to get an order instance for a given class.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# order_set class

oo::class create ::marsutil::order_set {
    #-------------------------------------------------------------------
    # Instance Variables

    # Superclass for defined order classes.
    variable baseClass

    # List of variable names to declare automatically in defined order
    # classes.
    variable autoVars

    # orders - dictionary, order name to order class
    variable orders
    
    #-------------------------------------------------------------------
    # Constructor/Destructor

    # constructor ?baseClass_? ?autoVars_?
    #
    # baseClass_    - The default base class for defined orders.
    #                 Defaults to marsutil::order.
    # autoVars_     - A list of variable names to automatically
    #                 declare in defined orders.  Empty by default.
    #
    # Creates a new order_set instance for collecting a library's or
    # application's orders.
    
    constructor {{baseClass_ ::marsutil::order} {autoVars_ {}}} {
        set baseClass $baseClass_
        set autoVars  $autoVars_
        set orders [dict create]
    }

    destructor {
        my reset
    }

    #-------------------------------------------------------------------
    # Order Definition

    # define order body
    #
    # order   - The order's name, e.g., MY:ORDER
    # body    - The ordex subclass definition script.
    #
    # Defines the new order class.  The full class name is
    # ${self}::${order}.  Also, defines the "name" meta for the class,
    # and provides empty defaults for the "from" and "parmtags" metas.

    method define {order body} {
        # FIRST, get the class name.
        set cls [self]::$order

        # NEXT, create and configure the class itself.
        oo::class create $cls
        oo::define $cls superclass $baseClass
        oo::define $cls meta name       $order
        oo::define $cls meta title      $order
        oo::define $cls meta sendstates ""
        oo::define $cls meta form       ""
        oo::define $cls meta parmtags   ""
        oo::define $cls meta monitor    yes
        oo::define $cls variable parms

        foreach varname $autoVars {
            oo::define $cls variable $varname
        } 
        
        oo::define $cls $body

        # NEXT, create the form.
        #
        # TODO: This is very preliminary.  We may want to doctor the
        # form in some way; and for mismatch testing, some orders might
        # have context fields that are distinct from the actual parms.
        if {[$cls form] ne ""} {
            # FIRST, define the form.
            dynaform define $cls [$cls form]

            # NEXT, Check for mismatch errors.
            set parms  [lsort [my GetParms $cls]]
            set fields [lsort [dynaform fields $cls]]

            if {$fields ne $parms} {
                throw {ORDER_SET MISMATCH} [::kiteutils::outdent "
                Order $order has a mismatch between its parameter list
                and its dynaform.

                parms  = <$parms>
                fields = <$fields>
                "]
            }
        }

        # NEXT, remember that we've successfully defined this order.
        dict set orders $order $cls
    }

    # GetParms cls
    #
    # cls   - An order class
    #
    # Extracts parm names from meta parmlist or defaults
    # NOTE: defaults is deprecated.

    method GetParms {cls} {
        set result ""

        try {
            foreach spec [$cls parmlist] {
                lassign $spec parm value
                lappend result $parm
            }

            return $result
        } on error {} {
            return [dict keys [$cls defaults]]
        }
    }

    # reset
    #
    # Destroys all orders and clears the saved data.  Note that
    # dynaforms aren't destroyed because there's no way to do it.

    method reset {} {
        dict for {name cls} $orders {
            $cls destroy
        }

        set orders [dict create]
    }

    #-------------------------------------------------------------------
    # Queries

    # names
    #
    # Returns the list of order names.

    method names {} {
        return [dict keys $orders]
    }

    # exists order
    #
    # order     An order order
    #
    # Returns 1 if there's an order with this name, and 0 otherwise

    method exists {order} {
        return [dict exists $orders $order]
    }

    # validate order
    #
    # order  - Possibly, the name of an order.
    #
    # Throws INVALID if the order name is unknown.  Returns the 
    # canonicalized order name.

    method validate {order} {
        set order [string toupper $order]

        if {![my exists $order]} {
            throw INVALID  \
                "Order is undefined: \"$order\""
        }

        return $order
    }

    # class order
    #
    # order   - The name of an order
    #
    # Returns the full order class name for the order.

    method class {order} {
        dict get $orders $order
    }

    # parms order
    #
    # Return the parm names for the order.

    method parms {order} {
        return [my GetParms [my class $order]]
    }

    # title order
    #
    # order - The name of an order.
    #
    # Returns the order's title.

    method title {order} {
        [my class $order] title
    }
}
