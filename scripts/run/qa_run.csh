#!/bin/csh -fx
#
# $Version$
# $Path$
# $Date$
#
# This script runs the SMOKE QA processors.  
#
# Script created by : M. Houyoux, North Carolina 
#                     Supercomputing Center
# Last edited : September, 2000
#
#*********************************************************************

# Create directory for output program logs

setenv OUTLOG $LOGS
if ( ! -e $OUTLOG ) then
   mkdir -p $OUTLOG
   chmod ug+w $OUTLOG
endif

# Initialize exit status
set exitstat = 0

# Make sure that debug mode and debug executable are set
if ( $?DEBUGMODE ) then
   set debugmode = $DEBUGMODE
else
   set debugmode = N
endif

if ( $?DEBUG_EXE ) then
   set debug_exe = $DEBUG_EXE
else
   set debug_exe = dbx
endif

# Ensure that SMK_SOURCE is defined
if ( $?SMK_SOURCE ) then

   # Set up input environment variables, with the help of the Assigns file
   if ( $SMK_SOURCE == 'A' || $SMK_SOURCE == 'M' || $SMK_SOURCE == 'P' ) then

      # Save existing values of run settings
      if ( $?RUN_SMKINVEN ) then
	 set run_smkinven = $RUN_SMKINVEN
      endif

      if ( $?RUN_GRDMAT ) then
	 set run_grdmat = $RUN_GRDMAT
      endif

      if ( $?RUN_SPCMAT ) then
	 set run_spcmat = $RUN_SPCMAT
      endif

      if ( $?RUN_TEMPORAL ) then
	 set run_temporal = $RUN_TEMPORAL
      endif

      if ( $?RUN_LAYPOINT ) then
	 set run_laypoint = $RUN_LAYPOINT
      endif

      # Temporarily set run settings to get input file names for Smkreport
      setenv RUN_SMKINVEN Y
      setenv RUN_GRDMAT   Y
      setenv RUN_SPCMAT   Y
      setenv RUN_TEMPORAL Y

      if ( $SMK_SOURCE == 'P' ) then
	 setenv RUN_LAYPOINT Y
      endif

      # Invoke the Assigns file, if it is defined
      if ( $?ASSIGNS_FILE ) then
	 source $ASSIGNS_FILE

      else
	 echo 'SCRIPT ERROR: Environment variable ASSIGNS_FILE is not set,'
	 echo '              but it is needed to use the qa_run.csh script!'
	 set exitstat = 1

      endif

      # If previous values of were set, restore E.V. settings
      if ( $?run_smkinven ) then
	 setenv RUN_SMKINVEN $run_smkinven
      endif

      if ( $?run_grdmat ) then
	 setenv RUN_GRDMAT $run_grdmat
      endif

      if ( $?run_spcmat ) then
	 setenv RUN_SPCMAT $run_spcmat
      endif

      if ( $?run_temporal ) then
	 setenv RUN_TEMPORAL $run_temporal
      endif

      if ( $?run_laypoint ) then
	 setenv RUN_LAYPOINT $run_laypoint
      endif

   # Set up for biogenics...   
   else

      # Nothing for now

   endif

# SMK_SOURCE is not defined   
else
   echo 'SCRIPT ERROR: Environment variable SMK_SOURCE is not set,'
   echo '              but it is needed to use the qa_run.csh script!'
   set exitstat = 1

endif

# Check if QA_TYPE variable is set
if ( ! $?QA_TYPE ) then

   echo 'SCRIPT ERROR: Environment variable QA_TYPE is not set,'
   echo '              but it is needed to use the qa_run.csh script!'
   echo '              Valid values are "inventory" or "monthly".'
   set exitstat = 1
   
endif

# Abort if already had an error
if ( $exitstat == 1 ) then
   exit( $exitstat )
endif

# Check if QA label is set, and initialize file
if ( $?QA_LABEL ) then

   set ilabl = $FYIOP.$QA_LABEL
   set slabl = $ESCEN.$QA_LABEL

