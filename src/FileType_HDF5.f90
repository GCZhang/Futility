!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
!                              Copyright (C) 2012                              !
!                   The Regents of the University of Michigan                  !
!              MPACT Development Group and Prof. Thomas J. Downar              !
!                             All rights reserved.                             !
!                                                                              !
! Copyright is reserved to the University of Michigan for purposes of          !
! controlled dissemination, commercialization through formal licensing, or     !
! other disposition. The University of Michigan nor any of their employees,    !
! makes any warranty, express or implied, or assumes any liability or          !
! responsibility for the accuracy, completeness, or usefulness of any          !
! information, apparatus, product, or process disclosed, or represents that    !
! its use would not infringe privately owned rights. Reference herein to any   !
! specific commercial products, process, or service by trade name, trademark,  !
! manufacturer, or otherwise, does not necessarily constitute or imply its     !
! endorsement, recommendation, or favoring by the University of Michigan.      !
!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
!> @brief Utility module for I/O defines the HDF5 file type object.
!>
!> This type is an extension of the base file type implemented in FileType_Base.
!> It contains specific routines for interrogating an HDF5-format binary file
!> and for writing to and reading from records in an HDF5 file. Since the module
!> relies of the HDF5 library to be present, the entire module is disabled and
!> not compiled if the build system does not have HDF5 support enabled.
!>
!> There are actually two versions of the HDF library, a serial implementation
!> and a parallel implementation. The latter relies on MPI and has separate
!> subroutine calls, so there will need to be preprocessor directives switching
!> between the two depending on which library is present.
!>
!> It is important to note that the read and write routines are typed to use
!> fixed precision (for instance SSK and SDK instead of SRK). This is important
!> because we need to use the supported types of the HDF5 library and file
!> format.
!>
!> @par Module Dependencies
!>  - @ref IO_Strings "IO_Strings' - @copybrief IO_Strings
!>  - @ref FileType_Base "FileType_Base' - @copybrief FileType_Base
!>  - @ref IntrType "IntrType' - @copybrief IntrType
!>  - @ref ExceptionHandler "ExceptionHandler' - @copybrief ExceptionHandler
!>  - @ref ParallelEnv "ParallelEnv' - @copybrief ParallelEnv
!>  - @ref Strings "Strings' - @copybrief Strings
!>
!> @author Mitchell T.H. Young
!>   @date 01/20/2013
!>
!> @par Revisions:
!> (03/12/2013) - Aaron Graham
!>   - Added read/write routines for SSK, SDK, SNK, SLK, SBK, and StringType
!>     variable types for arrays of rank 0-3.
!>   - Removed MPI/parallel code since it needs to be redesigned.
!> (03/28/2013) - Aaron Graham
!>   - Added delete routine
!> (10/01/2014) - Dan Jabaay
!>   - Cleaned up the read and write routines by making things more generalized.
!>   - Added more object state checking.
!> @todo
!>  - Implement MPI/Parallel HDF5
!>  - Make sure routines are safe (check for initialized object, etc.)
!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
MODULE FileType_HDF5
#ifdef MPACT_HAVE_HDF5
  USE HDF5
#endif
  USE IntrType
  USE Strings
  USE ExceptionHandler
  USE IO_Strings
  USE ParameterLists
  USE ParallelEnv
  USE FileType_Base

  IMPLICIT NONE
  PRIVATE

!#ifdef HAVE_MPI
!  INCLUDE 'mpif.h'
!#endif

#ifdef MPACT_HAVE_HDF5
  INTEGER(HID_T),PRIVATE :: error
#endif

  !> Name of the module
  CHARACTER(LEN=*),PARAMETER :: modName='FileType_HDF5'

  !> Set maximum string length
  INTEGER(SIK),PARAMETER :: MAXSTRLEN=1024

  !> This type extends the base file type, and adds support for writing to and
  !List of Public Members
  PUBLIC :: HDF5FileType
  PUBLIC :: HDF5FilePtrArrayType

  !> reading from HDF5 binary files. As implemented, there are three modes for
  !> accessing a file can be opened as: 'read' and 'write' and 'new'. Read mode
  !> opens an already extant HDF5 file and allows the client code to interrogate
  !> that file and extract data without permissions to alter the file. Write
  !> mode opens an extant HDF5 file and allows the client code to alter its
  !> contents. New mode overwrites any file by the same name and starts from
  !> scratch.
  TYPE,EXTENDS(BaseFileType) :: HDF5FileType
    !> Initialization status
    LOGICAL(SBK) :: isInit=.FALSE.
    !> Whether or not the file uses compression for writing
    LOGICAL(SBK) :: hasCompression=.FALSE.
    !> The 'new' status of a file
    LOGICAL(SBK),PRIVATE :: newstat=.FALSE.
    !> Full path to the file
    TYPE(StringType) :: fullname
    !> The unit number of the file
    INTEGER(SIK),PRIVATE :: unitno=-1
    !> Parallel environment for MPI I/O
    TYPE(MPI_EnvType),POINTER  :: pe => NULL()

#ifdef MPACT_HAVE_HDF5
    !> File id assigned by the HDF5 library when file is opened
    INTEGER(HID_T) :: file_id=0
#endif

    CONTAINS
      !> @copybrief FileType_HDF5::init_HDF5FileType
      !> @copydetails FileType_HDF5::init_HDF5FileType
      PROCEDURE,PASS :: init => init_HDF5FileType
      !> @copybrief FileType_HDF5::clear_HDF5FileType
      !> @copydetails FileType_HDF5::clear_HDF5FileType
      PROCEDURE,PASS :: clear => clear_HDF5FileType
      !> @copybrief FileType_HDF5::open_HDF5FileType
      !> @copydetails FileType_HDF5::open_HDF5FileType
      PROCEDURE,PASS :: fopen => open_HDF5FileType
      !> @copybrief FileType_HDF5::close_HDF5FileType
      !> @copydetails FileType_HDF5::close_HDF5FileType
      PROCEDURE,PASS :: fclose => close_HDF5FileType
      !> @copybrief FileType_HDF5::delete_HDF5FileType
      !> @copydetails FileType_HDF5::delete_HDF5FileType
      PROCEDURE,PASS :: fdelete => delete_HDF5FileType
      !> @copybrief FileType_HDF5::getUnitNo_HFD5FileType
      !> @copydetails FileType_HDF5::getUnitNo_HDF5FileType
      PROCEDURE,PASS :: getUnitNo => getUnitNo_HDF5FileType
      !> @copybrief FileType_HDF5::isNew_HDF5FileType
      !> @copydetails FileType_HDF5::isNew_HDF5FileType
      PROCEDURE,PASS :: isNew => isNew_HDF5FileType
      !> @copybrief FileType_HDF5::setNewStat_HDF5FileType
      !> @copydetails FileType_HDF5::setNewStat_HDF5FileType
      PROCEDURE,PASS,PRIVATE :: setNewStat => setNewStat_HDF5FileType
      !> @copybrief FileType_HDF5::ls_HDF5FileType
      !> @copydetails FileType_HDF5::ls_HDF5FileType
      PROCEDURE,PASS :: ls => ls_HDF5FileType
      !> @copybrief FileType_HDF5::mkdir_HDF5FileType
      !> @copydetails FileType_HDF5::mkdir_HDF5FileType
      PROCEDURE,PASS :: mkdir => mkdir_HDF5FileType
      !> @copybrief FileType_HDF5::ngrp_HDF5FileType
      !> @copydetails FileType_HDF5::ngrp_HDF5FileType
      PROCEDURE,PASS :: ngrp => ngrp_HDF5FileType
      !!> @copybrief FileType_HDF5::hasgrp_HDF5FileType
      !!> @copydetails FileType_HDF5::hasgrp_HDF5FileType
      !PROCEDURE,PASS :: hasGroup => hasgrp_HDF5FileType
      !> @copybrief FileType_HDF5::pathexists_HDF5FileType
      !> @copydetails FileType_HDF5::pathexists_HDF5FileType
      PROCEDURE,PASS :: pathExists => pathexists_HDF5FileType
      !> @copybrief FileType_HDF5::createHardLink_HDF5FileType
      !> @copydetails FileType_HDF5::createHardLink_HDF5FileType
      PROCEDURE,PASS :: createHardLink => createHardLink_HDF5FileType
      !> @copybrief FileType_HDF5::write_d0
      !> @copydoc FileType_HDF5::write_d0
      PROCEDURE,PASS,PRIVATE :: write_d0
      !> @copybrief FileType_HDF5::write_d1
      !> @copydoc FileType_HDF5::write_d1
      PROCEDURE,PASS,PRIVATE :: write_d1
      !> @copybrief FileType_HDF5::write_d2
      !> @copydoc FileType_HDF5::write_d2
      PROCEDURE,PASS,PRIVATE :: write_d2
      !> @copybrief FileType_HDF5::write_d3
      !> @copydoc FileType_HDF5::write_d3
      PROCEDURE,PASS,PRIVATE :: write_d3
      !> @copybrief FileType_HDF5::write_d4
      !> @copydoc FileType_HDF5::write_d4
      PROCEDURE,PASS,PRIVATE :: write_d4
      !> @copybrief FileType_HDF5::write_s0
      !> @copydoc FileType_HDF5::write_s0
      PROCEDURE,PASS,PRIVATE :: write_s0
      !> @copybrief FileType_HDF5::write_s1
      !> @copydoc FileType_HDF5::write_s1
      PROCEDURE,PASS,PRIVATE :: write_s1
      !> @copybrief FileType_HDF5::write_s2
      !> @copydoc FileType_HDF5::write_s2
      PROCEDURE,PASS,PRIVATE :: write_s2
      !> @copybrief FileType_HDF5::write_s3
      !> @copydoc FileType_HDF5::write_s3
      PROCEDURE,PASS,PRIVATE :: write_s3
      !> @copybrief FileType_HDF5::write_s4
      !> @copydoc FileType_HDF5::write_s4
      PROCEDURE,PASS,PRIVATE :: write_s4
      !> @copybrief FileType_HDF5::write_b0
      !> @copydoc FileType_HDF5::write_b0
      PROCEDURE,PASS,PRIVATE :: write_b0
      !> @copybrief FileType_HDF5::write_b1
      !> @copydoc FileType_HDF5::write_b1
      PROCEDURE,PASS,PRIVATE :: write_b1
      !> @copybrief FileType_HDF5::write_b2
      !> @copydoc FileType_HDF5::write_b2
      PROCEDURE,PASS,PRIVATE :: write_b2
      !> @copybrief FileType_HDF5::write_b3
      !> @copydoc FileType_HDF5::write_b3
      PROCEDURE,PASS,PRIVATE :: write_b3
      !> @copybrief FileType_HDF5::write_n0
      !> @copydoc FileType_HDF5::write_n0
      PROCEDURE,PASS,PRIVATE :: write_n0
      !> @copybrief FileType_HDF5::write_n1
      !> @copydoc FileType_HDF5::write_n1
      PROCEDURE,PASS,PRIVATE :: write_n1
      !> @copybrief FileType_HDF5::write_n2
      !> @copydoc FileType_HDF5::write_n2
      PROCEDURE,PASS,PRIVATE :: write_n2
      !> @copybrief FileType_HDF5::write_n3
      !> @copydoc FileType_HDF5::write_n3
      PROCEDURE,PASS,PRIVATE :: write_n3
      !> @copybrief FileType_HDF5::write_l0
      !> @copydoc FileType_HDF5::write_l0
      PROCEDURE,PASS,PRIVATE :: write_l0
      !> @copybrief FileType_HDF5::write_l1
      !> @copydoc FileType_HDF5::write_l1
      PROCEDURE,PASS,PRIVATE :: write_l1
      !> @copybrief FileType_HDF5::write_l2
      !> @copydoc FileType_HDF5::write_l2
      PROCEDURE,PASS,PRIVATE :: write_l2
      !> @copybrief FileType_HDF5::write_l3
      !> @copydoc FileType_HDF5::write_l3
      PROCEDURE,PASS,PRIVATE :: write_l3
      !> @copybrief FileType_HDF5::write_st0
      !> @copydoc FileType_HDF5::write_st0
      PROCEDURE,PASS,PRIVATE :: write_st0
      !> @copybrief FileType_HDF5::write_st1_helper
      !> @copydoc FileType_HDF5::write_st1_helper
      PROCEDURE,PASS,PRIVATE :: write_st1_helper
      !> @copybrief FileType_HDF5::write_st1
      !> @copydoc FileType_HDF5::write_st1
      PROCEDURE,PASS,PRIVATE :: write_st1
      !> @copybrief FileType_HDF5::write_st2_helper
      !> @copydoc FileType_HDF5::write_st2_helper
      PROCEDURE,PASS,PRIVATE :: write_st2_helper
      !> @copybrief FileType_HDF5::write_st2
      !> @copydoc FileType_HDF5::write_st2
      PROCEDURE,PASS,PRIVATE :: write_st2
      !> @copybrief FileType_HDF5::write_st3_helper
      !> @copydoc FileType_HDF5::write_st3_helper
      PROCEDURE,PASS,PRIVATE :: write_st3_helper
      !> @copybrief FileType_HDF5::write_st3
      !> @copydoc FileType_HDF5::write_st3
      PROCEDURE,PASS,PRIVATE :: write_st3
      !> @copybrief FileType_HDF5::write_c1
      !> @copydoc FileType_HDF5::write_c1
      PROCEDURE,PASS,PRIVATE :: write_c1
      !> @copybrief FileType_HDF5::write_pList
      !> @copydoc FileType_HDF5::write_pList
      PROCEDURE,PASS,PRIVATE :: write_pList
      !> Generic typebound interface for all @c write operations
      GENERIC :: fwrite => write_d0, write_d1, write_d2, write_d3, write_d4,   &
      write_s0, write_s1, write_s2, write_s3, write_s4, write_b0, write_b1,    &
      write_b2, write_b3, write_n0, write_n1, write_n2, write_n3, write_st0,    &
      write_st1_helper, write_st1, write_st2_helper, write_st2, write_st3_helper,   &
      write_st3, write_l0, write_l1, write_l2, write_l3, write_c1, write_pList
      !> @copybrief FileType_HDF5::read_d0
      !> @copydoc FileType_HDF5::read_d0
      PROCEDURE,PASS,PRIVATE :: read_d0
      !> @copybrief FileType_HDF5::read_d1
      !> @copydoc FileType_HDF5::read_d1
      PROCEDURE,PASS,PRIVATE :: read_d1
      !> @copybrief FileType_HDF5::read_d2
      !> @copydoc FileType_HDF5::read_d2
      PROCEDURE,PASS,PRIVATE :: read_d2
      !> @copybrief FileType_HDF5::read_d3
      !> @copydoc FileType_HDF5::read_d3
      PROCEDURE,PASS,PRIVATE :: read_d3
      !> @copybrief FileType_HDF5::read_d4
      !> @copydoc FileType_HDF5::read_d4
      PROCEDURE,PASS,PRIVATE :: read_d4
      !> @copybrief FileType_HDF5::read_dp4
      !> @copydoc FileType_HDF5::read_dp4
      PROCEDURE,PASS,PRIVATE :: read_dp4
      !> @copybrief FileType_HDF5::read_s0
      !> @copydoc FileType_HDF5::read_s0
      PROCEDURE,PASS,PRIVATE :: read_s0
      !> @copybrief FileType_HDF5::read_s1
      !> @copydoc FileType_HDF5::read_s1
      PROCEDURE,PASS,PRIVATE :: read_s1
      !> @copybrief FileType_HDF5::read_s2
      !> @copydoc FileType_HDF5::read_s2
      PROCEDURE,PASS,PRIVATE :: read_s2
      !> @copybrief FileType_HDF5::read_s3
      !> @copydoc FileType_HDF5::read_s3
      PROCEDURE,PASS,PRIVATE :: read_s3
      !> @copybrief FileType_HDF5::read_s4
      !> @copydoc FileType_HDF5::read_s4
      PROCEDURE,PASS,PRIVATE :: read_s4
      !> @copybrief FileType_HDF5::read_b0
      !> @copydoc FileType_HDF5::read_b0
      PROCEDURE,PASS,PRIVATE :: read_b0
      !> @copybrief FileType_HDF5::read_b1
      !> @copydoc FileType_HDF5::read_b1
      PROCEDURE,PASS,PRIVATE :: read_b1
      !> @copybrief FileType_HDF5::read_b2
      !> @copydoc FileType_HDF5::read_b2
      PROCEDURE,PASS,PRIVATE :: read_b2
      !> @copybrief FileType_HDF5::read_b3
      !> @copydoc FileType_HDF5::read_b3
      PROCEDURE,PASS,PRIVATE :: read_b3
      !> @copybrief FileType_HDF5::read_n0
      !> @copydoc FileType_HDF5::read_n0
      PROCEDURE,PASS,PRIVATE :: read_n0
      !> @copybrief FileType_HDF5::read_n1
      !> @copydoc FileType_HDF5::read_n1
      PROCEDURE,PASS,PRIVATE :: read_n1
      !> @copybrief FileType_HDF5::read_n2
      !> @copydoc FileType_HDF5::read_n2
      PROCEDURE,PASS,PRIVATE :: read_n2
      !> @copybrief FileType_HDF5::read_n3
      !> @copydoc FileType_HDF5::read_n3
      PROCEDURE,PASS,PRIVATE :: read_n3
      !> @copybrief FileType_HDF5::read_l0
      !> @copydoc FileType_HDF5::read_l0
      PROCEDURE,PASS,PRIVATE :: read_l0
      !> @copybrief FileType_HDF5::read_l1
      !> @copydoc FileType_HDF5::read_l1
      PROCEDURE,PASS,PRIVATE :: read_l1
      !> @copybrief FileType_HDF5::read_l2
      !> @copydoc FileType_HDF5::read_l2
      PROCEDURE,PASS,PRIVATE :: read_l2
      !> @copybrief FileType_HDF5::read_l3
      !> @copydoc FileType_HDF5::read_l3
      PROCEDURE,PASS,PRIVATE :: read_l3
      !> @copybrief FileType_HDF5::read_st0
      !> @copydoc FileType_HDF5::read_st0
      PROCEDURE,PASS,PRIVATE :: read_st0
      !> @copybrief FileType_HDF5::read_st1
      !> @copydoc FileType_HDF5::read_st1
      PROCEDURE,PASS,PRIVATE :: read_st1
      !> @copybrief FileType_HDF5::read_st2
      !> @copydoc FileType_HDF5::read_st2
      PROCEDURE,PASS,PRIVATE :: read_st2
      !> @copybrief FileType_HDF5::read_st3
      !> @copydoc FileType_HDF5::read_st3
      PROCEDURE,PASS,PRIVATE :: read_st3
      !> @copybrief FileType_HDF5::read_c1
      !> @copydoc FileType_HDF5::read_c1
      PROCEDURE,PASS,PRIVATE :: read_c1
      !> Generic typebound interface for all @c read operations
      GENERIC :: fread => read_d1, read_d2, read_d3, read_d4, read_s1, read_s2,&
        read_s3, read_s4, read_l1, read_l2, read_l3, read_b1, read_b2, read_b3,&
        read_st0, read_d0, read_s0, read_l0, read_b0, read_st1, read_st2, read_st3,&
        read_n0, read_n1, read_n2, read_n3, read_c1
      !> Generic typebound interface for pointer-based read operations
      GENERIC :: freadp => read_dp4
  ENDTYPE
  
  !> @brief Type that is a container so as to have an array of pointers to HDF5 files
  TYPE :: HDF5FilePtrArrayType
    !> @brief Pointer to a HDF5 file type
    TYPE(HDF5FileType),POINTER :: h5 => NULL()
  ENDTYPE HDF5FilePtrArrayType

  !> Variable for keeping track of the number of hdf5 files initialized
  !> This variable will be used in logic to call the h5close_f(error)
  !> which closes the interface.  
  INTEGER(SIK),SAVE :: nhdf5fileinuse=0
  !> Variable to make sure that the hdf5 interface was opened, and thus
  !> can then be closed.
  LOGICAL(SBK),SAVE :: lhdf5intfcopen=.FALSE.
