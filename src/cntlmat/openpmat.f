
        SUBROUTINE OPENPMAT( ENAME, BYEARIN, PYEAR, PNAME )

C***********************************************************************
C  subroutine body starts at line 87
C
C  DESCRIPTION:
C      Open the projection matrix.
C
C  PRECONDITIONS REQUIRED:
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C     
C
C****************************************************************************/
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

C.........  MODULES for public variables
C.........  This module contains the information about the source category
        USE MODINFO

C.........This module is required by the FileSetAPI
        USE MODFILESET

        IMPLICIT NONE

C...........   INCLUDES
        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'IODECL3.EXT'   !  I/O API function declarations
        INCLUDE 'SETDECL.EXT'   !  FileSetAPI variables and functions

C...........   EXTERNAL FUNCTIONS and their descriptions:
        CHARACTER*2            CRLF
        CHARACTER(LEN=IODLEN3) GETCFDSC
        INTEGER                GETIFDSC   
        CHARACTER*16           VERCHAR

        EXTERNAL     CRLF, GETCFDSC, GETIFDSC, VERCHAR

C...........   LOCAL PARAMETERS
        CHARACTER*50, PARAMETER :: CVSW = '$Name$' ! CVS release tag

C.........  SUBROUTINE ARGUMENTS
        CHARACTER(*), INTENT (IN) :: ENAME      ! emissions inven logical name
        INTEGER     , INTENT (IN) :: BYEARIN    ! base year of proj factors
        INTEGER     , INTENT (IN) :: PYEAR      ! projected year of proj factors
        CHARACTER(*), INTENT(OUT) :: PNAME      ! projection file name

      
C.........  Other local variables
        INTEGER          I, J           !  counters and indices
        INTEGER          IOS            !  i/o status

        CHARACTER(LEN=NAMLEN3) NAMBUF   ! file name buffer
        CHARACTER*300          MESG     ! message buffer

        CHARACTER(LEN=IODLEN3) IFDESC2, IFDESC3 ! fields 2 & 3 from inven FDESC

        CHARACTER*16 :: PROGNAME = 'OPENPMAT' ! program name

C***********************************************************************
C   begin body of subroutine OPENPMAT

C.........  Get header information from inventory file

        IF ( .NOT. DESCSET( ENAME,-1 ) ) THEN
            MESG = 'Could not get description of file "' 
     &             // ENAME( 1:LEN_TRIM( ENAME ) ) // '".'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        END IF

        IFDESC2 = GETCFDSC( FDESC3D, '/FROM/', .TRUE. )
        IFDESC3 = GETCFDSC( FDESC3D, '/VERSION/', .TRUE. )

C.........  Initialize I/O API output file headers
        CALL HDRMISS3

C.........  Set I/O API header parms that need values
        NVARSET = 1
        NROWS3D = NSRC

        FDESC3D( 1 ) = CATEGORY( 1:CATLEN ) // ' projection matrix'
        FDESC3D( 2 ) = '/FROM/ '    // PROGNAME
        FDESC3D( 3 ) = '/VERSION/ ' // VERCHAR( CVSW )

        WRITE( FDESC3D( 4 ), '(A,I4)' ) '/CTYPE/ ', CTYPPROJ
        WRITE( FDESC3D( 5 ), '(A,I4)' ) '/BASE YEAR/ ', BYEARIN
        WRITE( FDESC3D( 6 ), '(A,I4)' ) '/PROJECTED YEAR/ ', PYEAR

        FDESC3D( 11 ) = '/INVEN FROM/ ' // IFDESC2
        FDESC3D( 12 ) = '/INVEN VERSION/ ' // IFDESC3

        IF( ALLOCATED( VTYPESET ) ) 
     &      DEALLOCATE( VTYPESET, VNAMESET, VUNITSET, VDESCSET )
        ALLOCATE( VTYPESET( NVARSET ), STAT=IOS )
        CALL CHECKMEM( IOS, 'VTYPESET', PROGNAME )
        ALLOCATE( VNAMESET( NVARSET ), STAT=IOS )
        CALL CHECKMEM( IOS, 'VNAMESET', PROGNAME )
        ALLOCATE( VUNITSET( NVARSET ), STAT=IOS )
        CALL CHECKMEM( IOS, 'VUNITSET', PROGNAME )
        ALLOCATE( VDESCSET( NVARSET ), STAT=IOS )
        CALL CHECKMEM( IOS, 'VDESCSET', PROGNAME )

C.........  Also deallocate the number of variables per file so
C           that this will be set automatically by openset
        DEALLOCATE( VARS_PER_FILE )

C.........  Set up non-speciation variables
        J = 1
        VNAMESET( J )= 'pfac'  ! Lowercase used to permit inv data named "PFAC"
        VTYPESET( J )= M3REAL
        VUNITSET( J )= 'n/a'
        VDESCSET( J )= 'Projection factor'

        MESG = 'Enter logical name for projection matrix...'
        CALL M3MSG2( MESG )

C.........  Open projection matrix.
C.........  Using NAMBUF is needed for HP to ensure string length consistencies

        MESG = 'I/O API PROJECTION MATRIX'

        NAMBUF = PROMPTSET( MESG, FSUNKN3, CRL // 'PMAT', 
     &                      PROGNAME )
        PNAME = NAMBUF

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )

        END SUBROUTINE OPENPMAT
