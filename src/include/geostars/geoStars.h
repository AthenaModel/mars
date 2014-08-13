/*!
\file  geoStars.h
\brief This file has all of the definitions for the Geo Library:
       geoEllips, geoAstro, geoPoint, and geoMag.
*/

/*!
\mainpage GeoStars Library
\author Dean Nelson
\version 0.6 Functional Beta (01/08/05) First SourceForge Release - additional functions for easy Excel integration
\version 0.5 Functional Beta (01/08/05) Updated World Magnetic Model to 2005
\version 0.4 Functional beta (11/20/04) tuned for DLL and VB support
\version 0.3 Functional beta (11/1/03) with geomagnetism routines
\version 0.2 Functional beta (02/02/02) with test routines
\version 0.1 functional beta (01/28/02)

\section Home Home
Geodetic Library routines augmented by astrometry routines


\b Table \b of \b Contents
\li \ref intro
\li \ref compile
\li \ref formulas
\li \ref basic
\li \ref cosys
\li \ref conv
\li \ref mag
\li \ref dll
\li \ref xls
\li \ref how



\section intro Introduction
This geodetic library has functions for dealing with many geodesy-based problems
found in positioning, pointing, and surveying situations. It is useful to determine
absolute position on the earth, pointing vectors, coordinate transformations, and
deg/min/sec conversions. It has the following features:

\li ANSI C code
\li Sun position
\li Accurate Azimuth, Elevation, and Range calculation
\li Cartesian to Polar conversions
\li It has 23 ellipsoid definitions (can be used worldwide)
\li Links with the Naval Observatory's Novas library for astronomic calculations
\li Calculates the earth's magnetic declination of any location and time(2005-2010)

\subsection compile Compiling Instructions
Geo Library was designed to be as flexible as possible. It does not come as a linkable
library. You compile the code on your command line or place it in your own library.
Geo Library contains these files:

\li \b geoStars.h - Main Geo Library include file
\li \b geoEllips.c - Ellipsoid definitions and location descriptor routines
\li \b geoPoint.c - Coordinate transformations, polar and Cartesian conversions
\li \b geoAstro.c - Wrapper routines for the Novas library used in Sun Position
\li \b geoMag.c - Geo Magnetism routines for the World Magnetism Model of 2005
\li \b NOVAS \b Library - This is the Naval Observatory Vector Astrometry Subroutine library.

Test Code
\li \b geoTest.c - general test routines for the basic geodetic part of the GeoStars Library
\li \b geoMagTest.c - test routines for the World Magnetism Model of 2005 (WMM-2005)
\li \b geoTest.bas - VB test routines for geodetic and WMM-2005 functions

Novas could be located in a subdirectory called \e novas in the main code tree. When using Novas, you will
need to compile in the following files:
\li novas.c
\li novascon.c
\li readeph0.c
\li solsys3.c

There are also header files in that directory that you may want to make your compiler aware of.
Novas source code is not supplied with GeoStars Library. It can be downloaded 
from http://aa.usno.navy.mil/software/novas/novas_info.html

\b Example \b compilation \b with \b GNU \b C++

with novas already in a library:
\code
gcc geoTest.c geoAstro.c geoEllips.c geoPoint.c geoMag.c novas\novas.a
\endcode

with Novas not in a library:
\code
gcc geoTest.c geoAstro.c geoEllips.c geoPoint.c geoMag.c \
      novas\novas.c novas\novascon.c novas\readeph0.c novas\solsys3.c
\endcode

\b Example \b compilation \b with \b Borland \b C++

with novas already in a library:
\code
bcc32 geoTest.c geoAstro.c geoEllips.c geoPoint.c geoMag.c novas\novas.lib
\endcode

with Novas not in a library:
\code
bcc32 geoTest.c geoAstro.c geoEllips.c geoPoint.c geoMag.c \
      novas\novas.c novas\novascon.c novas\readeph0.c novas\solsys3.c
\endcode

\b Example \b compilation \b with \b Microsoft \b C++

with novas already in a library:
\code
cl geoTest.c geoAstro.c geoEllips.c geoPoint.c geoMag.c novas\novas.lib
\endcode

with Novas not in a library:
\code
cl geoTest.c geoAstro.c geoEllips.c geoPoint.c geoMag.c \
      novas\novas.c novas\novascon.c novas\readeph0.c novas\solsys3.c
\endcode


\b Calling \b the \b geo.dll \b from \b Visual \b Basic \n

Example:


\code
Private Declare Function MagD Lib "geo.dll" Alias "_geoMagGetDecRet@36" _
   (ByVal Latitude As Double, ByVal Longitude As Double, ByVal Altitude As Double, _
    ByVal Month As Integer, ByVal Day As Integer, ByVal Year As Integer) As Double

' Although the path to "geo.dll" could be included, if it is in the system path, the local
' directory, c:\windows or \windows\system32, the path is not required, as it will find it in going 
' through the defaults.

Dim dlat As Double          'Latitude as decimal.  Plus for Northern Latitudes
Dim dlong As Double         'Longitude as decimal.  Minus for West Longitude's
Dim alt As Double           'Altitude in Meters  An average value for a state can be used
Dim mo As Integer           'Month
Dim da As Integer           'Day
Dim yr As Integer           'Year


'_______________________________________________________________
Private Sub cmdDeclination_Click()          'They pushed the calculate button'
'Note, the following values would normally be generated by some program steps
'and checked to be sure they were numeric etc.
dlat = 37.1668611
dlong = -93.35138889
alt = 350
mo = 11
da = 2
yr = 2004

txtResult.Text = MagD(dlat, dlong, alt, mo, da, yr)   'The result is displayed in a text box txtResult

End Sub
'_______________________________________________________________

\endcode

More examples and definintions are included in \b geo.bas and \b geoTest.bas.

\ref Home


\section formulas Formulas
\subsection basic Basic Geodesy
\b Ellipsoids

Contrary to popular belief, the Earth is not round. It, like most people, is a
bit bigger around the girth. That \e girth is called the \e equator. The equator
is one of the two axis of the Earth. The other axis is the polar axis.

Ellipsoids contain several defining values:
  \li Major Axis - This is the equatorial axis or radius \f$a\f$
  \li Minor Axis - This is the polar axis or radius  \f$b\f$
  \li Flattening - This is a ratio describing the amount of flattening that
       is present on the ellipsoid. Flattening \f$f\f$ is represented by
       \f[f = \frac{a - b}{a}\f]  Flattening is usually a small number
       (i.e. 0.0033900753) and is often expressed as a fraction
       (i.e. \f$\frac{1}{297}\f$). \e Inverse \e Flattening \f$f^{-1}\f$ is,
       of course, the denominator of the fraction.
  \li Eccentricity - also called Eccentricity Squared \f$e^2\f$ is
       represented by \f[e^2 = \frac{a^2 - b^2}{a^2}\f]
  \li Eccentricity Prime - also called Eccentricity Squared Prime \f$e^2_p\f$ is
       represented by \f[e^2_p = \frac{a^2 - b^2}{b^2}\f]

\image html ellipse.gif "Ellipsoid Parameters"

\verbatim
The Geo Library contains definitions of the following ellipsoids:

       Ellipsoid Name,                       ID,  Major Axis, Inverse Flattening
  ---------------------------------------------------------------------------
 Airy 1830,                                  AA, 6377563.396, 299.3249646
 Australian National,                        AN, 6378160    , 298.25
 Bessel 1841,                                BR, 6377397.155, 299.1528128
 Bessel 1841 (Namibia),                      BN, 6377483.865, 299.1528128
 Clarke 1866,                                CC, 6378206.4  , 294.9786982
 Clarke 1880,                                CD, 6378249.145, 293.465
 Everest (Brunei, E. Malaysia ),             EB, 6377298.556, 300.8017
 Everest 1830,                               EA, 6377276.345, 300.8017
 Everest 1956 (India and Nepal),             EC, 6377301.243, 300.8017
 Everest (Pakistan),                         EF, 6377309.613, 300.8017
 Everest 1948 (W. Malaysia and Singapore),   EE, 6377304.063, 300.8017
 Everest 1969 (W. Malaysia),                 ED, 6377295.664, 300.8017
 Geodetic Reference System 1980,             RF, 6378137    , 298.257222101
 Helmert 1906,                               HE, 6378200    , 298.3
 Hough 1960,                                 HO, 6378270    , 297.0
 Indonesian 1974,                            ID, 6378160    , 298.247
 International 1924,                         IN, 6378388    , 297.0
 Krassovsky 1940,                            KA, 6378245    , 298.3
 Modified Airy,	                             AM, 6377340.189, 299.3249646
 Modified Fischer 1960,                      FA, 6378155    , 298.3
 South American 1969,                        SA, 6378160    , 298.25
 WGS 1972,                                   WD, 6378135    , 298.26
 WGS 1984,                                   WE, 6378137    , 298.257223563
\endverbatim

\ref Home


\subsection cosys Coordinate Systems
There are several coordinate systems used in the Geo Library.

\li \b Latitude (\f$\phi\f$), \b Longitude (\f$\lambda\f$), \b Height (\f$h\f$)
This coordinate system references a point on the Earth's ellipsoid.
Latitude and longitude are measured in degrees. Height is measured
in meters.

\image html latlon2.gif "Latitude, Longitude, and height"

\li \b Earth \b Fixed \b Geodetic \b Coordinates
This Cartesian coordinate system uses the center of the earth as a reference point.
The coordinates represent an X,Y,Z coordinate system. However, in Geo Library, these
coordinates are \e not called X,Y,Z. They are called E,F,G. This is to help
distinguish between the tangential plane X,Y,Z coordinate systems.

\image html ecefxyz.gif " Earth Fixed Geodetic Coordinates"

\li \b Range (\f$r\f$), \b Azimuth (\f$\alpha\f$), \b Elevation (\f$\epsilon\f$)
This polar coordinate system originates from a point on the Earth's ellipsoid.
\e Range (\f$r\f$) is measured in meters and represents the slant range from the
origin to the point.
\e Azimuth (\f$\alpha\f$) is measured clockwise from north (zero degrees) in degrees.
 \f$\epsilon\f$ is measured from the tangential plane upward. Also in degrees.

\image html rae.gif "Range, Azimuth, and Elevation Coordinates"

\li \b X, \b Y, \b Z (also known as ENU)
This coordinate system also originates at point on the Earth's ellipsoid. \e X
(also known as East) is measured in meters from the point eastward. \e Y
(also known as North) is measured in meters from the point northward. \e Z
(also known as Up) is measured in meters, in the tangential plane,
 in an upward direction.

\image html xyz.gif "X,Y,Z Cartesian Coordinates"

\ref Home


\subsection conv  Conversion Formulas

\li \b Range \f$r\f$, \b Azimuth \f$\alpha\f$, \b and \b Elevation \f$\epsilon\f$ \b to \b X,Y,Z
If the slant range \f$r\f$, azimuth \f$\alpha\f$, and elevation \f$\epsilon\f$
from the origin to a point are known, topocentric Cartesian coordinates can
be computed in the following manner:

\f[X = r \;    cos \, \epsilon \; sin \, \alpha \f]
\f[Y = r \;    cos \, \epsilon \; cos \, \alpha \f]
\f[Z = r \;    sin \, \epsilon  \f]

\image html xyz2aer.gif "Conversion of Range, Azimuth, and Elevation to E,F,G Geocentric Coordinates"


\li \b X,Y,Z \b to \b Range \f$r\f$, \b Azimuth \f$\alpha\f$, \b and \b Elevation \f$\epsilon\f$
 If Cartesian coordinates X,Y,Z are known, then slant range \f$r\f$,
azimuth \f$\alpha\f$, and elevation \f$\epsilon\f$ can be determined
this way:

\f[ r = \sqrt{X^2 + Y^2 + Z^2} \f]

\f[ \alpha = tan^{-1}\left\{\frac{X}{Y}\right\}
(if \;  \alpha < 0, \; then \; \alpha=\alpha +2\pi)\f]

\f[ \epsilon = tan^{-1}\left\{\frac{Z}{ \sqrt{X^2 + Y^2}}\right\}\f]




\li \b Latitude \f$\phi\f$, \b Longitude \f$\lambda\f$, \b Height \f$h\f$ \b to \b E,F,G
Geodetic coordinates, Latitude, longitude, and height can be converted to geocentric
coordinates through this method:

\f[Radius \; of \; curvature: \;  N=\frac{a}{\sqrt{1-e^2sin^2\phi}}\f]

\f[E=(N+h) \; cos\phi \; cos\lambda   \f]
\f[F=(N+h) \; cos\phi \; sin\lambda   \f]
\f[G=[N(1-e^2)+h] \; sin\phi   \f]


\li \b E,F,G \b to \b Latitude \f$\phi\f$, \b Longitude \f$\lambda\f$, \b Height \f$h\f$
Geocentric coordinates E,F,G can be converted to
latitude \f$\phi\f$, longitude \f$\lambda\f$, and height \f$h\f$ in the following manner:

\f[ p = \sqrt{E^2+F^2}\f]
\f[ u = tan^{-1}\left\{ \frac{G}{p} \; \frac{a}{b} \right\} \f]
\f[ \phi = tan^{-1} \left\{ \frac{G+e^2_p \; b \; sin^3u}{p - e^2 \; a \; cos^3u} \right\} \f]
\f[ u_p = tan^{-1} (( 1-f)tan \; \phi)\f]
\f[ h = \sqrt{(p-a \; cos \; u_p)^2 + (G-b \; sin \; u_p)^2} \f]
\f[ \lambda = tan^{-1} \left\{ \frac{E}{F} \right\}\f]
\note This routine will be exact only for WGS84 coordinates. All other
datums will be slightly off.

\subsection mag Geomagnetic Routines
The modeling of the earth's magnetic field is called \i geomagnetism. The most current
application of this model is magnetic declination - deflection of the compass needle off true north.
The earth's magnetic field is in constant motion. Thus, a stable model needed to be developed
so that one might be able to correct for the changes of the field in time.

By using the geomagnetic routines in this library, true north can be determined quite easily.

\section dll Using Visual Basic and Excel with the geoStarslib DLL 
geoStarsLib.dll can be used with VB, VBA, and other programs that can access external DLL's. The DLL must 
be located in the path to be used with Excel. The file \b \i geoTest.bas is an example of how the DLL
functions are called from VB. It tests the sun position at the current time. 
You must make sure that \b \i geo.bas is 
loaded in your project to provide the interface to the DLL.

All of the geoStarsLib routines can be called from Visual Basic using the \e \b Function and 
\e \b Call methods. 
The following routines are \e Excel \e Function friendly and were included for easy implementation in
spreadsheets:
	- geoDms2DD()
	- geoDms2Rads()
	- geoDD2Rads()
	- geoRads2DD()
	- geoLlh2E()
	- geoLlh2F()
	- geoLlh2G()
	- geoLlh2DiffX()
	- geoLlh2DiffY()
	- geoLlh2DiffZ()
	- geoXyz2R()
	- geoXyz2A()
	- geoXyz2E()
	- geoSunNowAz()
	- geoSunNowEl()
	- geoMagGetDecNow()

\include geoStarsExcel.h


\ref Home

\section how How do I ....
Here are some common questions:
  -# How do I convert Range, Azimuth, and Elevation to XYZ coordinates?
     - use geoRae2Xyz() \n\n
  -# How do I convert XYZ coordinates to Range, Azimuth, and Elevation?
     - use geoXyz2Rae() \n\n
  -# How do I get a Range, Azimuth, and Elevation from one point to another and all I have are their geodetic coordinates?
     - use geoInitLocation() to establish a base location and then again to establish the point location
     - use geoEfg2XyzDiff() to get the XYZ coordinates of the point (with the base as the origin).
     - use geoXyz2Rae() to get your polar coordinates \n\n
  -# How do I get X,Y,Z from one point to another and all I have are their geodetic coordinates?
     - use geoInitLocation() to establish a base location and then again to establish the point location
     - use geoEfg2XyzDiff() to get the XYZ coordinates of the point (with the base as the origin). \n\n
  -# How do I get earth centered coordinates (EFG) from Range, Azimuth, and Elevation?
     - use geoInitLocation() to establish a base location
     - use geoRae2Efg() \n\n
  -# How do I get the Latitude, Longitude and height of the point indicated by Range, Azimuth, and Elevation?
     - use geoInitLocation() to establish a base location
     - use geoRae2Efg() to get earth centered coordinates
     - use geoEfg2Llh() to get Latitude, Longitude, and height. \n\n
  -# How do I convert radians to degrees, minutes, and seconds?
     - use geoRads2Dms() \n\n
  -# How do I convert degrees, minutes, and seconds to radians?
     - use geoDms2Rads() \n\n
  -# How do I find out the magnetic declination given a Latitude and Longitude?
	- use geoMag() to get every blessed geomagnetic variable under the sun,  \i or...
	- use geoMagGetDec() to get just the magnetic declination,  \i or ...
	- use geoMagGetDecRet() to return a double precision value declination (also used in VB) \n\n
  -# How do I get the position of the sun right now?
     - use geoInitLocation() to establish a base location
     - use geoSunAzElNow() to get the Azimuth and Elevation \n\n
  -# How do I get the sun position for any day?
     - include time.h
     - use geoInitLocation() to establish a base location
     - fill in a tm structure with the date and time you want
     - use geoSunAzEltm() \n\n
  -# How do I get the sun position for any day when I only have a Julian date?
     - use geoInitLocation() to establish a base location
     - compute or obtain the Julian date/time
     - use geoSunAzElJD() to get the Azimuth and Elevation \n\n
  -# How do I get a date with this Julian?
     - get a life!

\ref Home
*/

