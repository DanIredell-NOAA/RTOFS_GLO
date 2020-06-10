#if defined (HAVE_CONFIG_H)
#  include "../src/config.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <math.h>

#include <cdi.h>
int      vlistInqVarMissvalUsed(int vlistID, int varID);
#ifndef DBL_IS_NAN
#if  defined  (HAVE_ISNAN)
#  define DBL_IS_NAN(x)     (isnan(x))
#elif  defined  (FP_NAN)
#  define DBL_IS_NAN(x)     (fpclassify(x) == FP_NAN)
#else
#  define DBL_IS_NAN(x)     ((x) != (x))
#endif
#endif

#ifndef DBL_IS_EQUAL
/*#define DBL_IS_EQUAL(x,y) (!(x < y || y < x)) */
#  define DBL_IS_EQUAL(x,y) (DBL_IS_NAN(x)||DBL_IS_NAN(y)?(DBL_IS_NAN(x)&&DBL_IS_NAN(y)?1:0):!(x < y || y < x))
#endif

#ifndef IS_EQUAL
#  define IS_NOT_EQUAL(x,y) (x < y || y < x)
#  define IS_EQUAL(x,y)     (!IS_NOT_EQUAL(x,y))
#endif


#include "printinfo.h"

void cdiDecodeDate(int date, int *year, int *month, int *day);
void cdiDecodeTime(int time, int *hour, int *minute, int *second);


int getopt(int argc, char *const argv[], const char *optstring);

extern char *optarg;
extern int optind, opterr, optopt;


char *Progname;

int DefaultFileType  = CDI_UNDEFID;
int DefaultDataType  = CDI_UNDEFID;
int DefaultByteorder = CDI_UNDEFID;

int Ztype  = COMPRESS_NONE;
int Zlevel = 0;


static
void version(void)
{
  fprintf(stderr, "CDI version 1.7.1\n");
  cdiPrintVersion();
  fprintf(stderr, "\n");
/*
  1.0.0   6 Feb 2001 : initial version
  1.1.0  30 Jul 2003 : missing values implemented
  1.2.0   8 Aug 2003 : changes for CDI library version 0.7.0
  1.3.0  10 Feb 2004 : changes for CDI library version 0.7.9
  1.4.0   5 May 2004 : changes for CDI library version 0.8.1 (error handling)
  1.4.1  18 Sep 2004 : netCDF 2 support
  1.4.2  22 Mar 2005 : change level from int to double
  1.4.3  11 Apr 2005 : change date and time format to ISO
  1.5.0  22 Nov 2005 : IEG support
  1.5.1  21 Feb 2006 : add option -s for short info
  1.6.0   1 Aug 2006 : add option -z szip for SZIP compression of GRIB records
  1.6.1  27 Feb 2007 : short info with ltype for GENERIC zaxis
  1.6.2   3 Jan 2008 : changes for CDI library version 1.1.0 (compress)
  1.6.3  26 Mar 2008 : call streamDefTimestep also if ntsteps = 0 (buf fix)
  1.7.0  11 Apr 2008 : add option -z zip for deflate compression of netCDF4 variables
  1.7.1   1 Nov 2009 : add option -z jpeg for JPEG compression of GRIB2 records
*/
}

static
void usage(void)
{
  char *name;
  int id;

  fprintf(stderr, "usage : %s  [Option]  [ifile]  [ofile]\n", Progname);

  fprintf(stderr, "\n");
  fprintf(stderr, "  Options:\n");
  fprintf(stderr, "    -d             Print debugging information\n");
  fprintf(stderr, "    -f <format>    Format of the output file. (grb, grb2, nc, nc2, nc4, src, ext or ieg)\n");
  fprintf(stderr, "    -s             give short information if ofile is missing\n");
  fprintf(stderr, "    -t <table>     Parameter table name/file\n");
  fprintf(stderr, "                   Predefined tables: ");
  for ( id = 0; id < tableInqNumber(); id++ )
    if ( (name = tableInqNamePtr(id)) )
      fprintf(stderr, " %s", name);
  fprintf(stderr, "\n");

  fprintf(stderr, "    -V             Print version number\n");
  fprintf(stderr, "    -z szip        SZIP compression of GRIB1 records\n");
  fprintf(stderr, "       jpeg        JPEG compression of GRIB2 records\n");
  fprintf(stderr, "        zip        Deflate compression of netCDF4 variables\n");
  fprintf(stderr, "\n");
  fprintf(stderr, "  Report bugs to <http://code.zmaw.de/projects/cdi>\n");
}


