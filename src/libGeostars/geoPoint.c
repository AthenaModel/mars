/*! \file geoPoint.c
    \brief  This file contains the geo library routines for:
       \li Conversion between coordinate systems
       \li Angle conversions
       \li Tangential plane calculations

*/

#include <stdio.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include "geoStars.h"


//-----------------------------------------------------------------
/*! \brief This routine will convert earth centered Cartesian
coordinates (E,F,G), into geodetic coordinates (latitude
\f$\phi\f$, longitude \f$\lambda\f$, and ellipsoid height \f$h\f$).

 \param  int datum
 \param  double efg[]   : EFG(xyz) in METERS
 \param  double *lat    : Latitude in RADIANS
 \param  double *lon    : Longitude in RADIANS
 \param  double *hgt    : Height in METERS
 \return nothing

\note This routine will be exact only for WGS84 coordinates. All other
datums will be slightly off.

*/


void    DLL_CALLCONV geoEfg2Llh (int datum,  double efg[],
                    double *lat, double *lon, double *hgt)
{
//    double phi,r,s,c,phi1;
//    int i;

    double p, u, u_prime, a, flat, b, e2, ee2,sign = 1.0;

    /* Get the ellipsoid parameters */
    geoGetEllipsoid (&a, &b, &e2, &ee2, &flat, datum);

#ifndef EFG2LLH
    // Computes EFG to lat, lon & height
    p = sqrt(sqr(efg[GEO_E]) + sqr(efg[GEO_F]));
//    u = atan((efg[GEO_G]/p)  * (a/b));
    u = atan2(efg[GEO_G] * a , p * b);

    *lat = atan((efg[GEO_G] + ee2 * b * pow(sin(u),3.0) ) /
          ( p - e2 * a * pow(cos(u),3.0) ) );

    u_prime =  atan((1.0 - flat) * tan(*lat));
    if((p - a * cos(u_prime) ) < 0.0) sign= -1.0; // determine sign

//     *hgt = p / cos(*lat) - ( a / (sqrt(1.0 - e2 * pow(sin(*lat),2.0))));   //same results
    *hgt =  sign * sqrt( sqr( p - a * cos(u_prime)) +
                         sqr(efg[GEO_G] - b * sin(u_prime)));
    *lon = atan2(efg[GEO_F], efg[GEO_E]);  // atan(f/e)
#else
    // Computes EFG to lat, lon & height
//    p = sqrt(sqr(efg[GEO_E]) + sqr(efg[GEO_F]));
//    u = atan((efg[GEO_G]/p) * ((1.0 - flat) + (e2 * a / (sqrt(sqr(p)+sqr(efg[GEO_G])))))); //  atan((efg[GEO_G]/p)  * (a/b));
//    *lat = atan2((efg[GEO_G]*(1.0 - flat) + e2 * a * pow(sin(u),3.0) ),
//          ((1.0-flat) * ( p - e2 * a * pow(cos(u),3.0) ) ) );

//    u_prime =  atan((1.0 - flat) * tan(*lat));
//    if((p - a * cos(u_prime) ) < 0.0) sign= -1.0; // determine sign

//    *hgt =  sign * sqrt( sqr( p - a * cos(u_prime)) +
//                         sqr(efg[GEO_G] - b * sin(u_prime)));
    *lon = atan2(efg[GEO_F], efg[GEO_E]);  // atan(f/e)
     r = sqrt(sqr(efg[GEO_E]) + sqr(efg[GEO_F]));
     phi = atan2(efg[GEO_G], r);
 //     printf("phi(1)=%f\n",phi * RAD_TO_DEG);
     for(i=0;i<15;i++)
     {
        phi1 = phi;
        c = sqrt(1.0 - e2*pow(sin(phi1),2.0));
        phi = atan2((efg[GEO_G] + a * c * e2 * sin(phi1)),r);
//        printf("phi=%f\n",phi * RAD_TO_DEG);
        if( phi == phi1) break;
     }
     *lat = phi;
//     printf("c=%f\n",c);
//     *hgt = r / cos(phi) - ( a / (sqrt(1.0 - e2 * pow(sin(phi),2.0))));

     *hgt = r / cos(phi) - a*c;

#endif
}