#include <time.h>

#ifndef GEO_H
#define GEO_H

/* WHD, 10/5/2011 -- By default, this library wants to be built as
 * a DLL on Windows; but we want a .a file.  Defining GEO_LIB turns off
 * the DLL magic. */
#define GEO_LIB

#if defined(GEO_LIB) || !defined(WIN32)
#define DLL_API                  //!< DLL calling convention
#define DLL_CALLCONV             //!< DLL calling convention
#else
#define WIN32_LEAN_AND_MEAN
#define DLL_CALLCONV __stdcall
// The following ifdef block is the standard way of creating macros which make exporting
// from a DLL simpler. All files within this DLL are compiled with the GEO_EXPORTS
// symbol defined on the command line. this symbol should not be defined on any project
// that uses this DLL. This way any other project whose source files include this file see
// DLL_API functions as being imported from a DLL, wheras this DLL sees symbols
// defined with this macro as being exported.
#ifdef GEO_EXPORTS
#define DLL_API __declspec(dllexport)
#else
#define DLL_API __declspec(dllimport)
#endif // GEO_EXPORTS
#endif // GEO_LIB || !WIN32



#define GEO_DATUM_DEFAULT 0 //!< Default datum (WGS84)
#define GEO_DATUM_AA 1   //!< Datum : Airy 1830
#define GEO_DATUM_AN 2   //!< Datum : Australian National
#define GEO_DATUM_BR 3   //!< Datum : Bessel 1841
#define GEO_DATUM_BN 4   //!< Datum : Bessel 1841 (Namibia)
#define GEO_DATUM_CC 5   //!< Datum : Clarke 1866
#define GEO_DATUM_CD 6   //!< Datum : Clarke 1880
#define GEO_DATUM_EB 7   //!< Datum : Everest (Brunei, E. Malaysia (Sabah and Sarawak))
#define GEO_DATUM_EA 8   //!< Datum : Everest 1830
#define GEO_DATUM_EC 9   //!< Datum : Everest 1956 (India and Nepal)
#define GEO_DATUM_EF 10  //!< Datum : Everest (Pakistan)
#define GEO_DATUM_EE 11  //!< Datum : Everest 1948 (W. Malaysia and Singapore)
#define GEO_DATUM_ED 12  //!< Datum : Everest 1969 (W. Malaysia)
#define GEO_DATUM_RF 13  //!< Datum : Geodetic Reference System 1980
#define GEO_DATUM_HE 14  //!< Datum : Helmert 1906
#define GEO_DATUM_HO 15  //!< Datum : Hough 1960
#define GEO_DATUM_ID 16  //!< Datum : Indonesian 1974
#define GEO_DATUM_IN 17  //!< Datum : International 1924
#define GEO_DATUM_KA 18  //!< Datum : Krassovsky 1940
#define GEO_DATUM_AM 19  //!< Datum : Modified Airy
#define GEO_DATUM_FA 20  //!< Datum : Modified Fischer 1960
#define GEO_DATUM_SA 21  //!< Datum : South American 1969
#define GEO_DATUM_WD 22  //!< Datum : WGS 1972
#define GEO_DATUM_WE 23  //!< Datum : WGS 1984