!
!===============================================================================
  CONTAINS
!
!-------------------------------------------------------------------------------
!> @brief Initializes an HDF5 file object.
!> @param thisHDF5File the object to be initialized
!> @param filename the relative path to the file on the filesystem
!> @param mode the access mode. Can be 'READ', 'WRITE' or 'NEW'
!> @param cmpStr (optional) the identifier for the compression mode
!>
!> This routine initializes an HDF5 file object by setting the objects
!> attributes, initializing the HDF5 library interface and calling the @c open
!> routine.
!>
    SUBROUTINE init_HDF5FileType(thisHDF5File,filename,mode,useZlib)
      CHARACTER(LEN=*),PARAMETER :: myName='init_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: filename
      CHARACTER(LEN=*),INTENT(IN) :: mode
      LOGICAL(SBK),INTENT(IN),OPTIONAL :: useZlib
#ifdef MPACT_HAVE_HDF5
      TYPE(StringType) :: fpath,fname,fext,mode_in
      INTEGER(SIK) :: unitno
      LOGICAL(SBK) :: ostat,exists,lcmp
#endif
#ifdef MPACT_HAVE_HDF5
      IF(.NOT.thisHDF5File%isinit) THEN
        CALL getFileParts(filename,fpath,fname,fext,thisHDF5File%e)
        CALL thisHDF5File%setFilePath(CHAR(fpath))
        CALL thisHDF5File%setFileName(CHAR(fname))
        CALL thisHDF5File%setFileExt(CHAR(fext))

        IF(PRESENT(useZlib)) thisHDF5File%hasCompression=useZlib

        ! Store the access mode
        mode_in=mode
        CALL toUPPER(mode_in)
        SELECTCASE(TRIM(mode_in))
          CASE('READ')
            INQUIRE(FILE=filename,EXIST=exists)
            IF(exists) THEN
              CALL thisHDF5File%setWriteStat(.FALSE.)
              CALL thisHDF5File%setReadStat(.TRUE.)
            ELSE
              CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
                ' - HDF5 file '//filename//' is being opened with '// &
                'mode READ but does not exist.')
            ENDIF
          CASE('WRITE')
            INQUIRE(FILE=filename,EXIST=exists)
            IF(exists) THEN
              CALL thisHDF5File%setWriteStat(.TRUE.)
              CALL thisHDF5File%setReadStat(.TRUE.)
            ELSE
              CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
                ' - HDF5 file '//filename//' is being opened with '// &
                'mode WRITE but does not exist.')
            ENDIF
          CASE('NEW')
            CALL thisHDF5File%setWriteStat(.TRUE.)
            CALL thisHDF5File%setNewStat(.TRUE.)
            CALL thisHDF5File%setReadStat(.TRUE.)
          CASE DEFAULT
            CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
              ' - Unrecognized access mode.')
        ENDSELECT

        thisHDF5File%fullname=filename

        ! Initialize the HDF5 interface. This needs be done before any other calls
        ! to the HF5 interface can be made.
        CALL h5open_f(error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Could not initialize HDF5 INTERFACE.')

        ! Assign arbitrary UNIT number to file.  Used only for deleting file.
        unitno=99
        INQUIRE(UNIT=unitno,OPENED=ostat)
        DO WHILE(thisHDF5File%unitno == -1)
          IF(ostat) THEN
            unitno=unitno-1_SIK
            INQUIRE(UNIT=unitno,OPENED=ostat)
          ELSE
            thisHDF5File%unitno=unitno
          ENDIF
        ENDDO
        thisHDF5File%isinit=.TRUE.
        nhdf5fileinuse=nhdf5fileinuse+1
        lhdf5intfcopen=.TRUE.
      ELSE
        CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - HDF5file '//thisHDF5File%getFileName()// &
           ' is already initialized!')
      ENDIF
#else
      ! We dont have HDF5, so we can't initialize
      CALL thisHDF5File%e%raiseWarning('The HDF5 library is not present in '// &
        'this build')
#endif
    ENDSUBROUTINE init_HDF5FileType
!
!-------------------------------------------------------------------------------
!> @brief Destructs an HDF5 file object.
!> @param thisHDF5File the HDF5 object to be destroyed
!> @param ldel logical on whether or not to delete or close the file.
!>
!> This routine releases resources used for interacting with the HSF5 file. It
!> closes or deletes the file and the HDF5 library interface. The structure
!> was taken from the Fortran file.
!>
    SUBROUTINE clear_HDF5FileType(thisHDF5File,ldel)
      CHARACTER(LEN=*),PARAMETER :: myName='clear_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      LOGICAL(SBK),INTENT(IN),OPTIONAL :: ldel
      LOGICAL(SBK) :: bool
      IF(thisHDF5File%isinit) THEN
#ifdef MPACT_HAVE_HDF5
        !Logical to close or delete the file.
        bool=.FALSE.
        IF(PRESENT(ldel)) bool=ldel
        IF(bool) THEN
          CALL thisHDF5File%fdelete()
        ELSE
          CALL thisHDF5File%fclose()
        ENDIF

        ! Close the HDF5 interface. This can only be done once all calls to the
        ! HDF5 library are complete.
        nhdf5fileinuse=nhdf5fileinuse-1
        IF(lhdf5intfcopen .AND. (nhdf5fileinuse == 0)) THEN
          CALL h5close_f(error)
          IF(error /= 0) THEN
            CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
              ' - Unable to close HDF5 INTERFACE.')
          ELSE
            lhdf5intfcopen=.FALSE.
          ENDIF
        ENDIF
#endif
        thisHDF5File%isinit=.FALSE.
        thisHDF5File%newstat=.FALSE.
        thisHDF5File%hasCompression=.FALSE.
        thisHDF5File%fullname=''
        thisHDF5File%unitno=-1
        CALL clear_base_file(thisHDF5File)
      ENDIF
    ENDSUBROUTINE clear_HDF5FileType
!
!-------------------------------------------------------------------------------
!> @brief Open an HDF5 file
!> @param file the HDF5FileType object to open
!>
!> This routine implements the abstract @c fopen routine in the base file type.
!> It uses the HDF5 library interface that was initialized in @c init to open
!> the file.
!>
    SUBROUTINE open_HDF5FileType(file)
      CHARACTER(LEN=*),PARAMETER :: myName='open_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: file