void    DLL_CALLCONV geoEfg2LlhOpt (EllipsoidData *eld,  double efg[],
                    double *lat, double *lon, double *hgt)
{
//    double phi,r,s,c,phi1;
//    int i;

    double p, u, u_prime, sign = 1.0;

    /* Get the ellipsoid parameters */
    /* geoGetEllipsoid (&a, &b, &e2, &ee2, &flat, datum); */

#ifndef EFG2LLH
    // Computes EFG to lat, lon & height
    p = sqrt(sqr(efg[GEO_E]) + sqr(efg[GEO_F]));
//    u = atan((efg[GEO_G]/p)  * (a/b));
    u = atan2(efg[GEO_G] * eld->a , p * eld->b);

    *lat = atan((efg[GEO_G] + eld->ee2 * eld->b * pow(sin(u),3.0) ) /
          ( p - eld->e2 * eld->a * pow(cos(u),3.0) ) );

    u_prime =  atan((1.0 - eld->flat) * tan(*lat));
    if((p - eld->a * cos(u_prime) ) < 0.0) sign= -1.0; // determine sign

//     *hgt = p / cos(*lat) - ( a / (sqrt(1.0 - e2 * pow(sin(*lat),2.0))));   //same results
    *hgt =  sign * sqrt( sqr( p - eld->a * cos(u_prime)) +
                         sqr(efg[GEO_G] - eld->b * sin(u_prime)));
    *lon = atan2(efg[GEO_F], efg[GEO_E]);  // atan(f/e)
#else
    // Computes EFG to lat, lon & height
//    p = sqrt(sqr(efg[GEO_E]) + sqr(efg[GEO_F]));
//    u = atan((efg[GEO_G]/p) * ((1.0 - flat) + (e2 * a / (sqrt(sqr(p)+sqr(efg[GEO_G])))))); //  atan((efg[GEO_G]/p)  * (a/b));
//    *lat = atan2((efg[GEO_G]*(1.0 - flat) + e2 * a * pow(sin(u),3.0) ),
//          ((1.0-flat) * ( p - e2 * a * pow(cos(u),3.0) ) ) );

//    u_prime =  atan((1.0 - flat) * tan(*lat));
//    if((p - a * cos(u_prime) ) < 0.0) sign= -1.0; // determine sign

//    *hgt =  sign * sqrt( sqr( p - a * cos(u_prime)) +
//                         sqr(efg[GEO_G] - b * sin(u_prime)));
    *lon = atan2(efg[GEO_F], efg[GEO_E]);  // atan(f/e)
     r = sqrt(sqr(efg[GEO_E]) + sqr(efg[GEO_F]));
     phi = atan2(efg[GEO_G], r);
 //     printf("phi(1)=%f\n",phi * RAD_TO_DEG);
     for(i=0;i<15;i++)
     {
        phi1 = phi;
        c = sqrt(1.0 - eld->e2*pow(sin(phi1),2.0));
        phi = atan2((efg[GEO_G] + eld->a * eld->c * eld->e2 * sin(phi1)),r);
//        printf("phi=%f\n",phi * RAD_TO_DEG);
        if( phi == phi1) break;
     }
     *lat = phi;
//     printf("c=%f\n",c);
//     *hgt = r / cos(phi) - ( a / (sqrt(1.0 - e2 * pow(sin(phi),2.0))));

     *hgt = r / cos(phi) - eld->a*eld->c;

#endif
}

//-----------------------------------------------------------------
/*!
\brief This function returns the XYZ offset of the target point with
 respect to the source point, given the  Earth Fixed Geodetic
 coordinates of the points. The EFG  coordinates for the source
 must appear in the GEO_LOCATION  record, which must be built
 previous to the call to this procedure.

\param  GEO_LOCATION *src_desc
\param  GEO_LOCATION *tgt_desc
\param  double xyz_disp[]
\retval GEO_OK on success
\retval GEO_ERROR on error

\note This routine will allow you input site coordinates from two
different datums. It is up to the caller to make sure the datums are the
same (if it matters).
*/

int DLL_CALLCONV geoEfg2XyzDiff (GEO_LOCATION *src_desc,
		   GEO_LOCATION *tgt_desc,
		   double xyz_disp[])
  {
    double delta_e, delta_f, delta_g, intermed_val;

 //   if(src_desc->datum != tgt_desc->datum) return(GEO_ERROR);

    delta_e = tgt_desc->e - src_desc->e;
    delta_f = tgt_desc->f - src_desc->f;
    delta_g = tgt_desc->g - src_desc->g;

    intermed_val = (-src_desc->clon * delta_e) -
		   ( src_desc->slon * delta_f);

    xyz_disp[GEO_X] =
	(-src_desc->slon * delta_e) +
	( src_desc->clon * delta_f);
    xyz_disp[GEO_Y] =
	(src_desc->slat * intermed_val) +
	(src_desc->clat * delta_g);
    xyz_disp[GEO_Z] =
	(-src_desc->clat * intermed_val) +
	( src_desc->slat * delta_g);

    return(GEO_OK);

  } /* End procedure site_xyz_diff */