#define GEO_DATUM_MAX GEO_DATUM_WE



#define GEO_OK     0      //!< Geo Library return OK
#define GEO_ERROR  1      //!< Geo Library return ERROR

#ifndef M_PI
#define M_PI            3.14159265358979323846  //!< Value of \f$\pi\f$
#endif
#define sqr(n)          pow(n,2.0)       //!< Squared value: \f$n^2\f$
#define cube(n)         pow(n,3.0)       //!< Cubed value: \f$n^3\f$

#define DEG_TO_RAD              (M_PI/180.0)      //!< Degrees to Radians conversion factor
#define RAD_TO_DEG              (180.0/M_PI)      //!< Radians to Degrees conversion factor
#define MIN_TO_DEG              (1.0/60.0)        //!< Minutes to Degrees conversion factor
#define DEG_TO_MIN              (60.0)            //!< Degrees to Minutes conversion factor
#define SEC_TO_DEG              (1.0/3600.0)      //!< Seconds to Degrees conversion factor
#define SIN_1                   (sin(SEC_TO_DEG*DEG_TO_RAD))
#define CIRCLE                  (360.0)
#define HALF_CIRCLE             (CIRCLE / 2.0)

//#define EARTH_RADIUS_APPROX     6400000.0


/*!
\def GEO_B(a,f)
All geodetic datums and ellipsoids are defined by flattening \f$f\f$ and the
major axis \f$a\f$. From these parameters, the other axis and
eccentricity can be calculated. \e Minor \e Axis \f$b\f$
of the Earth is calculated from the \e Inverse \e Flattening
\f$f^{-1}\f$ and the \e Major \e Axis \f$a\f$.

Where \f[b={a (1- \frac{1}{f^{-1}})}\f]
*/

