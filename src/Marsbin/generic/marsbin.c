/***********************************************************************
 *
 * TITLE:
 *	marsbin.c
 *
 * AUTHOR:
 *	Will Duquette
 *
 * DESCRIPTION:
 *	Mars: Marsbin extension
 *
 ***********************************************************************/

#include <tcl.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>

#ifndef WIN32
#define MARS_NET_API
#endif

#ifdef MARS_NET_API
#include <unistd.h>
#include <sys/utsname.h>
#include <sys/ioctl.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <net/if.h>
#endif


#include <errno.h>

#include <geotrans/geotrans.h>
//#include <geostars/geoStars.h>
#include <geotiff/xtiffio.h>
#include <geotiff/geotiffio.h>
#include <geotiff/geotiff.h>

#include "marsbin.h"

/*
 * Constants
 */

#define PRECISION_MIN     0
#define PRECISION_DEFAULT 5
#define PRECISION_MAX     5
#define LAT_MIN          -90.0
#define LAT_MAX           90.0
#define LON_MIN         -180.0
#define LON_MAX          360.0

const double pi            = M_PI;
const double radians       = 0.017453292519943295; /* pi/180.0 */
const double earthDiameter = 12742.0;
const double earthRadius   = 6371.0; /* earthDiameter/2.0 */

/* 
 * GeoTIFF constants
 * This will need to be expanded if and when
 * other projections are supported
 */
#define GT_MODEL_TYPE         1024
#define MODEL_TYPE_PROJECTED  1
#define MODEL_TYPE_GEOGRAPHIC 2
#define MODEL_TYPE_GEOCENTRIC 3

#define MODEL_PIXEL_SCALE_TAG 33550
#define MODEL_TIEPOINT_TAG    33922

/*
 * Structure Definitions
 */

/* Used to dispatch subcommands. */
typedef struct SubcommandVector {
    char* name;                /* Subcommand name */
    Tcl_ObjCmdProc* proc;      /* Implementing proc */
} SubcommandVector;

/* Ellipsoid Data */

typedef struct Ellipsoid {
    char*  code;
    double semi_major_axis;
    double inv_flattening;
} Ellipsoid;

/* A coordinate pair */
typedef struct Point {
    double x;
    double y;
} Point;

/* A bounding box */
typedef struct Bbox {
    double xmin;
    double ymin;
    double xmax;
    double ymax;
} Bbox;

/* A list of points */
typedef struct Points {
    int maxSize;
    Point* pts;
    int size;
} Points;

/* latlong(n) data */

typedef struct LatlongInfo {
    int spheroid;              /* Spheroid for coordinate conversions. */
    double poleLat;            /* Latitude and longitude for pole/radius. */
    double poleLon;
    Points* pointsBuffer;      /* Points cache */
} LatlongInfo;

/* geotiff(n) data */

typedef struct GeotiffInfo {
    TIFF*  tiff;
    GTIF*  gtif;
} GeotiffInfo;

/*
 * Static Function Prototypes
 */

/* Command Prototypes */
static int marsutil_hexdumpCmd      (ClientData, Tcl_Interp*, int, 
                                 Tcl_Obj* CONST argv[]);

/* marsutil(n) command prototypes */

#ifdef MARS_NET_API
static int marsutil_getnetifCmd     (ClientData, Tcl_Interp*, int, 
                                     Tcl_Obj* CONST argv[]);
#endif /* MARS_NET_API */

static int marsutil_gettimeofdayCmd (ClientData, Tcl_Interp*, int, 
                                 Tcl_Obj* CONST argv[]);

static int marsutil_letCmd          (ClientData, Tcl_Interp*, int, 
                                 Tcl_Obj* CONST argv[]);

static int marsutil_bboxCmd         (ClientData, Tcl_Interp*, int, 
                                  Tcl_Obj* CONST argv[]);

static int marsutil_ccwCmd          (ClientData, Tcl_Interp*, int, 
                                  Tcl_Obj* CONST argv[]);

static int marsutil_intersectCmd    (ClientData, Tcl_Interp*, int, 
                                  Tcl_Obj* CONST argv[]);

static int marsutil_ptinpolyCmd     (ClientData, Tcl_Interp*, int, 
                                  Tcl_Obj* CONST argv[]);

static int marsutil_latlongCmd      (ClientData, Tcl_Interp*, int, 
                                 Tcl_Obj* CONST argv[]);

static int marsutil_geotiffCmd     (ClientData, Tcl_Interp*, int,
                                 Tcl_Obj* CONST argv[]);

/* latlong Subcommands */
static int latlong_spheroid     (ClientData, Tcl_Interp*, int, 
                                 Tcl_Obj* CONST objv[]);
static int latlong_tomgrs       (ClientData, Tcl_Interp*, int, 
                                 Tcl_Obj* CONST objv[]);
static int latlong_frommgrs     (ClientData, Tcl_Interp*, int, 
                                 Tcl_Obj* CONST objv[]);
static int latlong_dist         (ClientData, Tcl_Interp*, int, 
                                 Tcl_Obj* CONST objv[]);
static int latlong_dist4        (ClientData, Tcl_Interp*, int, 
                                 Tcl_Obj* CONST objv[]);
static int latlong_pole         (ClientData, Tcl_Interp*, int, 
                                 Tcl_Obj* CONST objv[]);
static int latlong_radius       (ClientData, Tcl_Interp*, int, 
                                 Tcl_Obj* CONST objv[]);
static int latlong_validate     (ClientData, Tcl_Interp*, int, 
                                 Tcl_Obj* CONST objv[]);
static int latlong_area         (ClientData, Tcl_Interp*, int, 
                                 Tcl_Obj* CONST objv[]);
/* GeoTIFF subcommands */
static int geotiff_read         (ClientData, Tcl_Interp*, int,
                                 Tcl_Obj* CONST objv[]);

/* utility functions */

static LatlongInfo* newLatlongInfo    (void);
static void         deleteLatlongInfo (LatlongInfo*);
static Points*      newPoints         (void);
static void         deletePoints      (Points*);

static GeotiffInfo* newGeotiffInfo    (void);
static void         deleteGeotiffInfo (GeotiffInfo*);
static void         closeGeotiff      (GeotiffInfo*);

static double spheredist  (double, double, double, double);
static void   bbox        (Points*, Bbox*);
static int    ccw         (Point*, Point*, Point*);
static int    intersect   (Point*, Point*, Point*, Point*);
static int    ptinpoly    (Points*, Point*, Bbox*);
static double dmin        (double a, double b);
static double dmax        (double a, double b);
static double ll_area     (Points*);

static int    getBbox       (Tcl_Interp*, Tcl_Obj*, Bbox*);
static int    getPoint      (Tcl_Interp*, Tcl_Obj*, Point*);
static int    getPoints     (Tcl_Interp*, Tcl_Obj*, int minSize, Points*);
static int    getLatLong    (Tcl_Interp*, Tcl_Obj*, double*, double*);
static int    validateLatLong (Tcl_Interp*, double, double);

/*
 * Static Variables
 */

/* latlong Dispatch table */

static SubcommandVector latlongTable [] = {
    {"area",     latlong_area},
    {"dist",     latlong_dist},
    {"dist4",    latlong_dist4},
    {"pole",     latlong_pole},
    {"radius",   latlong_radius},
    {"validate", latlong_validate},
    {"spheroid", latlong_spheroid},
    {"tomgrs",   latlong_tomgrs},
    {"frommgrs", latlong_frommgrs},
    {NULL}
};

/* geotiff Dispatch table */

static SubcommandVector geotiffTable[] = {
    {"read",  geotiff_read},
    {NULL}
};

/* Ellipsoids */

static Ellipsoid ellipsoidTable [] = {
    {"WE", 6378137.0  , 298.257223563}, // WGS 84
    {"A1", 6377563.396, 299.3249646  }, // Airy 1830
    {"A2", 6377340.189, 299.3249646  }, // Modified Airy 
    {"AN", 6378160.0  , 298.25       }, // Australian National
    {"BN", 6377483.865, 299.1528128  }, // Bessel 1841 (Namibia) 
    {"BR", 6377397.155, 299.1528128  }, // Bessel 1841 
    {"CC", 6378206.4  , 294.9786982  }, // Clarke 1866 
    {"CD", 6378249.145, 293.465      }, // Clarke 1880
    {"E1", 6377276.345, 300.8017     }, // Everest (India 1830) 
    {"E2", 6377298.556, 300.8017     }, // Everest (Sabah Sarawak)  
    {"E3", 6377301.243, 300.8017     }, // Everest (India 1956) 
    {"E4", 6377295.664, 300.8017     }, // Everest (Malaysia 1969) 
    {"E5", 6377304.063, 300.8017     }, // Everest (Malay. & Sing)  
    {"E6", 6377309.613, 300.8017     }, // Everest (Pakistan)
    {"MF", 6378155.0  , 298.3        }, // Modified Fischer 1960 
    {"HM", 6378200.0  , 298.3        }, // Helmert 1906
    {"HO", 6378270.0  , 297.0        }, // Hough 1960 
    {"ID", 6378160.0  , 298.247      }, // Indonesian 1974 
    {"IN", 6378388.0  , 297.0        }, // International 1924 
    {"KR", 6378245.0  , 298.3        }, // Krassovsky 1940 
    {"G8", 6378137.0  , 298.257222101}, // GRS 80 
    {"SA", 6378160.0  , 298.25       }, // South American 1969 
    {"W7", 6378135.0  , 298.26       }, // WGS 72 
    {NULL}
};