double  DLL_CALLCONV geoLlh2DiffX (double lat1, double lon1, double hgt1,int datum1, double lat2, double lon2, double hgt2,int datum2)
{
	double xyz[3];
	GEO_LOCATION site1, site2;
	
	geoInitLocation(&site1, lat1, lon1, hgt1, datum1,  "site1");
	geoInitLocation(&site2, lat2, lon2, hgt2, datum2,  "site2");
	geoEfg2XyzDiff(&site1, &site2,xyz);
	return(xyz[GEO_X]);

}

double  DLL_CALLCONV geoLlh2DiffY (double lat1, double lon1, double hgt1,int datum1, double lat2, double lon2, double hgt2,int datum2)
{
	double xyz[3];
	GEO_LOCATION site1, site2;
	
	geoInitLocation(&site1, lat1, lon1, hgt1, datum1,  "site1");
	geoInitLocation(&site2, lat2, lon2, hgt2, datum2,  "site2");
	geoEfg2XyzDiff(&site1, &site2,xyz);
	return(xyz[GEO_Y]);

}
double  DLL_CALLCONV geoLlh2DiffZ (double lat1, double lon1, double hgt1,int datum1, double lat2, double lon2, double hgt2,int datum2)
{
	double xyz[3];
	GEO_LOCATION site1, site2;
	
	geoInitLocation(&site1, lat1, lon1, hgt1, datum1,  "site1");
	geoInitLocation(&site2, lat2, lon2, hgt2, datum2,  "site2");
	geoEfg2XyzDiff(&site1, &site2,xyz);
	return(xyz[GEO_Z]);

}
//-----------------------------------------------------------------
/*!
\brief This routine will convert geodetic coordinates (latitude
\f$\phi\f$, longitude \f$\lambda\f$, and ellipsoid height \f$h\f$)
into earth centered Cartesian coordinates (E,F,G).

 \param  double lat        : Latitude in RADIANS
 \param  double lon        : Longitude in RADIANS
 \param  double height     : Height in METERS
 \param  int datum1
 \param  double *e         : E(x) in METERS
 \param  double *f         : F(y) in METERS
 \param  double *g         : G(z) in METERS
 \return nothing
*/


void   DLL_CALLCONV  geoLlh2Efg (double lat, double lon, double height,int datum,
                    double *e,  double *f,  double *g)

{
    double N,a,e2,ee2, b, flat;

    /* Get the ellipsoid parameters */
    geoGetEllipsoid(&a,&b,&e2,&ee2,&flat,datum);

    /* Compute the radius of curvature */
    N = a / (sqrt(1.0 - e2 * pow(sin(lat),2.0)));

    /* Compute the EFG(XYZ) coordinates (earth centered) */
    *e = (N + height) * cos(lat) * cos(lon);
    *f = (N + height) * cos(lat) * sin(lon);
    *g = (N * (1.0 - e2) + height) * sin(lat);

}

void   DLL_CALLCONV  geoLlh2EfgOpt (double lat, double lon, double height,
                                    EllipsoidData *eld,
                                    double *e,  double *f,  double *g)

{
    double N;

    /* Compute the radius of curvature */
    N = eld->a / (sqrt(1.0 - eld->e2 * pow(sin(lat),2.0)));

    /* Compute the EFG(XYZ) coordinates (earth centered) */
    *e = (N + height) * cos(lat) * cos(lon);
    *f = (N + height) * cos(lat) * sin(lon);
    *g = (N * (1.0 - eld->e2) + height) * sin(lat);

}

//-----------------------------------------------------------------
/*!
\brief This routine will convert geodetic coordinates (latitude
\f$\phi\f$, longitude \f$\lambda\f$, and ellipsoid height \f$h\f$)
into earth centered Cartesian coordinates (E,F,G). This returns the 
E component.

 \param  double lat        : Latitude in RADIANS
 \param  double lon        : Longitude in RADIANS
 \param  double height     : Height in METERS
 \param  int datum1
 \return  double *e         : E(x) in METERS
*/


double   DLL_CALLCONV  geoLlh2E (double lat, double lon, double hgt,int datum)