/*!
\def GEO_FL(f)
Since the Geo Library \b ellips structure uses \e inverse \e flattening \f$f^{-1}\f$ then \e flattening
can be calculated by
\f[\frac{1}{f^{-1}}\f]

Duh!
*/

/*!
\def GEO_E2(a,f)
\e Eccentricity \e Squared \f$e^2\f$ is computed in the following manner:
\f[e^2 = \frac{a^2 - b^2}{a^2}\f]
*/
/*!
\def GEO_E2P(a,f)
\e Eccentricity \e Squared \e Prime \f$e^2_p\f$ is computed in the following manner:
\f[e^2_p = \frac{a^2 - b^2}{b^2}\f]
*/
#define GEO_B(a,f)                  (a*(1.0-(1.0/f)))
#define GEO_FL(f)                   (1.0/f)
#define GEO_E2(a,f)                 (((a*a) - ((GEO_B(a,f))*(GEO_B(a,f))))/(a*a))
#define GEO_E2P(a,f)                (((a*a) - ((GEO_B(a,f))*(GEO_B(a,f))))/((GEO_B(a,f))*(GEO_B(a,f))))




/* Define indices for 3-element coordinate set arrays: */
#define   GEO_LAT     0         //!< Latitude
#define   GEO_LON     1         //!< Longitude
#define   GEO_HGT     2         //!< Height  ( METERS )
#define   GEO_X       0         //!< X or East coordinate of the tangential plane ( METERS )
#define   GEO_Y       1         //!< Y or North coordinate of the tangential plane ( METERS )
#define   GEO_Z       2         //!< Z or Up coordinate of the tangential plane ( METERS )
#define   GEO_E       0         //!< E coordinate of Earth Fixed Geodetic coordinate ( METERS )
#define   GEO_F       1         //!< F coordinate of Earth Fixed Geodetic coordinate ( METERS )
#define   GEO_G       2         //!< G coordinate of Earth Fixed Geodetic coordinate ( METERS )
#define   GEO_RNG     0         //!< Slant range ( METERS )
#define   GEO_AZ      1         //!< Azimuth, clockwise from north
#define   GEO_EL      2         //!< Elevation, from horizon (0) up


