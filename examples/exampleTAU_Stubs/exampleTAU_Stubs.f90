!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
!                          Futility Development Group                          !
!                             All rights reserved.                             !
!                                                                              !
! Futility is a jointly-maintained, open-source project between the University !
! of Michigan and Oak Ridge National Laboratory.  The copyright and license    !
! can be found in LICENSE.txt in the head directory of this repository.        !
!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
PROGRAM testTAU_Stubs

!$ USE OMP_LIB
  USE IntrType
  USE TAU_Stubs
  IMPLICIT NONE

  INTEGER(SIK) :: profiler1(2),profiler2(2),tid
  REAL(SRK),ALLOCATABLE :: rdum(:)

  WRITE(*,*) '==================================================='
  WRITE(*,*) 'TESTING TAU_STUBS...'
  WRITE(*,*) '==================================================='
  CALL TAU_PROFILE_INIT()

  CALL TAUSTUB_CHECK_MEMORY()
  CALL TAUSTUB_CHECK_MEMORY()
  ALLOCATE(rdum(1048576))
  CALL TAUSTUB_CHECK_MEMORY()
  DEALLOCATE(rdum)
  CALL TAUSTUB_CHECK_MEMORY()
  READ(*,*)

  tid=1
  profiler1=0
  profiler2=0
!$ WRITE(*,*) 'OMP_IN_PARALLEL()=',OMP_IN_PARALLEL()
  CALL TAU_PROFILE_TIMER(profiler1,'Operation 1')
!$OMP PARALLEL DEFAULT(FIRSTPRIVATE) SHARED(TauStubLibData)

!$ WRITE(*,*) 'OMP_IN_PARALLEL()=',OMP_IN_PARALLEL()

!$ tid=OMP_GET_THREAD_NUM()+1
  WRITE(*,*) tid,' profiler1=',profiler1
  WRITE(*,*) tid,' profiler2=',profiler2
  CALL TAU_PROFILE_TIMER(profiler2,'Operation 2')
  WRITE(*,*) tid,' profiler2=',profiler2
  CALL TAU_PROFILE_START(profiler1)
  CALL sleep(1)
  CALL TAU_PROFILE_START(profiler2)
  CALL sleep(1)
  CALL TAU_PROFILE_STOP(profiler1)
  CALL TAU_PROFILE_STOP(profiler2)

!$OMP END PARALLEL
  CALL TAU_PROFILE_EXIT()
  WRITE(*,*) '==================================================='
  WRITE(*,*) 'TESTING TAU_STUBS PASSED!'
  WRITE(*,*) '==================================================='
#ifdef HAVE_MPI
  CALL MPI_Finalize(tid)
#endif
!
ENDPROGRAM testTAU_Stubs
