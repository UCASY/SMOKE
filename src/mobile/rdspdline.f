
        SUBROUTINE RDSPDLINE( SDEV, SCENNUM, CURRCOUNTY, NLINES,
     &                        LASAFLAG, ROADTYPE, SPEED, CURRLINE, 
     &                        SRCCT )

C***********************************************************************
C  subroutine body starts at line 88
C
C  DESCRIPTION:
C       Reads in all sources from the SPDSUM file for a given speed
C
C  PRECONDITIONS REQUIRED:
C
C  SUBROUTINES AND FUNCTIONS CALLED:  none
C
C  REVISION  HISTORY:
C     10/01: Created by C. Seppanen
C
C***********************************************************************
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
C***********************************************************************

C.........  MODULES for public variables

C...........   This module contains emission factor tables and related
        USE MODEMFAC
        
        IMPLICIT NONE

C...........   INCLUDES:

        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'M6CNST3.EXT'   !  MOBILE6 constants
        
C...........   EXTERNAL FUNCTIONS and their descriptions:
        INTEGER           STR2INT
        REAL              STR2REAL
        CHARACTER(LEN=2)  CRLF    
        
        EXTERNAL  STR2INT, STR2REAL, CRLF

C...........   SUBROUTINE ARGUMENTS
        INTEGER,                INTENT (IN)   :: SDEV        ! SPDSUM file unit number
        INTEGER,                INTENT (IN)   :: SCENNUM     ! current scenario number
        CHARACTER(LEN=FIPLEN3), INTENT (IN)   :: CURRCOUNTY  ! current county being processed
        INTEGER,                INTENT (IN)   :: NLINES      ! number of lines in SPDSUM file
        INTEGER,                INTENT (IN)   :: LASAFLAG    ! local-as-arterial setting for current county
        INTEGER,                INTENT (OUT)  :: ROADTYPE    ! road type from SPDSUM file
        REAL,                   INTENT (OUT)  :: SPEED       ! speed value from SPDSUM file
        INTEGER,                INTENT(INOUT) :: CURRLINE    ! current line number in SPDSUM file
        INTEGER,                INTENT(INOUT) :: SRCCT       ! total number of sources       

C...........   Local arrays
        INTEGER       SOURCES( 7 )          ! line of sources from SPDSUM file

C...........   Other local variables
        INTEGER I, J                      ! counters and indices                     
        
        INTEGER IOS                       ! I/O status
        INTEGER COUNTY                    ! county from SPDSUM file

        LOGICAL   :: EFLAG     = .FALSE. !  true: error found
                
        CHARACTER   CONTCHAR              ! continuation character from SPDSUM file
        CHARACTER(LEN=6)       SPDSTR     ! string for reading speed info
        CHARACTER(LEN=300)     MESG       !  message buffer

        CHARACTER*16 :: PROGNAME = 'RDSPDLINE'   ! program name

C***********************************************************************
C   begin body of subroutine RDSPDLINE

        SOURCES = 0
        
        DO

C.............  Make sure we don't try to read past the end of the file
            IF( CURRLINE > NLINES ) THEN
            	ROADTYPE = M6LOCAL
            	SPEED = 0.
            	EXIT
            END IF

C.............  Read line from SPDSUM file
            READ( SDEV, 93010, IOSTAT=IOS ) COUNTY, ROADTYPE, 
     &            SPDSTR, SOURCES( 1:7 ), CONTCHAR
       
            IF( IOS /= 0 ) THEN
                EFLAG = .TRUE.
                
                IF( IOS == -1 ) THEN
                    MESG = 'End of file reached unexpectedly. ' //
     &                     'Check format of SPDSUM file.'
                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )   
                END IF
                
                WRITE( MESG, 94010 )
     &                 'I/O error', IOS,
     &                 'reading speed summary file at line', CURRLINE
                CALL M3MESG( MESG )
                CYCLE
            END IF

C.............  Check that county from SPDSUM is still current county                
            IF( STR2INT( CURRCOUNTY ) /= COUNTY ) THEN
                BACKSPACE( SDEV )
            	ROADTYPE = M6LOCAL
            	SPEED = 0.
                EXIT
            END IF

C.............  Increment line count
            CURRLINE = CURRLINE + 1

C.............  Convert speed depending on format (if decimal point is present, 
C               store as actual speed, otherwise it references a profile and 
C               is stored as a negative number)
            IF( INDEX( SPDSTR, '.' ) == 0 ) THEN
                SPEED = -STR2REAL( ADJUSTL( SPDSTR ) )
            ELSE
                SPEED = STR2REAL( ADJUSTL( SPDSTR ) )
            END IF
            
C.............  Store scenario numbers with sources
            DO J = 1, 7
            
C.................  Exit if done with sources for this line
                IF( SOURCES( J ) == 0 ) EXIT
                    
                SRCCT = SRCCT + 1

C.................  Stick local sources in with previous scenario                    
                IF( ROADTYPE == M6LOCAL ) THEN
                    SCENLIST( SOURCES( J ),1 ) = SCENNUM - 1
                ELSE
                    SCENLIST( SOURCES( J ),1 ) = SCENNUM
                END IF
                    
                SCENLIST( SOURCES( J ),2 ) = LASAFLAG
            END DO

C.............  Check if there are more lines to read for this speed and road type
            IF( CONTCHAR /= '\' ) EXIT

        END DO

C.........  Abort if error found while reading SPDSUM file
        IF( EFLAG ) THEN
            MESG = 'Problem reading SPDSUM file'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        END IF

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Formatted file I/O formats............ 93xxx

93000   FORMAT( A )
93010   FORMAT( I6, 1X, I1, 1X, A6, 7( 1X, I6 ), 1X, 1A )  

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )
        
        END SUBROUTINE RDSPDLINE
        