#ifdef MPACT_HAVE_HDF5
      INTEGER(HID_T) :: acc
      INTEGER(HID_T) :: plist_id
      LOGICAL(SBK) :: opened

      IF(file%isinit) THEN
        CALL h5pcreate_f(H5P_FILE_ACCESS_F,plist_id,error)
        IF (error /= 0) CALL file%e%raiseError(modName//'::'//myName// &
          ' - Unable to create property list for open operation.')

        ! Decide what access type to use
        IF(file%isNew()) THEN
          acc=H5F_ACC_TRUNC_F
          CALL h5fcreate_f(CHAR(file%fullname),acc,file%file_id,error, &
            access_prp=plist_id)
          ! If the file is NEW, change the mode to WRITE after
          ! Creating it so we don't keep truncating it repeatedly.
          CALL file%setNewStat(.FALSE.)
        ELSEIF(file%isWrite()) THEN
          acc=H5F_ACC_RDWR_F
          CALL h5fopen_f(CHAR(file%fullname),acc,file%file_id,error, &
            access_prp=plist_id)
        ELSEIF(file%isRead()) THEN
          acc=H5F_ACC_RDONLY_F
          CALL h5fopen_f(CHAR(file%fullname),acc,file%file_id,error, &
            access_prp=plist_id)
        ELSE
          CALL file%e%raiseError(modName//'::'//myName// &
            ' - Unrecognized access mode! The file is not'// &
            ' set as either new, read, or write!')
        ENDIF

        CALL h5pclose_f(plist_id,error)
        IF(error /= 0) THEN
          CALL file%e%raiseError(modName//'::'//myName// &
            ' - Unable to destroy property list.')
        ELSE
          CALL file%setOpenStat(.TRUE.)
        ENDIF
      ENDIF
#endif
    ENDSUBROUTINE open_HDF5FileType
!
!-------------------------------------------------------------------------------
!> @brief Closes access to an HDF5 file
!> @param file the HDF5FileType object to close
!>
!> This routine implements the abstract @c fclose routine in the base file type.
!>
    SUBROUTINE close_HDF5FileType(file)
      CHARACTER(LEN=*),PARAMETER :: myName='close_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: file
