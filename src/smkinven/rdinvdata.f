
        SUBROUTINE RDINVDATA( FDEV, FNAME, NRAWBP, TFLAG )

C***********************************************************************
C  subroutine body starts at line 133
C
C  DESCRIPTION:
C      This subroutine controls reading an ASCII inventory file for any source 
C      category from one of many formats.  It determines the format and 
C      calls the appropriate reader subroutines. It controls the looping 
C      through multiple files when a list-formatted file is used as input.
C      This routine only reads the data (emissions and activities) from the
C      inventories.
C
C  PRECONDITIONS REQUIRED:
C      Input file unit FDEV opened
C      Inventory pollutant list created: MXIDAT, INVDCOD, and INVDNAM
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C      Subroutines: 
C      Functions: 
C
C  REVISION  HISTORY:
C      Created 1/03 by C. Seppanen (based on rdinven.f)
C
C**************************************************************************
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C
C COPYRIGHT (C) 2002, MCNC Environmental Modeling Center
C All Rights Reserved
C
C See file COPYRIGHT for conditions of use.
C
C Environmental Modeling Center
C MCNC
C P.O. Box 12889
C Research Triangle Park, NC  27709-2889
C
C smoke@emc.mcnc.org
C
C Pathname: $Source$
C Last updated: $Date$ 
C
C***************************************************************************

C...........   MODULES for public variables
C...........   This module is the inventory arrays
        USE MODSOURC, ONLY: INRECA, POLVLA, TPFLAG, INDEXA,
     &                      NSTRECS, SRCSBYREC, RECIDX, IPOSCODA, 
     &                      SRCIDA, INVYR, ICASCODA, ISIC, STKHT, 
     &                      STKDM, STKTK, STKVE, XLOCA, YLOCA, CORIS,
     &                      CBLRID, CPDESC, IDIU, IWEK, XLOC1, YLOC1,
     &                      XLOC2, YLOC2

C.........  This module contains the information about the source category
        USE MODINFO, ONLY: CATEGORY, NEM, NOZ, NEF, NCE, NRE, NRP, 
     &                     NC1, NC2, NPPOL, NSRC, NPACT
        
C.........  This module contains the lists of unique inventory information
        USE MODLISTS, ONLY: FILFMT, LSTSTR, MXIDAT, INVDCNV, INVDNAM,
     &                      NUNIQCAS, UNIQCAS, UCASNKEP, ITNAMA, 
     &                      SCASIDX, UCASIDX, UCASNPOL, ITKEEPA, ITFACA,
     &                      EMISBYCAS, RECSBYCAS, EMISBYPOL, INVSTAT

C.........  This module is for mobile-specific data
        USE MODMOBIL, ONLY: NVTYPE

        IMPLICIT NONE

C...........   INCLUDES
        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'CONST3.EXT'    !  physical and mathematical constants
        INCLUDE 'PARMS3.EXT'    !  I/O API parameters

C...........   EXTERNAL FUNCTIONS and their descriptions:
        
        LOGICAL         CHKINT
        LOGICAL         CHKREAL
        CHARACTER*2     CRLF
        INTEGER         ENVINT
        LOGICAL         ENVYN
        INTEGER         FINDC
        INTEGER         GETINVYR
        INTEGER         INDEX1
        INTEGER         STR2INT
        REAL            STR2REAL
        REAL            YR2DAY

        EXTERNAL        CHKINT, CHKREAL, CRLF, ENVINT, ENVYN, FINDC, 
     &                  GETINVYR, INDEX1, STR2INT, STR2REAL, YR2DAY

C...........   SUBROUTINE ARGUMENTS
        INTEGER,          INTENT (IN) :: FDEV         ! unit no. of inv file
        CHARACTER(LEN=*), INTENT (IN) :: FNAME        ! logical name of file
        INTEGER,          INTENT (IN) :: NRAWBP       ! no. sources with pollutants
        LOGICAL,          INTENT(OUT) :: TFLAG        ! true: PTREF output

C...........   Local parameters
        INTEGER, PARAMETER :: DATALEN3 = 25  ! length of data field
        
C...........   Dropped emissions
        INTEGER         NDROP             !  number of records dropped
        REAL            EDROP  ( MXIDAT ) !  total dropped for each pol/activity

C...........   File units and logical/physical names
        INTEGER         EDEV( 5 )   !  up to 5 EMS-95 emissions files
        INTEGER         TDEV        !  file listed in list formatted input file

C...........   Output from individual reader routines
        CHARACTER(LEN=DATALEN3), ALLOCATABLE :: READDATA( :,: )  ! data values
        CHARACTER(LEN=IOVLEN3),  ALLOCATABLE :: READPOL ( : )    ! pollutant names