{
	GEO_LOCATION site;
	
	geoInitLocation(&site, lat, lon, hgt, datum,  "site");
	return(site.e);
}

//-----------------------------------------------------------------
/*!
\brief This routine will convert geodetic coordinates (latitude
\f$\phi\f$, longitude \f$\lambda\f$, and ellipsoid height \f$h\f$)
into earth centered Cartesian coordinates (E,F,G). This returns the 
F component.

 \param  double lat        : Latitude in RADIANS
 \param  double lon        : Longitude in RADIANS
 \param  double height     : Height in METERS
 \param  int datum1
 \return  double *f        : F(x) in METERS
*/


double   DLL_CALLCONV  geoLlh2F (double lat, double lon, double hgt,int datum)

{
	GEO_LOCATION site;
	
	geoInitLocation(&site, lat, lon, hgt, datum,  "site");
	return(site.f);
}

//-----------------------------------------------------------------
/*!
\brief This routine will convert geodetic coordinates (latitude
\f$\phi\f$, longitude \f$\lambda\f$, and ellipsoid height \f$h\f$)
into earth centered Cartesian coordinates (E,F,G). This returns the 
G component.

 \param  double lat        : Latitude in RADIANS
 \param  double lon        : Longitude in RADIANS
 \param  double height     : Height in METERS
 \param  int datum1
 \return  double *g         : G(x) in METERS
*/


double   DLL_CALLCONV  geoLlh2G (double lat, double lon, double hgt,int datum)

{
	GEO_LOCATION site;
	
	geoInitLocation(&site, lat, lon, hgt, datum,  "site");
	return(site.g);
}


//-----------------------------------------------------------------
/*!
 \brief Given the X, Y, and Z coordinates (in meters) of a point
 in space, the procedure geoXyz2Rae calculates the range,
 azimuth, and elevation to that point.

 \b Notes:
 \li X is understood to be the east-west displacement of the
 point, with east being the positive direction.
 \li Y is the north-south displacement, with north being positive.
 \li Z is the vertical displacement of the point.
 \li Range is in meters. Azimuth and elevation are in radians

\param  double xyz_in[]
\param  double rae_out[]
\return nothing

*/

void DLL_CALLCONV geoXyz2Rae (double xyz_in[],
		 double rae_out[])
  {
    double horz_dist;

    /* Determine the range: */
    rae_out[GEO_RNG] =
      sqrt(pow(xyz_in[GEO_X],2.0) + pow(xyz_in[GEO_Y],2.0) + pow(xyz_in[GEO_Z],2.0));

    /* Determine the azimuth: */
    rae_out[GEO_AZ] = atan2(xyz_in[GEO_X], xyz_in[GEO_Y]);
    //if((xyz_in[GEO_X] >= 0.0) && (xyz_in[GEO_Y] < 0.0)) rae_out[GEO_AZ] += M_PI;
    if((xyz_in[GEO_X] <  0.0) && (xyz_in[GEO_Y] < 0.0)) rae_out[GEO_AZ] += (2.0 * M_PI);
    if((xyz_in[GEO_X] <  0.0) && (xyz_in[GEO_Y] > 0.0)) rae_out[GEO_AZ] += (2.0 * M_PI);

    /* Determine the elevation: */
    horz_dist = sqrt(pow(xyz_in[GEO_X],2.0) + pow(xyz_in[GEO_Y],2.0));
    rae_out[GEO_EL] = atan2(xyz_in[GEO_Z], horz_dist);
    if(rae_out[GEO_EL] < 0.0) rae_out[GEO_EL] += (2.0 * M_PI);

  } /* End procedure xyz_to_rae */

//-----------------------------------------------------------------
/*!
 \brief Given the X, Y, and Z coordinates (in meters) of a point
 in space, the procedure geoXyz2R calculates the range to that point.

 \b Notes:
 \li X is understood to be the east-west displacement of the
 point, with east being the positive direction.
 \li Y is the north-south displacement, with north being positive.
 \li Z is the vertical displacement of the point.
 \li Range is in meters. 

\param  double xyz_in[]
\return double range

*/
double  DLL_CALLCONV geoXyz2R (double x, double y, double z)
{
      double rae[3],xyz[3];
	  xyz[0]=x;
	  xyz[1]=y;
	  xyz[2]=z;
	  geoXyz2Rae(xyz,rae);
	  return(rae[GEO_RNG]);
}