#ifdef MPACT_HAVE_HDF5
      CALL file%e%setStopOnError(.FALSE.)
      !Check init status
      IF(.NOT.file%isinit) THEN
        CALL file%e%raiseError(modName// &
          '::'//myName//' - File object not initialized.')
      ELSE
        !Check open status.
        IF(file%isopen()) THEN
          CALL h5fclose_f(file%file_id,error)
          IF(error /= 0) THEN
            CALL file%e%raiseError(modName//'::'//myName// &
              ' - Unable to close HDF5 file.')
          ELSE
            CALL file%setOpenStat(.FALSE.)
          ENDIF
        ENDIF
      ENDIF
#endif
    ENDSUBROUTINE close_HDF5FileType
!
!-------------------------------------------------------------------------------
!> @brief delete and HDF5 file
!>
!> @param file the HDF5FileType object to delet
!>
!> This routine implements the abstract @c fdelete routine in the base file
!> type.
!> Mimicking FileType_Fortran logical structure.  We do not clear the file
!> after it is deleted.
!>
    SUBROUTINE delete_HDF5FileType(file)
      CHARACTER(LEN=*),PARAMETER :: myName='delete_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: file
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=EXCEPTION_MAX_MESG_LENGTH) :: emesg
      LOGICAL(SBK) :: bool
      
      IF(file%isinit) THEN
        !So, HDF5 is special in that the unitno assigned isn't used in the
        !fopen() operation.  So, regardless of the %isOpen() status, it needs
        !to be opened.
        OPEN(UNIT=file%unitno,FILE=TRIM(file%getFilePath())// &
          TRIM(file%getFileName())//TRIM(file%getFileExt()), &
            IOSTAT=error)
        IF(error /= 0) THEN
          WRITE(emesg,'(a,i4,a,i4)') 'Error deleting file (UNIT=', &
            file%unitno,') IOSTAT=',error
          CALL file%e%raiseError(modName//'::'//myName//' - '//emesg)
        ENDIF
        CLOSE(UNIT=file%unitno,STATUS='DELETE',IOSTAT=error)
        IF(error /= 0) THEN
          WRITE(emesg,'(a,i4,a,i4)') 'Error deleting file (UNIT=', &
              file%unitno,') IOSTAT=',error
          CALL file%e%raiseError(modName//'::'//myName//' - '//emesg)
        ELSE
          CALL file%setOpenStat(.FALSE.)
        ENDIF
      ENDIF
#else
      ! We dont have HDF5, so we can't initialize
      CALL file%e%raiseWarning('The HDF5 library is not present in '// &
        'this build')
#endif
    ENDSUBROUTINE delete_HDF5FileType
!
!-------------------------------------------------------------------------------
!> @brief gets the unit number used by the HDF5 file
!> @param file the HDF5 file type object
!> @returns val the value of the unit number
!>
    PURE FUNCTION getUnitNo_HDF5FileType(file) RESULT(val)
      CLASS(HDF5FileType),INTENT(IN) :: file
      INTEGER(SIK) :: val
      val=file%unitno
    ENDFUNCTION getUnitNo_HDF5FileType
!
!-------------------------------------------------------------------------------
!> @brief Returns whether or not the HDF5 file is new.
!> @param file the HDF5 file type object
!> @returns bool TRUE/FALSE if the file is new
!>
    PURE FUNCTION isNew_HDF5FileType(file) RESULT(bool)
      CLASS(HDF5FileType),INTENT(IN) :: file
      LOGICAL(SBK) :: bool
      bool=file%newstat
    ENDFUNCTION isNew_HDF5FileType
!
!-------------------------------------------------------------------------------
!> @brief Sets whether or not the HDF5 file is new.
!> @param file the HDF5 file type object
!> @returns bool TRUE/FALSE to set the file to new or not, respectively.
!>
    PURE SUBROUTINE setNewStat_HDF5FileType(file,bool)
      CLASS(HDF5FileType),INTENT(INOUT) :: file
      LOGICAL(SBK),INTENT(IN) :: bool
      file%newstat=bool
    ENDSUBROUTINE setNewStat_HDF5FileType
!
!-------------------------------------------------------------------------------
!> @brief List the contents of a group
!> @param thisHDF5File the HDF5FileType object to operate on
!> @param path the absolute path to the group of interest (group heirarchy
!> represented with '->')
!> @param objs the list of objects to be returned. See below.
!>
!> This routine is useful for discovering the contents of an HDF5 file. A path
!> to a group in the file is provided in the subroutine call and the names of
!> its constituents is stored in the objs list. If objs is passed in, it will be
!> deallocated and reallocated to the proper size to store the names of all of
!> the objects in the group.
!>
    SUBROUTINE ls_HDF5FileType(thisHDF5File,path,objs)
      CHARACTER(LEN=*),PARAMETER :: myName='ls_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: path
      CHARACTER(LEN=*),ALLOCATABLE,INTENT(INOUT) :: objs(:)
#ifdef MPACT_HAVE_HDF5
      TYPE(StringType) :: path2
      INTEGER(HSIZE_T) :: i
      INTEGER(HID_T) :: grp_id,error
      INTEGER :: store_type,nlinks,max_corder

      ! Make sure the object is initialized
      IF(.NOT.thisHDF5File%isinit) THEN
        CALL thisHDF5File%e%setStopOnError(.FALSE.)
        CALL thisHDF5File%e%raiseError(modName// &
          '::'//myName//' - File object not initialized.')
      ELSEIF(.NOT.thisHDF5File%isOpen()) THEN
        CALL thisHDF5File%e%setStopOnError(.FALSE.)
        CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - HDF5file '//thisHDF5File%getFileName()// &
           ' is not opened!')
      ELSE
        path2=convertPath(path)

        CALL h5gopen_f(thisHDF5File%file_id, CHAR(path2), grp_id, error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Unable to open file.')

        CALL h5gget_info_f(grp_id, store_type, nlinks, max_corder, error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Unable to get group information.')

        IF(ALLOCATED(objs)) DEALLOCATE(objs)
        ALLOCATE(objs(nlinks))

        DO i=0,nlinks-1
          CALL h5lget_name_by_idx_f(thisHDF5File%file_id,CHAR(path2), &
              H5_INDEX_NAME_F,H5_ITER_INC_F,i,objs(i+1),error)
          IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Unable to get object name.')
        ENDDO

        CALL h5gclose_f(grp_id, error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Unable to close group.')
      ENDIF
#endif
    ENDSUBROUTINE ls_HDF5FileType
!
!-------------------------------------------------------------------------------
!> @brief Creates a new group in the HDF file.
!> @param thisHDF5File the HDF5FileType object to operate on
!> @param path the path to the group to be created
!>
!> This routine is used to create a new group in an HDF5 file. It can only be
!> called if the file has write access.
!>
    SUBROUTINE mkdir_HDF5FileType(thisHDF5File,path)
      CHARACTER(LEN=*),PARAMETER :: myNAme='mkdir_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: path
#ifdef MPACT_HAVE_HDF5
      TYPE(StringType) :: path2
      INTEGER(HID_T) :: group_id,error

      ! Make sure the object is initialized
      IF(.NOT.thisHDF5File%isinit) THEN
        CALL thisHDF5File%e%setStopOnError(.FALSE.)
        CALL thisHDF5File%e%raiseError(modName// &
          '::'//myName//' - File object not initialized.')
      ! Ensure that we have write permissions to the file
      ELSEIF(.NOT.thisHDF5File%isWrite()) THEN
        CALL thisHDF5File%e%raiseError(modName &
            //'::'//myName//' - Can not create group in read-only file.')
      ELSEIF(.NOT.thisHDF5File%isOpen()) THEN
        CALL thisHDF5File%e%setStopOnError(.FALSE.)
        CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - HDF5file '//thisHDF5File%getFileName()// &
           ' is already not opened!')
      ELSE

        ! Convert the path to use slashes
        path2=convertPath(path)

        ! Create the group
        CALL h5gcreate_f(thisHDF5File%file_id,CHAR(path2),group_id,error)

        IF(error == 0) THEN
          ! Close the group
          CALL h5gclose_f(group_id,error)
          IF(error /= 0) CALL thisHDF5File%e%raiseDebug(modName//'::'// &
              myName//' - Failed to close HDF group')
        ELSE
          CALL thisHDF5File%e%raiseDebug(modName//'::'//myName// &
            ' - Failed to create HDF5 group.')
        ENDIF
      ENDIF
#endif
    ENDSUBROUTINE mkdir_HDF5FileType
!
!-------------------------------------------------------------------------------
!> @brief Returns the number of objects in a group
!> @param thisHDF5File the HDF5FileType object to interrogate
!> @param path the group in the file to interrogate
!>
!> This function returns how many objects are in the group @c path.
!>
    FUNCTION ngrp_HDF5FileType(thisHDF5File,path) RESULT(ngrp)
      CHARACTER(LEN=*),PARAMETER :: myName='ngrp_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: path
      INTEGER(SIK) :: ngrp
#ifdef MPACT_HAVE_HDF5
      TYPE(StringType) :: path2
      INTEGER(HID_T) :: grp_id,error
      INTEGER :: store_type,nlinks,max_corder

      ! Make sure the object is initialized
      IF(.NOT.thisHDF5File%isinit) THEN
        CALL thisHDF5File%e%setStopOnError(.FALSE.)
        CALL thisHDF5File%e%raiseError(modName// &
          '::'//myName//' - File object not initialized.')
      ELSEIF(.NOT.thisHDF5File%isOpen()) THEN
        CALL thisHDF5File%e%setStopOnError(.FALSE.)
        CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - HDF5file '//thisHDF5File%getFileName()// &
           ' is already not opened!')
      ELSE

        path2=convertPath(path)

        CALL h5gopen_f(thisHDF5File%file_id,CHAR(path2),grp_id,error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Could not open group in HDF5 file.')

        CALL h5gget_info_f(grp_id, store_type,nlinks,max_corder,error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Could not get group info in HDF5 file.')

        ngrp=nlinks
      ENDIF
#else
      ngrp=0
#endif
    ENDFUNCTION ngrp_HDF5FileType
!
!-------------------------------------------------------------------------------
!> @brief Returns whether the group exists in the file or not.
!> @param thisHDF5File the HDF5FileType object to interrogate
!> @param path the group in the file to check if it exists
!> @param bool the logical result of whether the specified group exists.
!>
!> This function returns a logical corresponding to whether the group specified
!> by @c path exists or not.  This function assumes a group path, and is not 
!> expected to parse the path to see if there is a dataset at the end that needs
!> to be removed, although that may be useful functionality at some point.
!>
!> So, after reading through the HDF5 manual, there doesn't seem to be a clean
!> way to interrogate an HDF5 path ("link") object to see to what type of object
!> it links.  You can check if the object at the end of the link object exists
!> via h5oexists_by_name_f, but to know whether it is a group, dataset, or 
!> datatype is uglier.  You need the identifier, not the path, so that means
!> trying to open the group, dataset, or datatype, and enduring the subsequent
!> errors, which is unsatisfying.  Commenting out for now.
!>
!    FUNCTION hasgrp_HDF5FileType(thisHDF5File,path) RESULT(bool)
!      CHARACTER(LEN=*),PARAMETER :: myName='hasgrp_HDF5FileType'
!      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
!      CHARACTER(LEN=*),INTENT(IN) :: path
!      LOGICAL(SBK) :: bool
!#ifdef MPACT_HAVE_HDF5
!      TYPE(StringType) :: path2
!      INTEGER(HID_T) :: grp_id,error
!      INTEGER :: arrow,arrowstt 
!
!      ! Make sure the object is initialized, and opened
!      bool=.FALSE.
!      IF(thisHDF5File%isinit .AND. thisHDF5File%isOpen()) THEN
!        bool=thisHDF5File%pathExists(path)
!        IF(bool) THEN
!          
!        arrow=1
!        !Loop over all sub groups to make sure they exist
!        DO WHILE (arrow > -1)
!          WRITE(*,*) "Before IF block="//path
!          arrow=INDEX(path(arrow:),'->')-1
!          WRITE(*,*) "INDEX result=",arrow
!          IF(arrow == -1) THEN
!            WRITE(*,*) "in the -1 ="//path
!            path2=convertPath(path)
!          ELSE
!            WRITE(*,*) path(:arrow)
!            path2=convertPath(path(:arrow))
!            arrow=arrow+3
!          ENDIF
!          CALL h5lexists_f(thisHDF5File%file_id,CHAR(path2),bool,error)
!          WRITE(*,*) "Result of h5lexists=",CHAR(path2),bool
!          IF(.NOT.bool) EXIT
!        ENDDO
!        !If all subgroups exist, check the last
!        IF(bool
!      ENDIF
!#else
!      bool=.FALSE.
!#endif
!    ENDFUNCTION hasgrp_HDF5FileType
!
!-------------------------------------------------------------------------------
!> @brief Returns whether the path exists in the file or not.
!> @param thisHDF5File the HDF5FileType object to interrogate
!> @param path the path in the file to check if it exists
!> @param bool the logical result of whether the specified path exists.
!>
!> This function returns a logical corresponding to whether the specified
!> @c path exists or not. 
!>
    FUNCTION pathexists_HDF5FileType(thisHDF5File,path) RESULT(bool)
      CHARACTER(LEN=*),PARAMETER :: myName='pathexists_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: path
      LOGICAL(SBK) :: bool
#ifdef MPACT_HAVE_HDF5
      TYPE(StringType) :: path2
      INTEGER(HID_T) :: grp_id,error
      INTEGER :: nextpos,oldpos

      ! Make sure the object is initialized, and opened
      bool=.FALSE.
      IF(thisHDF5File%isinit .AND. thisHDF5File%isOpen()) THEN
        nextpos=1
        oldpos=0
        !Loop over all sub paths to make sure they exist
        DO WHILE (nextpos > -1)
          nextpos=INDEX(path(nextpos:),'->')-1
          IF(nextpos == -1) THEN
            path2=convertPath(path)
          ELSE
            path2=convertPath(path(:nextpos+oldpos))
            nextpos=nextpos+oldpos+3
          ENDIF
          CALL h5lexists_f(thisHDF5File%file_id,CHAR(path2),bool,error)
          IF(.NOT.bool) EXIT
          oldpos=nextpos-1
        ENDDO
      ENDIF
#else
      bool=.FALSE.
#endif
    ENDFUNCTION pathexists_HDF5FileType
!
!-------------------------------------------------------------------------------
!> @brief 
!> @param thisHDF5File the HDF5FileType object to interrogate
!> @param source_path the path in the file to create a link to
!> @param link_path
!>
!>
    SUBROUTINE createHardLink_HDF5FileType(thisHDF5File,source_path,link_path)
      CHARACTER(LEN=*),PARAMETER :: myName='createHardLink_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: source_path
      CHARACTER(LEN=*),INTENT(IN) :: link_path
#ifdef MPACT_HAVE_HDF5
      INTEGER(HID_T) :: src_obj_id,h5err
      TYPE(StringType) :: spath,lpath

      INTERFACE
        FUNCTION H5Oclose(object_id) RESULT(herr_t) &
          BIND(C,NAME="H5Oclose")
          USE ISO_C_BINDING
          USE HDF5
          INTEGER(HID_T),VALUE :: object_id
          INTEGER :: herr_t
        ENDFUNCTION H5Oclose
      ENDINTERFACE


      IF(pathexists_HDF5FileType(thisHDF5File,source_path)) THEN
        IF(.NOT.pathexists_HDF5FileType(thisHDF5File,link_path)) THEN
          spath=convertPath(source_path)
          lpath=convertPath(link_path)

          !Get the source object ID
          CALL H5Oopen_f(thisHDF5File%file_id,CHAR(spath),src_obj_id,h5err)

          !Create the link target object ID
          CALL H5Lcreate_hard_f(src_obj_id,CHAR(spath),thisHDF5File%file_id, &
            CHAR(lpath),h5err)

          !Close the source object
          !CALL H5Oclose_f(src_obj_id,h5err)
          h5err=H5Oclose(src_obj_id)
        ELSE
          CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
            ' - Location of new link already exists!')
        ENDIF
      ELSE
        CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Target of new link must exist in file!')
      ENDIF
#endif
    ENDSUBROUTINE createHardLink_HDF5FileType
!
!-------------------------------------------------------------------------------
!> @brief Write a double to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a double @c vals to a dataset of name and path @c
!> dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_d0(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writed0_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SDK),INTENT(IN) :: vals
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id
      INTEGER(SIK) :: dim
      
      ! stash offset
      offset(1)=0
      IF(PRESENT(offset_in)) offset=offset_in
        
      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=1

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_NATIVE_DOUBLE
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id)  
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_d0
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-1 array of doubles to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-1 array of doubles @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_d1(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writed1_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SDK),INTENT(IN) :: vals(:)
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_NATIVE_DOUBLE
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_d1
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-2 array of doubles to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-2 array of doubles @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_d2(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writed2_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SDK),INTENT(IN) :: vals(:,:)
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(2) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=2

      INTEGER(HID_T) :: mem,dspace_id,gspace_id,dset_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      offset(2)=LBOUND(vals,2)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_NATIVE_DOUBLE
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_d2
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-3 array of doubles to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-3 array of doubles @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_d3(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writed3_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SDK),INTENT(IN) :: vals(:,:,:)
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(3) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=3

      INTEGER(HID_T) :: mem,dspace_id,gspace_id,dset_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      offset(2)=LBOUND(vals,2)-1
      offset(3)=LBOUND(vals,3)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_NATIVE_DOUBLE
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN 
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_d3
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-4 array of doubles to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-4 array of doubles @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_d4(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writed4_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SDK),INTENT(IN) :: vals(:,:,:,:)
      INTEGER(SIK),DIMENSION(4),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(4),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(4),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(4) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=4

      INTEGER(HID_T) :: mem,dspace_id,gspace_id,dset_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      offset(2)=LBOUND(vals,2)-1
      offset(3)=LBOUND(vals,3)-1
      offset(4)=LBOUND(vals,4)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      !Commented out since we don't have a 4 dimensional parameter list... yet.
      mem=H5T_NATIVE_DOUBLE
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_d4
!
!-------------------------------------------------------------------------------
!> @brief Write a real to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a real @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_s0(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writes0_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SSK),INTENT(IN) :: vals
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=0
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=1

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_NATIVE_REAL
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_s0
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-1 array of reals to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-1 array of reals @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_s1(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writes1_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SSK),INTENT(IN) :: vals(:)
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_NATIVE_REAL
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_s1
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-2 array of reals to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-2 array of reals @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_s2(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writes2_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SSK),INTENT(IN) :: vals(:,:)
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(2) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=2

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      offset(2)=LBOUND(vals,1)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_NATIVE_REAL
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_s2
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-3 array of reals to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-3 array of reals @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_s3(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writes3_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SSK),INTENT(IN) :: vals(:,:,:)
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(3) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=3

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      offset(2)=LBOUND(vals,2)-1
      offset(3)=LBOUND(vals,3)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_NATIVE_REAL
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_s3
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-4 array of reals to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-4 array of reals @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_s4(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writes4_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SSK),INTENT(IN) :: vals(:,:,:,:)
      INTEGER(SIK),DIMENSION(4),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(4),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(4),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(4) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=4

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      offset(2)=LBOUND(vals,2)-1
      offset(3)=LBOUND(vals,3)-1
      offset(4)=LBOUND(vals,4)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_NATIVE_REAL
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_s4
!
!-------------------------------------------------------------------------------
!> @brief Write a logical to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a logical @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_b0(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writeb0_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      LOGICAL(SBK),INTENT(IN) :: vals
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER :: charvals
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=0
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=1

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      IF(vals) THEN
        charvals='T'
      ELSE
        charvals='F'
      ENDIF
      mem=H5T_NATIVE_CHARACTER
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,charvals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_b0
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-1 array of logicals to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-1 array of logicals @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_b1(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writeb1_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      LOGICAL(SBK),INTENT(IN) :: vals(:)
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER :: charvals(1:SIZE(vals))
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(SIK) :: i
      INTEGER(HSIZE_T),DIMENSION(1) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      charvals='F'
      FORALL(i=1:SIZE(vals),vals(i))
        charvals(i:i)='T'
      END FORALL
      mem=H5T_NATIVE_CHARACTER
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,charvals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_b1
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-2 array of logicals to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-2 array of logicals @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_b2(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writeb2_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      LOGICAL(SBK),INTENT(IN) :: vals(:,:)
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER :: charvals(SIZE(vals,DIM=1),SIZE(vals,DIM=2))
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(SIK) :: i,j
      INTEGER(HSIZE_T),DIMENSION(2) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=2

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      offset(2)=LBOUND(vals,2)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      charvals(:,:)='F'
      FORALL(i=1:SIZE(vals,DIM=1),j=1:SIZE(vals,DIM=2),vals(i,j))
        charvals(i,j)='T'
      END FORALL
      mem=H5T_NATIVE_CHARACTER
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,charvals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_b2
!-------------------------------------------------------------------------------
!> @brief Write a rank-3 array of logicals to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-3 array of logicals @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_b3(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writeb3_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      LOGICAL(SBK),INTENT(IN) :: vals(:,:,:)
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER :: charvals(SIZE(vals,DIM=1),SIZE(vals,DIM=2),SIZE(vals,DIM=3))
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(SIK) :: i,j,k
      INTEGER(HSIZE_T),DIMENSION(3) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=3

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      offset(2)=LBOUND(vals,2)-1
      offset(3)=LBOUND(vals,3)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in
      
      charvals(:,:,:)='F'
      FORALL(i=1:SIZE(vals,DIM=1),j=1:SIZE(vals,DIM=2), &
          k=1:SIZE(vals,DIM=3),vals(i,j,k))
        charvals(i,j,k)='T'
      END FORALL
      mem=H5T_NATIVE_CHARACTER
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,charvals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_b3
!-------------------------------------------------------------------------------
!> @brief Write a 32-bit integer to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes an integer @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_n0(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writen0_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SNK),INTENT(IN) :: vals
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=0
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=1

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_NATIVE_INTEGER
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_n0
!-------------------------------------------------------------------------------
!> @brief Write a rank-1 array of 32-bit integers to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-1 array of integers @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_n1(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writen1_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SNK),INTENT(IN) :: vals(:)
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_NATIVE_INTEGER
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_n1
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-2 array of 32-bit integers to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-2 array of integers @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_n2(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writen2_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SNK),INTENT(IN) :: vals(:,:)
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(2) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=2

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      offset(2)=LBOUND(vals,2)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_NATIVE_INTEGER
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_n2
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-3 array of 32-bit integers to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-3 array of integers @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_n3(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writen3_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SNK),INTENT(IN) :: vals(:,:,:)
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(3) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=3

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      offset(2)=LBOUND(vals,2)-1
      offset(3)=LBOUND(vals,3)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_NATIVE_INTEGER
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_n3
!
!-------------------------------------------------------------------------------
!> @brief Write a 64-bit "integer" to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param valst data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a long integer @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.  A double is
!> used for the write operation to compensate for the lack of an long integer
!> write interface in the HDF5 library.
!>
    SUBROUTINE write_l0(thisHDF5File,dsetname,valst,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writel0_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SLK),INTENT(IN) :: valst
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      REAL(SDK) :: vals
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=0
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=1

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_STD_I64LE
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      mem=H5T_NATIVE_DOUBLE
      vals=DBLE(valst)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_l0
!-------------------------------------------------------------------------------
!> @brief Write a rank-1 array of 64-bit "integers" to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param valst data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-1 array of long integers @c vals to a dataset of
!> name and path @c dsetname using the shape @c gdims_in, if present.  Doubles
!> are used for the write operation to compensate for the lack of an long
!> integer write interface in the HDF5 library.
!>
    SUBROUTINE write_l1(thisHDF5File,dsetname,valst,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writel1_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SLK),INTENT(IN) :: valst(:)
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      REAL(SDK) :: vals(SIZE(valst))
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in
        
      mem=H5T_STD_I64LE
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      mem=H5T_NATIVE_DOUBLE
      vals=DBLE(valst)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_l1
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-2 array of 64-bit "integers" to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param valst data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-2 array of long integers @c vals to a dataset of
!> name and path @c dsetname using the shape @c gdims_in, if present.  Doubles
!> are used for the write operation to compensate for the lack of an long
!> integer write interface in the HDF5 library.
!>
    SUBROUTINE write_l2(thisHDF5File,dsetname,valst,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writel2_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SLK),INTENT(IN) :: valst(:,:)
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      REAL(SDK) :: vals(SIZE(valst,1),SIZE(valst,2))
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(2) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=2

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      offset(2)=LBOUND(vals,2)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_STD_I64LE
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      mem=H5T_NATIVE_DOUBLE
      vals=DBLE(valst)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_l2
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-3 array of 64-bit "integers" to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param valst data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-3 array of long integers @c vals to a dataset of
!> name and path @c dsetname using the shape @c gdims_in, if present.  Doubles
!> are used for the write operation to compensate for the lack of an long
!> integer write interface in the HDF5 library.
!>
    SUBROUTINE write_l3(thisHDF5File,dsetname,valst,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writel3_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SLK),INTENT(IN) :: valst(:,:,:)
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      REAL(SDK) :: vals(SIZE(valst,1),SIZE(valst,2),SIZE(valst,3))
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(3) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=3

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=LBOUND(vals,1)-1
      offset(2)=LBOUND(vals,2)-1
      offset(3)=LBOUND(vals,3)-1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims=SHAPE(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_STD_I64LE
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      mem=H5T_NATIVE_DOUBLE
      vals=DBLE(valst)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_l3
!
!-------------------------------------------------------------------------------
!> @brief Write a StringType to dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param valst data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a stringType @c vals to a dataset of
!> name and path @c dsetname using the shape @c gdims_in, if present.
!> StringsTypes are represented as rank-1 arrays of characters.
!>
    SUBROUTINE write_st0(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writest0_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      TYPE(StringType),INTENT(IN) :: vals
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: offset_in

      CALL write_c1(thisHDF5File,dsetname,CHAR(vals),gdims_in(1),cnt_in,offset_in)
    ENDSUBROUTINE write_st0
!
!-------------------------------------------------------------------------------
!> @brief Find max string length, then write rank-1 array of Strings to dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param valst data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine finds the length of the longest stringType in @c vals, stores
!> the value in @c length_max, and calls the @c fwrite routine.
!>
    SUBROUTINE write_st1_helper(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: MyName='writest1helper_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      TYPE(StringType),ALLOCATABLE,INTENT(IN) :: vals(:)
      INTEGER(SIK) :: length_max,i
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: offset_in
      INTEGER(SIK) :: local_gdims(2)

      length_max=0
      DO i=1,SIZE(vals)
        length_max=MAX(LEN(vals(i)),length_max)
      ENDDO
      local_gdims(1)=length_max
      local_gdims(2:)=SHAPE(vals)
      IF(PRESENT(gdims_in)) local_gdims(2)=gdims_in(1)
      CALL write_st1(thisHDF5File,dsetname,vals,length_max,local_gdims)
    ENDSUBROUTINE write_st1_helper
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-1 array of StringTypes to dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @length_max the length of the longest stringType to be written
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-1 array of stringTypes @c vals to a dataset of
!> name and path @c dsetname using the shape @c gdims_in, if present.
!> StringsTypes are represented as rank-1 arrays of characters.
!>
    SUBROUTINE write_st1(thisHDF5File,dsetname,vals,length_max,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writest1_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      TYPE(StringType),ALLOCATABLE,INTENT(IN) :: vals(:)
      INTEGER(SIK),INTENT(IN) :: length_max
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=length_max) :: valss
      CHARACTER :: charval(length_max,SIZE(vals))
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(SIK) :: i,j,ilen
      INTEGER(HSIZE_T),DIMENSION(2) :: ldims,gdims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=2

      INTEGER :: error
      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      path=dsetname
      ! Fill character array
      DO j=1,SIZE(vals,DIM=1)
        valss=CHAR(vals(j))
        ilen=length_max
        IF(vals(j)%n < length_max) ilen=vals(j)%n
        DO i=1,ilen
          charval(i,j)=valss(i:i)
        ENDDO
        DO i=ilen+1,length_max
          charval(i,j)=''
        ENDDO
      ENDDO

      ! stash offset
      offset(1)=LBOUND(charval,1)-1
      offset(2)=LBOUND(charval,2)-1
      IF(PRESENT(offset_in)) offset=offset_in

      ! Determine the dimensions for the dataspace
      ldims=SHAPE(charval)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_NATIVE_CHARACTER
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,charval,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_st1
!
!-------------------------------------------------------------------------------
!> @brief Find max string length, then write rank-2 array of Strings to dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param valst data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine finds the length of the longest stringType in @c vals, stores
!> the value in @c length_max, and calls the @c fwrite routine.
!>
    SUBROUTINE write_st2_helper(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: MyName='writest2helper_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      TYPE(StringType),ALLOCATABLE,INTENT(IN) :: vals(:,:)
      INTEGER(SIK) :: length_max,i,j
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(2),INTENT(IN),OPTIONAL :: offset_in

      length_max=0
      DO j=1,SIZE(vals,1)
        DO i=1,SIZE(vals,2)
          length_max=MAX(LEN(vals(j,i)),length_max)
        ENDDO
      ENDDO

      IF(PRESENT(gdims_in)) THEN
        CALL thisHDF5File%fwrite(dsetname,vals,length_max,(/length_max,gdims_in/))
      ELSE
        CALL thisHDF5File%fwrite(dsetname,vals,length_max)
      ENDIF
    ENDSUBROUTINE write_st2_helper
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-2 array of StringTypes to dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @length_max the length of the longest stringType to be written
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-2 array of stringTypes @c vals to a dataset of
!> name and path @c dsetname using the shape @c gdims_in, if present.
!> StringsTypes are represented as rank-1 arrays of characters.
!>
    SUBROUTINE write_st2(thisHDF5File,dsetname,vals,length_max,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writest2_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SIK),INTENT(IN) :: length_max
      TYPE(StringType),ALLOCATABLE,INTENT(IN) :: vals(:,:)
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER :: charval(length_max,SIZE(vals,1),SIZE(vals,2))
      CHARACTER(LEN=length_max) :: valss
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(SIK) :: i,j,k,ilen
      INTEGER(HSIZE_T),DIMENSION(3) :: gdims,ldims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=3

      INTEGER :: error
      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      path=dsetname
       DO k=1,SIZE(vals,2)
         DO j=1,SIZE(vals,1)
           valss=CHAR(vals(j,k))
           ilen=length_max
           IF(vals(j,k)%ntrim < length_max) ilen=vals(j,k)%ntrim
           DO i=1,ilen
             charval(i,j,k)=valss(i:i)
           ENDDO
           DO i=ilen+1,length_max
             charval(i,j,k)=valss(i:i)
           ENDDO
         ENDDO
       ENDDO

      ! stash offset
      offset(1)=LBOUND(charval,1)-1
      offset(2)=LBOUND(charval,2)-1
      offset(3)=LBOUND(charval,3)-1
      IF(PRESENT(offset_in)) offset=offset_in

      ! Determine the dimensions for the dataspace
      ldims=SHAPE(charval)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in
        
      mem=H5T_NATIVE_CHARACTER
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,charval,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_st2
!
!-------------------------------------------------------------------------------
!> @brief Find max string length, then write rank-3 array of Strings to dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param valst data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine finds the length of the longest stringType in @c vals, stores
!> the value in @c length_max, and calls the @c fwrite routine.
!>
    SUBROUTINE write_st3_helper(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: MyName='writest3helper_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      TYPE(StringType),ALLOCATABLE,INTENT(IN) :: vals(:,:,:)
      INTEGER(SIK) :: length_max,i,j,k
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(3),INTENT(IN),OPTIONAL :: offset_in

      length_max=0
      DO k=1,SIZE(vals,3)
        DO j=1,SIZE(vals,1)
          DO i=1,SIZE(vals,2)
            length_max=MAX(LEN_TRIM(vals(j,i,k)),length_max)
          ENDDO
        ENDDO
      ENDDO

      IF(PRESENT(gdims_in)) THEN
        CALL thisHDF5File%fwrite(dsetname,vals,length_max,(/length_max,gdims_in/))
      ELSE
        CALL thisHDF5File%fwrite(dsetname,vals,length_max)
      ENDIF
    ENDSUBROUTINE write_st3_helper
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-3 array of StringTypes to dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param length_max the length of the longest stringType to be written
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-3 array of stringTypes @c vals to a dataset of
!> name and path @c dsetname using the shape @c gdims_in, if present.
!> StringsTypes are represented as rank-1 arrays of characters.
!>
    SUBROUTINE write_st3(thisHDF5File,dsetname,vals,length_max,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writest3_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      TYPE(StringType),ALLOCATABLE,INTENT(IN) :: vals(:,:,:)
      INTEGER(SIK),INTENT(IN) :: length_max
      INTEGER(SIK),DIMENSION(4),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(4),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(4),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=length_max) :: valss
      CHARACTER :: charval(length_max,SIZE(vals,1),SIZE(vals,2),SIZE(vals,3))
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(SIK) :: i,j,k,l,ilen
      INTEGER(HSIZE_T),DIMENSION(4) :: gdims,ldims,offset,cnt
      INTEGER(HID_T),PARAMETER :: rank=4

      INTEGER :: error
      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      path=dsetname
      DO l=1,SIZE(vals,3)
        DO k=1,SIZE(vals,2)
          DO j=1,SIZE(vals,1)
            valss=CHAR(vals(j,k,l))
            ilen=length_max
            IF(vals(j,k,l)%ntrim < length_max) ilen=vals(j,k,l)%ntrim
            DO i=1,ilen
              charval(i,j,k,l)=valss(i:i)
            ENDDO
            DO i=ilen+1,length_max
              charval(i,j,k,l)=valss(i:i)
            ENDDO
          ENDDO
        ENDDO
      ENDDO
      
      ! stash offset
      offset(1)=LBOUND(charval,1)-1
      offset(2)=LBOUND(charval,2)-1
      offset(3)=LBOUND(charval,3)-1
      offset(4)=LBOUND(charval,4)-1
      IF(PRESENT(offset_in)) offset=offset_in

      ! Determine the dimensions for the dataspace
      ldims=SHAPE(charval)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims=gdims_in
      ELSE
        gdims=ldims
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      !Rank 3 string types don't exist on PL ... yet.
      mem=H5T_NATIVE_CHARACTER
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,charval,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_st3
!
!-------------------------------------------------------------------------------
!> @brief Write a rank-1 array of character (Fortran string) to a dataset
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname dataset name and path to write to
!> @param vals data to write to dataset
!> @param gdims_in shape of data to write with
!>
!> This routine writes a rank-1 array of characters @c vals to a dataset of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_c1(thisHDF5File,dsetname,vals,gdims_in,cnt_in,offset_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writec1_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      CHARACTER(LEN=*),INTENT(IN) :: vals
      INTEGER(SIK),INTENT(IN),OPTIONAL :: gdims_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: cnt_in
      INTEGER(SIK),DIMENSION(1),INTENT(IN),OPTIONAL :: offset_in
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: ldims,offset,gdims,cnt
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,dspace_id,dset_id,gspace_id,plist_id

      ! stash offset
      offset(1)=1
      IF(PRESENT(offset_in)) offset=offset_in

      path=dsetname
      ! Determine the dimensions for the dataspace
      ldims(1)=LEN(vals)

      ! Store the dimensions from global if present
      IF(PRESENT(gdims_in)) THEN
        gdims(1)=gdims_in
      ELSE
        gdims(1)=ldims(1)
      ENDIF
      cnt=gdims
      IF(PRESENT(cnt_in)) cnt=cnt_in

      mem=H5T_NATIVE_CHARACTER
      CALL preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      IF(error == 0) THEN
        CALL h5dwrite_f(dset_id,mem,vals,gdims,error,dspace_id,gspace_id,plist_id) 
        CALL postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      ENDIF
#endif
    ENDSUBROUTINE write_c1
!
!-------------------------------------------------------------------------------
!> @brief Write a Parameter List object to a group
!> @param thisHDF5File the HDF5FileType object to write to
!> @param dsetname group name and path to write to
!> @param vals data to write to group
!> @param gdims_in shape of data to write with
!>
!> This routine writes a Parameter List object @c vals to a group of name
!> and path @c dsetname using the shape @c gdims_in, if present.
!>
    SUBROUTINE write_pList(thisHDF5File,dsetname,vals,gdims_in)
      CHARACTER(LEN=*),PARAMETER :: myName='writec1_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      CLASS(ParamType),INTENT(IN) :: vals
      INTEGER(SIK),INTENT(IN),OPTIONAL :: gdims_in
#ifdef MPACT_HAVE_HDF5
      TYPE(StringType) :: address,path,root
      CLASS(ParamType),POINTER :: nextParam
      INTEGER(SNK) :: is0
      INTEGER(SLK) :: id0
      REAL(SSK) :: rs0
      REAL(SDK) :: rd0
      LOGICAL(SBK) :: l0
      TYPE(StringType) :: st0
      INTEGER(SNK),ALLOCATABLE :: is1(:)
      INTEGER(SLK),ALLOCATABLE :: id1(:)
      REAL(SSK),ALLOCATABLE :: rs1(:)
      REAL(SDK),ALLOCATABLE :: rd1(:)
      LOGICAL(SBK),ALLOCATABLE :: l1(:)
      TYPE(StringType),ALLOCATABLE :: st1(:)
      INTEGER(SNK),ALLOCATABLE :: is2(:,:)
      INTEGER(SLK),ALLOCATABLE :: id2(:,:)
      REAL(SSK),ALLOCATABLE :: rs2(:,:)
      REAL(SDK),ALLOCATABLE :: rd2(:,:)
      TYPE(StringType),ALLOCATABLE :: st2(:,:)
      INTEGER(SNK),ALLOCATABLE :: is3(:,:,:)
      INTEGER(SLK),ALLOCATABLE :: id3(:,:,:)
      REAL(SSK),ALLOCATABLE :: rs3(:,:,:)
      REAL(SDK),ALLOCATABLE :: rd3(:,:,:)

        
      ! Create root directory
      root=convertPath(dsetname)
      CALL thisHDF5File%mkdir(CHAR(root))

      ! Begin iterating over PL
      address=''
      CALL vals%getNextParam(address,nextParam)
      DO WHILE (ASSOCIATED(nextParam))
        path=root//'/'//CHAR(address)
        SELECTCASE(CHAR(nextParam%dataType))
          CASE('TYPE(ParamType_List)')
            CALL thisHDF5File%mkdir(CHAR(path))
          CASE('REAL(SSK)')
            CALL vals%get(CHAR(address),rs0)
            CALL thisHDF5File%write_s0(CHAR(path),rs0)
          CASE('REAL(SDK)')
            CALL vals%get(CHAR(address),rd0)
            CALL thisHDF5File%write_d0(CHAR(path),rd0)
          CASE('INTEGER(SNK)')
            CALL vals%get(CHAR(address),is0)
            CALL thisHDF5File%write_n0(CHAR(path),is0)
          CASE('INTEGER(SLK)')
            CALL vals%get(CHAR(address),id0)
            CALL thisHDF5File%write_l0(CHAR(path),id0)
          CASE('LOGICAL(SBK)')
            CALL vals%get(CHAR(address),l0)
            CALL thisHDF5File%write_b0(CHAR(path),l0)
          CASE('TYPE(StringType)')
            CALL vals%get(CHAR(address),st0)
            CALL thisHDF5File%write_st0(CHAR(path),st0)
          CASE('1-D ARRAY REAL(SSK)')
            CALL vals%get(CHAR(address),rs1)
            CALL thisHDF5File%write_s1(CHAR(path),rs1)
          CASE('1-D ARRAY REAL(SDK)')
            CALL vals%get(CHAR(address),rd1)
            CALL thisHDF5File%write_d1(CHAR(path),rd1)
          CASE('1-D ARRAY INTEGER(SNK)')
            CALL vals%get(CHAR(address),is1)
            CALL thisHDF5File%write_n1(CHAR(path),is1)
          CASE('1-D ARRAY INTEGER(SLK)')
            CALL vals%get(CHAR(address),id1)
            CALL thisHDF5File%write_l1(CHAR(path),id1)
          CASE('1-D ARRAY LOGICAL(SBK)')
            CALL vals%get(CHAR(address),l1)
            CALL thisHDF5File%write_b1(CHAR(path),l1)
          CASE('1-D ARRAY TYPE(StringType)')
            CALL vals%get(CHAR(address),st1)
            CALL thisHDF5File%write_st1_helper(CHAR(path),st1)
          CASE('2-D ARRAY REAL(SSK)')
            CALL vals%get(CHAR(address),rs2)
            CALL thisHDF5File%write_s2(CHAR(path),rs2)
          CASE('2-D ARRAY REAL(SDK)')
            CALL vals%get(CHAR(address),rd2)
            CALL thisHDF5File%write_d2(CHAR(path),rd2)
          CASE('2-D ARRAY INTEGER(SNK)')
            CALL vals%get(CHAR(address),is2)
            CALL thisHDF5File%write_n2(CHAR(path),is2)
          CASE('2-D ARRAY INTEGER(SLK)')
            CALL vals%get(CHAR(address),id2)
            CALL thisHDF5File%write_l2(CHAR(path),id2)
          CASE('2-D ARRAY TYPE(StringType)')
            CALL vals%get(CHAR(address),st2)
            CALL thisHDF5File%write_st2_helper(CHAR(path),st2)
          CASE('3-D ARRAY REAL(SSK)')
            CALL vals%get(CHAR(address),rs3)
            CALL thisHDF5File%write_s3(CHAR(path),rs3)
          CASE('3-D ARRAY REAL(SDK)')
            CALL vals%get(CHAR(address),rd3)
            CALL thisHDF5File%write_d3(CHAR(path),rd3)
          CASE('3-D ARRAY INTEGER(SNK)')
            CALL vals%get(CHAR(address),is3)
            CALL thisHDF5File%write_n3(CHAR(path),is3)
          CASE('3-D ARRAY INTEGER(SLK)')
            CALL vals%get(CHAR(address),id3)
            CALL thisHDF5File%write_l3(CHAR(path),id3)
          CASE DEFAULT
            CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
              ' - Unrecognized Parameter Type '//CHAR(nextParam%dataType)//'.')
        ENDSELECT
        CALL vals%getNextParam(address,nextParam)
      ENDDO
#endif
    ENDSUBROUTINE write_pList
!
!-------------------------------------------------------------------------------
!> @brief Read a double from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a double from the dataset @c dsetname and stores
!> the value in @c vals
!>
    SUBROUTINE read_d0(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readd0_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SDK),INTENT(INOUT) :: vals
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Read the dataset
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        mem=H5T_NATIVE_DOUBLE
        IF(error >= 0) THEN
          CALL h5dread_f(dset_id,mem,vals,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
        ENDIF
#endif
    ENDSUBROUTINE read_d0
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-1 array of doubles from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-1 array of doubles from the dataset @c dsetname
!> and stores the values in @c vals
!>
    SUBROUTINE read_d1(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readd1_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SDK),ALLOCATABLE,INTENT(INOUT) :: vals(:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1)))
          ENDIF

          ! Read the dataset
          mem=H5T_NATIVE_DOUBLE
          CALL h5dread_f(dset_id,mem,vals,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
        ENDIF
#endif
    ENDSUBROUTINE read_d1
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-2 array of doubles from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-2 array of doubles from the dataset @c dsetname
!> and stores the values in @c vals
!>
    SUBROUTINE read_d2(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readd2_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SDK),ALLOCATABLE,INTENT(INOUT) :: vals(:,:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(2) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=2

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1),dims(2)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1),dims(2)))
          ENDIF

          ! Read the dataset
          mem=H5T_NATIVE_DOUBLE
          CALL h5dread_f(dset_id,mem,vals,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
        ENDIF
#endif
    ENDSUBROUTINE read_d2
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-3 array of doubles from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-3 array of doubles from the dataset @c dsetname
!> and stores the values in @c vals
!>
    SUBROUTINE read_d3(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readd3_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SDK),ALLOCATABLE,INTENT(INOUT) :: vals(:,:,:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(3) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=3

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1),dims(2),dims(3)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1),dims(2),dims(3)))
          ENDIF

          ! Read the dataset
          mem=H5T_NATIVE_DOUBLE
          CALL h5dread_f(dset_id,mem,vals,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
        ENDIF
#endif
    ENDSUBROUTINE read_d3
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-4 array of doubles from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-4 array of doubles from the dataset @c dsetname
!> and stores the values in @c vals
!>
    SUBROUTINE read_d4(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readd4_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SDK),ALLOCATABLE,INTENT(INOUT) :: vals(:,:,:,:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(4) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=4

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1),dims(2),dims(3),dims(4)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1),dims(2),dims(3),dims(4)))
          ENDIF

          ! Read the dataset
          mem=H5T_NATIVE_DOUBLE
          CALL h5dread_f(dset_id,mem,vals,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
        ENDIF
#endif
    ENDSUBROUTINE read_d4
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-4 array of doubles from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-4 array of doubles from the dataset @c dsetname
!> and stores the values in @c vals
!>
    SUBROUTINE read_dp4(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readd4_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SDK),POINTER,INTENT(INOUT) :: vals(:,:,:,:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(4) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=4

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ASSOCIATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1),dims(2),dims(3),dims(4)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1),dims(2),dims(3),dims(4)))
          ENDIF

          ! Read the dataset
          mem=H5T_NATIVE_DOUBLE
          CALL h5dread_f(dset_id,mem,vals,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
        ENDIF
#endif
    ENDSUBROUTINE read_dp4
!
!-------------------------------------------------------------------------------
!> @brief Read a real from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a real from the dataset @c dsetname
!> and stores the value in @c vals
!>
    SUBROUTINE read_s0(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='reads0_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SSK),INTENT(INOUT) :: vals
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Read the dataset
        mem=H5T_NATIVE_REAL
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          CALL h5dread_f(dset_id,mem,vals,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
        ENDIF
#endif
    ENDSUBROUTINE read_s0
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-1 array of reals from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-1 array of reals from the dataset @c dsetname
!> and stores the values in @c vals
!>
    SUBROUTINE read_s1(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='reads1_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SSK),ALLOCATABLE,INTENT(INOUT) :: vals(:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1)))
          ENDIF

          ! Read the dataset
          mem=H5T_NATIVE_REAL
          CALL h5dread_f(dset_id,mem,vals,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
        ENDIF
#endif
    ENDSUBROUTINE read_s1
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-2 array of reals from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-2 array of reals from the dataset @c dsetname
!> and stores the values in @c vals
!>
    SUBROUTINE read_s2(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='reads2_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SSK),ALLOCATABLE,INTENT(INOUT) :: vals(:,:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(2) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=2

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1),dims(2)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1),dims(2)))
          ENDIF

          ! Read the dataset
          mem=H5T_NATIVE_REAL
          CALL h5dread_f(dset_id,mem,vals,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
        ENDIF
#endif
    ENDSUBROUTINE read_s2
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-3 array of reals from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-3 array of reals from the dataset @c dsetname
!> and stores the values in @c vals
!>
    SUBROUTINE read_s3(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='reads3_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SSK),ALLOCATABLE,INTENT(INOUT) :: vals(:,:,:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(3) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=3

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1),dims(2),dims(3)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1),dims(2),dims(3)))
          ENDIF

          ! Read the dataset
          mem=H5T_NATIVE_REAL
          CALL h5dread_f(dset_id,mem,vals,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
        ENDIF
#endif
    ENDSUBROUTINE read_s3
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-4 array of reals from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-4 array of reals from the dataset @c dsetname
!> and stores the values in @c vals
!>
    SUBROUTINE read_s4(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='reads4_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      REAL(SSK),ALLOCATABLE,INTENT(INOUT) :: vals(:,:,:,:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(4) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=4

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1),dims(2),dims(3),dims(4)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1),dims(2),dims(3),dims(4)))
          ENDIF

          ! Read the dataset
          mem=H5T_NATIVE_REAL
          CALL h5dread_f(dset_id,mem,vals,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
        ENDIF
#endif
    ENDSUBROUTINE read_s4
!
!-------------------------------------------------------------------------------
!> @brief Read a 32-bit integer from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads an integer from the dataset @c dsetname
!> and stores the values in @c vals
!>
    SUBROUTINE read_n0(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readn0_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SNK),INTENT(INOUT) :: vals
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Read the dataset
        mem=H5T_NATIVE_INTEGER
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          CALL h5dread_f(dset_id,mem,vals,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
        ENDIF
#endif
    ENDSUBROUTINE read_n0
!

!-------------------------------------------------------------------------------
!> @brief Read a rank-1 array of 32-bit integers from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-1 array of integers from the dataset @c dsetname
!> and stores the values in @c vals
!>
    SUBROUTINE read_n1(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readn1_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SNK),ALLOCATABLE,INTENT(INOUT) :: vals(:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1)))
          ENDIF

          ! Read the dataset
          mem=H5T_NATIVE_INTEGER
          CALL h5dread_f(dset_id,mem,vals,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
        ENDIF
#endif
    ENDSUBROUTINE read_n1
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-2 array of 32-bit integers from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-2 array of integers from the dataset @c dsetname
!> and stores the values in @c vals
!>
    SUBROUTINE read_n2(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readn2_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SNK),ALLOCATABLE,INTENT(INOUT) :: vals(:,:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(2) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=2

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1),dims(2)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1),dims(2)))
          ENDIF

          ! Read the dataset
          mem=H5T_NATIVE_INTEGER
          CALL h5dread_f(dset_id,mem,vals,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
        ENDIF
#endif
    ENDSUBROUTINE read_n2
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-3 array of 32-bit integers from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-3 array of integers from the dataset @c dsetname
!> and stores the values in @c vals
!>
    SUBROUTINE read_n3(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readn3_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SNK),ALLOCATABLE,INTENT(INOUT) :: vals(:,:,:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(3) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=3

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1),dims(2),dims(3)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1),dims(2),dims(3)))
          ENDIF

          ! Read the dataset
          mem=H5T_NATIVE_INTEGER
          CALL h5dread_f(dset_id,mem,vals,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
        ENDIF
#endif
    ENDSUBROUTINE read_n3
!
!-------------------------------------------------------------------------------
!> @brief Read a 64-bit "integer" from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a long integer from the dataset @c dsetname
!> and stores the values in @c vals.  A double is used to read the data to
!> compensate for the lack of a long integer read interface in the HDF5 library.
!>
    SUBROUTINE read_l0(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readl0_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SLK),INTENT(INOUT) :: vals
#ifdef MPACT_HAVE_HDF5
      REAL(SDK) :: valst
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Read the dataset
        mem=H5T_NATIVE_DOUBLE
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          CALL h5dread_f(dset_id,mem,valst,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
          ! Convert data type
          vals=INT(valst,SLK)
          CALL thisHDF5File%e%raiseDebug(modName//'::'//myName// &
            ' - Converting from double to long integer!')
        ENDIF
#endif
    ENDSUBROUTINE read_l0
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-1 array of 64-bit "integers" from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-1 array of long integers from the dataset @c
!> dsetname and stores the values in @c vals.  A double is used to read the data
!> to compensate for the lack of a long integer read interface in the HDF5
!> library.
!>
    SUBROUTINE read_l1(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readl1_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SLK),ALLOCATABLE,INTENT(INOUT) :: vals(:)
#ifdef MPACT_HAVE_HDF5
      INTEGER(SNK),ALLOCATABLE :: valst(:)
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1)))
          ENDIF
          ALLOCATE(valst(dims(1)))

          ! Read the dataset
          mem=H5T_NATIVE_INTEGER
          CALL h5dread_f(dset_id,mem,valst,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
          vals=INT(valst,SLK)
          CALL thisHDF5File%e%raiseDebug(modName//'::'//myName// &
            ' - Converting from double to long integer!')
        ENDIF
#endif
    ENDSUBROUTINE read_l1
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-2 array of 64-bit "integers" from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-2 array of long integers from the dataset @c
!> dsetname and stores the values in @c vals.  A double is used to read the data
!> to compensate for the lack of a long integer read interface in the HDF5
!> library.
!>
    SUBROUTINE read_l2(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readl2_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SLK),ALLOCATABLE,INTENT(INOUT) :: vals(:,:)
#ifdef MPACT_HAVE_HDF5
      INTEGER(SNK),ALLOCATABLE :: valst(:,:)
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(2) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=2

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1),dims(2)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1),dims(2)))
          ENDIF
          ALLOCATE(valst(dims(1),dims(2)))

          ! Read the dataset
          mem=H5T_NATIVE_INTEGER
          CALL h5dread_f(dset_id,mem,valst,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
          vals=INT(valst,SLK)
          CALL thisHDF5File%e%raiseDebug(modName//'::'//myName// &
            ' - Converting from double to long integer!')
        ENDIF
#endif
    ENDSUBROUTINE read_l2
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-3 array of 64-bit "integers" from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-3 array of long integers from the dataset @c
!> dsetname and stores the values in @c vals.  A double is used to read the data
!> to compensate for the lack of a long integer read interface in the HDF5
!> library.
!>
    SUBROUTINE read_l3(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readl3_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      INTEGER(SLK),ALLOCATABLE,INTENT(INOUT) :: vals(:,:,:)
#ifdef MPACT_HAVE_HDF5
      INTEGER(SNK),ALLOCATABLE :: valst(:,:,:)
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(3) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=3

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1),dims(2),dims(3)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1),dims(2),dims(3)))
          ENDIF
          ALLOCATE(valst(dims(1),dims(2),dims(3)))

          ! Read the dataset
          mem=H5T_NATIVE_INTEGER
          CALL h5dread_f(dset_id,mem,valst,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
          vals=INT(valst,SLK)
          CALL thisHDF5File%e%raiseDebug(modName//'::'//myName// &
            ' - Converting from double to long integer!')
        ENDIF
#endif
    ENDSUBROUTINE read_l3
!
!-------------------------------------------------------------------------------
!> @brief Read a logical from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a logical from the dataset @c
!> dsetname and stores the values in @c vals.  The datum is read as a character
!> 'T' or 'F' then converted to a logical.
!>
    SUBROUTINE read_b0(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readb0_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      LOGICAL(SBK),INTENT(INOUT) :: vals
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=1) :: valsc
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(1) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Read the dataset
        mem=H5T_NATIVE_CHARACTER
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          CALL h5dread_f(dset_id,mem,valsc,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
        ! Convert to logical from character
          IF(valsc=='F') THEN
            vals=.FALSE.
          ELSE
            vals=.TRUE.
          ENDIF
        ENDIF
#endif
    ENDSUBROUTINE read_b0
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-1 array of logicals from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-1 array of logicals from the dataset @c
!> dsetname and stores the values in @c vals.  The data are read as characters
!> 'T' or 'F' then converted to logicals.
!>
    SUBROUTINE read_b1(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readb1_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      LOGICAL(SBK),ALLOCATABLE,INTENT(INOUT) :: vals(:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER,ALLOCATABLE :: valsc(:)
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER :: i
      INTEGER(HSIZE_T),DIMENSION(1) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space in data if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1)))
          ENDIF
          ALLOCATE(valsc(dims(1)))

          ! Read the dataset
          mem=H5T_NATIVE_CHARACTER
          CALL h5dread_f(dset_id,mem,valsc,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
          ! Convert from surrogate character array to boolean array
          vals=.FALSE.
          FORALL(i=1:SIZE(vals),valsc(i) == 'T')
            vals(i)=.TRUE.
          ENDFORALL

          DEALLOCATE(valsc)
        ENDIF
#endif
    ENDSUBROUTINE read_b1
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-2 array of logicals from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-2 array of logicals from the dataset @c
!> dsetname and stores the values in @c vals.  The data are read as characters
!> 'T' or 'F' then converted to logicals.
!>
    SUBROUTINE read_b2(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readb2_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      LOGICAL(SBK),ALLOCATABLE,INTENT(INOUT) :: vals(:,:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=1),ALLOCATABLE :: valsc(:,:)
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(SIK) :: i,j
      INTEGER(HSIZE_T),DIMENSION(2) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=2

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space for data if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1),dims(2)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1),dims(2)))
          ENDIF
          ALLOCATE(valsc(dims(1),dims(2)))

          ! Read the dataset
          mem=H5T_NATIVE_CHARACTER
          CALL h5dread_f(dset_id,mem,valsc,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
          ! Convert from surrogate character array to boolean array
          vals=.FALSE.
          FORALL(i=1:SIZE(vals,DIM=1),j=1:SIZE(vals,DIM=2),valsc(i,j) == 'T')
            vals(i,j)=.TRUE.
          ENDFORALL
 
          DEALLOCATE(valsc)
        ENDIF
#endif
    ENDSUBROUTINE read_b2
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-3 array of logicals from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-3 array of logicals from the dataset @c
!> dsetname and stores the values in @c vals.  The data are read as characters
!> 'T' or 'F' then converted to logicals.
!>
    SUBROUTINE read_b3(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readb3_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      LOGICAL(SBK),ALLOCATABLE,INTENT(INOUT) :: vals(:,:,:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER(LEN=1),ALLOCATABLE :: valsc(:,:,:)
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(SIK) :: i,j,k
      INTEGER(HSIZE_T),DIMENSION(3) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=3

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate space for data if needed, make sure it is the right size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          IF(ALLOCATED(vals)) THEN
            IF(ANY(SHAPE(vals) /= dims)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(1),dims(2),dims(3)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(1),dims(2),dims(3)))
          ENDIF
          ALLOCATE(valsc(dims(1),dims(2),dims(3)))

          ! Read the dataset
          mem=H5T_NATIVE_CHARACTER
          CALL h5dread_f(dset_id,mem,valsc,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
          ! Convert from surrogate character array to boolean array
          vals(:,:,:)=.FALSE.
          FORALL(i=1:SIZE(vals,DIM=1),j=1:SIZE(vals,DIM=2),k=1:SIZE(vals,DIM=3), &
            valsc(i,j,k) == 'T')
            vals(i,j,k)=.TRUE.
          ENDFORALL

          DEALLOCATE(valsc)
        ENDIF
#endif
    ENDSUBROUTINE read_b3
!
!-------------------------------------------------------------------------------
!> @brief Read a string from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a stringType from the dataset @c
!> dsetname and stores the values in @c vals.  Each string is read as an array
!> of characters then converted to a stringType.
!>
    SUBROUTINE read_st0(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readst0_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      TYPE(StringType),INTENT(INOUT) :: vals
#ifdef MPACT_HAVE_HDF5
      CHARACTER,ALLOCATABLE :: valsc(:)
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER :: i
      INTEGER(HSIZE_T),DIMENSION(1) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

      path=convertPath(dsetname)
      ! Allocate surrogate data
      CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
      IF(error >= 0) THEN
        ALLOCATE(valsc(dims(1)))

        ! Read the dataset
        mem=H5T_NATIVE_CHARACTER
        CALL h5dread_f(dset_id,mem,valsc,dims,error)
        CALL postRead(thisHDF5File,dset_id,dspace_id,error)

        CALL convert_char_array_to_str(valsc,vals)
      ENDIF
#endif
    ENDSUBROUTINE read_st0
!
!-------------------------------------------------------------------------------
#ifdef MPACT_HAVE_HDF5
    SUBROUTINE read_st0_helper(dset_id,type_id,valsc,h_dims,strlen)
      INTEGER(HID_T),INTENT(IN) :: dset_id,type_id
      CHARACTER(LEN=MAXSTRLEN),INTENT(INOUT) :: valsc
      INTEGER(HSIZE_T),INTENT(IN) :: h_dims(:)
      INTEGER(SLK),INTENT(IN) :: strlen
      CHARACTER(LEN=strlen) :: tmpstr
      INTEGER(SIK) :: i,error

      tmpstr=' '
      CALL h5dread_f(dset_id,type_id,tmpstr,h_dims,error)
      IF(error /= 0) WRITE(*,*) 'crap'
      DO i=1,LEN(tmpstr)
        IF(ICHAR(tmpstr(i:i)) == 0) tmpstr(i:i)=' '
      ENDDO
      valsc=TRIM(tmpstr)
    ENDSUBROUTINE read_st0_helper
#endif
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-1 array of strings from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-1 array of stringTypes from the dataset @c
!> dsetname and stores the values in @c vals.  Each string is read as an array
!> of characters then converted to a stringType.
!>
    SUBROUTINE read_st1(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readst1_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      TYPE(StringType),ALLOCATABLE,INTENT(INOUT) :: vals(:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER,ALLOCATABLE :: valsc(:,:)
      INTEGER(SIK) :: i,j
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(2) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=2

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate character array to size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          ALLOCATE(valsc(dims(1),dims(2)))
          mem=H5T_NATIVE_CHARACTER
          CALL h5dread_f(dset_id,mem,valsc,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
          ! Allocate space if needed, make sure it is the right size
          IF(ALLOCATED(vals)) THEN
            IF(SIZE(vals) /= dims(2)) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(2)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(2)))
          ENDIF
          ! Convert to StringType
          DO i=1,SIZE(vals)
            vals(i)=''
            DO j=1,SIZE(valsc(:,i))
              vals(i)=vals(i)//valsc(j,i)
            ENDDO
          ENDDO
        ENDIF
#endif
    ENDSUBROUTINE read_st1
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-2 array of strings from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-2 array of stringTypes from the dataset @c
!> dsetname and stores the values in @c vals.  Each string is read as an array
!> of characters then converted to a stringType.
!>
    SUBROUTINE read_st2(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readst2_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      TYPE(StringType),ALLOCATABLE,INTENT(INOUT) :: vals(:,:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER,ALLOCATABLE :: valsc(:,:,:)
      INTEGER(SIK) :: i,j,k
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(3) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=3

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate character array to size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          ALLOCATE(valsc(dims(1),dims(2),dims(3)))
          mem=H5T_NATIVE_CHARACTER
          CALL h5dread_f(dset_id,mem,valsc,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
          ! Allocate space if needed, make sure it is the right size
          IF(ALLOCATED(vals)) THEN
            IF(ALL(SHAPE(vals) /= (/dims(2),dims(3)/))) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(2),dims(3)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(2),dims(3)))
          ENDIF

          ! Convert to StringType
          DO i=1,SIZE(vals,1)
            DO j=1,SIZE(vals,2)
              vals(i,j)=''
              DO k=1,SIZE(valsc(:,i,j))
                vals(i,j)=vals(i,j)//valsc(k,i,j)
              ENDDO
            ENDDO
          ENDDO
        ENDIF
#endif
    ENDSUBROUTINE read_st2
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-3 array of strings from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-3 array of stringTypes from the dataset @c
!> dsetname and stores the values in @c vals.  Each string is read as an array
!> of characters then converted to a stringType.
!>
    SUBROUTINE read_st3(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readst3_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      TYPE(StringType),ALLOCATABLE,INTENT(INOUT) :: vals(:,:,:)
#ifdef MPACT_HAVE_HDF5
      CHARACTER,ALLOCATABLE :: valsc(:,:,:,:)
      INTEGER(SIK) :: i,j,k,m
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER(HSIZE_T),DIMENSION(4) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=4

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

        path=convertPath(dsetname)
        ! Allocate character array to size
        CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
        IF(error >= 0) THEN
          ALLOCATE(valsc(dims(1),dims(2),dims(3),dims(4)))
          mem=H5T_NATIVE_CHARACTER
          CALL h5dread_f(dset_id,mem,valsc,dims,error)
          CALL postRead(thisHDF5File,dset_id,dspace_id,error)
          ! Allocate space if needed, make sure it is the right size
          IF(ALLOCATED(vals)) THEN
            IF(ALL(SHAPE(vals) /= (/dims(2),dims(3),dims(4)/))) THEN
              DEALLOCATE(vals)
              ALLOCATE(vals(dims(2),dims(3),dims(4)))
            ENDIF
          ELSE
            ALLOCATE(vals(dims(2),dims(3),dims(4)))
          ENDIF

          ! Convert to StringType
          DO i=1,SIZE(vals,1)
            DO j=1,SIZE(vals,2)
              DO m=1,SIZE(vals,3)
                vals(i,j,m)=''
                DO k=1,SIZE(valsc(:,i,j,m))
                 vals(i,j,m)=vals(i,j,m)//valsc(k,i,j,m)
                ENDDO
              ENDDO
            ENDDO
          ENDDO
        ENDIF
#endif
    ENDSUBROUTINE read_st3
!
!-------------------------------------------------------------------------------
!> @brief Read a rank-1 array of characters (Fortran string) from dataset
!> @param thisHDF5File the HDF5FileType object to read from
!> @param dsetname dataset name and path to read from
!> @param vals variable to hold read data
!>
!> This routine reads a rank-1 array of characters from the dataset @c
!> dsetname and stores the values in @c vals.  The data are read as characters
!> 'T' or 'F' then converted to logicals.
!>
    SUBROUTINE read_c1(thisHDF5File,dsetname,vals)
      CHARACTER(LEN=*),PARAMETER :: myName='readc1_HDF5FileType'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: dsetname
      CHARACTER(LEN=*),INTENT(INOUT) :: vals
#ifdef MPACT_HAVE_HDF5
      CHARACTER,ALLOCATABLE :: valsc(:)
      CHARACTER(LEN=LEN(dsetname)+1) :: path
      INTEGER :: i
      INTEGER(HSIZE_T),DIMENSION(1) :: dims,maxdims
      INTEGER(HID_T),PARAMETER :: rank=1

      INTEGER(HID_T) :: mem,ndims
      INTEGER(HID_T) :: dspace_id,dset_id

      path=convertPath(dsetname)
      ! Allocate surrogate data
      CALL preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
      IF(error >= 0) THEN
        ALLOCATE(valsc(dims(1)))

        ! Read the dataset
        mem=H5T_NATIVE_CHARACTER
        CALL h5dread_f(dset_id,mem,valsc,dims,error)
        CALL postRead(thisHDF5File,dset_id,dspace_id,error)
      
        ! Convert from surrogate character array to boolean array
        vals(:)=" "
        DO i=1,SIZE(valsc)
          vals(i:i)=valsc(i)
        ENDDO
      ENDIF
#endif
    ENDSUBROUTINE read_c1
!
!-------------------------------------------------------------------------------
!> @brief Convert a path provided with '->' separators to '/'
!> @param path the path string to convert.
!>
!> Paths in MPACT use '->' to resolve heirarchy. HSF5 uses '/'.
!>
    FUNCTION convertPath(path,HDF5File)
      CHARACTER(LEN=*),INTENT(IN) :: path
      CLASS(HDF5FileType),INTENT(INOUT),OPTIONAL :: HDF5File
      CHARACTER(LEN=LEN(path)+1) :: convertPath

      LOGICAL(SBK) :: lsubdir
      INTEGER(SIK) :: ipos,ipos2,last,ind,stor,nlinks,cord,error
      
      convertPath=''
      lsubdir=.FALSE.
      IF(PRESENT(HDF5File)) lsubdir=.TRUE.
      last=LEN_TRIM(path)
      ! Split the path string by '->'
      ipos=1
      DO
        ind=INDEX(path(ipos:last),'->')
        ipos2=ind+ipos-1
        IF(ind > 0) THEN
          convertPath=TRIM(convertPath)//'/'//path(ipos:ipos2-1)
          ipos=ipos2+2
        ELSE
          convertPath=TRIM(convertPath)//'/'//path(ipos:last)
          EXIT
        ENDIF
        !IF(lsubdir) THEN
        !  CALL h5gget_info_by_name_f(HDF5File%file_id,convertPath,stor,nlinks,cord,error)
        !  !Inquiry failed, therefore the group doesn't exist, so we call mkdir
        !  IF(error == -1) CALL HDF5File%mkdir(convertPath)
        !ENDIF
      ENDDO ! Elements in path string
    ENDFUNCTION convertPath
#ifdef MPACT_HAVE_HDF5
!
!-------------------------------------------------------------------------------
!> @brief 
!>
    SUBROUTINE preWrite(thisHDF5File,rank,gdims,ldims,path,mem,dset_id,dspace_id, &
        gspace_id,plist_id,error,cnt,offset)
      CHARACTER(LEN=*),PARAMETER :: myName='preWrite'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      INTEGER(HID_T),INTENT(IN) :: rank
      INTEGER(HSIZE_T),INTENT(INOUT) :: gdims(:)
      INTEGER(HSIZE_T),INTENT(IN) :: ldims(:)
      CHARACTER(LEN=*),INTENT(INOUT) :: path
      INTEGER(HID_T),INTENT(IN) :: mem
      INTEGER(HID_T),INTENT(OUT) :: dset_id
      INTEGER(HID_T),INTENT(OUT) :: dspace_id
      INTEGER(HID_T),INTENT(OUT) :: gspace_id
      INTEGER(HID_T),INTENT(OUT) :: plist_id
      INTEGER(SIK),INTENT(OUT) :: error
      INTEGER(HSIZE_T),INTENT(IN) :: cnt(:)
      INTEGER(HSSIZE_T),INTENT(IN) :: offset(:)
     
      INTEGER(HID_T) :: file_id 
      INTEGER(HSIZE_T) :: cdims(rank)

      error=0
      ! Make sure the object is initialized
      IF(.NOT.thisHDF5File%isinit) THEN
        CALL thisHDF5File%e%setStopOnError(.FALSE.)
        CALL thisHDF5File%e%raiseError(modName// &
          '::'//myName//' - File object not initialized.')
        error=-1
      ! Check that the file is writable. Best to catch this before HDF5 does.
      ELSEIF(.NOT.thisHDF5File%isWrite()) THEN
        CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - File is readonly!')
        error=-2
      ! Check that the file is Open.
      ELSEIF(.NOT.thisHDF5File%isOpen()) THEN
        CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - File is not Open!')
        error=-3
      ELSE
        file_id=thisHDF5File%file_id

        !> Convert path here, further reducing code
        path=convertPath(path)

!        parwrite=.FALSE.
!#ifdef HAVE_MPI
!        IF(PRESENT(cnt) .AND. PRESENT(offset) .AND. &
!          ASSOCIATED(thisHDF5File%pe)) THEN
!          IF(thisHDF5File%pe%isinit()) parwrite=.TRUE.
!        ENDIF
!#endif

        !Create an HDF5 parameter list for the dataset creation.
        CALL h5pcreate_f(H5P_DATASET_CREATE_F,plist_id,error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Could not create parameter list.')

        ! Create the dataspace
        ! Global dataspace
        CALL h5screate_simple_f(rank,gdims,gspace_id,error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Could not create dataspace.')

        ! Local dataspace
        CALL h5screate_simple_f(rank,ldims,dspace_id,error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Could not create dataspace.')

        ! Setup the DSpace creation property list to use ZLIB compression
        ! (requires chunking).
        !
        ! Do not compress on scalar data sets.
        IF(thisHDF5File%hasCompression .AND. &
          .NOT.(rank == 1 .AND. gdims(1) == 1)) THEN

          !Compute optimal chunk size and specify in property list.
          CALL compute_chunk_size(gdims,cdims)
          CALL h5pset_chunk_f(plist_id,rank,cdims,error)

          !Do not presently support user defined compression levels, just level 5
          !5 seems like a good trade-off of speed vs. compression ratio.
          CALL h5pset_deflate_f(plist_id,5,error)
        ENDIF

        ! Create the dataset
        CALL h5dcreate_f(file_id,path,mem,gspace_id,dset_id,error,dcpl_id=plist_id)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Could not create dataset:'//path)

        ! Destroy the property list
        CALL h5pclose_f(plist_id,error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Could not close parameter list.')
      
        ! Select the global dataspace for the dataset
        CALL h5dget_space_f(dset_id,gspace_id,error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Could not select global dataspace for the dataset.')

!#ifdef HAVE_MPI     
!        ! Select a hyperslab subset of the global data space
!        IF(parwrite) THEN 
!          CALL H5Sselect_hyperslab_f(gspace_id,H5S_SELECT_SET_F,offset,cnt,error)
!          IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
!            ' - Could not select a hyperslab.')
!        ENDIF
!#endif
        ! Create a property list for the write operation
        CALL h5pcreate_f(H5P_DATASET_XFER_F,plist_id,error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Could not create property list for write operation.')
!#ifdef HAVE_MPI
!!We need checks here for PAR_HDF5, or something, because it won't work with serial!
!!(facepalm)
!        IF(parwrite) THEN
!          CALL H5Pset_dxpl_mpio_f(plist_id,H5FD_MPIO_COLLECTIVE_F,error)
!          IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
!            ' - Could not set property list for collective mpi write.')
!        ENDIF
!#endif
      ENDIF
    ENDSUBROUTINE preWrite
!
!-------------------------------------------------------------------------------
!> @brief 
!>
    SUBROUTINE postWrite(thisHDF5File,error,dset_id,dspace_id,gspace_id,plist_id)
      CHARACTER(LEN=*),PARAMETER :: myName='postWrite'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      INTEGER(SIK),INTENT(INOUT) :: error
      INTEGER(HID_T),INTENT(INOUT) :: dset_id
      INTEGER(HID_T),INTENT(INOUT) :: dspace_id
      INTEGER(HID_T),INTENT(INOUT) :: gspace_id
      INTEGER(HID_T),INTENT(INOUT) :: plist_id

      ! Make sure the object is initialized
      IF(.NOT.thisHDF5File%isinit) THEN
        CALL thisHDF5File%e%setStopOnError(.FALSE.)
        CALL thisHDF5File%e%raiseError(modName// &
          '::'//myName//' - File object not initialized.')
      ! Check that the file is writable. Best to catch this before HDF5 does.
      ELSEIF(.NOT.thisHDF5File%isWrite()) THEN
        CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - File is not Writable!')
      ! Check that the file is Open.
      ELSEIF(.NOT.thisHDF5File%isOpen()) THEN
        CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - File is not Open!')
      ELSE
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
            ' - Could not write to the dataset.')
        ! Close the dataset
        CALL h5dclose_f(dset_id,error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Could not close the dataset.')
        ! Close the dataspace
        CALL h5sclose_f(dspace_id,error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Could not close the dataspace.')
        CALL h5sclose_f(gspace_id,error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Could not close the dataspace.')
        CALL h5pclose_f(plist_id,error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Could not close the parameter list.')
      ENDIF
    ENDSUBROUTINE postWrite
!
!-------------------------------------------------------------------------------
!> @brief 
!>
    SUBROUTINE preRead(thisHDF5File,path,rank,dset_id,dspace_id,dims,error)
      CHARACTER(LEN=*),PARAMETER :: myName='preRead'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      CHARACTER(LEN=*),INTENT(IN) :: path
      INTEGER(HID_T),INTENT(IN) :: rank
      INTEGER(HID_T),INTENT(INOUT) :: dset_id
      INTEGER(HID_T),INTENT(INOUT) :: dspace_id
      INTEGER(HSIZE_T),INTENT(INOUT) :: dims(:)
      INTEGER(SIK),INTENT(OUT) :: error

      INTEGER(HID_T) :: ndims
      INTEGER(HSIZE_T) :: maxdims(rank)

      error=0
      ! Make sure the object is initialized
      IF(.NOT.thisHDF5File%isinit) THEN
        CALL thisHDF5File%e%setStopOnError(.FALSE.)
        CALL thisHDF5File%e%raiseError(modName// &
          '::'//myName//' - File object not initialized.')
        error=-1
      ELSEIF(.NOT.thisHDF5File%isRead()) THEN
        CALL thisHDF5File%e%setStopOnError(.FALSE.)
        CALL thisHDF5File%e%raiseError(modName// &
          '::'//myName//' - File is not Readable!')
        error=-2
      ELSE
        ! Open the dataset
        CALL h5dopen_f(thisHDF5File%file_id, path, dset_id, error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
           ' - Failed to open dataset.')

        ! Get dataset dimensions for allocation
        CALL h5dget_space_f(dset_id,dspace_id,error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Failed to obtain the dataspace.')

        ! Make sure the rank is right
        CALL h5sget_simple_extent_ndims_f(dspace_id,ndims,error)
        IF(error < 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Failed to retrieve number of dataspace dimensions.')
        IF(ndims /= rank) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Using wrong read function for rank.')
        CALL h5sget_simple_extent_dims_f(dspace_id,dims,maxdims,error)
        IF(error < 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Failed to retrieve dataspace dimensions.')
      ENDIF
    ENDSUBROUTINE preRead
!
!-------------------------------------------------------------------------------
!> @brief 
!>
    SUBROUTINE postRead(thisHDF5File,dset_id,dspace_id,error)
      CHARACTER(LEN=*),PARAMETER :: myName='postRead'
      CLASS(HDF5FileType),INTENT(INOUT) :: thisHDF5File
      INTEGER(HID_T),INTENT(INOUT) :: dset_id
      INTEGER(HID_T),INTENT(INOUT) :: dspace_id
      INTEGER(SIK),INTENT(INOUT) :: error
      
!      ! Make sure the object is initialized
!      IF(.NOT.thisHDF5File%isinit) THEN
!        CALL thisHDF5File%e%setStopOnError(.FALSE.)
!        CALL thisHDF5File%e%raiseError(modName// &
!          '::'//myName//' - File object not initialized.')
!      ELSEIF(.NOT.thisHDF5File%isRead()) THEN
!        CALL thisHDF5File%e%setStopOnError(.FALSE.)
!        CALL thisHDF5File%e%raiseError(modName// &
!          '::'//myName//' - File is not Readable!')
!      ELSE
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Failed to read data from dataset.')
        ! Close the dataset
        CALL h5dclose_f(dset_id,error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Failed to close dataset.')
        ! Close the dataspace
        CALL h5sclose_f(dspace_id,error)
        IF(error /= 0) CALL thisHDF5File%e%raiseError(modName//'::'//myName// &
          ' - Failed to close dataspace.')
!      ENDIF
    ENDSUBROUTINE postRead
!
!------------------------------------------------------------------------------
    SUBROUTINE convert_char_array_to_str(char_array,str)
      CHARACTER(LEN=1),INTENT(IN) :: char_array(:)
      TYPE(StringType),INTENT(INOUT) :: str
      CHARACTER(LEN=SIZE(char_array)) :: c
      INTEGER(SIK) :: i
      DO i=1,LEN(c)
        c(i:i)=char_array(i)
      ENDDO
      str=c
    ENDSUBROUTINE convert_char_array_to_str
!
!-------------------------------------------------------------------------------
!> @brief Computes the optimal chunk size for a data set for writing with
!>        compression.
!> @param gdims the global dimensions of the data set
!> @param cdims the chunk dimensions to use
!>
!> Presently we take the lazy approach and just use gdims.
!> A more optimal approach would be to get chunks with an aspect ratio near 1
!> for all dimensions and then size this appropriately so the chunk size works
!> well in the I/O system's and HDF5 library's buffer and cache sizes.
!>
    SUBROUTINE compute_chunk_size(gdims,cdims)
      INTEGER(HSIZE_T),INTENT(IN) :: gdims(:)
      INTEGER(HSIZE_T),INTENT(OUT) :: cdims(:)

      !Lazy
      cdims=gdims
    ENDSUBROUTINE compute_chunk_size


#endif
!
ENDMODULE FileType_HDF5

