#include <math.h>
#include <float.h>
#include <stdio.h>
#include <stdlib.h>

#include "dmemory.h"

#ifndef  M_PI
#define  M_PI        3.14159265358979323846  /* pi */
#endif

#ifndef  M_SQRT2
#define  M_SQRT2     1.41421356237309504880
#endif


static
void cpledn(int kn, int kodd, double *pfn, double pdx, int kflag, 
            double *pw, double *pdxn, double *pxmod)
{
  double zdlk;
  double zdlldn;
  double zdlx;
  double zdlmod;
  double zdlxn;

  int ik, jn;

  /* 1.0 Newton iteration step */

  zdlx = pdx;
  zdlk = 0.0;
  if (kodd == 0) 
    {
      zdlk = 0.5*pfn[0];
    }
  zdlxn  = 0.0;
  zdlldn = 0.0;

  ik = 1;

  if (kflag == 0) 
    {
      for(jn = 2-kodd; jn <= kn; jn += 2) 
	{
	  /* normalised ordinary Legendre polynomial == \overbar{p_n}^0 */
	  zdlk   = zdlk + pfn[ik]*cos((double)(jn)*zdlx);
	  /* normalised derivative == d/d\theta(\overbar{p_n}^0) */
	  zdlldn = zdlldn - pfn[ik]*(double)(jn)*sin((double)(jn)*zdlx);
	  ik++;
	}
      /* Newton method */
      zdlmod = -(zdlk/zdlldn);
      zdlxn = zdlx + zdlmod;
      *pdxn = zdlxn;
      *pxmod = zdlmod;
    }

  /* 2.0 Compute weights */

  if (kflag == 1) 
    {
      for(jn = 2-kodd; jn <= kn; jn += 2) 
	{
	  /* normalised derivative */
	  zdlldn = zdlldn - pfn[ik]*(double)(jn)*sin((double)(jn)*zdlx);
	  ik++;
	}
      *pw = (double)(2*kn+1)/(zdlldn*zdlldn);
    }

  return;
}

static
void gawl(double *pfn, double *pl, double *pw, int kn, int *kiter)
{
  int iodd;
  double pmod = 0;
  int iflag;
  int itemax;
  int jter;
  double zw = 0;
  double zdlx;
  double zdlxn = 0;

  /* 1.0 Initizialization */

  iflag  =  0;
  itemax = 20;

  iodd   = (kn % 2);

  zdlx   =  *pl;

  /* 2.0 Newton iteration */

  for (jter = 1; jter <= itemax+1; jter++) 
    {
      *kiter = jter;
      cpledn(kn, iodd, pfn, zdlx, iflag, &zw, &zdlxn, &pmod);
      zdlx = zdlxn;
      if (iflag == 1) break;
      if (fabs(pmod) <= DBL_EPSILON*1000.0) iflag = 1;
    }

  *pl = zdlxn;
  *pw = zw;

  return;
}

static
void gauaw(int kn, double *pl, double *pw)
{
  /*
   * 1.0 Initialize Fourier coefficients for ordinary Legendre polynomials
   *
   * Belousov, Swarztrauber, and ECHAM use zfn(0,0) = sqrt(2)
   * IFS normalisation chosen to be 0.5*Integral(Pnm**2) = 1 (zfn(0,0) = 2.0)
   */
  double *zfn, *zfnlat;

  double z, zfnn;

  int *iter;

  int ik, ins2, isym, jgl, jglm1, jn, iodd;

  iter   = (int *)    malloc(kn*sizeof(int));
  zfn    = (double *) malloc((kn+1)*(kn+1)*sizeof(double));
  zfnlat = (double *) malloc((kn/2+1+1)*sizeof(double));  

  zfn[0] = M_SQRT2;
  for (jn = 1; jn <= kn; jn++)
    {
      zfnn = zfn[0];
      for (jgl = 1; jgl <= jn; jgl++)
	{
	  zfnn *= sqrt(1.0-0.25/((double)(jgl*jgl))); 
	}

      zfn[jn*(kn+1)+jn] = zfnn;

      iodd = jn % 2;
      for (jgl = 2; jgl <= jn-iodd; jgl += 2) 
	{
	  zfn[jn*(kn+1)+jn-jgl] = zfn[jn*(kn+1)+jn-jgl+2]
	    *((double)((jgl-1)*(2*jn-jgl+2)))/((double)(jgl*(2*jn-jgl+1)));
	}
    }


  /* 2.0 Gaussian latitudes and weights */

  iodd = kn % 2;
  ik = iodd;
  for (jgl = iodd; jgl <= kn; jgl += 2)
    {
      zfnlat[ik] = zfn[kn*(kn+1)+jgl];
      ik++;
    } 

  /*
   * 2.1 Find first approximation of the roots of the
   *     Legendre polynomial of degree kn.
   */

  ins2 = kn/2+(kn % 2);

  for (jgl = 1; jgl <= ins2; jgl++) 
    {
      z = ((double)(4*jgl-1))*M_PI/((double)(4*kn+2)); 
      pl[jgl-1] = z+1.0/(tan(z)*((double)(8*kn*kn)));
    }

  /* 2.2 Computes roots and weights for transformed theta */

  for (jgl = ins2; jgl >= 1 ; jgl--) 
    {
      jglm1 = jgl-1;
      gawl(zfnlat, &(pl[jglm1]), &(pw[jglm1]), kn, &(iter[jglm1]));
    }

  /* convert to physical latitude */

  for (jgl = 0; jgl < ins2; jgl++) 
    {
      pl[jgl] = cos(pl[jgl]);
    }

  for (jgl = 1; jgl <= kn/2; jgl++) 
    {
      jglm1 = jgl-1;
      isym =  kn-jgl;
      pl[isym] =  -pl[jglm1];
      pw[isym] =  pw[jglm1];
    }

  free(zfnlat);
  free(zfn);
  free(iter);

  return;
}

