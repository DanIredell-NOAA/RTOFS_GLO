#!/bin/sh
set -xa
###############################################################################
####  UNIX Script Documentation Block                                         #
#                                                                             #
# Script name:         exrtofs_glo_ncoda_hycom_var.sh                         #
# Script description:                                                         #
#                                                                             #
# Author:        Dan Iredell     Org: NP23         Date: 2020-07-30           #
#                                                                             #
# Abstract: 
#   this script runs a global 3DVAR multivariate analysis
#   the analysis is performed on the global HYCOM tri-polar grid
#   grid resoltuion is 8 km at the equator
#                                                                             #
# Sub-scripts called:                                                         #
#                                                                             #
# Script history log:                                                         #
# 2020-07-30  Dan Iredell                                                     #
#                                                                             #
###############################################################################

export PS4='$SECONDS + '

msg="RTOFS_GLO_NCODA_HYCOM_VAR JOB has begun on `hostname` at `date`"
postmsg "$jlogfile" "$msg"

cd $DATA

# --------------------------------------------------------------------------- #

# 1.a Populate DATA/hycom_var with hycom_var files from COMINm1/ncoda
echo timecheck RTOFS_GLO_HYCOM start get at `date`

mkdir -p $DATA/restart
mkdir -p $DATA/work
rm -f cmdfile.cpin
if compgen -G "$COMINm1/ncoda/hycom_var/restart/*" > /dev/null
then
  for hv in `ls $COMINm1/ncoda/hycom_var/restart/`; do
    echo "cp -p -f $COMINm1/ncoda/hycom_var/restart/$hv $DATA/restart" >> cmdfile.cpin
  done
else
  echo "Cold starting hycom var!"
fi

chmod +x cmdfile.cpin
echo mpirun cfp ./cmdfile.cpin > cpin.out
mpirun cfp ./cmdfile.cpin >> cpin.out
err=$? ; export err ; err_chk
date

ln -sf $COMIN/ncoda/ocnqc $DATA

# 1.b link in topo files
ln -f -s ${FIXrtofs}/${RUN}_${modID}.${inputgrid}.regional.grid.a ${DATA}/regional.grid.a
ln -f -s ${FIXrtofs}/${RUN}_${modID}.${inputgrid}.regional.grid.b ${DATA}/regional.grid.b
ln -f -s ${FIXrtofs}/${RUN}_${modID}.${inputgrid}.regional.depth.a ${DATA}/regional.depth.a
ln -f -s ${FIXrtofs}/${RUN}_${modID}.${inputgrid}.regional.depth.b ${DATA}/regional.depth.b

# BEGIN LINKING
# build links needed for hycom_var ... some names are mismatched so this is klugey
# when fixed change dsomrff below to COMIN