static
void printInfo(int gridtype, int vdate, int vtime, char *varname, double level,
	       int datasize, int number, int nmiss, double missval, const double *data, int vardis)
{
  static int rec = 0;
  int i, ivals = 0, imiss = 0;
  double arrmean, arrmin, arrmax;
  char vdatestr[32], vtimestr[32];
 
  if ( ! rec )
  {
    if ( vardis )
      fprintf(stdout, 
    "   Rec :       Date  Time    Varname      Level    Size    Miss :     Minimum        Mean     Maximum\n");
/*   ----1----+----2----+----3----+----4----+----5----+----6----+----7----+----8----+----9----+----0----+ */
    else
      fprintf(stdout, 
    "   Rec :       Date  Time    Param        Level    Size    Miss :     Minimum        Mean     Maximum\n");
/*   ----1----+----2----+----3----+----4----+----5----+----6----+----7----+----8----+----9----+----0----+ */
  }

  date2str(vdate, vdatestr, sizeof(vdatestr));
  time2str(vtime, vtimestr, sizeof(vtimestr));
	  
  fprintf(stdout, "%6d :%s %s %-10s %7g ", ++rec, vdatestr, vtimestr, varname, level);

  fprintf(stdout, "%7d ", datasize);

  fprintf(stdout, "%7d :", nmiss);

  /*
  if ( gridtype == GRID_SPECTRAL )
    {
      fprintf(stdout, "            %#12.5g\n", data[0]);
    }
  else
  */
  if ( number == CDI_REAL )
    {
      if ( nmiss > 0 )
	{
	  arrmean = 0;
	  arrmin  =  1.e300;
	  arrmax  = -1.e300;
	  for ( i = 0; i < datasize; i++ )
	    {
	      if ( !DBL_IS_EQUAL(data[i], missval) )
		{
		  if ( data[i] < arrmin ) arrmin = data[i];
		  if ( data[i] > arrmax ) arrmax = data[i];
		  arrmean += data[i];
		  ivals++;
		}
	    }
	  imiss = datasize - ivals;
	  datasize = ivals;
	}
      else
	{
	  arrmean = data[0];
	  arrmin  = data[0];
	  arrmax  = data[0];
	  for ( i = 1; i < datasize; i++ )
	    {
	      if ( data[i] < arrmin ) arrmin = data[i];
	      if ( data[i] > arrmax ) arrmax = data[i];
	      arrmean += data[i];
	    }
	}

      if ( datasize > 0 ) arrmean /= datasize;

      fprintf(stdout, "%#12.5g%#12.5g%#12.5g\n", arrmin, arrmean, arrmax);
    }
  else
    {
      int nvals_r = 0, nvals_i = 0;
      double arrsum_r, arrsum_i, arrmean_r = 0, arrmean_i = 0;
      arrsum_r = 0;
      arrsum_i = 0;

      for ( i = 0; i < datasize; i++ )
	{
	  if ( !DBL_IS_EQUAL(data[i*2], missval) )
	    {
	      arrsum_r += data[i*2];
	      nvals_r++;
	    }
	  if ( !DBL_IS_EQUAL(data[i*2+1], missval) )
	    {
	      arrsum_i += data[i*2+1];
	      nvals_i++;
	    }
	}

      imiss = datasize - nvals_r;

      if ( nvals_r > 0 ) arrmean_r = arrsum_r / nvals_r;
      if ( nvals_i > 0 ) arrmean_i = arrsum_i / nvals_i;
      fprintf(stdout, "  -  (%#12.5g,%#12.5g)  -\n", arrmean_r, arrmean_i);
    }

  if ( imiss != nmiss && nmiss > 0 )
    fprintf(stdout, "Found %d of %d missing values!\n", imiss, nmiss);
}


