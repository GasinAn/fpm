!> Implementation of the meta data for preprocessing.
!>
!> A preprocess table can currently have the following fields
!>
!> ```toml
!> [preprocess]
!> [preprocess.cpp]
!> suffixes = ["F90", "f90"]
!> directories = ["src/feature1", "src/models"]
!> macros = []
!> ```

module fpm_manifest_preprocess
   use fpm_error, only : error_t, syntax_error
   use fpm_strings, only : string_t
   use fpm_toml, only : toml_table, toml_key, toml_stat, get_value, get_list
   implicit none
   private

   public :: preprocess_config_t, new_preprocess_config, new_preprocessors, operator(==)

   !> Configuration meta data for a preprocessor
   type :: preprocess_config_t

      !> Name of the preprocessor
      character(len=:), allocatable :: name

      !> Suffixes of the files to be preprocessed
      type(string_t), allocatable :: suffixes(:)

      !> Directories to search for files to be preprocessed
      type(string_t), allocatable :: directories(:)

      !> Macros to be defined for the preprocessor
      type(string_t), allocatable :: macros(:)

   contains

      !> Print information on this instance
      procedure :: info

   end type preprocess_config_t

   interface operator(==)
       module procedure preprocess_is_same
   end interface

contains

   !> Construct a new preprocess configuration from TOML data structure
   subroutine new_preprocess_config(self, table, error)

      !> Instance of the preprocess configuration
      type(preprocess_config_t), intent(out) :: self

      !> Instance of the TOML data structure.
      type(toml_table), intent(inout) :: table

      !> Error handling
      type(error_t), allocatable, intent(out) :: error

      call check(table, error)
      if (allocated(error)) return

      call table%get_key(self%name)

      call get_list(table, "suffixes", self%suffixes, error)
      if (allocated(error)) return

      call get_list(table, "directories", self%directories, error)
      if (allocated(error)) return

      call get_list(table, "macros", self%macros, error)
      if (allocated(error)) return

   end subroutine new_preprocess_config

   !> Check local schema for allowed entries
   subroutine check(table, error)

      !> Instance of the TOML data structure.
      type(toml_table), intent(inout) :: table

      !> Error handling
      type(error_t), allocatable, intent(inout) :: error

      character(len=:), allocatable :: name
      type(toml_key), allocatable :: list(:)
      integer :: ikey

      call table%get_key(name)
      call table%get_keys(list)

      do ikey = 1, size(list)
         select case(list(ikey)%key)
         !> Valid keys.
         case("suffixes", "directories", "macros")
         case default
            call syntax_error(error, "Key '"//list(ikey)%key//"' not allowed in preprocessor '"//name//"'."); exit
         end select
      end do
   end subroutine check

   !> Construct new preprocess array from a TOML data structure.
   subroutine new_preprocessors(preprocessors, table, error)

      !> Instance of the preprocess configuration
      type(preprocess_config_t), allocatable, intent(out) :: preprocessors(:)

      !> Instance of the TOML data structure
      type(toml_table), intent(inout) :: table

      !> Error handling
      type(error_t), allocatable, intent(out) :: error

      type(toml_table), pointer :: node
      type(toml_key), allocatable :: list(:)
      integer :: iprep, stat

      call table%get_keys(list)

      ! An empty table is not allowed
      if (size(list) == 0) then
         call syntax_error(error, "No preprocessors defined")
      end if

      allocate(preprocessors(size(list)))
      do iprep = 1, size(list)
         call get_value(table, list(iprep)%key, node, stat=stat)
         if (stat /= toml_stat%success) then
            call syntax_error(error, "Preprocessor "//list(iprep)%key//" must be a table entry")
            exit
         end if
         call new_preprocess_config(preprocessors(iprep), node, error)
         if (allocated(error)) exit
      end do

   end subroutine new_preprocessors

   !> Write information on this instance
   subroutine info(self, unit, verbosity)

      !> Instance of the preprocess configuration
      class(preprocess_config_t), intent(in) :: self

      !> Unit for IO
      integer, intent(in) :: unit

      !> Verbosity of the printout
      integer, intent(in), optional :: verbosity

      integer :: pr, ilink
      character(len=*), parameter :: fmt = '("#", 1x, a, t30, a)'

      if (present(verbosity)) then
         pr = verbosity
      else
         pr = 1
      end if

      if (pr < 1) return

      write(unit, fmt) "Preprocessor"
      if (allocated(self%name)) then
         write(unit, fmt) "- name", self%name
      end if
      if (allocated(self%suffixes)) then
         write(unit, fmt) " - suffixes"
         do ilink = 1, size(self%suffixes)
            write(unit, fmt) "   - " // self%suffixes(ilink)%s
         end do
      end if
      if (allocated(self%directories)) then
         write(unit, fmt) " - directories"
         do ilink = 1, size(self%directories)
            write(unit, fmt) "   - " // self%directories(ilink)%s
         end do
      end if
      if (allocated(self%macros)) then
         write(unit, fmt) " - macros"
         do ilink = 1, size(self%macros)
            write(unit, fmt) "   - " // self%macros(ilink)%s
         end do
      end if

   end subroutine info

   logical function preprocess_is_same(this,that)
      class(preprocess_config_t), intent(in) :: this
      class(preprocess_config_t), intent(in) :: that

      integer :: istr

      preprocess_is_same = .false.

      select type (other=>that)
         type is (preprocess_config_t)
            if (allocated(this%name).neqv.allocated(other%name)) return
            if (allocated(this%name)) then
                if (.not.(this%name==other%name)) return
            endif
            if (.not.(allocated(this%suffixes).eqv.allocated(other%suffixes))) return
            if (allocated(this%suffixes)) then
               do istr=1,size(this%suffixes)
                  if (.not.(this%suffixes(istr)%s==other%suffixes(istr)%s)) return
               end do
            end if
            if (.not.(allocated(this%directories).eqv.allocated(other%directories))) return
            if (allocated(this%directories)) then
               do istr=1,size(this%directories)
                  if (.not.(this%directories(istr)%s==other%directories(istr)%s)) return
               end do
            end if
            if (.not.(allocated(this%macros).eqv.allocated(other%macros))) return
            if (allocated(this%macros)) then
               do istr=1,size(this%macros)
                  if (.not.(this%macros(istr)%s==other%macros(istr)%s)) return
               end do
            end if

         class default
            ! Not the same type
            return
      end select

      !> All checks passed!
      preprocess_is_same = .true.

    end function preprocess_is_same

end module fpm_manifest_preprocess