//-----------------------------------------------------------------
/*!
 \brief Given the X, Y, and Z coordinates (in meters) of a point
 in space, the procedure geoXyz2R calculates the azimuth to that point.

 \b Notes:
 \li X is understood to be the east-west displacement of the
 point, with east being the positive direction.
 \li Y is the north-south displacement, with north being positive.
 \li Z is the vertical displacement of the point.
 \li Azimuth is in decimal degrees

\param  double xyz_in[]
\return double azimuth

*/
double  DLL_CALLCONV geoXyz2A (double x, double y, double z)
{
      double rae[3],xyz[3];
	  xyz[0]=x;
	  xyz[1]=y;
	  xyz[2]=z;
	  geoXyz2Rae(xyz,rae);
	  return(rae[GEO_AZ]*RAD_TO_DEG);
}

//-----------------------------------------------------------------
/*!
 \brief Given the X, Y, and Z coordinates (in meters) of a point
 in space, the procedure geoXyz2R calculates the elevation angle to that point.

 \b Notes:
 \li X is understood to be the east-west displacement of the
 point, with east being the positive direction.
 \li Y is the north-south displacement, with north being positive.
 \li Z is the vertical displacement of the point.
 \li Elevation is in decimal degrees

\param  double xyz_in[]
\return double elevation

*/

double  DLL_CALLCONV geoXyz2E (double x, double y, double z)
{
      double rae[3],xyz[3];
	  xyz[0]=x;
	  xyz[1]=y;
	  xyz[2]=z;
	  geoXyz2Rae(xyz,rae);
	  return(rae[GEO_EL]*RAD_TO_DEG);
}

//-----------------------------------------------------------------
/*!
\brief This routine converts from Range, Azimuth, and Elevation
 into Cartesian coordinates X,Y,Z.

 \param double rae_in[]
 \param double xyz_out[]
 \return nothing
*/
void DLL_CALLCONV geoRae2Xyz (double rae_in[],
		 double xyz_out[])
  {
    double r_cos_e;

    r_cos_e = rae_in[GEO_RNG] * cos(rae_in[GEO_EL]);

    xyz_out[GEO_X] = sin(rae_in[GEO_AZ]) * r_cos_e;
    xyz_out[GEO_Y] = cos(rae_in[GEO_AZ]) * r_cos_e;
    xyz_out[GEO_Z] = rae_in[GEO_RNG] * sin(rae_in[GEO_EL]);

  }

//-----------------------------------------------------------------
/*!
 \brief Ingests Range, Azimuth, Elevation and site info and returns the EFG coordinates
 that the RAE points to.

 \param GEO_LOCATION *loc
 \param double aer_in[]
 \param double efg_out[]
 \return nothing
*/

void DLL_CALLCONV geoRae2Efg (GEO_LOCATION *loc,
		 double aer_in[],
		 double efg_out[])
  {
    double c1, c2, c3;
    double xyz_val[3];

    /* Convert the RAE value to XYZ: */
    geoRae2Xyz(aer_in, xyz_val);

    /* Do the matrix multiplication: */

    c1 = -loc->slon * xyz_val[GEO_X] +
	 -loc->clon * loc->slat * xyz_val[GEO_Y] +
	  loc->clon * loc->clat * xyz_val[GEO_Z];

    c2 =  loc->clon * xyz_val[GEO_X] +
	 -loc->slon * loc->slat * xyz_val[GEO_Y] +
	  loc->slon * loc->clat * xyz_val[GEO_Z];

    c3 = loc->clat * xyz_val[GEO_Y] +
	 loc->slat * xyz_val[GEO_Z];

    /* Add resultant matrix to local EFG to get remote EFG: */
    efg_out[GEO_E] = c1 + loc->e;
    efg_out[GEO_F] = c2 + loc->f;
    efg_out[GEO_G] = c3 + loc->g;

  } /* End procedure aer_to_efg */