static
void printShortinfo(int streamID, int vlistID, int vardis)
{
  int varID;
  int gridsize = 0;
  int gridID, zaxisID, param;
  int zaxistype, ltype;
  int vdate, vtime;
  int nrecs, nvars, nzaxis, ntsteps;
  int levelID, levelsize;
  int tsID, ntimeout;
  int timeID, taxisID;
  int nbyte, nbyte0;
  int index;
  char varname[128];
  char longname[128];
  char units[128];
  double level;
  char *modelptr, *instptr;
  int datatype;
  int year, month, day, hour, minute, second;
  char pstr[4];
  char paramstr[32];

      printf("   File format: ");
      printFiletype(streamID, vlistID);

      if ( vardis )
	fprintf(stdout,
		"   Var : Institut Source   Varname     Time Typ  Grid Size Num  Levels Num\n");
      else
	fprintf(stdout,
		"   Var : Institut Source   Param       Time Typ  Grid Size Num  Levels Num\n");

      nvars = vlistNvars(vlistID);

      for ( varID = 0; varID < nvars; varID++ )
	{
	  param   = vlistInqVarParam(vlistID, varID);
	  gridID  = vlistInqVarGrid(vlistID, varID);
	  zaxisID = vlistInqVarZaxis(vlistID, varID);

	  cdiParamToString(param, paramstr, sizeof(paramstr));

	  if ( vardis ) vlistInqVarName(vlistID, varID, varname);

	  gridsize = gridInqSize(gridID);

	  fprintf(stdout, "%6d : ", varID + 1);

	  instptr = institutInqNamePtr(vlistInqVarInstitut(vlistID, varID));
	  if ( instptr )
	    fprintf(stdout, "%-9s", instptr);
	  else
	    fprintf(stdout, "unknown  ");

	  modelptr = modelInqNamePtr(vlistInqVarModel(vlistID, varID));
	  if ( modelptr )
	    fprintf(stdout, "%-9s", modelptr);
	  else
	    fprintf(stdout, "unknown  ");

	  if ( vardis )
	    fprintf(stdout, "%-12s", varname);
	  else
	    fprintf(stdout, "%-12s", paramstr);

	  timeID = vlistInqVarTime(vlistID, varID);
	  if ( timeID == TIME_CONSTANT )
	    fprintf(stdout, "con ");
	  else
	    fprintf(stdout, "var ");

	  datatype = vlistInqVarDatatype(vlistID, varID);
	  
	  if      ( datatype == DATATYPE_PACK   ) strcpy(pstr, "P0");
	  else if ( datatype > 0 && datatype <= 32  ) sprintf(pstr, "P%d", datatype);
	  else if ( datatype == DATATYPE_CPX32  ) strcpy(pstr, "C32");
	  else if ( datatype == DATATYPE_CPX64  ) strcpy(pstr, "C64");
	  else if ( datatype == DATATYPE_FLT32  ) strcpy(pstr, "F32");
	  else if ( datatype == DATATYPE_FLT64  ) strcpy(pstr, "F64");
	  else if ( datatype == DATATYPE_INT8   ) strcpy(pstr, "I8");
	  else if ( datatype == DATATYPE_INT16  ) strcpy(pstr, "I16");
	  else if ( datatype == DATATYPE_INT32  ) strcpy(pstr, "I32");
	  else if ( datatype == DATATYPE_UINT8  ) strcpy(pstr, "U8");
	  else if ( datatype == DATATYPE_UINT16 ) strcpy(pstr, "U16");
	  else if ( datatype == DATATYPE_UINT32 ) strcpy(pstr, "U32");
	  else                                    strcpy(pstr, "-1");

	  fprintf(stdout, " %-3s", pstr);

	  if ( vlistInqVarZtype(vlistID, varID) == COMPRESS_NONE )
	    fprintf(stdout, " ");
	  else
	    fprintf(stdout, "z");

	  fprintf(stdout, "%9d", gridsize);

	  fprintf(stdout, " %3d ", gridID + 1);

	  levelsize = zaxisInqSize(zaxisID);
	  fprintf(stdout, " %6d", levelsize);
	  fprintf(stdout, " %3d", zaxisID + 1);

	  fprintf(stdout, "\n");
	}

      fprintf(stdout, "   Horizontal grids :\n");
      printGridInfo(vlistID);

      nzaxis = vlistNzaxis(vlistID);
      fprintf(stdout, "   Vertical grids :\n");
      for ( index = 0; index < nzaxis; index++)
	{
	  zaxisID   = vlistZaxis(vlistID, index);
	  zaxistype = zaxisInqType(zaxisID);
	  ltype     = zaxisInqLtype(zaxisID);
	  levelsize = zaxisInqSize(zaxisID);
	  /* zaxisInqLongname(zaxisID, longname); */
	  zaxisName(zaxistype, longname);
	  longname[16] = 0;
	  zaxisInqUnits(zaxisID, units);
	  units[12] = 0;
	  if ( zaxistype == ZAXIS_GENERIC && ltype != 0 )
	    nbyte0    = fprintf(stdout, "  %4d : %-10s  (ltype=%3d) : ", zaxisID+1, longname, ltype);
	  else
	    nbyte0    = fprintf(stdout, "  %4d : %-16s  %5s : ", zaxisID+1, longname, units);
	  nbyte = nbyte0;
	  for ( levelID = 0; levelID < levelsize; levelID++ )
	    {
	      if ( nbyte > 80 )
		{
		  fprintf(stdout, "\n");
		  fprintf(stdout, "%*s", nbyte0, "");
		  nbyte = nbyte0;
		}
	      level = zaxisInqLevel(zaxisID, levelID);
	      nbyte += fprintf(stdout, "%.9g ", level);
	    }
	  fprintf(stdout, "\n");
	  if ( zaxisInqLbounds(zaxisID, NULL) && zaxisInqUbounds(zaxisID, NULL) )
	    {
	      double level1, level2;
	      nbyte = nbyte0;
	      nbyte0 = fprintf(stdout, "%32s : ", "bounds");
	      for ( levelID = 0; levelID < levelsize; levelID++ )
		{
		  if ( nbyte > 80 )
		    {
		      fprintf(stdout, "\n");
		      fprintf(stdout, "%*s", nbyte0, "");
		      nbyte = nbyte0;
		    }
		  level1 = zaxisInqLbound(zaxisID, levelID);
		  level2 = zaxisInqUbound(zaxisID, levelID);
		  nbyte += fprintf(stdout, "%.9g-%.9g ", level1, level2);
		}
	      fprintf(stdout, "\n");
	    }
	}

      taxisID = vlistInqTaxis(vlistID);
      ntsteps = vlistNtsteps(vlistID);

      if ( ntsteps != 0 )
	{
	  if ( ntsteps == CDI_UNDEFID )
	    fprintf(stdout, "   Time axis :  unlimited steps\n");
	  else
	    fprintf(stdout, "   Time axis :  %d step%s\n", ntsteps, ntsteps == 1 ? "" : "s");

	  if ( taxisID != CDI_UNDEFID )
	    {
	      int calendar, unit;

	      if ( taxisInqType(taxisID) == TAXIS_RELATIVE )
		{
		  vdate = taxisInqRdate(taxisID);
		  vtime = taxisInqRtime(taxisID);

		  cdiDecodeDate(vdate, &year, &month, &day);
		  cdiDecodeTime(vtime, &hour, &minute, &second);

		  fprintf(stdout, "     RefTime = %4.4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
			  year, month, day, hour, minute, second);
		      
		  unit = taxisInqTunit(taxisID);
		  if ( unit != CDI_UNDEFID )
		    {
		      if ( unit == TUNIT_YEAR )
			fprintf(stdout, "  Units = years");
		      else if ( unit == TUNIT_MONTH )
			fprintf(stdout, "  Units = months");
		      else if ( unit == TUNIT_DAY )
			fprintf(stdout, "  Units = days");
		      else if ( unit == TUNIT_HOUR )
			fprintf(stdout, "  Units = hours");
		      else if ( unit == TUNIT_MINUTE )
			fprintf(stdout, "  Units = minutes");
		      else if ( unit == TUNIT_SECOND )
			fprintf(stdout, "  Units = seconds");
		      else
			fprintf(stdout, "  Units = unknown");
		    }
	      
		  calendar = taxisInqCalendar(taxisID);
		  if ( calendar != CDI_UNDEFID )
		    {
		      if ( calendar == CALENDAR_STANDARD )
			fprintf(stdout, "  Calendar = STANDARD");
		      else if ( calendar == CALENDAR_PROLEPTIC )
			fprintf(stdout, "  Calendar = PROLEPTIC");
		      else if ( calendar == CALENDAR_360DAYS )
			fprintf(stdout, "  Calendar = 360DAYS");
		      else if ( calendar == CALENDAR_365DAYS )
			fprintf(stdout, "  Calendar = 365DAYS");
		      else if ( calendar == CALENDAR_366DAYS )
			fprintf(stdout, "  Calendar = 366DAYS");
		      else
			fprintf(stdout, "  Calendar = unknown");
		    }

		  fprintf(stdout, "\n");
		}
	    }

	  fprintf(stdout, "  YYYY-MM-DD hh:mm:ss  YYYY-MM-DD hh:mm:ss  YYYY-MM-DD hh:mm:ss  YYYY-MM-DD hh:mm:ss\n");

	  ntimeout = 0;
	  tsID = 0;
	  while ( (nrecs = streamInqTimestep(streamID, tsID)) )
	    {
	      if ( ntimeout == 4 )
		{
		  ntimeout = 0;
		  fprintf(stdout, "\n");
		}

	      vdate = taxisInqVdate(taxisID);
	      vtime = taxisInqVtime(taxisID);

	      cdiDecodeDate(vdate, &year, &month, &day);
	      cdiDecodeTime(vtime, &hour, &minute, &second);

	      fprintf(stdout, " %5.4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",
		      year, month, day, hour, minute, second);
	      ntimeout++;
	      tsID++;
	    }
	  fprintf(stdout, "\n");
	}
}