#define GEO_SZ_ELLIPSOID_NAME 82     //!< Max size of the Ellipsoid name field



/*! \struct GEO_ELLIPSOID
This defines an earth ellipsoid with the least amount of information.
Additional information will be computed from these values
 */
typedef struct
{
   char name[GEO_SZ_ELLIPSOID_NAME]; /*!< Name/title of ellipsoid */
   char id[4];    /*!< ID designation of the ellipsoid */
   double a;      /*!< Major Earth axis in meters */
   double f1;     /*!< Inverse flattening value */
} GEO_ELLIPSOID;




/*! \struct GEO_LOCATION
This structure holds all of the pertinent location,
ellipsoid, and datum data associated with a location.
*/
typedef struct
{
   /* Geodetic coordinates */
   double lat;     /*!< Site Latitude in decimal degrees */
   double lon;     /*!< Site Longitude in decimal degrees */
   double hgt;     /*!< Site Height above the ellipsoid in meters */

   double rlat;    /*!< Radian value of latitude */
   double rlon;    /*!< Radian value of longitude */

   /* Sine and Cosine values */
   double slat;    /*!< Sine of latitude */
   double clat;    /*!< Cosine of latitude */
   double slon;    /*!< Sine of longitude */
   double clon;    /*!< Cosine of longitude */
   double tlat;    /*!< Tangent of latitude */

   /* Precomputed values (for speed) */
   double clonclat; /*!< Cos(lon) * Cos(lat) */
   double slonslat; /*!< Sin(lon) * Sin(lat) */
   double clonslat; /*!< Cos(lon) * Sin(lat) */
   double slonclat; /*!< Sin(lon) * Cos(lat) */

   /* Geocentric coordinates */
   double e;       /*!< X : Earth Fixed Geocentric (XYZ) Coordinates */
   double f;       /*!< Y : Earth Fixed Geocentric (XYZ) Coordinates */
   double g;       /*!< Z : Earth Fixed Geocentric (XYZ) Coordinates */

   /* Ellipsoid values */
   double a;      /*!< Major Earth axis in meters */
   double b;      /*!< Minor Earth axis in meters */
   double flat;   /*!< Earth flattening value */
   double e2;     /*!< Eccentricity squared */
   double e2p;    /*!< Eccentricity squared prime */
   double m1e2;   /*!< 1 - eccentricity squared */

   /* Geomagentism Related information */
   /* Caution: this field's value can change daily! (but not by much) */
   double Declination;    /*!< Geomagnetic Declination */

   /* Misc values */
   int datum;     /*!< Numeric datum value */
   char name[GEO_SZ_ELLIPSOID_NAME]; /*!< Site Name */
} GEO_LOCATION;