C...........   Other local variables
        INTEGER         I, J, K, SP !  counters and indices

        INTEGER         CURFIL      !  current file from list formatted inventory
        INTEGER         CURFMT      !  format of current inventory file
        INTEGER         CURSRC      !  current source number
        INTEGER      :: INY = 0     !  tmp inventory year
        INTEGER         IOS         !  i/o status
        INTEGER         INVYEAR     !  inventory year from inventory file
        INTEGER         IREC        !  no. of records read
        INTEGER         ISTREC      !  no. of records stored
        INTEGER         IZONE       !  UTM zone
        INTEGER         LSTYR       !  inventory year from list file
        INTEGER         MXWARN      !  maximum number of warnings
        INTEGER         NPOLPERCAS  !  no. of pollutants per CAS number
        INTEGER         NPOLPERLN   !  no. of pollutants per line of inventory file
        INTEGER      :: NWARN = 0   !  current number of warnings
        INTEGER         POLCOD      !  pollutant code
        INTEGER         TPF         !  temporal adjustments setting
        INTEGER         SCASPOS     !  position of CAS number in sorted array
        INTEGER         UCASPOS     !  position of CAS number in unique array
        INTEGER         WKSET       !  setting for wkly profile TPFLAG component

        REAL            CEFF        !  tmp control effectiveness
        REAL            EANN        !  annual-ave emission value
        REAL            EMFC        !  emission factor
        REAL            EOZN        !  ozone-season-ave emission value
        REAL            REFF        !  rule effectiveness
        REAL            RPEN        !  rule penetration
        REAL            CPRI        !  primary control code
        REAL            CSEC        !  secondary control code
        REAL            DAY2YR      !  factor to convert from daily data to annual
        REAL            YEAR2DAY    !  factor to convert from annual to daily
        REAL            POLFAC      !  factor for current pollutant
        REAL            POLANN      !  annual emissions for current pollutant
        REAL            RBUF        !  tmp real value
        REAL            REALFL      !  tmp exit flow rate
        REAL            XLOCA1      !  x-dir link coord 1
        REAL            YLOCA1      !  y-dir link coord 1
        REAL            XLOCA2      !  x-dir link coord 2
        REAL            YLOCA2      !  y-dir link coord 2
        REAL            XLOC        !  tmp x coord
        REAL            YLOC        !  tmp y coord

        LOGICAL      :: ACTFLAG = .FALSE. ! true: current pollutant is activity
        LOGICAL      :: CFLAG             ! true: recalc vel w/ flow & diam
        LOGICAL      :: EFLAG   = .FALSE. ! true: error occured
        LOGICAL      :: DFLAG   = .FALSE. ! true: weekday (not full week) nrmlizr 
        LOGICAL      :: FFLAG   = .FALSE. ! true: fill annual data with seasonal
        LOGICAL      :: HDRFLAG           ! true: current line is part of header
        LOGICAL      :: LNKFLAG = .FALSE. ! true: current line has link information
        LOGICAL      :: LSTFLG  = .FALSE. ! true: using list-fmt inventory file
        LOGICAL      :: LSTTIME = .FALSE. ! true: last time through 
        LOGICAL      :: NOPOLFLG= .FALSE. ! true: no pollutants stored for this line
        LOGICAL      :: WFLAG   = .FALSE. ! true: all lat-lons to western hemi

        CHARACTER(LEN=25)       X1        ! x-dir link coord 1
        CHARACTER(LEN=25)       Y1        ! y-dir link coord 1
        CHARACTER(LEN=25)       X2        ! x-dir link coord 2
        CHARACTER(LEN=25)       Y2        ! y-dir link coord 2
        CHARACTER(LEN=2)        ZONE      ! UTM zone

        CHARACTER(LEN=ORSLEN3)  CORS      ! DOE plant ID
        CHARACTER(LEN=6)        BLID      ! boiler ID
        CHARACTER(LEN=40)       DESC      ! plant description
        CHARACTER(LEN=4)        HT        ! stack height
        CHARACTER(LEN=6)        DM        ! stack diameter
        CHARACTER(LEN=4)        TK        ! exit temperature
        CHARACTER(LEN=10)       FL        ! flow rate
        CHARACTER(LEN=9)        VL        ! exit velocity
        CHARACTER(LEN=SICLEN3)  SIC       ! SIC
        CHARACTER(LEN=9)        LAT       ! stack latitude
        CHARACTER(LEN=9)        LON       ! stack longitude

        CHARACTER(LEN=IOVLEN3) POLNAM     !  tmp pollutant name
        CHARACTER(LEN=300)     INFILE     !  input file line buffer
        CHARACTER(LEN=3000)    LINE       !  input file line buffer
        CHARACTER(LEN=300)     MESG       !  message buffer

        CHARACTER*16 :: PROGNAME =  'RDINVDATA' ! program name

C***********************************************************************
C   begin body of subroutine RDINVDATA

C.........  Check if inventory file is list format
        IF( ALLOCATED( LSTSTR ) ) LSTFLG = .TRUE.
        
C.........   Initialize variables for keeping track of dropped emissions
        NDROP = 0
        EDROP = 0.  ! array

C.........  Get setting for interpreting weekly temporal profiles from the
C           environment. Default is false for non-EMS-95 and true for EMS-95
C           inventory inputs.
        DFLAG = .FALSE.
        
        DO I = 1, SIZE( FILFMT )
            IF ( FILFMT( I ) .EQ. EMSFMT ) DFLAG = .TRUE.
        END DO
        
        MESG = 'Use weekdays only to normalize weekly profiles'
        DFLAG = ENVYN( 'WKDAY_NORMALIZE', MESG, DFLAG, IOS )

C.........  Set weekly profile interpretation flag...
C.........  Weekday normalized
        IF( DFLAG ) THEN
            WKSET = WDTPFAC
            MESG = 'NOTE: Setting inventory to use weekday '//
     &             'normalizer for weekly profiles'

C.........  Full-week normalized
        ELSE
            WKSET = WTPRFAC
            MESG = 'NOTE: Setting inventory to use full-week '//
     &             'normalizer for weekly profiles'

        END IF

C.........  Write message
        CALL M3MSG2( MESG )

C.........  If EMS-95 format, check the setting for the interpretation of
C           the weekly profiles
        DO I = 1, SIZE( FILFMT )
            IF( FILFMT( I ) == EMSFMT .AND. 
     &          WKSET /= WDTPFAC ) THEN

                MESG = 'WARNING: EMS-95 format files will be using ' //
     &             'non-standard approach of ' // CRLF() // BLANK10 //
     &             'full-week normalized weekly profiles.  Can ' //
     &             'correct by setting ' // CRLF() // BLANK10 //
     &             'WKDAY_NORMALIZE to Y and rerunning.'
                CALL M3MSG2( MESG )

            ELSE IF( FILFMT( I ) == EPSFMT .AND. 
     &               WKSET /= WTPRFAC ) THEN

                MESG = 'WARNING: EPS2.0 format files will be using ' //
     &             'non-standard approach of ' // CRLF() // BLANK10 //
     &             'weekday normalized weekly profiles.  Can ' //
     &             'correct by setting ' // CRLF() // BLANK10 //
     &             'WKDAY_NORMALIZE to N and rerunning.'
                CALL M3MSG2( MESG )

            END IF
        END DO