#undef  IsBigendian
#define IsBigendian()  ( u_byteorder.c[sizeof(long) - 1] )


static
void setDefaultDataType(char *datatypestr)
{
  static union {unsigned long l; unsigned char c[sizeof(long)];} u_byteorder = {1};
  int nbits = -1;
  enum {D_UINT, D_INT, D_FLT};
  int dtype = -1;

  if      ( *datatypestr == 'i' || *datatypestr == 'I' )
    {
      dtype = D_INT;
      datatypestr++;
    }
  else if ( *datatypestr == 'u' || *datatypestr == 'U' )
    {
      dtype = D_UINT;
      datatypestr++;
    }
  else if ( *datatypestr == 'f' || *datatypestr == 'F' )
    {
      dtype = D_FLT;
      datatypestr++;
    }

  if ( isdigit((int) *datatypestr) )
    {
      nbits = atoi(datatypestr);
      if ( nbits < 10 )
	datatypestr += 1;
      else
	datatypestr += 2;

      if ( dtype == -1 )
	{
	  if      ( nbits > 0 && nbits < 32 ) DefaultDataType = nbits;
	  else if ( nbits == 32 )
	    {
	      if ( DefaultFileType == FILETYPE_GRB )
		DefaultDataType = DATATYPE_PACK32;
	      else
		DefaultDataType = DATATYPE_FLT32;
	    }
	  else if ( nbits == 64 ) DefaultDataType = DATATYPE_FLT64;
	  else
	    {
	      fprintf(stderr, "Unsupported number of bits %d!\n", nbits);
	      fprintf(stderr, "Use 32/64 for filetype nc, srv, ext, ieg and 1-32 for grb.\n");
	      exit(EXIT_FAILURE);
	    }
	}
      else
	{
	  if ( dtype == D_INT )
	    {
	      if      ( nbits ==  8 ) DefaultDataType = DATATYPE_INT8;
	      else if ( nbits == 16 ) DefaultDataType = DATATYPE_INT16;
	      else if ( nbits == 32 ) DefaultDataType = DATATYPE_INT32;
	      else
		{
		  fprintf(stderr, "Unsupported number of bits = %d for datatype INT!\n", nbits);
		  exit(EXIT_FAILURE);
		}
	    }
	  /*
	  else if ( dtype == D_UINT )
	    {
	      if      ( nbits ==  8 ) DefaultDataType = DATATYPE_UINT8;
	      else
		{
		  fprintf(stderr, "Unsupported number of bits = %d for datatype UINT!\n", nbits);
		  exit(EXIT_FAILURE);
		}
	    }
	  */
	  else if ( dtype == D_FLT )
	    {
	      if      ( nbits == 32 ) DefaultDataType = DATATYPE_FLT32;
	      else if ( nbits == 64 ) DefaultDataType = DATATYPE_FLT64;
	      else
		{
		  fprintf(stderr, "Unsupported number of bits = %d for datatype FLT!\n", nbits);
		  exit(EXIT_FAILURE);
		}
	    }
	}
    }

  if ( *datatypestr == 'l' || *datatypestr == 'L' )
    {
      if ( IsBigendian() ) DefaultByteorder = CDI_LITTLEENDIAN;
      datatypestr++;
    }

  if ( *datatypestr == 'b' || *datatypestr == 'B' )
    {
      if ( ! IsBigendian() ) DefaultByteorder = CDI_BIGENDIAN;
      datatypestr++;
    }
}

