
        SUBROUTINE PROCAR2PT( NRAWBP )

C**************************************************************************
C  subroutine body starts at line 
C
C  DESCRIPTION:
C      This subroutine process the area-to-point sources, adding X and Y
C      locations and adjusting the annual and average day emissions.
C
C  PRECONDITIONS REQUIRED:
C      
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C      Split from adjustinv.f 1/03 by C. Seppanen 
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
        USE MODSOURC, ONLY: IFIP, NPCNT, IPOSCOD, TPFLAG, INVYR,
     &                      POLVAL, CSOURC, CSCC,
     &                      XLOCA, YLOCA, CELLID

C...........   This module contains the cross-reference tables
        USE MODXREF, ONLY: AR2PTIDX, AR2PTTBL, AR2PTCNT
        
C.........  This module contains the information about the source category
        USE MODINFO, ONLY: NSRC, NEM, NDY, NEF, NRP, NPPOL

C.........  This module contains the arrays for the area-to-point x-form
        USE MODAR2PT, ONLY: AR2PTABL, NCONDSRC, REPAR2PT
        
        IMPLICIT NONE

C...........   INCLUDES
        INCLUDE 'EMCNST3.EXT'   !  emissions constat parameters
        INCLUDE 'PARMS3.EXT'    !  I/O API parameters

C...........   EXTERNAL FUNCTIONS and their descriptions
        INTEGER         STR2INT
        
        EXTERNAL        STR2INT

C...........   SUBROUTINE ARGUMENTS
        INTEGER , INTENT (INOUT) :: NRAWBP  ! no. raw records by pollutant

C...........   Local pointers
        INTEGER, POINTER :: OLDIFIP   ( : )   !  source FIPS ID
        INTEGER, POINTER :: OLDNPCNT  ( : )   !  number of pollutants per source
        INTEGER, POINTER :: OLDIPOSCOD( : )   !  positn of pol in INVPCOD
        INTEGER, POINTER :: OLDTPFLAG ( : )   ! temporal profile types
        INTEGER, POINTER :: OLDINVYR  ( : )   ! inventory year

        REAL   , POINTER :: OLDPOLVAL( :,: )   ! emission values

        CHARACTER(LEN=ALLLEN3), POINTER :: OLDCSOURC( : ) ! concat src
        CHARACTER(LEN=SCCLEN3), POINTER :: OLDCSCC  ( : ) ! scc code

C...........   Local allocatable arrays
        INTEGER, ALLOCATABLE :: REPIDX( : )      ! index for sorting
        INTEGER, ALLOCATABLE :: REPLSCC( : )     ! left half of scc
        INTEGER, ALLOCATABLE :: REPRSCC( : )     ! right half of scc
        INTEGER, ALLOCATABLE :: REPSTA( : )      ! state fips code
        INTEGER, ALLOCATABLE :: REPPOL( : )      ! pollutant number
        REAL   , ALLOCATABLE :: REPORIGEMIS( : ) ! original emissions
        REAL   , ALLOCATABLE :: REPSUMEMIS ( : ) ! split and summed emissions

C...........   Other local variables
        INTEGER         I,J,K,S     ! counters
        INTEGER         IOS         ! I/O error status
        INTEGER         LSTA        ! last state code
        INTEGER         LPOL        ! last pollutant code
        INTEGER         NA2PSRCS    ! no. of area-to-point sources to add
        INTEGER         NA2PRECS    ! no. of sources with pollutants to add
        INTEGER         NEWSRCPOS   ! position in new source arrays
        INTEGER         NEWRECPOS   ! position in new source w/ pollutant arrays
        INTEGER         OLDRECPOS   ! position in old source w/ pollutant arrays
        INTEGER         NREPSRCS    ! total no. of area-to-point sources
        INTEGER         TBLE        ! current area-to-point table number
        INTEGER         TSTA        ! temporary state code
        INTEGER         TPOL        ! temporary pollutant code
        INTEGER         REPPOS      ! position in reporting arrays
        INTEGER         TMPPOS      ! temporary position in reporting arrays
        INTEGER         ROW         ! current area-to-point row
        INTEGER         OLDNSRC     ! old number of srcs

        REAL            FACTOR      ! factor for area-to-point conversion

        CHARACTER(LEN=SRCLEN3)  CSRC        !  temporary source information
        CHARACTER(LEN=SCCLEN3)  LSCC        !  last scc code
        CHARACTER(LEN=SCCLEN3)  TSCC        !  temporary scc code
        CHARACTER(LEN=256    )  MESG        !  message buffer 

        CHARACTER*16 :: PROGNAME = 'PROCAR2PT' ! program name