static
void gauaw_old(double *pa, double *pw, int nlat)
{
  /*
   * Compute Gaussian latitudes.  On return pa contains the
   * sine of the latitudes starting closest to the north pole and going
   * toward the south
   *
   */

  const int itemax = 20;

  int isym, iter, ins2, jn, j;
  double za, zw, zan;
  double z, zk, zkm1, zkm2, zx, zxn, zldn, zmod;

  /*
   * Perform the Newton loop
   * Find 0 of Legendre polynomial with Newton loop
   */

  ins2 = nlat/2 + nlat%2;

  for ( j = 0; j < ins2; j++ )
    {
      z = (double) (4*(j+1)-1)*M_PI / (double) (4*nlat+2);
      pa[j] = cos(z + 1.0/(tan(z)*(double)(8*nlat*nlat)));
    }

  for ( j = 0; j < ins2; j++ )
    {

      za = pa[j];

      iter = 0;
      do
	{
	  iter++;
	  zk = 0.0;

	  /* Newton iteration step */

	  zkm2 = 1.0;
	  zkm1 = za;
	  zx = za;
	  for ( jn = 2; jn <= nlat; jn++ )
	    {
	      zk = ((double) (2*jn-1)*zx*zkm1-(double)(jn-1)*zkm2) / (double)(jn);
	      zkm2 = zkm1;
	      zkm1 = zk;
	    }
	  zkm1 = zkm2;
	  zldn = ((double) (nlat)*(zkm1-zx*zk)) / (1.-zx*zx);
	  zmod = -zk/zldn;
	  zxn = zx+zmod;
	  zan = zxn;

	  /* computes weight */

	  zkm2 = 1.0;
	  zkm1 = zxn;
	  zx = zxn;
	  for ( jn = 2; jn <= nlat; jn++ )
	    {
	      zk = ((double) (2*jn-1)*zx*zkm1-(double)(jn-1)*zkm2) / (double) (jn);
	      zkm2 = zkm1;
	      zkm1 = zk;
	    }
	  zkm1 = zkm2;
	  zw = (1.0-zx*zx) / ((double) (nlat*nlat)*zkm1*zkm1);
	  za = zan;
	}
      while ( iter <= itemax && fabs(zmod) >= DBL_EPSILON );

      pa[j] = zan;
      pw[j] = 2.0*zw;
    }

#if defined (SX)
#pragma vdir nodep
#endif
  for (j = 0; j < nlat/2; j++)
    {
      isym = nlat-(j+1);
      pa[isym] = -pa[j];
      pw[isym] =  pw[j];
    }

  return;
}


void gaussaw(double *pa, double *pw, int nlat)
{
  //gauaw_old(pa, pw, nlat);
  gauaw(nlat, pa, pw);
}

/*
#define NGL  48

int main (int rgc, char *argv[])
{
  int ngl = NGL;
  double plo[NGL], pwo[NGL];
  double pl[NGL], pw[NGL];

  int i;

  gauaw(ngl, pl, pw);
  gauaw_old(plo, pwo, ngl);

  for (i = 0; i < ngl; i++)
    {
      fprintf(stderr, "%4d%25.18f%25.18f%25.18f%25.18f\n", i, pl[i], pw[i], pl[i]-plo[i], pw[i]-pwo[i]);
    }

  return 0;
}
*/