static
void setDefaultFileType(char *filetypestr)
{
  if ( filetypestr )
    {
      char *ftstr = filetypestr;

      if      ( memcmp(filetypestr, "grb2", 4)  == 0 ) { ftstr += 4; DefaultFileType = FILETYPE_GRB2;}
      else if ( memcmp(filetypestr, "grb1", 4)  == 0 ) { ftstr += 4; DefaultFileType = FILETYPE_GRB; }
      else if ( memcmp(filetypestr, "grb",  3)  == 0 ) { ftstr += 3; DefaultFileType = FILETYPE_GRB; }
      else if ( memcmp(filetypestr, "nc2",  3)  == 0 ) { ftstr += 3; DefaultFileType = FILETYPE_NC2; }
      else if ( memcmp(filetypestr, "nc4",  3)  == 0 ) { ftstr += 3; DefaultFileType = FILETYPE_NC4; }
      else if ( memcmp(filetypestr, "nc",   2)  == 0 ) { ftstr += 2; DefaultFileType = FILETYPE_NC;  }
      else if ( memcmp(filetypestr, "srv",  3)  == 0 ) { ftstr += 3; DefaultFileType = FILETYPE_SRV; }
      else if ( memcmp(filetypestr, "ext",  3)  == 0 ) { ftstr += 3; DefaultFileType = FILETYPE_EXT; }
      else if ( memcmp(filetypestr, "ieg",  3)  == 0 ) { ftstr += 3; DefaultFileType = FILETYPE_IEG; }
      else
	{
	  fprintf(stderr, "Unsupported filetype %s!\n", filetypestr);
	  fprintf(stderr, "Available filetypes: grb, grb2, nc, nc2, nc4, srv, ext and ieg\n");
	  exit(EXIT_FAILURE);
	}

      if ( DefaultFileType != CDI_UNDEFID && *ftstr != 0 )
	{
	  if ( *ftstr == '_' )
	    {
	      ftstr++;

	      setDefaultDataType(ftstr);
	    }
	  else
	    {
	      fprintf(stderr, "Unexpected character >%c< in file type >%s<!\n", *ftstr, filetypestr);
	      fprintf(stderr, "Use format[_nbits] with:\n");
	      fprintf(stderr, "    format = grb, grb2, nc, nc2, nc4, srv, ext or ieg\n");
	      fprintf(stderr, "    nbits  = 32/64 for nc, nc2, nc4, srv, ext, ieg; 1 - 32 for grb, grb2\n");
	      exit(EXIT_FAILURE);
	    }
	}
    }
}


