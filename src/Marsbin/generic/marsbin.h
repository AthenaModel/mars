/***********************************************************************
 *
 * TITLE:
 *	marsbin.h
 *
 * AUTHOR:
 *	Will Duquette
 *
 * DESCRIPTION:
 *	Mars: Marsbin extension header file
 *
 ***********************************************************************/

#ifndef _MARSBIN
#define _MARSBIN

#include <stdlib.h>
#include <tcl.h>

 typedef struct EllipsoidData {
    double a;     /* - Major Axis. */         
    double b;     /* - Minor axis value. */
    double e2;    /* - Eccentricity squared. */
    double ee2;   /* - Eccentricity squared prime. */
    double flat;  /* - Earth Flattening. */
} EllipsoidData;

/*
 * Windows needs to know which symbols to export.
 */

#ifdef BUILD_Marsbin
#undef TCL_STORAGE_CLASS
#define TCL_STORAGE_CLASS DLLEXPORT
#endif /* BUILD_Marsbin */

EXTERN int Marsbin_Init(Tcl_Interp* interp);

#endif /* _MARSBIN */