/*
 * Public Function Definitions
 */

/***********************************************************************
 *
 * FUNCTION:
 *	Marsbin_Init()
 *
 * INPUTS:
 *	interp		A Tcl interpreter
 *
 * RETURNS:
 *	TCL_OK
 *
 * DESCRIPTION:
 *	Initializes the extension's Tcl commands
 */

int
Marsbin_Init(Tcl_Interp *interp)
{
    /* Provide the package */
    if (Tcl_InitStubs(interp, "8.5", 0) == NULL) {
	return TCL_ERROR;
    }
    if (Tcl_PkgRequire(interp, "Tcl", "8.5", 0) == NULL) {
	return TCL_ERROR;
    }
    if (Tcl_PkgProvide(interp, PACKAGE_NAME, PACKAGE_VERSION) != TCL_OK) {
	return TCL_ERROR;
    }

    /* Define the commands. */
    Tcl_CreateObjCommand(interp, "::marsutil::hexdump", 
                         marsutil_hexdumpCmd, NULL, NULL);
#ifdef MARS_NET_API
    Tcl_CreateObjCommand(interp, "::marsutil::getnetif", 
                         marsutil_getnetifCmd, NULL, NULL);
#endif

    Tcl_CreateObjCommand(interp, "::marsutil::gettimeofday", 
                         marsutil_gettimeofdayCmd, NULL, NULL);

    Tcl_CreateObjCommand(interp, "::marsutil::let", 
                         marsutil_letCmd, NULL, NULL);

    Tcl_CreateObjCommand(interp, "::marsutil::bbox", 
                         marsutil_bboxCmd, newPoints(), 
                         (Tcl_CmdDeleteProc*)deletePoints);

    Tcl_CreateObjCommand(interp, "::marsutil::ccw", 
                         marsutil_ccwCmd, NULL, NULL);

    Tcl_CreateObjCommand(interp, "::marsutil::intersect", 
                         marsutil_intersectCmd, NULL, NULL);

    Tcl_CreateObjCommand(interp, "::marsutil::ptinpoly", 
                         marsutil_ptinpolyCmd, newPoints(), 
                         (Tcl_CmdDeleteProc*)deletePoints);

    Tcl_CreateObjCommand(interp, "::marsutil::latlong",
                         marsutil_latlongCmd, newLatlongInfo(), 
                         (Tcl_CmdDeleteProc*)deleteLatlongInfo);

    Tcl_CreateObjCommand(interp, "::marsutil::geotiff",
                         marsutil_geotiffCmd, newGeotiffInfo(),
                         (Tcl_CmdDeleteProc*)deleteGeotiffInfo);

    return TCL_OK;
}

/*
 * Command Procedures
 *
 * The functions in this section are all Tcl command definitions,
 * with the standard calling sequence.  Rather than repeat the same
 * description over again, the header comment for each will 
 * describe the implemented Tcl command, along with any notable
 * details about the implementation.
 */

/***********************************************************************
 *
 * FUNCTION:
 *	hexdump value
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *	A hex dump of the bytes of the value.
 *
 * DESCRIPTION:
 *	Gets the value as a byte array, and returns of list of unsigned
 *      bytes in hexadecimal notation.
 */

static int 
marsutil_hexdumpCmd(ClientData cd, Tcl_Interp *interp, 
                int objc, Tcl_Obj* CONST objv[])
{
    int      count;
    char*    bytes;
    unsigned long i;
    Tcl_Obj* result;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "value");
        return TCL_ERROR;
    }

    bytes  = (char*)Tcl_GetByteArrayFromObj(objv[1], &count);
    result = Tcl_GetObjResult(interp);

    for (i = 0; i < count; i++)
    {
        char buf[10];
        sprintf(buf, "%02X", (unsigned char)bytes[i]);
        Tcl_ListObjAppendElement(interp, result,
                                 Tcl_NewStringObj(buf, -1));
    }

    return TCL_OK;
}

/***********************************************************************
 * marsutil(n) optimizations
 *
 * The following commands are fast implementations of commands defined
 * in marsutil(n).  The Tcl version is defined only if the C version is
 * not present.  All of these commands are defined in the ::marsutil::
 * namespace.
 */

#ifdef MARS_NET_API

/***********************************************************************
 *
 * FUNCTION:
 *	getnetif
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *      A list containing network_interface/address pairs.
 *
 * DESCRIPTION:
 *      Returns network interface names and their assigned IP addresses 
 *      in dotted-decimal format (nnn.nnn.nnn.nnn).
 */

static int 
marsutil_getnetifCmd(ClientData cd, Tcl_Interp *interp, 
                     int objc, Tcl_Obj* CONST objv[])
{
    if (objc != 1) {
        Tcl_WrongNumArgs(interp, 1, objv, "");
        return TCL_ERROR;
    }
    
    char     addrStr[INET_ADDRSTRLEN];
    char     *ptr, *buf;
    int	     sockfd, len, lastlen;
    struct ifconf	ifc;
    struct ifreq        *ifr;
    struct sockaddr_in  *sinptr;

    /* FIRST, we need a socket to call ioctl on */
    sockfd = socket(AF_INET, SOCK_DGRAM, 0);

    /* NEXT, loop until we get the complete set of data.
       This is required since ioctl returns 0 even on overflow. */
    lastlen = 0;
    len = 100 * sizeof(struct ifreq);	/* initial buffer size guess */
    for ( ; ; ) {
        buf = malloc(len);
        ifc.ifc_len = len;
        ifc.ifc_buf = buf;
        if (ioctl(sockfd, SIOCGIFCONF, &ifc) < 0) {
            if (errno != EINVAL || lastlen != 0) 
            {
                Tcl_SetResult(interp, 
                              "can't do SIOCGIFCONF to get network interfaces",
                              TCL_STATIC);
                return TCL_ERROR;
            }
        } else {
            if (ifc.ifc_len == lastlen)
            {
                break;		/* success, len has not changed */
            }
            lastlen = ifc.ifc_len;
        }
        len += 10 * sizeof(struct ifreq);	/* increment */
        free(buf);
    }

    /* NEXT, get a result buffer */
    Tcl_Obj* result = Tcl_GetObjResult(interp);

    /* NEXT, for all intefaces found, return their name and IP address */
    ptr = buf;
    while (ptr < buf + ifc.ifc_len)
    {
        ifr = (struct ifreq *) ptr;

        /* Make sure we have the correct size */
        switch (ifr->ifr_addr.sa_family) 
        {
        case AF_INET6:	
            len = sizeof(struct sockaddr_in6);
            break;

        case AF_INET:	
        default:	
            len = sizeof(struct sockaddr);
            break;
        }

        /* Get ready for next buffer */
        ptr += sizeof(ifr->ifr_name) + len;

        /* We're only interested in IPv4 addresses for now */
        if (ifr->ifr_addr.sa_family != AF_INET)
        {
            continue;
        }

        /* Return the name */
        Tcl_ListObjAppendElement(interp, result, 
                                 Tcl_NewStringObj(ifr->ifr_name, -1));

        /* Get the address, convert to doted-decimal and return it */
        sinptr = (struct sockaddr_in *) &ifr->ifr_addr;
        inet_ntop(AF_INET, &sinptr->sin_addr, addrStr, sizeof(addrStr));

        Tcl_ListObjAppendElement(interp, result, 
                                 Tcl_NewStringObj(addrStr, strlen(addrStr)));
    }

    /* NEXT, we're all done with the socket and the buffer */
    close(sockfd);
    free(buf);

    return TCL_OK;
}
#endif

/***********************************************************************
 *
 * FUNCTION:
 *	gettimeofday
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *	Wallclock time in decimal seconds as a double-precision 
 *      floating point value 
 *
 * DESCRIPTION:
 *	Uses gettimeofday(2) to compute the time of day in decimal
 *      seconds at microsecond resolution.
 *
 *      This function is documented in marsutil(n).
 */