else

   set ilabl = $INVOP
   set slabl = $ESCEN

endif

# Set up input file for Smkreport depending on settings

switch ( $QA_TYPE ) 

case emuncert:
   switch ( $SMK_SOURCE )
   case A:
      setenv REPCONFIG $SCRIPTS/configure/REPCONFIG.ar.emuncert.txt
      setenv REPORT1 $REPSTAT/a.county.$ilabl.rpt
      setenv REPORT2 $REPSTAT/a.scc.$ilabl.rpt
      setenv REPORT3 $REPSTAT/ag.county.$ilabl.rpt
      setenv REPORT4 $REPSTAT/ag.scc.$ilabl.rpt
      setenv REPORT5 $REPSCEN/agt.county.$GRID.$ilabl.rpt
      setenv REPORT6 $REPSCEN/agts.county.$GRID.$ilabl.rpt
      breaksw

   case M:
      setenv REPCONFIG $SCRIPTS/configure/REPCONFIG.mb.emuncert.txt
      setenv REPORT1 $REPSTAT/m.county.$ilabl.rpt
      setenv REPORT2 $REPSTAT/m.scc.$ilabl.rpt
      setenv REPORT3 $REPSTAT/mg.county.$ilabl.rpt
      setenv REPORT4 $REPSTAT/mg.scc.$ilabl.rpt
      setenv REPORT5 $REPSCEN/mgt.county.$GRID.$ilabl.rpt
      setenv REPORT6 $REPSCEN/mgts.county.$GRID.$ilabl.rpt
      breaksw

   endsw
   
   set logabbr = emuncert.$ilabl
   
   breaksw

case inventory:

   switch ( $SMK_SOURCE )
   case A:
      setenv REPCONFIG $SCRIPTS/configure/REPCONFIG.ar.inv.txt
      setenv REPORT1 $REPSTAT/a.state.$ilabl.rpt
      setenv REPORT2 $REPSTAT/a.county.$ilabl.rpt
      setenv REPORT3 $REPSTAT/a.scc.$ilabl.rpt
      setenv REPORT4 $REPSTAT/a.state_scc.$ilabl.rpt
      setenv REPORT5 $REPSTAT/ag.state.$GRID.$ilabl.rpt
      setenv REPORT6 $REPSTAT/ag.scc.$GRID.$ilabl.rpt
      breaksw
      
   case M:
      setenv REPCONFIG $SCRIPTS/configure/REPCONFIG.mb.inv.txt
      setenv REPORT1 $REPSTAT/m.state.$ilabl.rpt
      setenv REPORT2 $REPSTAT/m.county.$ilabl.rpt
      setenv REPORT3 $REPSTAT/m.scc.$ilabl.rpt
      setenv REPORT4 $REPSTAT/m.state_scc.$ilabl.rpt
      setenv REPORT5 $REPSTAT/m.state_rclas.$ilabl.rpt
      setenv REPORT6 $REPSTAT/mg.state.$GRID.$ilabl.rpt
      setenv REPORT7 $REPSTAT/mg.scc.$GRID.$ilabl.rpt
      breaksw
      
   case P:
      setenv REPCONFIG $SCRIPTS/configure/REPCONFIG.pt.inv.txt
      setenv REPORT1 $REPSTAT/p.state.$ilabl.rpt
      setenv REPORT2 $REPSTAT/p.county.$ilabl.rpt
      setenv REPORT3 $REPSTAT/p.scc.$ilabl.rpt
      setenv REPORT4 $REPSTAT/p.state_scc.$ilabl.rpt
      setenv REPORT5 $REPSTAT/pg.state.$GRID.$ilabl.rpt
      setenv REPORT6 $REPSTAT/pg.scc.$GRID.$ilabl.rpt
      breaksw
      
   endsw
   
   set logabbr = inv.$ilabl
   
   breaksw
   