//-----------------------------------------------------------------
/*!
\brief Converts degrees minutes seconds to radians.
\param double  deg, min, sec
\param char    sign            : N,E,S,W
\return radians
*/
double  DLL_CALLCONV geoDms2Rads(double deg, double min, double sec, char *sign)
{
    double direction;

    switch (toupper(*sign))
    {
      case   'W':                    /* If coordinate is West or South, returned */
      case   'S':
             direction = -1.0;       /* radian will have negative value.         */
           break;
      case   'E':                    /* If coordinate is East or North, returned */
      case   'N':
             direction = 1.0;        /* radian will have positive value.         */
           break;
      default:
             direction = 1.0;        /* If no compass direction entered, returned*/
    }                                /* radian will be assumed positive.         */

    /* Return radians to calling function. */
    return( direction * DEG_TO_RAD *
        ( fabs(deg) + (min * MIN_TO_DEG) + (sec * SEC_TO_DEG)));
}
//-----------------------------------------------------------------
/*!
\brief Converts degrees minutes seconds to Decimal Degrees
\param double  deg, min, sec
\param char    sign            : N,E,S,W
\return decimal degrees
*/
double  DLL_CALLCONV geoDms2DD(double deg, double min, double sec, char *sign)
{
    double direction;

    switch (toupper(*sign))
    {
      case   'W':                    /* If coordinate is West or South, returned */
      case   'S':
             direction = -1.0;       /* radian will have negative value.         */
           break;
      case   'E':                    /* If coordinate is East or North, returned */
      case   'N':
             direction = 1.0;        /* radian will have positive value.         */
           break;
      default:
             direction = 1.0;        /* If no compass direction entered, returned*/
    }                                /* radian will be assumed positive.         */

    /* Return radians to calling function. */
    return( direction *
        ( fabs(deg) + (min * MIN_TO_DEG) + (sec * SEC_TO_DEG)));
}



//-----------------------------------------------------------------
/*!
\brief  Convert decimal degrees, minutes, and seconds ("dmmss.s") to radians.
\param double in; // decimal deg,min,sec
\return radians
*/
double DLL_CALLCONV geoDecdms2Rads(double in)       /* minutes and seconds */
{
   double t1,m,d,s,sign;

   if (in < 0.0)
      sign = -1.0;
   else
      sign =  1.0;

   s = modf(fabs(in)/100.0, &t1) * 100.0;
   m = modf(t1/100.0,        &d) * 100.0;

   /* Return radians to calling function. */
   return( (d + (m/60.0) + (s/3600.0)) * sign * DEG_TO_RAD);
}

//-----------------------------------------------------------------
/*!
\brief Converts radians to degrees minutes seconds.
\param double rads
\param double  deg, min, sec
\param char    dir            : -1.0 or 1.0
\return nothing
*/


void  DLL_CALLCONV geoRads2Dms(double rads,
           double *deg, double *min, double *sec, double *dir)
{

   double temp;
   double fraction;


   if (rads < 0.0)
     *dir = -1.0;
   else
     *dir =  1.0;

   rads = fabs (rads);

   temp = RAD_TO_DEG * rads;
   fraction = modf(temp,deg);

   temp = fraction * 60.0;
   fraction = modf(temp,min);

   *sec = fraction * 60.0;
}

//-----------------------------------------------------------------
/*!
\brief Convert radians to decimal degrees, minutes, and seconds ("dddmmss.s").
\param double rads
\return double Decimal Deg/min/sec
 */
double DLL_CALLCONV geoRads2Decdms(double rads)
{
      double d,m,s,sign;
      double frac;

      if (rads < 0.0)
          sign = -1.0;
      else
          sign =  1.0;

      frac = modf(fabs(rads * RAD_TO_DEG),&d);
      frac = modf(frac * 60.0,&m);
      s = frac * 60.0;

      /* Return dddmmss.s to calling function. */
      return(((d*10000.0)+(m*100)+s)*sign);
}

//-----------------------------------------------------------------
/*!
\brief Converts radians to Decimal Degrees
\param double radians
\return double decimal degrees
*/


double  DLL_CALLCONV geoRads2DD(double rads)
{

  return(rads * RAD_TO_DEG);
}

//-----------------------------------------------------------------
/*!
\brief Converts Decimal Degrees to radians
\param double decimal degrees
\return radians
*/


double  DLL_CALLCONV geoDD2Rads(double dd)
{

  return(dd * DEG_TO_RAD);
}


//-----------------------------------------------------------------
/*!
\brief Converts Decimal Degrees to degrees minutes seconds.
\param double decimal degrees
\param double  deg, min, sec
\param char    dir            : -1.0 or 1.0
\return nothing
*/


void  DLL_CALLCONV geoDD2Dms(double dd,
           double *deg, double *min, double *sec, double *dir)
{

   double temp;
   double fraction;


   if (dd < 0.0)
     *dir = -1.0;
   else
     *dir =  1.0;

   dd = fabs (dd);

   //temp = RAD_TO_DEG * rads;
   fraction = modf(dd,deg);

   temp = fraction * 60.0;
   fraction = modf(temp,min);

   *sec = fraction * 60.0;
}

