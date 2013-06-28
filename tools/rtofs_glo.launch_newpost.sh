#!/bin/bash
#
#
set -x

if [ $# -ne 2 ] 
then
  echo "USAGE: $0 <YYYYMMDD-forecast_start> <YYYYMMDD-post_start>"
  exit -2
fi
echo 'NOTE: The run parameters are set in parm/rtofs_glo.navy_0.08.config file'

export today=$1
export startdate=$2
hindcast=NO # YES or NO
testcast=YES # YES or NO

# Set some run environment variables.
export HOMErtofs=/gpfs/`hostname | cut -c1-1`d1/emc/marine/noscrub/save/$LOGNAME/hycom_glo/projects/RB-1.0.2
export COMtmp=/ptmp/$LOGNAME/tmpdir/com.$$
export projID=`basename $HOMErtofs`
export cyc=00
export RUN_ENVIR=dev
export envir=prod # prod or para

# Get the length of the forecast from a config file
RUN=rtofs
modID=glo
inputgrid=navy_0.08
. $HOMErtofs/parm/${RUN}_${modID}.${inputgrid}.config
export fcstdays=`expr ${fcstdays_step1} + ${fcstdays_step2} + ${fcstdays_step3}`
#
# Redefine default top level directories for rtofs_forcing_getges.sh script
if [ $hindcast = YES ] 
then
  export GETGES_COM=$COMtmp
fi
if [ $hindcast = NO ] &&  [ $testcast = YES ]
then
  export GETGES_COM=/com_p6
fi 
if [ $hindcast = NO ] &&  [ $testcast = NO ]
then
  export GETGES_COM=/com
fi 

#dbgz
# test -d /ptmp/$LOGNAME/tmpdir/$projID && rm -rf /ptmp/$LOGNAME/tmpdir/$projID
# mkdir -p /ptmp/$LOGNAME/tmpdir/$projID
test -d /ptmp/$LOGNAME/tmpdir/$projID || mkdir -p /ptmp/$LOGNAME/tmpdir/$projID

# Set paths to directories.
export utilexec=/nwprod/util/exec
export HOMEout=/ptmp/$LOGNAME/testpost ### /marine/noscrub/$LOGNAME/simulations/$projID
export tmpdir=/ptmp/$LOGNAME/tmpdir/${projID}
FLUXDIR=/marine/noscrub/seaspara/flux/gfs/prod  # needed only if hidcast=YES

#=== DON'T EDIT BELOW THIS LINE ==================

# very important: redefinition of the default date (PDY !!!
# if PDY is defined here, it will not be reset by setpdy utility.
export PDY=$today
# This variable is used in hidncast mode to set up forcing directories.
let analhrs=analdays*24
nowcast_start=`$utilexec/ndate -${analhrs} ${today}${cyc} | cut -c1-8`
forecast_start=$btoday

# Calculate forecast length.
export nowcast_end=$today
let fcsthrs=${fcstdays}*24
export forecast_end=`$utilexec/ndate $fcsthrs ${forecast_start}${cyc} | cut -c1-8`

# Test restart file in hindcast

if [ $hindcast = YES ] 
then
  RESTdir=${HOMEout}/rtofs/nwges/rtofs.`$utilexec/ndate -24 ${PDY}'00' | cut -c1-8`
  RESTfile=${RESTdir}/rtofs_glo.t${cyc}z.restart_f24
  if ! [ -s ${RESTfile}.a ] || ! [ -s  ${RESTfile}.b ]
  then
      echo "LAUNCHER ERROR: No restart found."
      echo "                FILE:  ${RESTfile}.[ab] "    
      exit -3
   fi
fi

# Write out some info.
echo "LAUNCHER INFO: run: ${projID}, cycle: t${cyc}z, PDY=${PDY}."
echo "LAUNCHER INFO: forecast starts at ${forecast_start}, ends at ${forecast_end}."

# Make logs directory if necessary.
test -d $HOMEout/logs || mkdir -p $HOMEout/logs

# Submit the job.
module load lsf
echo startdate $startdate
bsub < rtofs_job_command_fcst_post.lsf
bsub < rtofs_job_command_fcst_reg_post.lsf

