#!/bin/csh -fx

# Version %W%
# Path    %P%
# Date    %G% %U%

# This script runs the SMOKE processors.  
#
# Time independent programs only need to be run once.
# Time dependent programs need to be processed once
# for each day needed for the air quality simulation.  
#
# Script created by : M. Houyoux and J. Vukovich, MCNC 
#                     Environmental Modeling Center 
# Last edited : April 2002
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

#
### Control matrix generation
#
setenv TMPLOG   $OUTLOG/cntlmat.$SRCABBR.$INVEN.log
if ( $?RUN_CNTLMAT ) then
   if ( $RUN_CNTLMAT == 'Y' && -e $SMK_BIN/cntlmat ) then

      # Make temporary control file directory and make sure that it is
      #    writable by the user
      if ( ! -e $SMK_TMPPATH ) then
          mkdir -p $SMK_TMPPATH
          chmod ug+w $SMK_TMPPATH

      else
	 set line   = ( `/bin/ls -ld $SMK_TMPPATH` )
	 set owner  = $line[3]
	 set check  = ( `echo $line | grep $user` )
	 if ( $status == 0 ) then

             set permis = ( `echo $line | grep drwxrw` )
             if( $status != 0 ) then
        	 chmod ug+w $SMK_TMPPATH
             endif

	 else

             set permis = ( `echo $line | grep drwxrw` )
             if ( $status != 0 ) then
        	 echo "NOTE: Do not have write permission for temporary control"
                 echo "      file directory:"
        	 echo "      $SMK_TMPPATH"
        	 echo "      Check with user $owner for write permissions"
                 set exitstat = 1
             endif

	 endif
      endif


      if ( -e $TMPLOG ) then
	 source $SCRIPTS/run/movelog.csh
      endif

      ## Remove any existing tmp files
      ls -1 $SMK_TMPPATH > $SMK_TMPPATH/filelist.txt
      set list = ( `cat $SMK_TMPPATH/filelist.txt | grep cntlmat` )
      if ( $status == 0 ) then
         /bin/rm -rf $SMK_TMPPATH/cntlmat*
      endif

      if ( $exitstat == 0 ) then         # Run program
         setenv LOGFILE $TMPLOG
         time $SMK_BIN/cntlmat
      endif

      ## Remove any existing tmp files
      ls -1 $SMK_TMPPATH > $SMK_TMPPATH/filelist.txt
      set list = ( `cat $SMK_TMPPATH/filelist.txt | grep cntlmat` )
      if ( $status == 0 ) then
         /bin/rm -rf $SMK_TMPPATH/cntlmat*
      endif

   else 
      if ( $RUN_CNTLMAT == 'Y' ) then
	 echo 'SCRIPT ERROR: CNTLMAT program does not exist in:'
	 echo '              '$SMK_BIN
	 set exitstat = 1
      endif
   endif
endif

#
### Inventory growth and control
#
setenv TMPLOG   $OUTLOG/grwinven.$SRCABBR.$INVEN.log
if ( $?RUN_GRWINVEN ) then
   if ( $RUN_GRWINVEN == 'Y' && -e $SMK_BIN/grwinven ) then

      if ( -e $TMPLOG ) then
	 source $SCRIPTS/run/movelog.csh
      endif

      ## Remove any existing tmp files
      ls -1 $SMK_TMPPATH > $SMK_TMPPATH/filelist.txt
      set list = ( `cat $SMK_TMPPATH/filelist.txt | grep grwinven` )
      if ( $status == 0 ) then
         /bin/rm -rf $SMK_TMPPATH/grwinven*
      endif

      if ( $exitstat == 0 ) then         # Run program
         setenv LOGFILE $TMPLOG
         time $SMK_BIN/grwinven 
      endif

      ## Remove any existing tmp files
      ls -1 $SMK_TMPPATH > $SMK_TMPPATH/filelist.txt
      set list = ( `cat $SMK_TMPPATH/filelist.txt | grep grwinven` )
      if ( $status == 0 ) then
         /bin/rm -rf $SMK_TMPPATH/grwinven*
      endif

   else 
      if ( $RUN_GRWINVEN == 'Y' ) then
	 echo 'SCRIPT ERROR: GRWINVEN program does not exist in:'
	 echo '              '$SMK_BIN
	 set exitstat = 1
      endif
   endif
endif

#
## Ending of script with exit status
#
exit( $exitstat )