int handle_error(int cdiErrno, const char *fmt, ...)
{
  va_list args;
	
  va_start(args, fmt);

  printf("\n");
  vfprintf(stderr, fmt, args);
   fprintf(stderr, "\n");

  va_end(args);

  fprintf(stderr, "%s\n", cdiStringError(cdiErrno));

  return (cdiErrno);
}


void defineCompress(const char *arg)
{
  size_t len = strlen(arg);

  if      ( strncmp(arg, "szip", len) == 0 )
    {
      Ztype = COMPRESS_SZIP;
    }
  else if ( strncmp(arg, "jpeg", len) == 0 )
    {
      Ztype = COMPRESS_JPEG;
    }
  else if ( strncmp(arg, "gzip", len) == 0 )
    {
      Ztype = COMPRESS_GZIP;
      Zlevel = 6;
    }
  else if ( strncmp(arg, "zip", len) == 0 )
    {
      Ztype = COMPRESS_ZIP;
      Zlevel = 1;
    }
  else
    fprintf(stderr, "%s compression unsupported!\n", arg);
}



int main(int argc, char *argv[])
{
  int c;
  char *fname1 = NULL;
  char *fname2 = NULL;
  char *rTable = NULL;
  char *wTable = NULL;
  int Move = 0;
  int Record = 0;
  int Debug = 0;
  int Quiet  = 0;
  int Vardis = 0;
  int Version = 0;
  int Longinfo = 0;
  int Shortinfo = 0;
  int varID;
  int itableID = CDI_UNDEFID, otableID = CDI_UNDEFID;
  int Info = 1;
  char varname[128];
  char paramstr[32];

  Progname = strrchr(argv[0], '/');
  if (Progname == 0) Progname = argv[0];
  else               Progname++;

  while ( (c = getopt(argc, argv, "f:t:w:z:cdhlMmqRrsvVZ")) != EOF )
    {
      switch (c)
	{
	case 'd':
	  Debug = 1;
	  break;
	case 'f':
	  setDefaultFileType(optarg);
	  break;
	case 'h':
	  usage();
	  exit (0);
	case 'l':
	  Longinfo = 1;
	  break;
	case 'M':
	  cdiDefGlobal("HAVE_MISSVAL", 1);
	  break;
	case 'm':
	  Move = 1;
	  break;
	case 'q':
	  Quiet = 1;
	  break;
	case 'R':
	  cdiDefGlobal("REGULARGRID", 1);
	  break;
	case 'r':
	  Record = 1;
	  break;
	case 's':
	  Shortinfo = 1;
	  break;
	case 't':
	  rTable = optarg;
	  break;
	case 'v':
	  Vardis = 1;
	  break;
	case 'V':
	  Version = 1;
	  break;
	case 'w':
	  wTable = optarg;
	  break;
	case 'z':
	  defineCompress(optarg);
	  break;
	}
    }

  if ( optind < argc ) fname1 = argv[optind++];
  if ( optind < argc ) fname2 = argv[optind++];
  if ( optind < argc ) 
    {
      fprintf(stderr, "optind: %d argc: %d\n", optind, argc);
    }

  if ( Debug || Version ) version();

  if ( Debug ) cdiDebug(Debug);

  if ( rTable )
    {
      itableID = tableInq(-1, 0, rTable);
      otableID = itableID;
    }

  if ( fname1 == NULL && ! (Debug || Version) )
    {
      usage();
      exit (0);
    }

  if ( fname1 )
    {
      double *data = NULL;
      double missval;
      double level;
      int nmiss;
      int number;
      int datasize = 0;
      int streamID1 = CDI_UNDEFID;
      int streamID2 = CDI_UNDEFID;
      int filetype;
      int gridID, zaxisID;
      int param;
      int vdate, vtime;
      int nrecs, nvars;
      int levelID, levelsize;
      int nts = 0;
      int gridsize = 0;
      int recID;
      int tsID;
      int ntsteps = 0;
      int taxisID;
      int gridtype;
      int vlistID1, vlistID2 = CDI_UNDEFID;

      streamID1 = streamOpenRead(fname1);
      if ( streamID1 < 0 )
	return (handle_error(streamID1, "Open failed on %s", fname1));

      vlistID1 = streamInqVlist(streamID1);

      if ( Longinfo )
	{
	  int ngrids, nzaxis;
	  vlistPrint(vlistID1);
	  ngrids = vlistNgrids(vlistID1);
	  nzaxis = vlistNzaxis(vlistID1);
	  for ( gridID = 0; gridID < ngrids; gridID++ ) gridPrint(gridID, 1);
	  for ( zaxisID = 0; zaxisID < nzaxis; zaxisID++ ) zaxisPrint(zaxisID);
	}

      nvars   = vlistNvars(vlistID1);
      taxisID = vlistInqTaxis(vlistID1);
      ntsteps = vlistNtsteps(vlistID1);

      if ( Debug ) fprintf(stderr, "nvars = %d\n", nvars);
      if ( Debug ) fprintf(stderr, "ntsteps = %d\n", ntsteps);

      if ( fname2 ) vlistID2 = vlistDuplicate(vlistID1);
	  
      for ( varID = 0; varID < nvars; varID++)
	{
	  gridID   = vlistInqVarGrid(vlistID1, varID);
	  gridsize = gridInqSize(gridID);
	  if ( gridsize > datasize ) datasize = gridsize;
	  if ( fname2 )
	    {
	      if ( DefaultDataType != CDI_UNDEFID )
		vlistDefVarDatatype(vlistID2, varID, DefaultDataType);
	    }
	}

      if ( fname2 )
	{
	  Info = 0;
	  filetype = streamInqFiletype(streamID1);

	  if ( DefaultFileType != CDI_UNDEFID )
	    filetype = DefaultFileType;

	  streamID2 = streamOpenWrite(fname2, filetype);
	  if ( streamID2 < 0 )
	    return (handle_error(streamID2, "Open failed on %s", fname2));

	  if ( DefaultByteorder != CDI_UNDEFID )
	    streamDefByteorder(streamID2, DefaultByteorder);

	  if ( Ztype != COMPRESS_NONE )
	    {
	      streamDefZtype(streamID2, Ztype);
	      streamDefZlevel(streamID2, Zlevel);
	    }

	  streamDefVlist(streamID2, vlistID2);

	  if ( otableID == CDI_UNDEFID ) otableID = itableID;
	}
      
      if ( vlistNumber(vlistID1) != CDI_REAL ) datasize *= 2;
      data = (double *) malloc(datasize*sizeof(double));

      /*
	nts = cdiInqTimeSize(streamID1);
      */
      if ( Debug )
	printf("nts = %d\n", nts);

      if ( Debug )
	printf("streamID1 = %d, streamID2 = %d\n", streamID1, streamID2);

      if ( Shortinfo )
	{
	  Info = 0;
	  printShortinfo(streamID1, vlistID1, Vardis);
	}

      tsID = 0;
      if ( Info || fname2 )
      while ( (nrecs = streamInqTimestep(streamID1, tsID)) > 0 )
	{
	  if ( fname2 /* && ntsteps != 0*/ )
	    streamDefTimestep(streamID2, tsID);

	  vdate = taxisInqVdate(taxisID);
	  vtime = taxisInqVtime(taxisID);

	  if ( Debug )
	    fprintf(stdout, "tsID = %d nrecs = %d date = %d time = %d\n", tsID, nrecs, vdate, vtime);

	  if ( Record )
	    {
	      for ( recID = 0; recID < nrecs; recID++ )
		{
		  streamInqRecord(streamID1, &varID, &levelID);
		  streamReadRecord(streamID1, data, &nmiss);

		  number   = vlistInqVarNumber(vlistID1, varID);
		  gridID   = vlistInqVarGrid(vlistID1, varID);
		  zaxisID  = vlistInqVarZaxis(vlistID1, varID);
		  param    = vlistInqVarParam(vlistID1, varID);
 
		  cdiParamToString(param, paramstr, sizeof(paramstr));

		  if ( Vardis ) vlistInqVarName(vlistID1, varID, varname);
		  else          strcpy(varname, paramstr);
		  /*
		  printf("varID=%d, param=%d, gridID=%d, zaxisID=%d levelID=%d\n",
			 varID, param, gridID, zaxisID, levelID);
		  */
		  gridtype = gridInqType(gridID);
		  gridsize = gridInqSize(gridID);
		  level    = zaxisInqLevel(zaxisID, levelID);
		  missval  = vlistInqVarMissval(vlistID1, varID);
		  
		  if ( Info )
		    printInfo(gridtype, vdate, vtime, varname, level, gridsize, number, nmiss, missval, data, Vardis);

		  if ( fname2 )
		    {
		      streamDefRecord(streamID2, varID, levelID);
		      if ( Move )
			streamCopyRecord(streamID2, streamID1);
		      else
			streamWriteRecord(streamID2, data, nmiss);
		    }
	      	}
	    }
	  else
	    {
	      for ( varID = 0; varID < nvars; varID++ )
		{
		  if ( vlistInqVarTime(vlistID1, varID) == TIME_CONSTANT && tsID > 0 ) continue;

		  number   = vlistInqVarNumber(vlistID1, varID);
		  gridID   = vlistInqVarGrid(vlistID1, varID);
		  zaxisID  = vlistInqVarZaxis(vlistID1, varID);
		  param    = vlistInqVarParam(vlistID1, varID);

		  cdiParamToString(param, paramstr, sizeof(paramstr));

		  if ( Vardis ) vlistInqVarName(vlistID1, varID, varname);
		  else          strcpy(varname, paramstr);

		  if ( Debug )
		    fprintf(stdout, "varID = %d param = %d gridID = %d zaxisID = %d\n",
			    varID, param, gridID, zaxisID);

		  gridtype = gridInqType(gridID);
		  gridsize = gridInqSize(gridID);
		  missval  = vlistInqVarMissval(vlistID1, varID);

		  levelsize = zaxisInqSize(zaxisID);
		  for ( levelID = 0; levelID < levelsize; levelID++ )
		    {
		      level = zaxisInqLevel(zaxisID, levelID);
		      streamReadVarSlice(streamID1, varID, levelID, data, &nmiss);

		      if ( Info )
			printInfo(gridtype, vdate, vtime, varname, level, gridsize, number, nmiss, missval, data, Vardis);

		      if ( fname2 )
			streamWriteVarSlice(streamID2, varID, levelID, data, nmiss);
		    }
		}
	    }
	  tsID++;
        }

      free(data);

      /* fprintf(stderr, "%ld\n", (long) streamNvals(streamID1)); */

      if ( fname2 )
	{
	  streamClose(streamID2);
	  vlistDestroy(vlistID2);
	}
      streamClose(streamID1);
    }

  if ( wTable )
    tableWrite(wTable, itableID);

  return (0);
}