static int 
marsutil_gettimeofdayCmd(ClientData cd, Tcl_Interp *interp, 
                     int objc, Tcl_Obj* CONST objv[])
{
    if (objc != 1) {
        Tcl_WrongNumArgs(interp, 1, objv, "");
        return TCL_ERROR;
    }

    struct timeval tv;
    
    int retcode = gettimeofday(&tv, NULL);

    if (retcode != 0)
    {
        /* This should never happen. */
        Tcl_SetResult(interp, "can't retrieve time of day", TCL_STATIC);

        return TCL_ERROR;
    }

    double ds = tv.tv_sec + tv.tv_usec/1000000.0;

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    Tcl_SetDoubleObj(result, ds);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	let varname expression
 *
 * INPUTS:
 *	varname         A variable name in the caller's scope.
 *      expression      An expr expression
 *
 * RETURNS:
 *	The value of the expression.
 *
 * DESCRIPTION:
 *	Evaluates the expression in the caller's context, assigns the
 *      result to the named variable, and returns the result.
 *
 *      This function is documented in marsutil(n).
 */

static int 
marsutil_letCmd(ClientData cd, Tcl_Interp *interp, 
            int objc, Tcl_Obj* CONST objv[])
{
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "varname expression");
        return TCL_ERROR;
    }

    Tcl_Obj* result;

    if (Tcl_ExprObj(interp, objv[2], &result) != TCL_OK)
    {
        return TCL_ERROR;
    }

    Tcl_ObjSetVar2(interp, objv[1], NULL, result, 0);

    Tcl_SetObjResult(interp, result);
    Tcl_DecrRefCount(result);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	bbox coords
 *
 * INPUTS:
 *	coords	A list or coordinates
 *
 * RETURNS:
 *      A bounding box for the coordinates, {xmin ymin xmax ymax}
 */

static int 
marsutil_bboxCmd(ClientData cd, Tcl_Interp *interp, 
             int objc, Tcl_Obj* CONST objv[])
{
    Points* pointsBuffer = (Points*)cd;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "coords");
        return TCL_ERROR;
    }

    /* FIRST, get the points. */
    if (getPoints(interp, objv[1], 1, pointsBuffer) != TCL_OK)
    {
        return TCL_ERROR;
    }

    Bbox box;

    bbox(pointsBuffer, &box);

    Tcl_Obj* result = Tcl_GetObjResult(interp);

    Tcl_ListObjAppendElement(interp, result, Tcl_NewDoubleObj(box.xmin));
    Tcl_ListObjAppendElement(interp, result, Tcl_NewDoubleObj(box.ymin));
    Tcl_ListObjAppendElement(interp, result, Tcl_NewDoubleObj(box.xmax));
    Tcl_ListObjAppendElement(interp, result, Tcl_NewDoubleObj(box.ymax));
    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	ccw a b c
 *
 * INPUTS:
 *	a	An {x y} point
 *	b	An (x y) point
 *	c	An {x y} point
 *
 * Checks whether a path from point a to point b to point c turns 
 * counterclockwise or not.  Wraps ccw().
 */

