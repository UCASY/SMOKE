
        SUBROUTINE GENAGMAT( GNAME, MXSCEL, NASRC, NGRID, NMATX, 
     &                       NX, IX, CX, NCOEF, CMAX, CMIN )

C***********************************************************************
C  subroutine body starts at line
C
C  DESCRIPTION:
C
C  PRECONDITIONS REQUIRED:
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C      Created by M. Houyoux 5/99
C
C****************************************************************************/
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C
C COPYRIGHT (C) 1999, MCNC--North Carolina Supercomputing Center
C All Rights Reserved
C
C See file COPYRIGHT for conditions of use.
C
C Environmental Programs Group
C MCNC--North Carolina Supercomputing Center
C P.O. Box 12889
C Research Triangle Park, NC  27709-2889
C
C env_progs@mcnc.org
C
C Pathname: $Source$
C Last updated: $Date$ 
C
C***************************************************************************

C...........   MODULES for public variables
C...........   This module is the source inventory arrays
        USE MODSOURC

C...........   This module contains the cross-reference tables
        USE MODXREF

C...........   This module contains the gridding surrogates tables
        USE MODSURG

C.........  This module contains the lists of unique source characteristics
        USE MODLISTS

C.........  This module contains the information about the source category
        USE MODINFO

        IMPLICIT NONE

C...........   INCLUDES

        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'PARMS3.EXT'    !  I/O API parameters
        INCLUDE 'IODECL3.EXT'   !  I/O API function declarations
        INCLUDE 'FDESC3.EXT'    !  I/O API file description data structures

C...........   EXTERNAL FUNCTIONS 
        CHARACTER*2     CRLF
        INTEGER         FIND1
        INTEGER         FINDC
        LOGICAL         DSCM3GRD

        EXTERNAL        CRLF, FIND1, FINDC, DSCM3GRD

C...........   SUBROUTINE ARGUMENTS
        CHARACTER(*), INTENT (IN) :: GNAME         ! gridding mtx logical name
        INTEGER     , INTENT (IN) :: MXSCEL        ! max sources per cell
        INTEGER     , INTENT (IN) :: NASRC         ! no. mobile sources
        INTEGER     , INTENT (IN) :: NGRID         ! actual grid cell count
        INTEGER     , INTENT (IN) :: NMATX         ! no. source-cell intersects
        INTEGER     , INTENT(OUT) :: NX  ( NGRID ) ! no. srcs per cell
        INTEGER     , INTENT(OUT) :: IX  ( NMATX ) ! src IDs 
        REAL        , INTENT(OUT) :: CX  ( NMATX ) ! gridding coefficients
        INTEGER     , INTENT(OUT) :: NCOEF         ! no. of gridding coeffs
        INTEGER     , INTENT(OUT) :: CMAX          ! max no. of sources per cell
        INTEGER     , INTENT(OUT) :: CMIN          ! min no. of sources per cell

C...........   Local arrays dimensioned by subroutine arguments...

C...........   Scratch Gridding Matrix (subscripted by source-within-cell, cell)

        INTEGER     IS ( MXSCEL, NGRID ) ! source IDs for each cell
        REAL        CS ( MXSCEL, NGRID ) ! factors 

C...........   Temporary array for flagging sources that are outside the
C              domain and for flagging sources with all zero surrogates
        LOGICAL     INDOMAIN( NASRC )    ! true: source is in the domain
        LOGICAL     SRCSTAT ( NASRC )    ! true: source has non-zero surrogates

C.........  Local allocatable arrays
        INTEGER, ALLOCATABLE :: FIPNOSRG( : )  ! cy/st/co codes w/o surrogates

C...........   Other local variables

        INTEGER         C, F, I, J, K, N, S !  indices and counters.

        INTEGER         FIP     ! tmp country/state/county code
        INTEGER         IOS     ! i/o status
        INTEGER         ISIDX   ! tmp surrogate ID code index
        INTEGER         JMAX    ! counter for storing correct max dimensions
        INTEGER         L2      ! string length
        INTEGER         LFIP    ! cy/st/co code from previous iteration
        INTEGER         NCEL    ! tmp number of cells 
        INTEGER         NNOSRG  ! no. of cy/st/co codes with no surrogates

        REAL            FRAC    ! tmp surrogate fraction

        LOGICAL      :: EFLAG = .FALSE.  !  true: error detected

        CHARACTER*16    COORD     !  coordinate system name
        CHARACTER*16    COORUNIT  !  coordinate system projection units
        CHARACTER*16    GRDNM     !  grid name
        CHARACTER*80    GDESC     !  grid description
        CHARACTER*300   BUFFER    !  source fields buffer
        CHARACTER*300   MESG      !  message buffer 

        CHARACTER(LEN=SRCLEN3)    CSRC  ! tmp source chars string

        CHARACTER*16 :: PROGNAME = 'GENAGMAT' ! program name

C***********************************************************************
C   begin body of subroutine GENAGMAT

C.........  Get grid name from the environment and read grid parameters
        IF( .NOT. DSCM3GRD( GRDNM, GDESC, COORD, GDTYP3D, COORUNIT, 
     &                      P_ALP3D, P_BET3D, P_GAM3D, XCENT3D, YCENT3D,
     &                      XORIG3D, YORIG3D, XCELL3D, YCELL3D,
     &                      NCOLS3D, NROWS3D, NTHIK3D ) ) THEN

            MESG = 'Could not get Models-3 grid description'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