C.........  Get annual data setting from environment
        MESG = 'Fill in 0. annual data based on seasonal data.'
        FFLAG = ENVYN( 'FILL_ANN_WSEAS', MESG, .FALSE., IOS )

C.........  Get point specific settings
        IF( CATEGORY == 'POINT' ) THEN
            MESG = 'Flag for recalculating velocity'
            CFLAG = ENVYN( 'VELOC_RECALC', MESG, .FALSE., IOS )
        END IF
        
        IF( CATEGORY == 'POINT' .OR. CATEGORY == 'MOBILE' ) THEN
            MESG = 'Western hemisphere flag'
            WFLAG = ENVYN( 'WEST_HSPHERE', MESG, .FALSE., IOS )
        END IF

C.........  Get maximum number of warnings
        MXWARN = ENVINT( WARNSET, ' ', 100, IOS )

C.........  Set default inventory characteristics (declared in MODINFO) used
C           by the IDA and EPS formats, including NPPOL
        CALL INITINFO( FILFMT( 1 ) )
        
C.........  Allocate memory for storing inventory data
        ALLOCATE( INDEXA( NRAWBP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'INDEXA', PROGNAME )
        ALLOCATE( POLVLA( NRAWBP,NPPOL ), STAT=IOS )
        CALL CHECKMEM( IOS, 'POLVLA', PROGNAME )
        ALLOCATE( INRECA( NRAWBP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'INRECA', PROGNAME )
        ALLOCATE( IPOSCODA( NRAWBP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'IPOSCODA', PROGNAME )
        ALLOCATE( ICASCODA( NRAWBP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'ICASCODA', PROGNAME )
        
        ALLOCATE( TPFLAG( NSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'TPFLAG', PROGNAME )
        ALLOCATE( INVYR( NSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'INVYR', PROGNAME )
        
        IF( CATEGORY == 'MOBILE' ) THEN
            ALLOCATE( XLOC1( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'XLOC1', PROGNAME )
            ALLOCATE( YLOC1( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'YLOC1', PROGNAME )
            ALLOCATE( XLOC2( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'XLOC2', PROGNAME )
            ALLOCATE( YLOC2( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'YLOC2', PROGNAME )
            
            XLOC1 = BADVAL3  ! array
            YLOC1 = BADVAL3  ! array
            XLOC2 = BADVAL3  ! array
            YLOC2 = BADVAL3  ! array
        END IF
        
        IF( CATEGORY == 'POINT' ) THEN
            ALLOCATE( ISIC  ( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'ISIC', PROGNAME )
            ALLOCATE( IDIU  ( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'IDIU', PROGNAME )
            ALLOCATE( IWEK  ( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'IWEK', PROGNAME )
            ALLOCATE( STKHT ( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'STKHT', PROGNAME )
            ALLOCATE( STKDM ( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'STKDM', PROGNAME )
            ALLOCATE( STKTK ( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'STKTK', PROGNAME )
            ALLOCATE( STKVE ( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'STKVE', PROGNAME )
            ALLOCATE( XLOCA ( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'XLOCA', PROGNAME )
            ALLOCATE( YLOCA ( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'YLOCA', PROGNAME )
            ALLOCATE( CORIS ( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'CORIS', PROGNAME )
            ALLOCATE( CBLRID( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'CBLRID', PROGNAME )
            ALLOCATE( CPDESC( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'CPDESC', PROGNAME )

        END IF

C.........  Initialize pollutant-specific values as missing
        POLVLA  = BADVAL3  ! array

C.........  If inventory is list format, open first file for reading
        CURFIL = 1

        IF( LSTFLG ) THEN
            LINE = LSTSTR( CURFIL )

C.............  Check if line is year packet
            LSTYR = GETINVYR( LINE )
            
            IF( LSTYR > 0 ) THEN
                CURFIL = CURFIL + 1
            END IF

C.............  Store path of file name            
            INFILE = LSTSTR( CURFIL )
            
C.............  Open current file
            OPEN( FDEV, FILE=INFILE, STATUS='OLD', IOSTAT=IOS )

C.............  Check for errors while opening file
            IF( IOS /= 0 ) THEN
            
                WRITE( MESG,94010 ) 'Problem at line ', CURFIL, 'of ' //
     &             TRIM( FNAME ) // '.' // ' Could not open file:' //
     &             CRLF() // BLANK5 // TRIM( INFILE ) 
                CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

            ELSE
                WRITE( MESG,94010 ) 'Successful OPEN for ' //
     &             'inventory file:' // CRLF() // BLANK5 //
     &             TRIM( INFILE )
                CALL M3MSG2( MESG ) 

            END IF

C.............  Set default inventory characteristics that depend on file format
            CALL INITINFO( FILFMT( CURFIL ) )

C.........  Otherwise, rewind individual file
        ELSE
            REWIND( FDEV )
        
        END IF

C.........  Allocate memory to store emissions and pollutant from a single line
C.........  For now, set number of pollutants per line to 1 
C           (will change if format is IDA)
        ALLOCATE( READDATA( 1,NPPOL ), STAT=IOS )
        CALL CHECKMEM( IOS, 'READDATA', PROGNAME )
        ALLOCATE( READPOL( 1 ), STAT=IOS )
        CALL CHECKMEM( IOS, 'READPOL', PROGNAME )
        
        CURFMT = FILFMT( CURFIL )

        IREC = 0    ! current record number
        ISTREC = 0  ! current stored record
        SP = 0      ! current source with pollutant index

C.........  Loop through inventory files and read data
        DO

C.............  If reached end of SRCSBYREC array, make sure we finished the file
            IF( ISTREC == NSTRECS ) THEN
!                READ( FDEV, 93000, IOSTAT=IOS ) LINE
!                IF( IOS == 0 ) THEN   ! successful read -> not the end of the file
!                    WRITE( MESG,94010 ) 'INTERNAL ERROR:' //
!     &                  'reached end of records before end ' //
!     &                  'of file.'
!                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
!                ELSE
                    EXIT
!                END IF
            END IF
        
            READ( FDEV, 93000, IOSTAT=IOS ) LINE
            
            IREC = IREC + 1
            
            IF( IOS > 0 ) THEN
                EFLAG = .TRUE.
                WRITE( MESG,94010 ) 'I/O error', IOS,
     &             'reading inventory file at line', IREC
                CALL M3MESG( MESG )
                CYCLE
            END IF
            
C.............  Check if we've reached the end of the file            
            IF( IOS < 0 ) THEN

C.................  If list format, try to open next file
                IF( LSTFLG ) THEN

C.....................  Close current file and reset counter
                    CLOSE( FDEV )
                    IREC = 0
                
                    CURFIL = CURFIL + 1

C.....................  Check if there are more files to read
                    IF( CURFIL <= SIZE( FILFMT ) ) THEN 
                        INFILE = LSTSTR( CURFIL )
                
                        OPEN( FDEV, FILE=INFILE, STATUS='OLD', 
     &                        IOSTAT=IOS )
                
C.........................  Check for errors while opening file
		     	        IF( IOS /= 0 ) THEN
					
				            WRITE( MESG,94010 ) 'Problem at line ', 
     &  		               CURFIL, 'of ' // TRIM( FNAME ) // 
     &  		               '.' // ' Could not open file:' //
     &		                   CRLF() // BLANK5 // TRIM( INFILE ) 
				            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
			
			            ELSE
				            WRITE( MESG,94010 ) 
     &  		              'Successful OPEN for ' //
     &		                  'inventory file(s):' // CRLF() // 
     &                        BLANK5 // TRIM( INFILE )
				            CALL M3MSG2( MESG ) 
			
				        END IF

C.........................  Set default inventory characteristics that depend on file format
			            CALL INITINFO( FILFMT( CURFIL ) )
			            CURFMT = FILFMT( CURFIL )

C.........................  Reallocate memory to store emissions from a single line
                        DEALLOCATE( READDATA, READPOL )
                        ALLOCATE( READDATA( 1,NPPOL ), STAT=IOS )
                        CALL CHECKMEM( IOS, 'READDATA', PROGNAME )
                        ALLOCATE( READPOL( 1 ), STAT=IOS )
                        CALL CHECKMEM( IOS, 'READPOL', PROGNAME )
                        
C.........................  Skip back to the beginning of the loop
                        CYCLE
			  
C.....................  Otherwise, no more files to read, so exit
			        ELSE
			            LSTTIME = .TRUE.
			            EXIT
			        END IF

C.................  Otherwise, not a list file, so exit
                ELSE
                    LSTTIME = .TRUE.
                    EXIT
                END IF
             
            END IF   ! end check for end of file
            
C.............  Skip blank lines
            IF( LINE == ' ' ) CYCLE

C.............  Process line depending on file format and source category
            SELECT CASE( CURFMT )
            CASE( IDAFMT )
                SELECT CASE( CATEGORY )
                CASE( 'AREA' )
                    CALL RDDATAIDAAR( LINE, READDATA, READPOL, 
     &                                NPOLPERLN, INVYEAR, HDRFLAG, 
     &                                EFLAG )
                CASE( 'MOBILE' )
                    CALL RDDATAIDAMB( LINE, READDATA, READPOL,
     &                                NPOLPERLN, INVYEAR, HDRFLAG,
     &                                EFLAG )
                    LNKFLAG = .FALSE.
                CASE( 'POINT' )
                    CALL RDDATAIDAPT( LINE, READDATA, READPOL, 
     &                                NPOLPERLN, INVYEAR, CORS, BLID, 
     &                                DESC, HT, DM, TK, FL, VL, SIC,
     &                                LAT, LON, HDRFLAG, EFLAG )
                END SELECT
            CASE( EMSFMT )
                SELECT CASE( CATEGORY )
                CASE( 'MOBILE' )
                    CALL RDDATAEMSMB( LINE, READDATA, READPOL,
     &                                NPOLPERLN, INVYEAR, X1, Y1,
     &                                X2, Y2, ZONE, LNKFLAG, HDRFLAG, 
     &                                EFLAG )
                END SELECT
            CASE( NTIFMT )
                SELECT CASE( CATEGORY )
                CASE( 'AREA' )
                    CALL RDDATANTIAR( LINE, READDATA, READPOL, 
     &                                INVYEAR, HDRFLAG, EFLAG )
                    NPOLPERLN = 1
                CASE( 'MOBILE' )
                    CALL RDDATANTIMB( LINE, READDATA, READPOL,
     &                                INVYEAR, HDRFLAG, EFLAG )
                    NPOLPERLN = 1
                    LNKFLAG = .FALSE.
                END SELECT
            END SELECT
            
C.............  Check for header lines
            IF( HDRFLAG ) THEN 

C.................  If IDA or EMS format, reallocate emissions memory with proper number
C                   of pollutants per line
                IF( ( CURFMT == IDAFMT .OR. CURFMT == EMSFMT ) .AND. 
     &                NPOLPERLN /= 0 ) THEN
                    DEALLOCATE( READDATA, READPOL )
                    ALLOCATE( READDATA( NPOLPERLN,NPPOL ), STAT=IOS )
                    CALL CHECKMEM( IOS, 'READDATA', PROGNAME )
                    ALLOCATE( READPOL( NPOLPERLN ), STAT=IOS )
                    CALL CHECKMEM( IOS, 'READPOL', PROGNAME )
                END IF

C.................  Calculate day to year conversion factor
                IF( INVYEAR /= 0 ) THEN
                    IF( LSTYR > 0 .AND. INVYEAR /= LSTYR ) THEN
                        WRITE( MESG,94010 ) 'NOTE: Using year', LSTYR,
     &                         'from list file, and not year', INVYEAR,
     &                         'from inventory file.'
                        CALL M3MSG2( MESG )
                        
                        INVYEAR = LSTYR
                    END IF
                    
                    YEAR2DAY = YR2DAY( INVYEAR )
                    DAY2YR = 1. / YEAR2DAY
                END IF
                
                CYCLE
            END IF

C.............  Check that mobile link info is correct
            IF( CATEGORY == 'MOBILE' .AND. LNKFLAG ) THEN
                IF( X1 == ' ' .OR. Y1 == ' ' .OR.
     &              X2 == ' ' .OR. Y2 == ' ' .OR. ZONE == ' ' ) THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 'ERROR: Missing link ' //
     &                     'coordinates or UTM zone at line', IREC
                    CALL M3MSG2( MESG )
                END IF
            
                IF( .NOT. CHKREAL( X1 ) .OR.
     &              .NOT. CHKREAL( Y1 ) .OR.
     &              .NOT. CHKREAL( X2 ) .OR.
     &              .NOT. CHKREAL( Y2 )      ) THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 'ERROR: Link coordinates ' //
     &                     'are not numbers or have bad formatting' //
     &                     CRLF() // BLANK10 // 'at line', IREC
                    CALL M3MSG2( MESG )
                END IF
                
                IF( .NOT. CHKINT( ZONE ) ) THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 'ERROR: UTM zone is not a ' //
     &                     'number or is badly formatted at line', IREC
                    CALL M3MSG2( MESG )
                END IF
            END IF

C.............  Check that point source information is correct
            IF( CATEGORY == 'POINT' ) THEN
                IF( .NOT. CHKREAL( HT ) .OR.
     &              .NOT. CHKREAL( DM ) .OR.
     &              .NOT. CHKREAL( TK ) .OR.
     &              .NOT. CHKREAL( FL ) .OR.
     &              .NOT. CHKREAL( VL )      )THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 'ERROR: Stack parameters ' //
     &                     'are not numbers or have bad formatting' // 
     &                     CRLF() // BLANK10 // 'at line', IREC
                    CALL M3MSG2( MESG )
                END IF
                
                IF( .NOT. CHKREAL( LAT ) .OR.
     &              .NOT. CHKREAL( LON )      ) THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 'ERROR: Latitude and/or ' //
     &                     'longitude are not numbers or have bad ' //
     &                     'formatting' // CRLF() // BLANK10 //
     &                     'at line', IREC
                    CALL M3MSG2( MESG )
                ELSE IF( LAT == ' ' .OR. LON == ' ' ) THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 'ERROR: Latitude and/or ' //
     &                     'longitude are missing at line', IREC
                    CALL M3MSG2( MESG )
                END IF
                
                IF( .NOT. CHKINT( SIC ) ) THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 'ERROR: SIC code is non-' //
     &                     'integer at line', IREC
                    CALL M3MESG( MESG )
                ELSE IF( SIC == ' ' ) THEN
                    IF( NWARN < MXWARN ) THEN
                        WRITE( MESG,94010 ) 'WARNING: Missing SIC ' //
     &                         'code at line', IREC, '. Default ' //
     &                         '0000 will be used.'
                        CALL M3MESG( MESG )
                        NWARN = NWARN + 1
                    END IF
                    SIC = '0000'
                END IF            
            END IF

C.............  Check that data values are numbers
            DO I = 1, NPOLPERLN
                POLNAM = READPOL( I )

C.................  Loop through values for this pollutant
C                   Technically, activities will not have NPPOL values,
C                   but we put in blanks when reading the data to avoid problems
C                   Could check if pollutant is an activity, but that would 
C                   require an extra search to get the pollutant code                            
                DO J = 1, NPPOL
                    IF( .NOT. CHKREAL( READDATA( I,J ) ) ) THEN
                        EFLAG = .TRUE.
                        WRITE( MESG,94010 ) 'ERROR: Emission data, ' //
     &                     'control percentages, and/or emission ' //
     &                     CRLF() // BLANK10 // 'factor for ' //
     &                     TRIM( POLNAM ) // ' are not a number ' //
     &                     'or have bad formatting at line', IREC
                        CALL M3MESG( MESG )
                        EXIT
                    END IF
                END DO  ! end loop over data values
                
                IF( READDATA( I,1 ) == ' ' .AND.
     &              READDATA( I,2 ) == ' '       ) THEN
                    IF( NWARN < MXWARN ) THEN
                        WRITE( MESG,94010 ) 'WARNING: Missing annual' //
     &                     ' AND seasonal emissions for ' // 
     &                     TRIM( POLNAM ) // ' at line', IREC
                        CALL M3MESG( MESG )
                        NWARN = NWARN + 1
                    END IF
                    READDATA( I,1 ) = '0.'
                    READDATA( I,2 ) = '0.'
                END IF            
            END DO  ! end loop over pollutants per line

C.............  Skip rest of loop if an error has occured
            IF( EFLAG ) CYCLE

C.............  Get current CAS number position and check that it is valid
            IF( CURFMT == NTIFMT ) THEN
                POLNAM = READPOL( 1 )
                UCASPOS = FINDC( POLNAM, NUNIQCAS, UNIQCAS )
                IF( UCASPOS < 1 ) THEN
                    WRITE( MESG,94010 ) 'Source dropped: ' //
     &                  'CAS number ' // TRIM( POLNAM ) //
     &                  ' at line', IREC, CRLF() // BLANK5 //
     &                  'is not in the inventory pollutants list'
                    CALL M3MESG( MESG )
                    CYCLE

C.................  Check if any part of the CAS number is kept;
C                   could skip rest of loop since no emissions will 
C                   by stored, but need values for reporting
                ELSE 
                    IF( UCASNKEP( UCASPOS ) == 0 ) THEN
                        NOPOLFLG = .TRUE.
                    ELSE
                        NOPOLFLG = .FALSE.
                    END IF
                END IF

            ELSE
C.................  For non-toxic sources, set UCASPOS to use in ICASCODA
                UCASPOS = 0
                NOPOLFLG = .FALSE.
            END IF

C.............  Increment number of stored records and double check that we are
C               where we're supposed to be
            IF( .NOT. NOPOLFLG ) THEN
                ISTREC = ISTREC + 1
                IF( SRCSBYREC( RECIDX( ISTREC ),1 ) /= CURFIL .OR.
     &              SRCSBYREC( RECIDX( ISTREC ),2 ) /= IREC       ) THEN
                    MESG = 'INTERNAL ERROR: Current record does ' //
     &                 'not match expected record'
                        CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                END IF
            END IF   

C.............  Get source ID for current source
            CURSRC = SRCIDA( SRCSBYREC( RECIDX( ISTREC ),3 ) )

C.............  Loop through all pollutants for current line
            DO I = 1, NPOLPERLN
                        
                POLNAM = READPOL( I )

C.................  If format is not NTI, find code corresponding to current pollutant
                ACTFLAG = .FALSE.
                IF( CURFMT /= NTIFMT ) THEN
                    POLCOD = INDEX1( POLNAM, MXIDAT, INVDNAM )
                    IF( POLCOD == 0 ) THEN
                        WRITE( MESG,94010 ) 'ERROR: Unknown  ' //
     &                      'pollutant ' // TRIM( POLNAM ) // 
     &                      ' at line', IREC
                        CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                    END IF
                    
                    IF( INVSTAT( POLCOD ) < 0 ) THEN
                        ACTFLAG = .TRUE.
                    END IF
                END IF
            
C.................  Convert data to real numbers and check for missing values                
                EANN = STR2REAL( READDATA( I,NEM ) )
                
                IF( EANN < AMISS3 .OR. EANN == -9 ) THEN
                    IF( NWARN < MXWARN ) THEN
                        IF( ACTFLAG ) THEN
                            WRITE( MESG,94010 ) 'WARNING: Missing ' //
     &                          'inventory data for ' //
     &                          TRIM( POLNAM ) // ' at line', IREC
                        ELSE
                            WRITE( MESG,94010 ) 'WARNING: Missing ' //
     &                          'annual emissions for ' // 
     &                          TRIM( POLNAM ) // ' at line', IREC
                        END IF
                        CALL M3MESG( MESG )
                        NWARN = NWARN + 1
                    END IF
                    
                    EANN = BADVAL3
                END IF
                
                IF( .NOT. ACTFLAG ) THEN
                    EOZN = STR2REAL( READDATA( I,NOZ ) )
                
                    IF( EOZN < AMISS3 .OR. EOZN == -9 ) THEN
                        IF( NWARN < MXWARN ) THEN
                            WRITE( MESG,94010 ) 'WARNING: ' //
     &                          'Missing seasonal emissions for ' //
     &                          TRIM( POLNAM ) // ' at line', IREC
                            CALL M3MESG( MESG )
                            NWARN = NWARN + 1
                        END IF
                        
                        EOZN = BADVAL3
                    END IF
                END IF

C.................  For area and point, convert control percentages
                IF( CATEGORY == 'AREA' .OR. CATEGORY == 'POINT' ) THEN
                    EMFC = STR2REAL( READDATA( I,NEF ) )
                    
                    IF( EMFC < AMISS3 .OR. EMFC == -9 ) THEN
                        IF( NWARN < MXWARN ) THEN
                            WRITE( MESG,94010 ) 'WARNING: Missing ' //
     &                         'emission factor for ' //
     &                         TRIM( POLNAM ) // ' at line', IREC
                            CALL M3MESG( MESG )
                            NWARN = NWARN + 1
                        END IF
                        
                        EMFC = BADVAL3
                    END IF
                
                    CEFF = STR2REAL( READDATA( I,NCE ) )
                    
                    IF( CEFF < AMISS3 .OR. CEFF == -9 ) THEN
                        IF( NWARN < MXWARN ) THEN
                            WRITE( MESG,94010 ) 'WARNING: Missing ' //
     &                         'control efficiency for ' //
     &                         TRIM( POLNAM ) // ' at line', IREC
                            CALL M3MESG( MESG )
                            NWARN = NWARN + 1
                        END IF
                        
                        CEFF = BADVAL3
                    END IF
                    
                    REFF = STR2REAL( READDATA( I,NRE ) )
                    
                    IF( REFF < AMISS3 .OR. REFF == -9 ) THEN
                        IF( NWARN < MXWARN ) THEN
                            WRITE( MESG,94010 ) 'WARNING: Missing ' //
     &                         'rule effectiveness for ' //
     &                         TRIM( POLNAM ) // ' at line', IREC
                            CALL M3MESG( MESG )
                            NWARN = NWARN + 1
                        END IF
                        
                        REFF = BADVAL3
                    END IF
                END IF
                
                IF( CATEGORY == 'AREA' ) THEN    
                    RPEN = STR2REAL( READDATA( I,NRP ) )
                    
                    IF( RPEN < AMISS3 .OR. RPEN == -9 ) THEN
                        IF( NWARN < MXWARN ) THEN
                            WRITE( MESG,94010 ) 'WARNING: Missing ' //
     &                         'rule penetration for ' //
     &                         TRIM( POLNAM ) // ' at line', IREC
                            CALL M3MESG( MESG )
                            NWARN = NWARN + 1
                        END IF
                        
                        RPEN = BADVAL3
                    END IF
                END IF
                
                IF( CATEGORY == 'POINT' ) THEN
                    CPRI = STR2REAL( READDATA( I,NC1 ) )
                    
                    IF( CPRI < AMISS3 .OR. CPRI == -9 ) THEN
                        IF( NWARN < MXWARN ) THEN
                            WRITE( MESG,94010 ) 'WARNING: Missing ' //
     &                         'primary control code for ' //
     &                        TRIM( POLNAM ) // ' at line', IREC
                            CALL M3MESG( MESG )
                            NWARN = NWARN + 1
                        END IF
                        
                        CPRI = BADVAL3
                    END IF
                    
                    CSEC = STR2INT( READDATA( I,NC2 ) )
                    
                    IF( CSEC < AMISS3 .OR. CSEC == -9 ) THEN
                        IF( NWARN < MXWARN ) THEN
                            WRITE( MESG,94010 ) 'WARNING: Missing ' //
     &                         'secondary control code for ' //
     &                         TRIM( POLNAM ) // ' at line', IREC
                            CALL M3MESG( MESG )
                            NWARN = NWARN + 1
                        END IF
                        
                        CSEC = BADVAL3
                    END IF
                END IF

C.................  Set the default temporal resolution of the data
                TPF = MTPRFAC * WKSET

C.................  Replace annual data with ozone-season information
C                   Only do this if current pollutant is not an activity, flag is set,
C                   annual data is less than or equal to zero and ozone
C                   data is greater than zero
                IF( .NOT. ACTFLAG .AND. 
     &                      FFLAG .AND. 
     &                 EANN <= 0. .AND. 
     &                 EOZN >  0.       ) THEN
                    WRITE( MESG,94010 ) 'NOTE: Using seasonal ' //
     &                 'emissions to fill in annual emissions' //
     &                 CRLF() // BLANK10 // 'for ' // TRIM( POLNAM ) //
     &                 ' at line', IREC
                    CALL M3MESG( MESG )
                    
                    EANN = EOZN * DAY2YR

C.....................  Remove monthly factors for this source
                    TPF = WKSET
                END IF

C.................  Calculate season emissions from annual data if needed
C                   Only do this if current pollutant is not an activity,
C                   annual data is greater than zero, and ozone data is
C                   zero or negative
                IF( .NOT. ACTFLAG .AND. 
     &                 EANN >  0. .AND. 
     &                 EOZN <= 0.       ) THEN
                    EOZN = EANN * YEAR2DAY
                END IF

C.................  If current format is NTI, check if current CAS number
C                   is split
                IF( CURFMT == NTIFMT ) THEN
                    NPOLPERCAS = UCASNPOL( UCASPOS )

C.....................  Store emissions by CAS number for reporting
                    EMISBYCAS( UCASPOS ) = EMISBYCAS( UCASPOS ) + EANN
                    RECSBYCAS( UCASPOS ) = RECSBYCAS( UCASPOS ) + 1

                ELSE
                    NPOLPERCAS = 1
                    POLFAC = 1.
                END IF
                    
                DO J = 0, NPOLPERCAS - 1

C.....................  If NTI format, set current pollutant
                    IF( CURFMT == NTIFMT ) THEN

                        SCASPOS = UCASIDX( UCASPOS ) + J

C.........................  Set factor for this CAS number
                        POLFAC = ITFACA( SCASIDX( SCASPOS ))

C.........................  Multiply annual emissions by factor                        
                        IF( EANN > 0. ) THEN
                            POLANN = EANN * POLFAC
                        END IF
                        
C.........................  Store emissions by pollutant for reporting
                        EMISBYPOL( SCASPOS ) = 
     &                      EMISBYPOL( SCASPOS ) + POLANN
                        
C.........................  Make sure current pollutant is kept
                        IF( ITKEEPA( SCASIDX( SCASPOS ) ) ) THEN
                            POLNAM = ITNAMA( SCASIDX( SCASPOS ) ) 
                        ELSE
                            CYCLE
                        END IF
                                                
C.........................  Find code corresponding to current pollutant
                        POLCOD = INDEX1( POLNAM, MXIDAT, INVDNAM )
                        IF( POLCOD == 0 ) THEN
                            WRITE( MESG,94010 ) 'ERROR: Unknown  ' //
     &                          'pollutant ' // TRIM( POLNAM ) // 
     &                          ' at line', IREC
                            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                        END IF

                    ELSE  
                        POLANN = EANN
                    END IF
                
C.....................  Store data in unsorted order
                    SP = SP + 1
                
                    IF( SP <= NRAWBP ) THEN

C......................... If mobile EMS format, loop through vehicle types                         
                        IF( CATEGORY == 'MOBILE' .AND.
     &                      CURFMT   == EMSFMT       ) THEN
     
                            DO K = 1, NVTYPE
                                
                                IF( SP > NRAWBP ) EXIT
                                
                                INRECA( SP ) = CURSRC
                                INDEXA( SP ) = SP
                                IPOSCODA( SP ) = POLCOD
                                ICASCODA( SP ) = UCASPOS
                                POLVLA( SP,NEM ) = INVDCNV( POLCOD ) * 
     &                                             POLANN
                                
                                IF( K < NVTYPE ) THEN
                                    SP = SP + 1
                                    ISTREC = ISTREC + 1
                                    CURSRC = SRCIDA( SRCSBYREC( 
     &                                         RECIDX( ISTREC ),3 ) )
                                END IF
                            END DO
                        ELSE
                        
                            INRECA  ( SP ) = CURSRC    ! map to sorted source number
                            INDEXA  ( SP ) = SP        ! index for sorting POLVLA
                            IPOSCODA( SP ) = POLCOD    ! pollutant code
                            ICASCODA( SP ) = UCASPOS   ! CAS number (set to 0 for non-toxic sources)
                        
                            POLVLA( SP,NEM ) = INVDCNV( POLCOD ) * 
     &                                         POLANN
                            
                            IF( .NOT. ACTFLAG ) THEN
                                IF( EOZN > 0. ) THEN
                                    POLVLA( SP,NOZ ) = EOZN * POLFAC
                                ELSE
                                    POLVLA( SP,NOZ ) = EOZN
                                END IF
                            END IF
                        
                            IF( CATEGORY == 'AREA' .OR. 
     &                          CATEGORY == 'POINT'     ) THEN
                                POLVLA( SP,NEF ) = EMFC
                                POLVLA( SP,NCE ) = CEFF
                                POLVLA( SP,NRE ) = REFF
                            END IF    
                            
                            IF( CATEGORY == 'AREA' ) THEN    
                                POLVLA( SP,NRP ) = RPEN
                            END IF
                            
                            IF( CATEGORY == 'POINT' ) THEN
                                POLVLA( SP,NC1 ) = CPRI
                                POLVLA( SP,NC2 ) = CSEC
                            END IF
                        END IF
                    END IF

                END DO  ! end loop through pols per CAS number

            END DO  ! end loop through pols per line
            
C.............  Store source specific values in sorted order
            IF( CATEGORY == 'MOBILE' .AND. CURFMT == EMSFMT ) THEN
            
C.................  Convert link coordinates from UTM to lat-lon
                IF( LNKFLAG ) THEN
                    IZONE = STR2INT( ZONE )
                    
                    XLOCA1 = STR2REAL( X1 )
                    YLOCA1 = STR2REAL( Y1 )
                    XLOCA2 = STR2REAL( X2 )
                    YLOCA2 = STR2REAL( Y2 )
                    
                    IF( IZONE > 0 ) THEN
                        XLOC = XLOCA1
                        YLOC = YLOCA1
                        CALL UTM2LL( XLOC, YLOC, IZONE, XLOCA1, YLOCA1 )
                    
                        XLOC = XLOCA2
                        YLOC = YLOCA2
                        CALL UTM2LL( XLOC, YLOC, IZONE, XLOCA2, YLOCA2 )
                    END IF

C.....................  Convert lat-lon coords to western hemisphere                    
                    IF( WFLAG ) THEN
                        IF( XLOCA1 > 0 ) XLOCA1 = -XLOCA1
                        IF( XLOCA2 > 0 ) XLOCA2 = -XLOCA2
                    END IF
                END IF                
                    
                DO I = NVTYPE,1,-1
                    CURSRC = SRCIDA( SRCSBYREC( 
     &                               RECIDX( ISTREC-I+1 ),3 ) )
     
                    INVYR ( CURSRC ) = INVYEAR
                    TPFLAG( CURSRC ) = TPF
            
                    IF( LNKFLAG ) THEN
                        XLOC1( CURSRC ) = XLOCA1
                        YLOC1( CURSRC ) = YLOCA1
                        XLOC2( CURSRC ) = XLOCA2
                        YLOC2( CURSRC ) = YLOCA1
                    END IF
                END DO

C.................  Skip rest of loop                
                CYCLE
            END IF
                 
            INVYR ( CURSRC ) = INVYEAR
            TPFLAG( CURSRC ) = TPF
            
            IF( CATEGORY == 'POINT' ) THEN
                ISIC  ( CURSRC ) = STR2INT( SIC )
                STKHT ( CURSRC ) = STR2REAL( HT )
                STKDM ( CURSRC ) = STR2REAL( DM )
                STKTK ( CURSRC ) = STR2REAL( TK )
                STKVE ( CURSRC ) = STR2REAL( VL )
                XLOCA ( CURSRC ) = STR2REAL( LON )
                YLOCA ( CURSRC ) = STR2REAL( LAT )
                CORIS ( CURSRC ) = CORS
                CBLRID( CURSRC ) = BLID
                CPDESC( CURSRC ) = DESC

C.................  Convert units on values                
                IF( CURFMT == IDAFMT ) THEN
                    IF( STKHT( CURSRC ) < 0. ) STKHT( CURSRC ) = 0.
                    STKHT( CURSRC ) = STKHT( CURSRC ) * FT2M   ! ft to m
                    
                    IF( STKDM( CURSRC ) < 0. ) STKDM( CURSRC ) = 0.
                    STKDM( CURSRC ) = STKDM( CURSRC ) * FT2M   ! ft to m
                    
                    IF( STKTK( CURSRC ) < 0. ) THEN
                        STKTK( CURSRC ) = 0.
                    ELSE
                        STKTK( CURSRC ) = ( STKTK( CURSRC ) - 32 ) *   ! F to K
     &                                    FTOC + CTOK
                    END IF
                    
C.....................  Recompute velocity if that option has been set
                    IF( CFLAG .OR. STKVE( CURSRC ) == 0. ) THEN
                        RBUF = 0.25 * PI * 
     &                         STKDM( CURSRC ) * STKDM( CURSRC )
                        
                        REALFL = STR2REAL( FL )
                        IF( REALFL < 0. ) REALFL = 0.
                        REALFL = REALFL * FT2M3                 ! ft^3/s to m^3/s
                        
                        IF( RBUF > 0 ) THEN
                            STKVE( CURSRC ) = REALFL / RBUF
                        END IF
                    ELSE
                        STKVE( CURSRC ) = STKVE( CURSRC ) * FT2M  ! ft/s to m/s
                    END IF

C.....................  Correct hemisphere for stack longitude
                    IF( WFLAG .AND. XLOCA( CURSRC ) > 0. ) THEN
                        XLOCA( CURSRC ) = -XLOCA( CURSRC )
                    END IF
                    
                END IF
            END IF
            
        END DO  ! end loop through records array

C.........  Abort if there was an error
        IF( EFLAG ) THEN
            MESG = 'Error reading data from inventory file ' //
     &              TRIM( FNAME )
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        END IF
            
C.........  Sort inventory data by source
        CALL M3MESG( 'Sorting inventory data by source ' //
     &               'and pollutant...' )
        
        CALL SORTI2( SP, INDEXA, INRECA, IPOSCODA )

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats............ 94xxx

93000   FORMAT( A )

94010   FORMAT( 10( A, :, I8, :, 1X ) )

94060   FORMAT( 10( A, :, E10.3, :, 1X ) )

        END SUBROUTINE RDINVDATA