mkdir -p $RUN
ln -s $COMROOT/${NET}/${envir}/${RUN}.${PDYm2} $RUN/${RUN}.${PDYm2}
ln -s $COMROOT/${NET}/${envir}/${RUN}.${PDYm3} $RUN/${RUN}.${PDYm3}
ln -s $COMROOT/${NET}/${envir}/${RUN}.${PDYm4} $RUN/${RUN}.${PDYm4}
ln -s $COMROOT/${NET}/${envir}/${RUN}.${PDYm5} $RUN/${RUN}.${PDYm5}
ln -s $COMROOT/${NET}/${envir}/${RUN}.${PDYm6} $RUN/${RUN}.${PDYm6}
ln -s $COMROOT/${NET}/${envir}/${RUN}.${PDYm7} $RUN/${RUN}.${PDYm7}
mkdir -p $RUN/$RUN.$PDYm1
ln -s $COMROOT/${NET}/${envir}/${RUN}.${PDYm1}/* $RUN/${RUN}.${PDYm1}/.

# rename n-24:n00  to  n00:n24
cd $RUN/${RUN}.${PDYm1}

for n in `ls rtofs_glo.t00z.n*.[ab]`;do 
p1=`echo $n | cut -d. -f1-2`
p2=`echo $n | cut -d. -f4-`
hh=`echo $n | cut -d. -f3`
if [ $hh == n00 ]; then
  N=24
else
  h2=`echo $hh | cut -c3-3`
  if [ $h2 -eq 0 ] ; then
    h=`echo $hh | cut -c4-`
  else
    h=`echo $hh | cut -c3-`
  fi
  let N=24-$h
fi
if [[ $N -le 9 && $N -ge 0 ]]; then
 N=0${N}
fi
if [ $N -lt 0 ]; then
 N=`echo $N | cut -c2-`
 N=-0${N}
fi
mv $n ${p1}.n${N}.${p2}
done

cd $DATA

#end LINKING

# 2. build namelists

rm -f odsetnl
rm -f ogridnl
rm -f oanl

#  deny metop-a: 110, 111, 112
#  deny metop-b: 115, 116, 117

cat << eof1 > odsetnl
 &dsetnl
  dsoclim = '$FIXrtofs/codaclim'
  dsogdem = '$FIXrtofs/gdem'
  dsomrff = '$DATA/rtofs'
  dsomfix = '$DATA'
  dsorff  = '$DATA/restart'
  dsoudat = '$DATA/ocnqc'
  dsowork = '$DATA/work'
 &end
eof1

cat << eof2 > ogridnl
 &gridnl
  delx(1) = 8896.78809,
  dely(1) = 8895.59277,
  kko     = 41,
  m       = 4500,
  n       = 3298,
  nnest   = 1,
  nproj   = -1,
  rlat    = 70.2,
 &end
eof2

cp $PARMrtofs/${RUN}_${modID}.hycom.oanl.in   ./oanl

cat << eof4 > omapnl
 &omapnl
  do_data_raw  = .true.,
 &end
eof4
echo timecheck RTOFS_GLO_HYCOM finish build at `date`

# 3. Run Hycom var (NCODA 3D)

ddtg=${PDYm1}00
log_dir=$DATA/logs
mkdir -p $log_dir

echo timecheck RTOFS_GLO_HYCOM start setup at `date`
#NCODA setup
$EXECrtofs/rtofs_ncoda_setup 3D hycom ogridnl $ddtg > pout1
err=$?; export err ; err_chk
echo " error from rtofs_ncoda_setup=",$err

#NCODA prep
echo timecheck RTOFS_GLO_HYCOM start prep at `date`
mpirun -n  72 $EXECrtofs/rtofs_ncoda_prep 3D hycom ogridnl $ddtg > pout2
err=$?; export err ; err_chk
echo " error from rtofs_ncoda_prep=",$err

#NCODA var
echo timecheck RTOFS_GLO_HYCOM start ncoda3d at `date`
mpirun -n 360 $EXECrtofs/rtofs_ncoda 3D hycom ogridnl $ddtg > pout3
err=$?; export err ; err_chk
echo " error from rtofs_ncoda=",$err

#NCODA post
echo timecheck RTOFS_GLO_HYCOM start post at `date`
mpirun -n 360 $EXECrtofs/rtofs_ncoda_post 3D hycom ogridnl $ddtg relax > pout4
echo timecheck RTOFS_GLO_HYCOM finish post at `date`
err=$?; export err ; err_chk
echo " error from rtofs_ncoda_post=",$err

#   rename local files
mv fort.32 $log_dir/hycom_var.$ddtg.rej
mv fort.33 $log_dir/hycom_var.$ddtg.prf
mv fort.34 $log_dir/hycom_var.$ddtg.gpt
mv fort.36 $log_dir/hycom_var.$ddtg.mvo
mv fort.37 $log_dir/hycom_var.$ddtg.drc
mv fort.38 $log_dir/hycom_var.$ddtg.lyp
mv fort.39 $log_dir/hycom_var.$ddtg.fix
#mv fort.40 $log_dir/hycom_var.$ddtg.sus
mv fort.41 $log_dir/hycom_var.$ddtg.dup
mv fort.42 $log_dir/hycom_var.$ddtg.ssh
mv fort.67 $log_dir/hycom_var.$ddtg.obs
mv fort.68 $log_dir/hycom_var.$ddtg.grd
mv fort.69 $log_dir/hycom_var.$ddtg.via

#   create data coverage graphics
export OCN_OUTPUT_DIR=$DATA/restart
export OCN_CLIM_DIR=$FIXrtofs/codaclim
# NCODA map
$EXECrtofs/rtofs_ncoda_map $ddtg > pout5
err=$?; export err ; err_chk
echo " error from rtofs_ncoda_map=",$err
mv gmeta $log_dir/hycom_var.$ddtg.gmeta

#   combine and remove work files
cat pout* > $log_dir/hycom_var.$ddtg.out
cat $log_dir/hycom_var.$ddtg.out > $pgmout

# 4. Copy last 15 days of data back to COMOUT/ncoda
echo timecheck RTOFS_GLO_HYCOM start put at `date`

# taken car of at code level
#mkdir -p $DATA/nokeep
#mv $DATA/restart/*_01??_*fcstfld          $DATA/nokeep
#mv $DATA/restart/*_00[456789]?_*fcstfld   $DATA/nokeep

mkdir -p $COMOUT/ncoda/hycom_var/restart
rm -f cmdfile.cpout

for d in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  backymdh=$( $EXECrtofs/rtofs_dtg -d -$d ${PDY}00 )
  backymd=${backymdh:0:8}
  for f in `ls $DATA/restart/*${backymd}*`; do
    echo "cp -p -f $f $COMOUT/ncoda/hycom_var/restart" >> cmdfile.cpout
  done
done

chmod +x cmdfile.cpout
echo mpirun cfp ./cmdfile.cpout > cpout.out
mpirun cfp ./cmdfile.cpout >> cpout.out
err=$? ; export err ; err_chk
date

mkdir -p $COMOUT/ncoda/logs/hycom_var
cp -p -f $DATA/logs/*.$ddtg.* $COMOUT/ncoda/logs/hycom_var

echo timecheck RTOFS_GLO_HYCOM finish put at `date`

#################################################
msg="THE RTOFS_GLO_NCODA_HYCOM_VAR JOB HAS ENDED NORMALLY on `hostname` at `date`"
postmsg "$jlogfile" "$msg"

################## END OF SCRIPT #######################