static int 
marsutil_ccwCmd(ClientData cd, Tcl_Interp *interp, 
            int objc, Tcl_Obj* CONST objv[])
{
    if (objc != 4) {
        Tcl_WrongNumArgs(interp, 1, objv, "a b c");
        return TCL_ERROR;
    }

    /* FIRST, get the points. */

    Point a;
    Point b;
    Point c;

    if (getPoint(interp, objv[1], &a) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (getPoint(interp, objv[2], &b) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (getPoint(interp, objv[3], &c) != TCL_OK)
    {
        return TCL_ERROR;
    }

    int result = ccw(&a, &b, &c);

    Tcl_Obj* resObj = Tcl_GetObjResult(interp);
    Tcl_SetIntObj(resObj, result);

    return TCL_OK;
}
 
/***********************************************************************
 *
 * FUNCTION:
 *	intersect p1 p2 q1 q2
 *
 * INPUTS:
 *	p1	A point
 *      p2	A point
 *      q1	A point
 *      q2	A point
 *
 * RETURNS:
 *	1 if the line segments intersect, and 0 otherwise.	
 *
 * DESCRIPTION:
 *	
 *	Given two line segments p1-p2 and q1-q2, returns 1 if the line
 *	segments intersect and 0 otherwise.  The segments are still said
 *	to intersect if the point of intersection is the end point of one
 *	or both segments.  Either segment may be degenerate, i.e.,
 *	p1 == p2 and/or q1 == q2.
 *
 *	From Sedgewick, Algorithms in C, 1990, Addison-Wesley, page 351.
 */

static int 
marsutil_intersectCmd(ClientData cd, Tcl_Interp *interp, 
                  int objc, Tcl_Obj* CONST objv[])
{
    if (objc != 5) {
        Tcl_WrongNumArgs(interp, 1, objv, "p1 p2 q1 q2");
        return TCL_ERROR;
    }

    /* FIRST, get the points. */

    Point p1;
    Point p2;
    Point q1;
    Point q2;

    if (getPoint(interp, objv[1], &p1) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (getPoint(interp, objv[2], &p2) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (getPoint(interp, objv[3], &q1) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (getPoint(interp, objv[4], &q2) != TCL_OK)
    {
        return TCL_ERROR;
    }

    int result = intersect(&p1, &p2, &q1, &q2);

    Tcl_Obj* resObj = Tcl_GetObjResult(interp);
    Tcl_SetIntObj(resObj, result);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	ptinpoly poly p ?bbox?
 *
 * INPUTS:
 *	poly	A polygon expressed as a list of coordinates
 *      p       A point
 *      bbox    The polygon's cached bounding box, or NULL
 *
 * RETURNS:
 *      1 if the point is in the polygon, and 0 otherwise.
 */

static int 
marsutil_ptinpolyCmd(ClientData cd, Tcl_Interp *interp, 
                 int objc, Tcl_Obj* CONST objv[])
{
    Points* pointsBuffer = (Points*)cd;

    if (objc < 3 || objc > 4) {
        Tcl_WrongNumArgs(interp, 1, objv, "poly p ?bbox?");
        return TCL_ERROR;
    }

    /* FIRST, get the polygon. */
    if (getPoints(interp, objv[1], 1, pointsBuffer) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, get the point. */
    Point p;

    if (getPoint(interp, objv[2], &p) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, get the bounding box. */
    Bbox box;

    if (objc == 4) 
    {
        if (getBbox(interp, objv[3], &box) != TCL_OK)
        {
            return TCL_ERROR;
        }
    }
    else
    {
        bbox(pointsBuffer, &box);
    }

    int value = ptinpoly(pointsBuffer, &p, &box);

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    Tcl_SetIntObj(result, value);

    return TCL_OK;
}

/*
 * latlong command and subcommands
 */

/***********************************************************************
 *
 * FUNCTION:
 *	marsutil_latlongCmd()
 *
 * INPUTS:
 *	subcommand		The subcommand name
 *      args                    Subcommand arguments
 *
 * RETURNS:
 *	Whatever the subcommand returns.
 *
 * DESCRIPTION:
 *	This is the ensemble command for the latlong subcommands.
 *      It looks up the subcommand name, and
 *      then passes execution to the subcommand proc.
 */

static int 
marsutil_latlongCmd(ClientData cd, Tcl_Interp* interp, 
                   int objc, Tcl_Obj* CONST objv[])
{
    if (objc < 2) 
    {
        Tcl_WrongNumArgs(interp, 1, objv, "subcommand ?arg arg ...?");
        return TCL_ERROR;
    } 

    int index = 0;

    if (Tcl_GetIndexFromObjStruct(interp, objv[1], 
                                  latlongTable, sizeof(SubcommandVector),
                                  "subcommand",
                                  TCL_EXACT,
                                  &index) != TCL_OK)
    {
        return TCL_ERROR;
    }

    return (*latlongTable[index].proc)(cd, interp, objc, objv);
}

            



/***********************************************************************
 *
 * FUNCTION:
 *	latlong dist loc1 loc2
 *
 * INPUTS:
 *	loc1		A lat/long pair in decimal degrees
 *      loc2            A lat/long pair in decimal degrees
 *
 * RETURNS:
 *	The distance between loc1 and loc2 in kilometers.
 *
 * DESCRIPTION:
 *	Computes the distance between the two points and returns
 *      an answer in kilometers.  The algorithm is equivalent to
 *      that used in CBS.
 *
 *      This function is documented in marsutil(n).
 */

static int 
latlong_dist(ClientData cd, Tcl_Interp *interp, 
             int objc, Tcl_Obj* CONST objv[])
{
    if (objc != 4) {
        Tcl_WrongNumArgs(interp, 2, objv, "loc1 loc2");
        return TCL_ERROR;
    }

    /* FIRST, get loc1 and loc2 */
    double lat1 = 0.0;
    double lon1 = 0.0;

    if (getLatLong(interp, objv[2], &lat1, &lon1) != TCL_OK)
    {
        return TCL_ERROR;
    }

    double lat2 = 0.0;
    double lon2 = 0.0;

    if (getLatLong(interp, objv[3], &lat2, &lon2) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, convert points to radians */
    double dist = spheredist(lat1, lon1, lat2, lon2);

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    Tcl_SetDoubleObj(result, dist);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	latlong dist4 lat1 lon1 lat2 lon2
 *
 * INPUTS:
 *	lat1		Latitude  1 in decimal degrees
 *      lon1            Longitude 1 in decimal degrees
 *	lat2		Latitude  2 in decimal degrees
 *      lon2            Longitude 2 in decimal degrees
 *
 * RETURNS:
 *	The distance between lat1,lon1 and lat2,lon2 in kilometers.
 *
 * DESCRIPTION:
 *	Computes the distance between the two points and returns
 *      an answer in kilometers.  The algorithm is equivalent to
 *      that used in CBS.
 *
 *      This function is documented in marsutil(n).
 */

static int 
latlong_dist4(ClientData cd, Tcl_Interp *interp, 
             int objc, Tcl_Obj* CONST objv[])
{
    if (objc != 6) {
        Tcl_WrongNumArgs(interp, 2, objv, "lat1 lon1 lat2 lon2");
        return TCL_ERROR;
    }

    /* FIRST, get the lat/lon values */
    double lat1 = 0.0;
    double lon1 = 0.0;
    double lat2 = 0.0;
    double lon2 = 0.0;

    if (Tcl_GetDoubleFromObj(interp, objv[2], &lat1) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (Tcl_GetDoubleFromObj(interp, objv[3], &lon1) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (Tcl_GetDoubleFromObj(interp, objv[4], &lat2) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (Tcl_GetDoubleFromObj(interp, objv[5], &lon2) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, convert points to radians */
    double dist = spheredist(lat1, lon1, lat2, lon2);

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    Tcl_SetDoubleObj(result, dist);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	latlong pole ?loc?
 *
 * INPUTS:
 *	loc		A lat/long pair in decimal degrees
 *
 * RETURNS:
 *	Nothing.
 *
 * DESCRIPTION:
 *	Sets/gets the location as the pole for the "latlong radius" command.
 */

static int 
latlong_pole(ClientData cd, Tcl_Interp *interp, 
             int objc, Tcl_Obj* CONST objv[])
{
    LatlongInfo* info = (LatlongInfo*)cd;

    if (objc < 2 || objc > 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "?loc?");
        return TCL_ERROR;
    }

    /* FIRST, get loc, if any */
    if (objc == 3) {
        double lat;
        double lon;

        if (getLatLong(interp, objv[2], &lat, &lon) != TCL_OK)
        {
            return TCL_ERROR;
        }

        info->poleLat = lat;
        info->poleLon = lon;
    }

    /* NEXT, return lat and lon. */
    Tcl_Obj* result = Tcl_GetObjResult(interp);
    Tcl_ListObjAppendElement(interp, result, Tcl_NewDoubleObj(info->poleLat));
    Tcl_ListObjAppendElement(interp, result, Tcl_NewDoubleObj(info->poleLon));

    return TCL_OK;
}


/***********************************************************************
 *
 * FUNCTION:
 *	latlong radius lat lon
 *
 * INPUTS:
 *	lat		A latitude in decimal degrees
 *	lon		A latitude in decimal degrees
 *
 * RETURNS:
 *	The distance between lat/lon and the pole set with [latlong pole].
 *
 * DESCRIPTION:
 *	Computes the distance between the two points using
 *      spheredist().
 */

static int 
latlong_radius(ClientData cd, Tcl_Interp *interp, 
               int objc, Tcl_Obj* CONST objv[])
{
    LatlongInfo* info = (LatlongInfo*)cd;

    if (objc != 4) {
        Tcl_WrongNumArgs(interp, 2, objv, "lat lon");
        return TCL_ERROR;
    }

    /* FIRST, get lat and lon */
    double lat = 0.0;
    double lon = 0.0;

    if (Tcl_GetDoubleFromObj(interp, objv[2], &lat) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (Tcl_GetDoubleFromObj(interp, objv[3], &lon) != TCL_OK)
    {
        return TCL_ERROR;
    }

    double dist = spheredist(lat, lon, info->poleLat, info->poleLon);

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    Tcl_SetDoubleObj(result, dist);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	latlong validate loc
 *
 * INPUTS:
 *	loc		A lat/long pair in decimal degrees
 *
 * RETURNS:
 *	Nothing.
 *
 * DESCRIPTION:
 *	Validates a lat/long pair.
 */

static int 
latlong_validate(ClientData cd, Tcl_Interp *interp, 
                 int objc, Tcl_Obj* CONST objv[])
{
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "loc");
        return TCL_ERROR;
    }

    double lat;
    double lon;

    if (getLatLong(interp, objv[2], &lat, &lon) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (validateLatLong(interp, lat, lon) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, return lat and lon. */
    Tcl_Obj* result = Tcl_GetObjResult(interp);
    Tcl_ListObjAppendElement(interp, result, Tcl_NewDoubleObj(lat));
    Tcl_ListObjAppendElement(interp, result, Tcl_NewDoubleObj(lon));

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	latlong area coords
 *
 * INPUTS:
 *	coords	A list of lat/long coordinates in decimal degrees.
 *
 * RETURNS:
 *      Given a polygon expressed as 3 or more lat/long coordinate pairs,
 *      computes the area of the polygon in square kilometers.  See 
 *      lib/util/latlong.tcl for a discussion of the algorithm and its
 *      assumptions and limitations.
 */

static int 
latlong_area(ClientData cd, Tcl_Interp *interp, 
             int objc, Tcl_Obj* CONST objv[])
{
    LatlongInfo* info = (LatlongInfo*)cd;
    int          i;
    double       area;
    Tcl_Obj*     result;

    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "coords");
        return TCL_ERROR;
    }

    /* FIRST, get the points. */
    if (getPoints(interp, objv[2], 3, info->pointsBuffer) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, ensure that all pairs are valid */
    for (i = 0; i < info->pointsBuffer->size; i++) {
        if (validateLatLong(interp, 
                            info->pointsBuffer->pts[i].x,
                            info->pointsBuffer->pts[i].y) != TCL_OK)
        {
            return TCL_ERROR;
        }
    }

    area = ll_area(info->pointsBuffer);

    result = Tcl_GetObjResult(interp);
    Tcl_SetDoubleObj(result, area);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	latlong spheroid ?name?
 *
 * INPUTS:
 *	name          The name of the spheroid.
 *
 * RETURNS:
 *      The name of the current spheroid.
 *
 * DESCRIPTION:
 *	Sets/gets the name of the current spheroid.
 */

static int 
latlong_spheroid(ClientData cd, Tcl_Interp *interp, 
                int objc, Tcl_Obj* CONST objv[])
{
    LatlongInfo* info = (LatlongInfo*)cd;

    if (objc < 2 || objc > 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "?name?");
        return TCL_ERROR;
    }

    if (objc == 3)
    {
        int index;

        if (Tcl_GetIndexFromObjStruct(interp, objv[2], 
                                      ellipsoidTable, sizeof(Ellipsoid),
                                      "name",
                                      TCL_EXACT,
                                      &index) != TCL_OK)
        {
            return TCL_ERROR;
        }

        info->spheroid = index;
    }

    Tcl_SetResult(interp, ellipsoidTable[info->spheroid].code, TCL_STATIC);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	latlong tomgrs loc ?precision?
 *
 * INPUTS:
 *	loc          A location as a lat/long pair in decimal degrees.
 *      precision    The number of digits of each of easting and northing.
 *                   5 gives one-meter accuracy, 3 gives hundred-meter
 *                   accuracy; 1 gives 10km accuracy.
 *
 * RETURNS:
 *      The MGRS coordination string.
 *
 * DESCRIPTION:
 *	Computes and returns the MGRS coordinate string associated with
 *      the location.  Takes into account the spheroid.
 */

static int 
latlong_tomgrs(ClientData cd, Tcl_Interp *interp, 
            int objc, Tcl_Obj* CONST objv[])
{
    LatlongInfo* info = (LatlongInfo*)cd;
    double lat;
    double lon;
    double latRadians;
    double lonRadians;
    int    precision;
    long   result;
    char   mgrsString[20];
    char   errBuf[80];


    if (objc < 3 || objc > 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "loc ?precision?");
        return TCL_ERROR;
    }

    /* FIRST, get loc, and convert to radians */

    if (getLatLong(interp, objv[2], &lat, &lon) != TCL_OK)
    {
        return TCL_ERROR;
    }

    latRadians = lat * radians;
    lonRadians = lon * radians;

    /* NEXT, get the precision */
    precision = PRECISION_DEFAULT;

    if (objc == 4)
    {

        if (Tcl_GetIntFromObj(interp, objv[3], &precision) != TCL_OK)
        {
            return TCL_ERROR;
        }
    }

    /* NEXT, set the ellipsoid parameters */
    result = 
        Set_MGRS_Parameters(
            ellipsoidTable[info->spheroid].semi_major_axis,
            1.0 / ellipsoidTable[info->spheroid].inv_flattening,
            ellipsoidTable[info->spheroid].code);

    if (result != MGRS_NO_ERROR)
    {
        printf("code     %ld\n", 
               result);
        printf("spheroid %d\n",  
               info->spheroid);
        printf("sm axis  %f\n", 
               ellipsoidTable[info->spheroid].semi_major_axis);
        printf("inv flat  %f\n", 
              ellipsoidTable[info->spheroid].inv_flattening);

        Tcl_SetResult(interp, "flawed ellipsoid definition", TCL_STATIC);
        return TCL_ERROR;
    }

    /* NEXT, Convert our lat/long to an MGRS_String, and handle errors. */
    result = 
        Convert_Geodetic_To_MGRS(latRadians, lonRadians, precision, 
                                 mgrsString);

    if (result == MGRS_NO_ERROR)
    {
        Tcl_SetResult(interp, mgrsString, TCL_VOLATILE);
        return TCL_OK;
    }

    if (result & MGRS_LAT_ERROR) {
        sprintf(errBuf,
                "Invalid latitude, should be -90.0 to 90.0 degrees: \"%g\"",
                lat);
    } 
    else if (result & MGRS_LON_ERROR) 
    {
        sprintf(errBuf,
                "Invalid longitude, should be -180.0 to 360.0 degrees: \"%g\"",
                lon);
    } 
    else if (result & MGRS_PRECISION_ERROR) 
    {
        sprintf(errBuf, "Invalid precision, should be 0 to 5: \"%d\"",
                precision);
    } 
    else 
    {
        sprintf(errBuf, "unexpected error return: %ld", result);
        
    }

    Tcl_SetResult(interp, errBuf, TCL_VOLATILE);

    return TCL_ERROR;
}

/***********************************************************************
 *
 * FUNCTION:
 *	latlong frommgrs utm
 *
 * INPUTS:
 *	utm          A location as a UTM (MGRS) string.
 *
 * RETURNS:
 *      The lat/long coordinates in decimal degrees.
 *
 * DESCRIPTION:
 *	Computes and returns the lat/long coordinates corresponding
 *      to the MGRS string.  Takes into account the spheroid.
 */

static int 
latlong_frommgrs(ClientData cd, Tcl_Interp *interp, 
            int objc, Tcl_Obj* CONST objv[])
{
    LatlongInfo* info = (LatlongInfo*)cd;
    char*        mgrsString;
    long         result;
    double       lat;
    double       lon;
    Tcl_Obj*     pair;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "utm");
        return TCL_ERROR;
    }

    /* NEXT, get the UTM string */
    mgrsString = Tcl_GetStringFromObj(objv[2], NULL);

    /* NEXT, set the ellipsoid parameters 
     * TBD: Refactor into a separate routine; call at startup and
     * when the spheroid changes. */
    result = 
        Set_MGRS_Parameters(
            ellipsoidTable[info->spheroid].semi_major_axis,
            1.0 / ellipsoidTable[info->spheroid].inv_flattening,
            ellipsoidTable[info->spheroid].code);

    if (result != MGRS_NO_ERROR)
    {
        printf("code     %ld\n", 
               result);
        printf("spheroid %d\n",  
               info->spheroid);
        printf("sm axis  %f\n", 
               ellipsoidTable[info->spheroid].semi_major_axis);
        printf("inv flat  %f\n", 
              ellipsoidTable[info->spheroid].inv_flattening);

        Tcl_SetResult(interp, "flawed ellipsoid definition", TCL_STATIC);
        return TCL_ERROR;
    }

    /* NEXT, Convert our MGRS_String to a lat/long, and handle errors. */

    result = 
        Convert_MGRS_To_Geodetic(mgrsString, &lat, &lon);

    if (result != MGRS_NO_ERROR)
    {
        char errBuf[80];

        /* NOTE: The Geotrans documentation says that the constant 
         * is MGRS_STR_ERROR; the source code defines MGRS_STRING_ERROR. */
        if (result & MGRS_STRING_ERROR) {

            if (strlen(mgrsString) > 20)
            {
              sprintf(errBuf,
                      "Invalid MGRS string: \"%-20.20s...\"",
                      mgrsString);
            } else {
              sprintf(errBuf,
                      "Invalid MGRS string: \"%s\"",
                      mgrsString);

            }
        } 
        else 
        {
            sprintf(errBuf, "unexpected error return: %ld", result);
            
        }

        Tcl_SetResult(interp, errBuf, TCL_VOLATILE);

        return TCL_ERROR;
    }

    /* NEXT, convert lat/long to decimal degrees and return the result. */
    lat /= radians;
    lon /= radians;


    /* TBD: refactor returning a lat/long pair? */
    pair = Tcl_GetObjResult(interp);
    Tcl_ListObjAppendElement(interp, pair, Tcl_NewDoubleObj(lat));
    Tcl_ListObjAppendElement(interp, pair, Tcl_NewDoubleObj(lon));

    return TCL_OK;
}

/*
 * geotiff command and subcommands
 */

/***********************************************************************
 * 
 * FUNCTION :
 *     marsutil_geotiffCmd()
 *
 * INPUTS:
 *     subcommand        The subcommand name
 *     args              Subcommand arguments
 *
 * RETURNS:
 *     Whatever the subcommand returns.
 *
 * DESCRIPTION:
 *     This is the ensemble command for the geotiff subcommands.
 *     It looks up the subcommand name, and then passes execution
 *     to the subcommand proc.
 *
 */

static int
marsutil_geotiffCmd(ClientData cd, Tcl_Interp* interp,
                   int objc, Tcl_Obj* CONST objv[])
{
    if (objc < 2)
    {
        Tcl_WrongNumArgs(interp, 1, objv, "subcommand ?arg arg ...?");
        return TCL_ERROR;
    }

    int index = 0;

    if (Tcl_GetIndexFromObjStruct(interp, objv[1],
                                  geotiffTable, sizeof(SubcommandVector),
                                  "subcommand",
                                  TCL_EXACT,
                                  &index) != TCL_OK)
    {
        return TCL_ERROR;
    }

    return(*geotiffTable[index].proc)(cd, interp, objc, objv);
}

/***********************************************************************
 * 
 * FUNCTION :
 *     geotiff read filename
 *
 * INPUTS:
 *     filename - the name of a GeoTIFF file to read
 *
 * RETURNS:
 *     Projection information to be used in geo-referencing the
 *     map image contained within the GeoTIFF
 *
 * DESCRIPTION:
 *     Opens a TIFF file and reads the appropriate geokeys and values
 *     from the Geo information embedded in the TIFF. If this file is
 *     not a TIFF or if the appropriate Geo information is not in it
 *     an appropriate error message is returned.
 *
 */

static int
geotiff_read(ClientData cd, Tcl_Interp *interp,
             int objc, Tcl_Obj* CONST objv[])
{
    double    *d_list = NULL;
    uint16    d_list_count;
    ttag_t    field;
    geocode_t code;
    geokey_t  key;
    Tcl_Obj   *result = NULL;

    GeotiffInfo* info = (GeotiffInfo*)cd;

    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "filename");
        return TCL_ERROR;
    }

    FILE* f;
    char* fname = Tcl_GetStringFromObj(objv[2], NULL);

    /* See if the file exists */
    if ((f = fopen(fname, "r")) == NULL)
    {
        Tcl_SetResult(interp, "file does not exist", TCL_STATIC);
        return TCL_ERROR;
    }

    fclose(f);

    /* Disable TIFF libraries internal error handling, */
    /* this prevents messages from going to stderr     */
    TIFFSetErrorHandler(NULL); 

    info->tiff = XTIFFOpen(fname, "r");

    /* File is not a TIFF */
    if (info->tiff == NULL)
    {
        Tcl_SetResult(interp, "file is not a TIFF", TCL_STATIC);
        return TCL_ERROR;
    }

    info->gtif = GTIFNew(info->tiff);

    /* File does not contain any geokeys */
    if (!info->gtif)
    {
        Tcl_SetResult(interp, "file does not contain geokeys", TCL_STATIC);
        XTIFFClose(info->tiff);
        info->tiff = NULL ;
        return TCL_ERROR;
    }

    /* Extract data */

    /* Model Type */
    key = (geokey_t)GT_MODEL_TYPE;

    if (!GTIFKeyGet(info->gtif, key, &code, 0, 1))
    {
        Tcl_SetResult(interp, "file is not a GeoTIFF", TCL_STATIC);
        closeGeotiff(info);
        return TCL_ERROR;
    }
        
    switch (code) 
    {
        /* Unsupported Model Types */
        case MODEL_TYPE_GEOCENTRIC:
        case MODEL_TYPE_PROJECTED:
            Tcl_SetResult(interp, 
                          "usupported model type, must be geographic", 
                          TCL_STATIC);

            closeGeotiff(info);

            return TCL_ERROR;

         /* Look for right tags */
         case MODEL_TYPE_GEOGRAPHIC:
            /* Result returned as a dictionary */
            result = Tcl_NewDictObj();

            /* Model type */
            Tcl_Obj* modelkey = Tcl_NewStringObj("modeltype", 9);
            Tcl_Obj* modelval = Tcl_NewStringObj("GEOGRAPHIC", 10);
            Tcl_DictObjPut(interp, result, modelkey, modelval);

            /* Tiepoints */
            field = (ttag_t)MODEL_TIEPOINT_TAG;

            if (TIFFGetField(info->tiff, field, &d_list_count, &d_list))
            {
                Tcl_Obj* tpkey  = Tcl_NewStringObj("tiepoints", 9);
                Tcl_Obj* tplist = Tcl_NewObj();
                
                int i;

                for (i=0; i<d_list_count; i++)
                {
                    Tcl_ListObjAppendElement(interp, tplist,
                                             Tcl_NewDoubleObj(d_list[i]));
                }

                Tcl_DictObjPut(interp, result, tpkey, tplist);

            } 
            else
            {
                Tcl_SetResult(interp, 
                              "no tiepoints found in image", 
                              TCL_STATIC);

                closeGeotiff(info);

                return TCL_ERROR;
            }

            /* Pixel scaling */
            field = (ttag_t)MODEL_PIXEL_SCALE_TAG;

            if (TIFFGetField(info->tiff, field, &d_list_count, &d_list))
            {
                Tcl_Obj* pskey  = Tcl_NewStringObj("pscale", 6);
                Tcl_Obj* pslist = Tcl_NewObj();
                
                int i;

                for (i=0; i<d_list_count; i++)
                {
                    Tcl_ListObjAppendElement(interp, pslist,
                                             Tcl_NewDoubleObj(d_list[i]));
                }

                Tcl_DictObjPut(interp, result, pskey, pslist);
                break;

            }
            else
            {
                Tcl_SetResult(interp, 
                              "no pixel scaling found in image", 
                              TCL_STATIC);

                closeGeotiff(info);
                
                return TCL_ERROR;
            }

         default:
            Tcl_SetResult(interp, "unrecognized model type", TCL_STATIC);
            closeGeotiff(info);

            return TCL_ERROR;
    }


    /* Done */
    closeGeotiff(info);
    Tcl_SetObjResult(interp, result);

    return TCL_OK;
}

/*
 * Math and Geometry Functions
 */

/***********************************************************************
 *
 * FUNCTION:
 *	spheredist
 *
 * INPUTS:
 *	lat1		A latitude in decimal degrees
 *      lon1            A longitude in decimal degrees
 *	lat2		A latitude in decimal degrees
 *      lon2            A longitude in decimal degrees
 *
 * RETURNS:
 *	The distance between loc 1 and loc 2 in kilometers.
 *
 * DESCRIPTION:
 *	Computes the distance between the two points and returns
 *      an answer in kilometers.  The algorithm is equivalent to
 *      that used in CBS.
 */

static double
spheredist(double lat1, double lon1, double lat2, double lon2)
{
    /* Earth's diameter in kilometers, per CBS */
    double diameter = 12742.0;

    /* NEXT, convert points to radians */
    lat1 *= radians;
    lon1 *= radians;
    lat2 *= radians;
    lon2 *= radians;

    /* NEXT, compute the distance. */
    double sinHalfDlat = sin((lat2 - lat1)/2.0);
    double sinHalfDlon = sin((lon2 - lon1)/2.0);

    double dist = 
        diameter * 
        asin(sqrt(sinHalfDlat*sinHalfDlat +
                  cos(lat1)*cos(lat2)*sinHalfDlon*sinHalfDlon));

    return dist;
}

/***********************************************************************
 *
 * FUNCTION:
 *	bbox()
 *
 * INPUTS:
 *	points		A list of Points
 *
 * OUTPUTS
 *      bbox	A bounding box
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Computes the bounding box of the Points
 */

static void 
bbox(Points* points, Bbox* bbox)
{
    int i;

    /* FIRST, get the first point as the start point. */
    bbox->xmin = points->pts[0].x;
    bbox->xmax = bbox->xmin;

    bbox->ymin = points->pts[0].y;
    bbox->ymax = bbox->ymin;

    for (i = 1; i < points->size; i++)
    {
        double x = points->pts[i].x;
        double y = points->pts[i].y;

        if (x < bbox->xmin)
        {
            bbox->xmin = x;
        } 
        else if (x > bbox->xmax)
        {
            bbox->xmax = x;
        }

        if (y < bbox->ymin)
        {
            bbox->ymin = y;
        } 
        else if (y > bbox->ymax)
        {
            bbox->ymax = y;
        }
    }
}

/***********************************************************************
 *
 * FUNCTION:
 *	ccw
 *
 * INPUTS:
 *	a	An {x y} point
 *	b	An (x y) point
 *	c	An {x y} point
 *
 * Checks whether a path from point a to point b to point c turns 
 * counterclockwise or not.
 *
 *                   c
 *                   |
 * Returns:   1    a-b    or   a-b-c
 *
 *
 *           -1    a-b    or   c-a-b
 *                   | 
 *                   c
 *
 *            0    a-c-b
 *                 
 * From Sedgewick, Algorithms in C, page 350, via the CBS Simscript
 * code.  Explicitly handles the case where a == b, which Sedgewick's
 * code doesn't.
 */

static int
ccw(Point* a, Point* b, Point* c)
{
    /* FIRST, compute the deltas from a-b and a-c */
    double dx1 = b->x - a->x;
    double dy1 = b->y - a->y;
    double dx2 = c->x - a->x;
    double dy2 = c->y - a->y;

    /* NEXT, see if point c is on the left of a-b */
    if (dx1*dy2 > dy1*dx2) {
        return 1;
    }
    
    /* NEXT, see if point c is on the right of a-b */
    if (dx1*dy2 < dy1*dx2) {
        return -1;
    }

    /* NEXT, the points are collinear.
     * c-a-b */
    if ((dx1 * dx2 < 0) || (dy1 * dy2 < 0)) {
        return -1;
    }

    /* NEXT, Explicitly handle the case where a == b */
    if (dx1 == 0 && dy1 == 0) {
        /* a == b */

        if (dx2 < 0) {
            /* c->x < a->x */
            return -1;
        } else if (dx2 > 0) {
            /* c->x > a->x */
            return 1;
        } else {
            return 0;
        }
    }
        
    if ((dx1*dx1 + dy1*dy1) < (dx2*dx2 + dy2*dy2)) {
        return 1;
    }

    return 0;
}

/***********************************************************************
 *
 * FUNCTION:
 *	intersect()
 *
 * INPUTS:
 *	p1	A point
 *      p2	A point
 *      q1	A point
 *      q2	A point
 *
 * RETURNS:
 *	1 if the line segments intersect, and 0 otherwise.	
 *
 * DESCRIPTION:
 *	
 *	Given two line segments p1-p2 and q1-q2, returns 1 if the line
 *	segments intersect and 0 otherwise.  The segments are still said
 *	to intersect if the point of intersection is the end point of one
 *	or both segments.  Either segment may be degenerate, i.e.,
 *	p1 == p2 and/or q1 == q2.
 *
 *	From Sedgewick, Algorithms in C, 1990, Addison-Wesley, page 351.
 */

static int 
intersect(Point* p1, Point* p2, Point* q1, Point* q2)
{
    if (ccw(p1, p2, q1) * ccw(p1, p2, q2) <= 0 &&
        ccw(q1, q2, p1) * ccw(q1, q2, p2) <= 0) {
        return 1;
    } else {
        return 0;
    }
}

/***********************************************************************
 *
 * FUNCTION:
 *	ptinpoly()
 *
 * INPUTS:
 *	poly		A polygon defines as a list of Points
 *	p		A point
 *	bbox		The polygon's bounding box
 *
 * RETURNS:
 *	1 if the point is inside the polygon or on its border, and 0
 *	otherwise.
 *
 * DESCRIPTION:
 * This function determines whether a given point q is inside or outside
 * of a given polygon; if a point is on an edge or vertex it is defined to
 * be on the inside.  The function determines this by:
 *
 * (1) Comparing q against the bounding box of the polygon; if it's outside
 *     the bounding box, it's outside the polygon.
 *
 * (2) Checking q against each edge of the polygon, using [intersect].
 *     If it's explicitly on the border, it's "inside".
 *
 * (3) Checking whether q is inside the polygon by counting the number
 *     intersections made between q and a point outside the polygon.
 *     This part of the algorithm was found in an on-line paper by
 *     Paul Bourke called "Determining If A Point Lies On The Interior
 *     Of A Polygon", at 
 *
 *     http://astronomy.swin.edu.au/~pbourke/geometry/insidepoly
 */

static int
ptinpoly(Points* poly, Point* p, Bbox* box)
{
    int    i;
    int    counter;
    Point* p1;

    /* FIRST, if p is outside the bounding box, it's outside the
     * polygon. */
    if (p->x < box->xmin || p->x > box->xmax ||
        p->y < box->ymin || p->y > box->ymax) {
        return 0;
    }

    /* NEXT, count the intersections */
    counter = 0;
    p1 = &poly->pts[0];

    for (i = 1; i <= poly->size; i++)
    {
        Point* p2 = &poly->pts[i % poly->size];

        /* FIRST, if the point is on this edge then it's "inside" */
        if (intersect(p1, p2, p, p)) {
            return 1;
        }

        /* NEXT, check for an intersection */
        if (p->y > dmin(p1->y, p2->y))
        {
            if (p->y <= dmax(p1->y, p2->y))
            {
                if (p->x <= dmax(p1->x, p2->x))
                {
                    if (p1->y != p2->y) 
                    {
                        double xInters = 
                            (p->y - p1->y)*(p2->x - p1->x)/(p2->y - p1->y) 
                            + p1->x;

                        if (p1->x == p2->x || p->x <= xInters) {
                            ++counter;
                        }
                    }
                }
            }
        }
        
        p1 = p2;
    }

    if (counter % 2 == 0) {
        return 0;
    } else {
        return 1;
    }
}

/***********************************************************************
 *
 * FUNCTION:
 *	dmin()
 *
 * INPUTS:
 *	a	a value
 *	b	a value
 *
 * RETURNS:
 *	The minimum of the two values.
 */

static double
dmin(double a, double b)
{
    if (a < b)
    {
        return a;
    }
    else
    {
        return b;
    }
}

/***********************************************************************
 *
 * FUNCTION:
 *	dmax()
 *
 * INPUTS:
 *	a	a value
 *	b	a value
 *
 * RETURNS:
 *	The maximum of the two values.
 */

static double
dmax(double a, double b)
{
    if (a > b)
    {
        return a;
    }
    else
    {
        return b;
    }
}

/***********************************************************************
 *
 * FUNCTION:
 *	ll_area()
 *
 * INPUTS:
 *	poly		A list of (lat,lon) pairs
 *
 * RETURNS:
 *	The area of the polygon in square kilometers
 *
 * DESCRIPTION:
 *	Computes the area of the polygon, taking curvature of the
 *      Earth into account.  See latlong.tcl for a discussion of the
 *      algorithm and its limitations.
 */

static double
ll_area(Points* poly)
{
    int    i;
    double sum;

    /* FIRST, convert the lat/lon points to radians */
    for (i = 0; i < poly->size; i++)
    {
        poly->pts[i].x *= radians;
        poly->pts[i].y *= radians;
    }

    /* NEXT, compute the sum. */
    sum = 0.0;

    for (i = 0; i < poly->size; i++)
    {
        int j = (i - 2);

        if (j < 0)
        {
            j += poly->size;
        }

        int k = (i - 1);

        if (k < 0)
        {
            k += poly->size;
        }

        double ilon = poly->pts[i].y;
        double jlon = poly->pts[j].y;
        double klat = poly->pts[k].x;

        sum += (ilon - jlon)*sin(klat);
    }

    double area = -(earthRadius*earthRadius/2.0)*sum;

    return area;
}

/*
 * Private Helper Functions
 */


/***********************************************************************
 *
 * FUNCTION:
 *	newLatlongInfo()
 *
 * INPUTS:
 *	nothing
 *
 * OUTPUTS:
 *	none
 *
 * RETURNS:
 *	A pointer to a zeroed LatlongInfo struct
 *
 * DESCRIPTION:
 *	Allocates a new LatlongInfo struct, and zeroes it.
 */

static LatlongInfo*
newLatlongInfo(void)
{
    LatlongInfo* info = (LatlongInfo*)Tcl_Alloc(sizeof(LatlongInfo));
    memset(info, 0, sizeof(LatlongInfo));
    info->pointsBuffer = newPoints();
    info->spheroid = 0;

    return info;
}

/***********************************************************************
 *
 * FUNCTION:
 *	newGeotiffInfo()
 *
 * INPUTS:
 *	nothing
 *
 * OUTPUTS:
 *	none
 *
 * RETURNS:
 *	A pointer to a zeroed GeotiffInfo struct
 *
 * DESCRIPTION:
 *	Allocates a new GeotiffInfo struct, and zeroes it.
 */

static GeotiffInfo*
newGeotiffInfo(void)
{
    GeotiffInfo* info = (GeotiffInfo*)Tcl_Alloc(sizeof(GeotiffInfo));
    memset(info, 0, sizeof(GeotiffInfo));
    info->tiff = NULL;

    return info;
}

/***********************************************************************
 *
 * FUNCTION:
 *	closeGeotiff()
 *
 * INPUTS:
 *	Pointer to a GeotiffInfo struct
 *
 * OUTPUTS:
 *	none
 *
 * RETURNS:
 *  nothing
 *
 * DESCRIPTION:
 *	Closes a Geotiff associated with a Geotiff info and cleans up
 *  pointers.
 *
 */

static void
closeGeotiff(GeotiffInfo* info)
{
    XTIFFClose(info->tiff);
    info->tiff = NULL;
    info->gtif = NULL;
    return;
}


/***********************************************************************
 *
 * FUNCTION:
 *	deleteLatlongInfo()
 *
 * INPUTS:
 *	none
 *
 * OUTPUTS:
 *	none
 *
 * RETURNS:
 *	A pointer to a LatlongInfo struct allocated with newLatlongInfo().
 *
 * DESCRIPTION:
 *	Frees the LatlongInfo* data.
 */

static void
deleteLatlongInfo(LatlongInfo* p)
{
    deletePoints(p->pointsBuffer);

    Tcl_Free((void*)p);
}

/***********************************************************************
 *
 * FUNCTION:
 *	deleteGeotiffInfo()
 *
 * INPUTS:
 *	A pointer to a GeotiffInfo struct
 *
 * OUTPUTS:
 *	none
 *
 * RETURNS:
 *  nothing
 *
 * DESCRIPTION:
 *	Frees the GeotiffInfo* data.
 */

static void
deleteGeotiffInfo(GeotiffInfo* g)
{
    Tcl_Free((void*)g);
}

/***********************************************************************
 *
 * FUNCTION:
 *	newPoints()
 *
 * INPUTS:
 *	none
 *
 * OUTPUTS:
 *	none
 *
 * RETURNS:
 *	A pointer to an initialized Points struct
 *
 * DESCRIPTION:
 *	Allocates and zeros a new Points struct.
 */

static Points*
newPoints()
{
    Points* p = (Points*)Tcl_Alloc(sizeof(Points));
    memset(p, 0, sizeof(Points));

    return p;
}

/***********************************************************************
 *
 * FUNCTION:
 *	deletePoints()
 *
 * INPUTS:
 *	none
 *
 * OUTPUTS:
 *	none
 *
 * RETURNS:
 *	A pointer to a Points struct allocated with newPoints().
 *
 * DESCRIPTION:
 *	Frees the Points* data.
 */

static void
deletePoints(Points* p)
{
    if (p->pts != NULL)
    {
        Tcl_Free((void*)p->pts);
    }

    Tcl_Free((void*)p);
}


/***********************************************************************
 *
 * FUNCTION:
 *	getBbox()
 *
 * INPUTS:
 *	interp		The Tcl interpreter
 *      coords		The coordinates: xmin ymin xmax ymax
 *
 * OUTPUTS:
 *	box		A pointer to the Bbox struct.
 *
 * RETURNS:
 *	TCL_OK on success and TCL_ERROR on failure, setting the error
 *      string in the latter case.
 *
 * DESCRIPTION:
 *	Converts a flat list of coordinates into a bounding box.
 */

static int
getBbox(Tcl_Interp* interp, Tcl_Obj* coords, Bbox* box)
{
    int listc;
    Tcl_Obj** listv;
    
    if (Tcl_ListObjGetElements(interp, coords, &listc, &listv) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (listc != 4)
    {
        Tcl_Obj* result = Tcl_GetObjResult(interp);

        Tcl_AppendStringsToObj(
            result, 
            "invalid bounding box, expected 4 coordinates, got: \"", NULL);
        Tcl_AppendObjToObj(result, Tcl_NewIntObj(listc));
        Tcl_AppendStringsToObj(
            result, 
            "\"", NULL);
        
        return TCL_ERROR;
    }

    if (Tcl_GetDoubleFromObj(interp, listv[0], &box->xmin) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (Tcl_GetDoubleFromObj(interp, listv[1], &box->ymin) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (Tcl_GetDoubleFromObj(interp, listv[2], &box->xmax) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (Tcl_GetDoubleFromObj(interp, listv[3], &box->ymax) != TCL_OK)
    {
        return TCL_ERROR;
    }

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	getPoint()
 *
 * INPUTS:
 *	interp		The Tcl interpreter
 *      coords		The coordinates: a 2-element Tcl list
 *
 * OUTPUTS:
 *	point		A pointer to the Point struct.
 *
 * RETURNS:
 *	TCL_OK on success and TCL_ERROR on failure, setting the error
 *      string in the latter case.
 *
 * DESCRIPTION:
 *	Converts a coordinate pair into a Point.
 */

static int
getPoint(Tcl_Interp* interp, Tcl_Obj* coords, Point* point)
{
    int listc;
    Tcl_Obj** listv;
    
    if (Tcl_ListObjGetElements(interp, coords, &listc, &listv) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (listc != 2)
    {
        Tcl_SetResult(interp, "not a coordinate pair",
                      TCL_STATIC);
        return TCL_ERROR;
    }

    if (Tcl_GetDoubleFromObj(interp, listv[0], &point->x) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (Tcl_GetDoubleFromObj(interp, listv[1], &point->y) != TCL_OK)
    {
        return TCL_ERROR;
    }

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	getPoints()
 *
 * INPUTS:
 *	interp		The Tcl interpreter
 *      coords		The coordinates: an N-element Tcl list
 *      minSize         Minimum number of points
 *
 * OUTPUTS:
 *	points		A pointer to the Points struct.
 *
 * RETURNS:
 *	TCL_OK on success and TCL_ERROR on failure, setting the error
 *      string in the latter case.
 *
 * DESCRIPTION:
 *	Converts a flat list of coordinates into a set of Points.
 *
 *      getPoints allocates enough space in points to hold the current 
 *      Note that it assumes that the points buffer is being reused.
 *      Initially, the points buffer should be all zeros.
 */

static int
getPoints(Tcl_Interp* interp, Tcl_Obj* coords, int minSize, Points* points)
{
    int       listc;
    Tcl_Obj** listv;
    int       i;
    
    if (Tcl_ListObjGetElements(interp, coords, &listc, &listv) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (listc % 2 != 0)
    {
        Tcl_Obj* result = Tcl_GetObjResult(interp);

        Tcl_AppendStringsToObj(result, 
                               "expected even number of coordinates, got ", 
                               NULL);
        Tcl_AppendObjToObj(result, Tcl_NewIntObj(listc));
        Tcl_AppendStringsToObj(result, ": \"", NULL);
        Tcl_AppendObjToObj(result, coords);
        Tcl_AppendStringsToObj(result, "\"", NULL);

        return TCL_ERROR;
    }

    if (listc < 2*minSize)
    {
        Tcl_Obj* result = Tcl_GetObjResult(interp);

        Tcl_AppendStringsToObj(result, "expected at least ", NULL);
        Tcl_AppendObjToObj(result, Tcl_NewIntObj(minSize));
        Tcl_AppendStringsToObj(result, " point(s), got ", NULL);
        Tcl_AppendObjToObj(result, Tcl_NewIntObj(listc/2));
        Tcl_AppendStringsToObj(result, ": \"", NULL);
        Tcl_AppendObjToObj(result, coords);
        Tcl_AppendStringsToObj(result, "\"", NULL);

        
        return TCL_ERROR;
    }

    points->size = listc/2;

    if (points->maxSize == 0)
    {
        points->maxSize = points->size;
        points->pts = (Point*)Tcl_Alloc(points->size * sizeof(Point));
    }
    else if (points->size > points->maxSize)
    {
        points->maxSize = points->size;
        points->pts = (Point*)Tcl_Realloc((char*)points->pts, 
                                          points->size * sizeof(Point));
    }

    for (i = 0; i < points->size; i++) {
        if (Tcl_GetDoubleFromObj(interp, listv[2*i], 
                                 &points->pts[i].x) != TCL_OK)
        {
            return TCL_ERROR;
        }

        if (Tcl_GetDoubleFromObj(interp, listv[2*i + 1], 
                                 &points->pts[i].y) != TCL_OK)
        {
            return TCL_ERROR;
        }
    }
    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	getLatLong()
 *
 * INPUTS:
 *	interp		The Tcl interpreter
 *      loc		The location: a 2-element Tcl list
 *
 * OUTPUTS:
 *	lat		The latitude
 *      lon		The longitude
 *
 * RETURNS:
 *	TCL_OK on success and TCL_ERROR on failure, setting the error
 *      string in the latter case.
 *
 * DESCRIPTION:
 *	Converts a lat/long pair into doubles--or, really, any 
 *      double-valued coordinate pair.
 */

static int
getLatLong(Tcl_Interp* interp, Tcl_Obj* loc, double* lat, double* lon)
{
    int locc;
    Tcl_Obj** locv;
    
    if (Tcl_ListObjGetElements(interp, loc, &locc, &locv) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (locc != 2)
    {
        Tcl_Obj* result = Tcl_GetObjResult(interp);

        Tcl_AppendStringsToObj(
            result, 
            "expected lat/long pair, got: \"", NULL);
        Tcl_AppendObjToObj(result, loc);
        Tcl_AppendStringsToObj(
            result, 
            "\"", NULL);

        return TCL_ERROR;
    }

    if (Tcl_GetDoubleFromObj(interp, locv[0], lat) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (Tcl_GetDoubleFromObj(interp, locv[1], lon) != TCL_OK)
    {
        return TCL_ERROR;
    }

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	validateLatLong()
 *
 * INPUTS:
 *	interp		The Tcl interpreter
 *	lat		The latitude
 *      lon		The longitude
 *
 * RETURNS:
 *	TCL_OK on success and TCL_ERROR on failure, setting the error
 *      string in the latter case.
 *
 * DESCRIPTION:
 *	Validates the lat and lon values.
 */

static int
validateLatLong(Tcl_Interp* interp, double lat, double lon)
{
    if (lat < LAT_MIN || lat > LAT_MAX)
    {
        Tcl_Obj* result = Tcl_GetObjResult(interp);

        Tcl_AppendStringsToObj(result, 
            "invalid latitude, should be ", NULL);
        Tcl_AppendObjToObj(result, Tcl_NewDoubleObj(LAT_MIN));
        Tcl_AppendStringsToObj(result, 
            " to ", NULL);
        Tcl_AppendObjToObj(result, Tcl_NewDoubleObj(LAT_MAX));
        Tcl_AppendStringsToObj(result, 
            " degrees: \"", NULL);
        Tcl_AppendObjToObj(result, Tcl_NewDoubleObj(lat));
        Tcl_AppendStringsToObj(result, 
            "\"", NULL);

        return TCL_ERROR;
    }

    if (lon < LON_MIN || lon > LON_MAX)
    {
        Tcl_Obj* result = Tcl_GetObjResult(interp);

        Tcl_AppendStringsToObj(result, 
            "invalid longitude, should be ", NULL);
        Tcl_AppendObjToObj(result, Tcl_NewDoubleObj(LON_MIN));
        Tcl_AppendStringsToObj(result, 
            " to ", NULL);
        Tcl_AppendObjToObj(result, Tcl_NewDoubleObj(LON_MAX));
        Tcl_AppendStringsToObj(result, 
            " degrees: \"", NULL);
        Tcl_AppendObjToObj(result, Tcl_NewDoubleObj(lon));
        Tcl_AppendStringsToObj(result, 
            "\"", NULL);

        return TCL_ERROR;
    }

    return TCL_OK;
}