case monthly:

   switch ( $SMK_SOURCE )
   case A:
      setenv REPCONFIG $SCRIPTS/configure/REPCONFIG.ar.monthly.txt
      setenv REPORT1  $REPSCEN/at.state.$slabl.rpt
      setenv REPORT2  $REPSCEN/at.county.$slabl.rpt
      setenv REPORT3  $REPSCEN/at.scc.$slabl.rpt
      setenv REPORT4  $REPSCEN/at.state_scc.$slabl.rpt
      setenv REPORT5  $REPSCEN/at.hour_scc.$slabl.rpt
      setenv REPORT6  $REPSCEN/agt.state.$GRID.$slabl.rpt
      setenv REPORT7  $REPSCEN/agt.county.$GRID.$slabl.rpt
      setenv REPORT8  $REPSCEN/agt.scc.$GRID.$slabl.rpt
      setenv REPORT9  $REPSCEN/ats.state.$slabl.rpt
      setenv REPORT10 $REPSCEN/ats.scc.$slabl.rpt
      setenv REPORT11 $REPSCEN/ats.state_scc.$slabl.rpt
      breaksw
      
   case M:
      setenv REPCONFIG $SCRIPTS/configure/REPCONFIG.mb.monthly.txt
      setenv REPORT1  $REPSCEN/mt.state.$slabl.rpt
      setenv REPORT2  $REPSCEN/mt.county.$slabl.rpt
      setenv REPORT3  $REPSCEN/mt.scc.$slabl.rpt
      setenv REPORT4  $REPSCEN/mt.state_scc.$slabl.rpt
      setenv REPORT5  $REPSCEN/mt.hour_scc.$slabl.rpt
      setenv REPORT6  $REPSCEN/mt.state_rclas.$slabl.rpt
      setenv REPORT7  $REPSCEN/mt.county_rclas.$slabl.rpt
      setenv REPORT8  $REPSCEN/mgt.state.$GRID.$slabl.rpt
      setenv REPORT9  $REPSCEN/mgt.county.$GRID.$slabl.rpt
      setenv REPORT10 $REPSCEN/mgt.scc.$GRID.$slabl.rpt
      setenv REPORT11 $REPSCEN/mgt.state_rclas.$GRID.$slabl.rpt
      setenv REPORT12 $REPSCEN/mgt.county_rclas.$GRID.$slabl.rpt
      setenv REPORT13 $REPSCEN/mts.state.$slabl.rpt
      setenv REPORT14 $REPSCEN/mts.scc.$slabl.rpt
      setenv REPORT15 $REPSCEN/mts.state_scc.$slabl.rpt
      breaksw
      
   case P:
      setenv REPCONFIG $SCRIPTS/configure/REPCONFIG.pt.monthly.txt
      setenv REPORT1  $REPSCEN/pt.state.$slabl.rpt
      setenv REPORT2  $REPSCEN/pt.county.$slabl.rpt
      setenv REPORT3  $REPSCEN/pt.scc.$slabl.rpt
      setenv REPORT4  $REPSCEN/pt.state_scc.$slabl.rpt
      setenv REPORT5  $REPSCEN/pt.hour_scc.$slabl.rpt
      setenv REPORT6  $REPSCEN/pt.source.$slabl.rpt
      setenv REPORT7  $REPSCEN/pgt.state.$GRID.$slabl.rpt
      setenv REPORT8  $REPSCEN/pgt.county.$GRID.$slabl.rpt
      setenv REPORT9  $REPSCEN/pgt.scc.$GRID.$slabl.rpt
      setenv REPORT10 $REPSCEN/pgt.source.$GRID.$slabl.rpt
      setenv REPORT11 $REPSCEN/pts.state.$slabl.rpt
      setenv REPORT12 $REPSCEN/pts.scc.$slabl.rpt
      setenv REPORT13 $REPSCEN/pts.state_scc.$slabl.rpt
      breaksw
      
   endsw
   
   set logabbr = $ESDATE.$slabl
   
   breaksw
   