extern GEO_ELLIPSOID ellips[];
extern int geoSunError;



/*  \struct WMM_DATA
This structure contains the WMM-2005 coefficients.
*/
typedef struct
{
	int n;          //!< n
	int m;          //!< m
	double gnm;     //!< gnm
	double hnm;     //!< hnm
	double dgnm;    //!< dgnm
	double dhnm;    //!< dhnm
} WMM_DATA;

typedef struct EllipsoidData {
    double a;     /* - Major Axis. */         
    double b;     /* - Minor axis value. */
    double e2;    /* - Eccentricity squared. */
    double ee2;   /* - Eccentricity squared prime. */
    double flat;  /* - Earth Flattening. */
} EllipsoidData;


/* geo function prototypes */

#ifdef __cplusplus
extern "C" {
#endif


/* geoEllips function */
DLL_API void    DLL_CALLCONV geoGetEllipsoid(double *a,double *b,double *e2,double *ee2,double *f,int datum);
DLL_API int     DLL_CALLCONV geoInitLocation(GEO_LOCATION *l, double lat, double lon, double hgt, int datum,  char *name);

/* geoAstro functions */
DLL_API int     DLL_CALLCONV geoSunAzElNow(GEO_LOCATION *loc, double *az, double *el);
DLL_API int     DLL_CALLCONV geoSunAzEltm(GEO_LOCATION *loc, double *az, double *el, struct tm *newtime);
DLL_API int     DLL_CALLCONV geoSunAzElJD(GEO_LOCATION *loc, double *az, double *el, double tjd_now);
DLL_API int     DLL_CALLCONV geoGetSunError(void);
DLL_API int     DLL_CALLCONV geoGettm(int part);
DLL_API double  DLL_CALLCONV geoSunNowEl(double lat, double lon, double hgt);
DLL_API double  DLL_CALLCONV geoSunNowAz(double lat, double lon, double hgt);

/* geoPoint functions */
DLL_API int     DLL_CALLCONV geoEfg2XyzDiff (GEO_LOCATION *src_desc, GEO_LOCATION *tgt_desc,  double xyz_disp[]);
DLL_API void    DLL_CALLCONV geoRae2Efg     (GEO_LOCATION *loc, double aer_in[], double efg_out[]);
DLL_API void    DLL_CALLCONV geoEfg2Llh (int datum,  double efg[], double *lat, double *lon, double *hgt);

DLL_API void    DLL_CALLCONV geoEfg2LlhOpt (EllipsoidData *eld,  double efg[], double *lat, double *lon, double *hgt);

DLL_API void    DLL_CALLCONV geoLlh2Efg (double lat, double lon, double height,int datum, double *e,  double *f,  double *g);

DLL_API void    DLL_CALLCONV geoLlh2EfgOpt (double lat, double lon, double height, EllipsoidData *eld, double *e,  double *f,  double *g);

DLL_API double  DLL_CALLCONV geoLlh2E (double lat, double lon, double height,int datum);
DLL_API double  DLL_CALLCONV geoLlh2F (double lat, double lon, double height,int datum);
DLL_API double  DLL_CALLCONV geoLlh2G (double lat, double lon, double height,int datum);
DLL_API double  DLL_CALLCONV geoLlh2DiffX (double lat1, double lon1, double hgt1,int datum1, double lat2, double lon2, double hgt2,int datum2);
DLL_API double  DLL_CALLCONV geoLlh2DiffY (double lat1, double lon1, double hgt1,int datum1, double lat2, double lon2, double hgt2,int datum2);
DLL_API double  DLL_CALLCONV geoLlh2DiffZ (double lat1, double lon1, double hgt1,int datum1, double lat2, double lon2, double hgt2,int datum2);

DLL_API void    DLL_CALLCONV geoXyz2Rae (double xyz_in[], double rae_out[]);
DLL_API double  DLL_CALLCONV geoXyz2R (double x, double y, double z);
DLL_API double  DLL_CALLCONV geoXyz2A (double x, double y, double z);
DLL_API double  DLL_CALLCONV geoXyz2E (double x, double y, double z);


DLL_API void    DLL_CALLCONV geoRae2Xyz (double rae_in[], double xyz_out[]);
DLL_API double  DLL_CALLCONV geoRads2Decdms(double rads) ;
DLL_API void    DLL_CALLCONV geoRads2Dms(double rads,double *deg, double *min, double *sec, double *dir);
DLL_API double  DLL_CALLCONV geoRads2DD(double rads);
DLL_API double  DLL_CALLCONV geoDecdms2Rads(double in);
DLL_API double  DLL_CALLCONV geoDms2DD(double deg, double min, double sec, char *sign);
DLL_API double  DLL_CALLCONV geoDms2Rads(double deg, double min, double sec, char *sign);
DLL_API void    DLL_CALLCONV geoDD2Dms(double dd, double *deg, double *min, double *sec, double *dir);
DLL_API double  DLL_CALLCONV geoDD2Rads(double dd);


/* geoMag functions */
DLL_API int   DLL_CALLCONV geomg1( double alt,  double glat,  double glon,  double time,
			  double *dec, double *dip,  double *ti,   double *gv);

DLL_API int   DLL_CALLCONV geoMag( double alt,  double glat,  double glon,  double time,
			  double *dec, double *dip,  double *ti,   double *gv,
			  double *adec,double *adip, double *ati,
			  double *x,   double *y,    double *z,    double *h,
			  double *ax,  double *ay,   double *az,   double *ah);

DLL_API int     DLL_CALLCONV geoMagGetDec(double lat, double lon, double hgt, int month, int day, int year, double *dec);
DLL_API double  DLL_CALLCONV geoMagGetDecRet(double lat, double lon, double hgt, int month, int day, int year);
DLL_API int     DLL_CALLCONV geoMagFillDec(GEO_LOCATION *l, double *dec);
DLL_API double  DLL_CALLCONV geoMagGetDecNow(double lat, double lon, double hgt);



//void geoEfg2Llh(double efg[], double *lat, double *lon, double *hgt);

#ifdef __cplusplus
}
#endif

#endif // GEO_H