C***********************************************************************
C   begin body of subroutine PROCAR2PT
            
C.........  Determine total number of sources to be added; if source only
C           has one location, can use existing arrays and don't need to 
C           create additional memory for it
        NA2PSRCS = 0
        NA2PRECS = 0
        NREPSRCS = 0
        
        DO S = 1, NSRC
            IF( AR2PTTBL( S ) /= 0 ) THEN
                NA2PSRCS = NA2PSRCS + AR2PTCNT( S ) - 1
                NA2PRECS = NA2PRECS + (AR2PTCNT( S ) - 1)*NPCNT( S )
                NREPSRCS = NREPSRCS + NPCNT( S )
            END IF
        END DO

C.........  Check if any sources need to be processed
        IF( NREPSRCS == 0 ) RETURN

C.........  Allocate memory for reporting
        ALLOCATE( REPIDX ( NREPSRCS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'REPIDX', PROGNAME )
        ALLOCATE( REPLSCC( NREPSRCS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'REPLSCC', PROGNAME )
        ALLOCATE( REPRSCC( NREPSRCS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'REPRSCC', PROGNAME )
        ALLOCATE( REPSTA( NREPSRCS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'REPSTA', PROGNAME )
        ALLOCATE( REPPOL( NREPSRCS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'REPPOL', PROGNAME )
        ALLOCATE( REPORIGEMIS( NREPSRCS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'REPORIGEMIS', PROGNAME )
        ALLOCATE( REPSUMEMIS( NREPSRCS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'REPSUMEMIS', PROGNAME )

C.........  Store old number of sources
        OLDNSRC = NSRC

        IF( NA2PSRCS > 0 ) THEN

C.............  Update total number of sources and records
            NSRC   = NSRC   + NA2PSRCS
            NRAWBP = NRAWBP + NA2PRECS

C.............  Associate temporary pointers with sorted arrays
            OLDIFIP    => IFIP
            OLDNPCNT   => NPCNT
            OLDIPOSCOD => IPOSCOD
            OLDTPFLAG  => TPFLAG
            OLDINVYR   => INVYR
            
            OLDPOLVAL  => POLVAL
            
            OLDCSOURC  => CSOURC
            OLDCSCC    => CSCC

C.............  Nullify original sorted arrays
            NULLIFY( IFIP, NPCNT, IPOSCOD, TPFLAG, INVYR,
     &               POLVAL, CSOURC, CSCC )

C.............  Deallocate original X and Y location arrays
C               Don't need to store old values since they aren't set
            DEALLOCATE( XLOCA, YLOCA, CELLID )

C.............  Allocate memory for larger sorted arrays
            ALLOCATE( IFIP( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'IFIP', PROGNAME )
            ALLOCATE( NPCNT( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'NPCNT', PROGNAME )
            ALLOCATE( IPOSCOD( NRAWBP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'IPOSCOD', PROGNAME )
            ALLOCATE( TPFLAG( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'TPFLAG', PROGNAME )
            ALLOCATE( INVYR( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'INVYR', PROGNAME )
            
            ALLOCATE( POLVAL( NRAWBP,NPPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'POLVAL', PROGNAME )
            
            ALLOCATE( CSOURC( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'CSOURC', PROGNAME )
            ALLOCATE( CSCC( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'CSCC', PROGNAME )
            
            ALLOCATE( XLOCA( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'XLOCA', PROGNAME )
            ALLOCATE( YLOCA( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'YLOCA', PROGNAME )
            ALLOCATE( CELLID( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'CELLID', PROGNAME )
            
            NPCNT = 0         ! array
            
            POLVAL = BADVAL3  ! array
            
            XLOCA = BADVAL3   ! array
            YLOCA = BADVAL3   ! array
            CELLID = 0        ! array
            
        END IF
        
        NEWSRCPOS = 0
        NEWRECPOS = 0
        OLDRECPOS = 1
        REPPOS = 0

C.........  Loop through original sources
        DO S = 1, OLDNSRC

C.............  Check if current source is to be processed
            IF( AR2PTTBL( S ) /= 0 ) THEN

C.................  Set area-to-point table and row for current source                	
                TBLE = AR2PTTBL( S )
                ROW  = AR2PTIDX( S )

C.................  If no sources are actually added, just modify existing values
                IF( NA2PSRCS == 0 ) THEN
                    XLOCA( S ) = AR2PTABL( ROW,TBLE )%LON
                    YLOCA( S ) = AR2PTABL( ROW,TBLE )%LAT
                    
                    FACTOR = AR2PTABL( ROW,TBLE )%ALLOC                 

C.....................  Loop through pollutants for this source                    
                    DO K = OLDRECPOS, OLDRECPOS + NPCNT( S ) - 1
                    
C.........................  Store information for reporting
                        REPPOS = REPPOS + 1
                        REPIDX( REPPOS ) = REPPOS
                        REPLSCC( REPPOS ) = STR2INT( CSCC( S )( 1:5 ) )
                        REPRSCC( REPPOS ) = 
     &                           STR2INT( CSCC( S )( 6:SCCLEN3 ) )
                        REPSTA( REPPOS ) = STR2INT( CSOURC( S )( 1:3 ) )
                        REPPOL( REPPOS ) = IPOSCOD( K )
                        REPORIGEMIS( REPPOS ) = POLVAL( K,NEM )
                        
C.........................  If not adding sources, factor should be 1.0, so skip 
C                           adjusting emissions                        
                        IF( FACTOR /= 1. ) THEN
                            POLVAL( K,NEM ) = POLVAL( K,NEM ) * FACTOR
                            POLVAL( K,NDY ) = POLVAL( K,NDY ) * FACTOR
                        END IF

                        REPSUMEMIS( REPPOS ) = POLVAL( K,NEM )
                        
                    END DO
                    
                    OLDRECPOS = OLDRECPOS + NPCNT( S )
                
                ELSE

C.....................  Loop through all locations for this source
                    DO J = 0, AR2PTCNT( S ) - 1

C.........................  Increment source position and copy source info
                        NEWSRCPOS = NEWSRCPOS + 1
                        
                        IFIP( NEWSRCPOS ) = OLDIFIP( S )
                        NPCNT( NEWSRCPOS ) = OLDNPCNT( S )
                        TPFLAG( NEWSRCPOS ) = OLDTPFLAG( S )
                        INVYR( NEWSRCPOS ) = OLDINVYR( S )
                        CSOURC( NEWSRCPOS ) = OLDCSOURC( S )
                        CSCC( NEWSRCPOS ) = OLDCSCC( S )
                        
C.........................  Store X and Y locations
                        XLOCA( NEWSRCPOS ) = AR2PTABL( ROW+J,TBLE )%LON
                        YLOCA( NEWSRCPOS ) = AR2PTABL( ROW+J,TBLE )%LAT

C.........................  Set factor for this location
                        FACTOR = AR2PTABL( ROW+J,TBLE )%ALLOC

C.........................  Loop through pollutants for this source
                        DO K = OLDRECPOS, OLDRECPOS + OLDNPCNT( S ) - 1
                    
C.............................  Increment record position and store pollutant code
                            NEWRECPOS = NEWRECPOS + 1
                            IPOSCOD( NEWRECPOS ) = OLDIPOSCOD( K )

C.............................  Adjust annual and average day emissions based on ar2pt factor
                            POLVAL( NEWRECPOS, NEM ) = 
     &                          OLDPOLVAL( K,NEM ) * FACTOR
                
                            POLVAL( NEWRECPOS,NDY ) = 
     &                          OLDPOLVAL( K,NDY ) * FACTOR

C.............................  Copy remaining values to new array
                            POLVAL( NEWRECPOS,NEF:NRP ) = 
     &                          OLDPOLVAL( K,NEF:NRP )

C.............................  Store information for reporting
                            IF( J == 0 ) THEN
                                REPPOS = REPPOS + 1
                                REPIDX( REPPOS ) = REPPOS
                                REPLSCC( REPPOS ) = 
     &                             STR2INT( OLDCSCC( S )( 1:5 ) )
                                REPRSCC( REPPOS ) = 
     &                             STR2INT( OLDCSCC( S )( 6:SCCLEN3 ) )
                                REPSTA( REPPOS ) = 
     &                             STR2INT( OLDCSOURC( S )( 1:3 ) )
                                REPPOL( REPPOS ) = OLDIPOSCOD( K )
                                REPORIGEMIS( REPPOS ) = 
     &                              OLDPOLVAL( K,NEM )
                                REPSUMEMIS( REPPOS ) =
     &                              POLVAL( NEWRECPOS,NEM )
                            ELSE
                                TMPPOS = REPPOS - OLDNPCNT( S ) + 
     &                                   K - OLDRECPOS + 1
                                REPSUMEMIS( TMPPOS ) = 
     &                              REPSUMEMIS( TMPPOS ) + 
     &                              POLVAL( NEWRECPOS,NEM )
                            END IF
                        
                        END DO  ! loop through pollutants
                    
                    END DO  ! loop through area-to-point locations
                    
                    OLDRECPOS = OLDRECPOS + OLDNPCNT( S )

                END IF  ! end check if any sources are added
            
            ELSE

C.................  Not processing current source, but if we're adding sources,
C                   then need to copy information to new arrays
                IF( NA2PSRCS > 0 ) THEN
                
                    NEWSRCPOS = NEWSRCPOS + 1
                    
                    IFIP( NEWSRCPOS ) = OLDIFIP( S )
                    NPCNT( NEWSRCPOS ) = OLDNPCNT( S )
                    TPFLAG( NEWSRCPOS ) = OLDTPFLAG( S )
                    INVYR( NEWSRCPOS ) = OLDINVYR( S )
                    CSOURC( NEWSRCPOS ) = OLDCSOURC( S )
                    CSCC( NEWSRCPOS ) = OLDCSCC( S )
                    
                    DO K = OLDRECPOS, OLDRECPOS + OLDNPCNT( S ) - 1
                        
                        NEWRECPOS = NEWRECPOS + 1
                        IPOSCOD( NEWRECPOS ) = OLDIPOSCOD( K )
                        POLVAL( NEWRECPOS,: ) = OLDPOLVAL( K,: )
                        
                    END DO
                
                    OLDRECPOS = OLDRECPOS + OLDNPCNT( S )
                
                END IF
                
            END IF  ! check if source is processed
            
        END DO  ! loop through sources

C.........  Deallocate old source and emissions arrays
        IF( NA2PSRCS > 0 ) THEN
            DEALLOCATE( OLDIFIP, OLDNPCNT, OLDIPOSCOD, OLDTPFLAG,
     &                  OLDINVYR, OLDPOLVAL, OLDCSOURC, OLDCSCC )   
        END IF

C.........  Sort source information for reporting
        CALL SORTI4( NREPSRCS, REPIDX, REPSTA, REPLSCC, REPRSCC, 
     &               REPPOL )
        
C.........  Determine total number of sources accounting for multiple
C           pollutants and counties
        LSTA = 0
        LSCC = EMCMISS3
        LPOL = 0
        NCONDSRC = 0
        
        DO I = 1,NREPSRCS
            J = REPIDX( I )
            
            TSTA = REPSTA( J )
            WRITE( TSCC, '(2I5.5)' ) REPLSCC( J ), REPRSCC( J )
            TPOL = REPPOL( J )
            
            IF( TSTA /= LSTA .OR.
     &          TSCC /= LSCC .OR.
     &          TPOL /= LPOL      ) THEN
                NCONDSRC = NCONDSRC + 1
            END IF
            
            LSTA = TSTA
            LSCC = TSCC
            LPOL = TPOL
        END DO

C.........  Allocate final size for reporting array
        ALLOCATE( REPAR2PT( NCONDSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'REPAR2PT', PROGNAME )
        REPAR2PT%NFIPS    = 0
        REPAR2PT%ORIGEMIS = 0.
        REPAR2PT%SUMEMIS  = 0.

C.........  Loop through and store final reporting information   
        LSTA = 0
        LSCC = EMCMISS3
        LPOL = 0
        K    = 0
        
        DO I = 1,NREPSRCS
            J = REPIDX( I )
            
            TSTA = REPSTA( J )
            WRITE( TSCC, '(2I5.5)' ) REPLSCC( J ), REPRSCC( J )
            TPOL = REPPOL( J )
            
            IF( TSTA /= LSTA .OR.
     &          TSCC /= LSCC .OR.
     &          TPOL /= LPOL      ) THEN
     
                K = K + 1
                REPAR2PT( K )%STATE = TSTA
                REPAR2PT( K )%SCC   = TSCC
                REPAR2PT( K )%POLL  = TPOL
                REPAR2PT( K )%NFIPS = 1
                
                REPAR2PT( K )%ORIGEMIS = REPORIGEMIS( J )
                REPAR2PT( K )%SUMEMIS  = REPSUMEMIS ( J )
            ELSE
                REPAR2PT( K )%NFIPS = REPAR2PT( K )%NFIPS + 1
                
                REPAR2PT( K )%ORIGEMIS = REPAR2PT( K )%ORIGEMIS +
     &              REPORIGEMIS( J )
                REPAR2PT( K )%SUMEMIS = REPAR2PT( K )%SUMEMIS +
     &              REPSUMEMIS( J )
            END IF
            
            LSTA = TSTA
            LSCC = TSCC
            LPOL = TPOL

        END DO

C.........  Deallocate temporary reporting arrays
        DEALLOCATE( REPIDX, REPSTA, REPLSCC, REPRSCC, REPPOL, 
     &              REPORIGEMIS, REPSUMEMIS )
            
        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )
 
        END SUBROUTINE PROCAR2PT