case county:

   switch ( $SMK_SOURCE )
   case A:
      setenv REPCONFIG $SCRIPTS/configure/REPCONFIG.ar.$QA_TYPE.txt
      setenv REPORT1 $REPSTAT/ats.county_scc.$slabl.rpt
      breaksw

   endsw

   set logabbr = cty.$ilabl

   breaksw

case state:

   switch ( $SMK_SOURCE )
   case A:
      setenv REPCONFIG $SCRIPTS/configure/REPCONFIG.ar.$QA_TYPE.txt
      setenv REPORT1 $REPSTAT/a.$QA_TYPE.$ilabl.rpt
      setenv REPORT2 $REPSTAT/ag.$QA_TYPE.$ilabl.rpt
      setenv REPORT3 $REPSTAT/as.$QA_TYPE.$ilabl.rpt
      setenv REPORT4 $REPSCEN/at.$QA_TYPE.$slabl.rpt
      setenv REPORT5 $REPSCEN/agts.$QA_TYPE.$slabl.rpt
      breaksw
      
   case M:

      set standard = yes
      if ( $?QA_MOBILE ) then

         switch ( $QA_MOBILE  ) 
         case emis:

            set standard = no    
            setenv REPCONFIG $SCRIPTS/configure/REPCONFIG.mb.$QA_TYPE.emis.txt
            setenv REPORT1 $REPSTAT/m.$QA_TYPE.$ilabl.rpt
            setenv REPORT2 $REPSTAT/mg.$QA_TYPE.$ilabl.rpt
            setenv REPORT3 $REPSTAT/ms.$QA_TYPE.$ilabl.rpt
            setenv REPORT4 $REPSCEN/mt.$QA_TYPE.$slabl.rpt
            setenv REPORT5 $REPSCEN/mgts.$QA_TYPE.$slabl.rpt

            breaksw

         case emis_o3:

            set standard = no    
            setenv REPCONFIG $SCRIPTS/configure/REPCONFIG.mb.$QA_TYPE.emis_o3.txt
            setenv REPORT1 $REPSTAT/m.$QA_TYPE.$ilabl.rpt
            setenv REPORT2 $REPSTAT/mg.$QA_TYPE.$ilabl.rpt
            setenv REPORT3 $REPSTAT/ms.$QA_TYPE.$ilabl.rpt
            setenv REPORT4 $REPSCEN/mt.$QA_TYPE.$slabl.rpt
            setenv REPORT5 $REPSCEN/mgts.$QA_TYPE.$slabl.rpt

            breaksw

         case std:
            breaksw

         default
            echo 'SCRIPT ERROR: Environment variable QA_MOBILE is set to'
            echo '              an unknown setting.  Valid values are'
            echo '              "emis", "emis_o3", or "standard".'
            set exitstat = 1
            breaksw

         endsw

      endif

      if ( $standard == yes ) then

         setenv REPCONFIG $SCRIPTS/configure/REPCONFIG.mb.$QA_TYPE.std.txt
         setenv REPORT1 $REPSTAT/m.$QA_TYPE.$ilabl.rpt
         setenv REPORT2 $REPSCEN/mgt.$QA_TYPE.$ilabl.rpt
         setenv REPORT3 $REPSCEN/mst.$QA_TYPE.$ilabl.rpt
         setenv REPORT4 $REPSCEN/mt.$QA_TYPE.$slabl.rpt
         setenv REPORT5 $REPSCEN/mgts.$QA_TYPE.$slabl.rpt

      endif

      breaksw
      
   case P:
      setenv REPCONFIG $SCRIPTS/configure/REPCONFIG.pt.$QA_TYPE.txt
      setenv REPORT1 $REPSTAT/p.$QA_TYPE.$ilabl.rpt
      setenv REPORT2 $REPSTAT/pg.$QA_TYPE.$ilabl.rpt
      setenv REPORT3 $REPSTAT/ps.$QA_TYPE.$ilabl.rpt
      setenv REPORT4 $REPSCEN/pt.$QA_TYPE.$slabl.rpt
      setenv REPORT5 $REPSCEN/pgts.$QA_TYPE.$slabl.rpt
      breaksw
      
   endsw
   
   set logabbr = cy.$ilabl
   
   breaksw