C.........  Store grid parameters for later processing
        ELSE

            IF( NCOLS3D * NROWS3D .NE. NGRID ) THEN
 
                MESG = 'INTERNAL ERROR: Number of cells in "' //
     &                 PROGNAME( 1:16 ) // '" are inconsistent '//
     &                 'with calling program.'
                CALL M3MSG2( MESG )
                CALL M3EXIT( PROGNAME, 0, 0, ' ', 2 )

            ENDIF

        ENDIF

C.........  Initialize number of sources per cell counter
        NX = 0   ! Array

        ALLOCATE( FIPNOSRG( NINVIFIP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'FIPNOSRG', PROGNAME )

C.........  Allocate memory for temporary

C.......   Compute gridding matrix:
C.......       First case:   explicit link (ILINK > 0
C.......       Second case:  some LNKDEF entry applies
C.......       Third case:   FIP+roadtype cross-reference match
C.......       Fourth case:  state+roadtype cross-reference match
C.......       fifth case:   roadtype cross-reference match
C.......       sixth case:   fallback default

        MESG = 'Computing gridding matrix and statistics...'
        CALL M3MSG2( MESG )

        LFIP  = 0
        NNOSRG   = 0
        JMAX  = -1

        DO S = 1, NSRC
            
            FIP  = IFIP  ( S )
            CSRC = CSOURC( S )

C.............  Initialize sources as being in the domain
            INDOMAIN( S ) = .TRUE.

C.............  Retrieve the indices to the surrogates tables
            ISIDX = SRGIDPOS( S )
            F   = SGFIPPOS( S )

C.............  Store the number and values of unfound cy/st/co codes
C.............  Keep track of sources that are outside the domain
            IF ( F .LE. 0 ) THEN

                IF( FIP .NE. LFIP ) THEN
                    NNOSRG = NNOSRG + 1
                    FIPNOSRG( NNOSRG ) = FIP
                    LFIP = FIP
                END IF
              
                INDOMAIN( S ) = .FALSE.
                CYCLE   ! To next source

            END IF

C.............  Loop through all of the cells intersecting this FIPS code. 
            DO K = 1, NCELLS( F )
            
                C    = FIPCELL( K,F )  ! Retrieve cell number
                FRAC = SRGFRAC( ISIDX,K,F )
                J    = NX( C )

C.................  Check that the maximum number of sources per cell is ok
C.................  Note that this J comparison to MXSCEL is not the typical
C                   .LE. on purpose.
                IF ( J .LT. MXSCEL .AND. FRAC .NE. 0. ) THEN
                    J = J + 1
                    IS ( J,C ) = S
                    CS ( J,C ) = FRAC

C.................  Keep track of the maximum sources per cell for error mesg
                ELSE
                    IF( J+1 .GT. JMAX ) JMAX = J+1
                END IF

C.................  Store the count of sources for current cell
                NX( C )   = J

            END DO    !  end of loop on cells K for this FIP

        END DO        !  end loop on sources S, computing gridding matrix.

C.........  Abort if overflow occurred
        IF ( JMAX .GT. MXSCEL ) THEN   
            
            WRITE( MESG,94010 )
     &       'INTERNAL ERROR: Gridding matrix not ' //
     &       'written.' // CRLF() // BLANK10 //
     &       'Arrays would have overflowed.' 
     &       // CRLF() // BLANK10 // 
     &       'Current maximum sources per cell (MXSCEL) =', MXSCEL, '.'
     &       // CRLF() // BLANK10 // 
     &       'Actual  maximum sources per cell          =', JMAX  , '.'
            CALL M3MSG2( MESG )
            CALL M3EXIT( PROGNAME, 0, 0, ' ', 2 )

        END IF

C.........  Initialize status of sources as getting zero gridding factors
        SRCSTAT = .FALSE.  ! array

C.........  Compress matrix into I/O representation from scratch 
C.........  representation and compute statistics.
                   
        K    = 0
        CMAX = NX( 1 )
        CMIN = CMAX
        DO C = 1, NGRID  ! Loop through cells
            
            J = NX( C )
                   
            IF (      J .GT. CMAX ) THEN
                CMAX = J
            ELSE IF ( J .LT. CMIN ) THEN
                CMIN = J
            END IF
                   
            DO N = 1, J  ! Loop through sources in this cell
                K = K + 1
                IF ( K .LE. NMATX ) THEN
                    S       = IS( N,C )
                    IX( K ) = S
                    CX( K ) = CS( N,C )
                    SRCSTAT( S ) = .TRUE.
                END IF
            END DO
                   
        END DO    !  end of loop on cells C for this FIP

        NCOEF = K

C.........  Write gridding matrix
        MESG = 'Writing out GRIDDING MATRIX file...'
        CALL M3MSG2( MESG )

        IF( .NOT. WRITE3( GNAME, 'ALL', 0, 0, NX ) ) THEN
            MESG = 'Error writing GRIDDING MATRIX file.'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        END IF

C.........  Report sources that go to zero because of the gridding factors
        DO S = 1, NASRC

            IF( .NOT. SRCSTAT( S ) ) THEN

                CALL FMTCSRC( CSOURC( S ), NCHARS, BUFFER, L2 )
                WRITE( MESG,94010 ) 
     &                 'WARNING: Surrogate data will cause zero ' //
     &                 'emissions inside the grid for:'// CRLF()// 
     &                 BLANK10// BUFFER( 1:L2 )
                CALL M3MESG( MESG )

            END IF

        END DO

C.........  Report FIPS that don't have surrogate data
C.........  Report links that are outside the grid
c        CALL RPSRCOUT( NNOSRG, 0, FIPNOSRG, ' ' )

C.........  Dellallocate locally allocated memory
        DEALLOCATE( FIPNOSRG )

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I9, :, 1X ) )
 
        END SUBROUTINE GENAGMAT