case custom:
   set logabbr = custom.$ilabl
   breaksw

default
   echo 'SCRIPT ERROR: Environment variable QA_TYPE is set to'
   echo '              an unknown setting.  Valid values are'
   echo '              "state", "county", "inventory", or "monthly".'
   set exitstat = 1
   breaksw
      
endsw

 # Abort if already had an error
if ( $exitstat == 1 ) then
   exit( $exitstat )
endif
  
#
### Smkreport processing for area, mobile, or point sources
#
set debugexestat = 0
set exestat = 0
setenv TMPLOG   $OUTLOG/smkreport.$SRCABBR.$logabbr.log
if ( $?RUN_SMKREPORT ) then
   if ( $RUN_SMKREPORT == 'Y' && -e $SMK_BIN/smkreport ) then

      if ( -e $TMPLOG ) then
	 source $SCRIPTS/run/movelog.csh
      endif

      if ( $exitstat == 0 ) then         # Run program
         setenv LOGFILE $TMPLOG
         if ( $debugmode == Y ) then
            if ( -e $QA_SRC/smkreport.debug ) then
               $debug_exe $QA_SRC/smkreport.debug
            else
                set debugexestat = 1
            endif
         else
            if ( -e $SMK_BIN/smkreport ) then
               time $SMK_BIN/smkreport
            else
               set exestat = 1 
            endif
         endif
      endif

      if ( $exestat == 1 ) then
	 echo 'SCRIPT ERROR: smkreport program does not exist in:'
	 echo '              '$SMK_BIN
         set exitstat = 1
      endif

      if ( $debugexestat == 1 ) then
	 echo 'SCRIPT ERROR: smkreport.debug program does not exist in:'
	 echo '              '$QA_SRC
         set exitstat = 1
      endif

   endif
endif

#
### Merging
#
#setenv TMPLOG   $OUTLOG/smkmerge.$SRCABBR.$INVEN.$ESDATE.$GRID.log
#if ( $?RUN_SMKMERGE ) then
#   if ( $RUN_SMKMERGE == 'Y' && -e $SMK_BIN/smkmerge ) then

      # Set mole/mass-based speciation matrices.  Default, mole.
#      if ( $?ASMAT_L ) then
#         setenv ASMAT $ASMAT_L
#      endif
#      if ( $?BGTS_L ) then
#         setenv BGTS $BGTS_L
#      endif
#      if ( $?MSMAT_L ) then
#         setenv MSMAT $MSMAT_L
#      endif
#      if ( $?PSMAT_L ) then
#         setenv PSMAT $PSMAT_L
#      endif
#      if ( $?SPC_INPUT ) then
#         if ( $SPC_INPUT == 'mass' ) then
#            if ( $?ASMAT_S ) then
#               setenv ASMAT $ASMAT_S
#            endif
#            if ( $?BGTS_S ) then
#               setenv BGTS $BGTS_S
#            endif
#            if ( $?MSMAT_S ) then
#               setenv MSMAT $MSMAT_S
#            endif
#            if ( $?PSMAT_S ) then
#               setenv PSMAT $PSMAT_S
#            endif
#         endif
#      endif

#      if ( -e $TMPLOG ) then
#         source $SCRIPTS/run/movelog.csh
#      endif

#      if ( $exitstat == 0 ) then         # Run program
#         setenv LOGFILE $TMPLOG
#         time $SMK_BIN/smkmerge
#      endif

#   else
#      if ( $RUN_SMKMERGE == 'Y' ) then
#         echo 'SCRIPT ERROR: SMKMERGE program does not exist in:'
#         echo '              '$SMK_BIN
#         set exitstat = 1
#      endif
#   endif
#endif

#
## Ending of script with exit status
#
exit( $exitstat )

