;;; eldoc-cmake.el --- Eldoc support for CMake -*- lexical-binding: t -*-
;;
;; Author: Kirill Ignatiev
;; URL: https://github.com/ikirill/eldoc-cmake
;; Version: 1.0
;; Package-Requires: ((emacs "25.1"))
;;
;;; Commentary:
;;
;; CMake eldoc support, using a pre-generated set of docstrings from
;; CMake's documentation source.
;;
;; See function `eldoc-cmake-enable'.
;;
;;; Code:

(require 'thingatpt)
(require 'subr-x)
(require 'cl-lib)

(defvar eldoc-cmake--docstrings)

;;;###autoload
(defun eldoc-cmake-enable ()
  "Enable eldoc support for a CMake file."
  (interactive)
  (setq-local eldoc-documentation-function
              #'eldoc-cmake--function)
  (unless eldoc-mode (eldoc-mode)))

(defun eldoc-cmake--function ()
  "`eldoc-documentation-function` for CMake (`cmake-mode`)."
  (when-let
      ((cursor (thing-at-point 'symbol))
       (docstring (assoc-string cursor eldoc-cmake--docstrings t)))
    (let ((synopsis (cadr docstring))
          (example (caddr docstring)))
      (if eldoc-echo-area-use-multiline-p
          (concat synopsis "\n" example)
        (replace-regexp-in-string "\n" " " synopsis)))))

(defconst eldoc-cmake--langs
  '("ASM"
    "ASM_ATT"
    "ASM_MARMASM"
    "ASM_MASM"
    "ASM_NASM"
    "C"
    "CSharp"
    "CUDA"
    "CXX"
    "Fortran"
    "HIP"
    "ISPC"
    "OBJC"
    "OBJCXX"
    "Swift")
  "CMake's known languages, substituted for \"<LANG>\".")

(defun eldoc-cmake--extract-command (path)
  "Extract documentation from an .rst file in CMake.

Extremely hacky: relies on whitespace, paragraphs, etc.  It tries
to take the first English paragraph and the first code block as
the synopsis and code example for a command/variable.

To get better docstrings, the results \"may\" need to be examined
by hand and potentially adjusted.

Argument PATH is the path to a .rst file in CMake's source that
describes a single command."
  (with-temp-buffer
    (insert-file-contents path)
    (let (synopsis example name)
      ;; (message (buffer-string))
      (goto-char (point-min))
      (when (and
             (search-forward "\n\n")
             (search-forward-regexp (rx line-start (any alpha ?`)) nil t))
        (setq synopsis (thing-at-point 'sentence t))
        (when (search-forward "::" nil t)
          (forward-line)
          (let ((start (point)))
            (when (search-forward "\n\n" nil t)
              (setq example (string-trim (buffer-substring start (point)) "\n+"))))))
      ;; (message "Synopsis: %S" synopsis)
      ;; (message "Example: %S" example)
      (setq name (file-name-sans-extension (file-name-nondirectory path)))
      (cond
       ((string-match (rx string-start (group (+? (any "A-Z" ?_))) "_LANG_" (group (+? (any "A-Z" ?_))) string-end) name)
        (cl-loop
         for lang in eldoc-cmake--langs
         collect
         (let ((rep (concat (match-string 1 name) "_" lang "_" (match-string 2 name))))
           (list rep synopsis example))))
       (t
        (list (list name synopsis example)))))))

(defun eldoc-cmake--extract-commands (path)
  "Extract docstrings from CMake source.

Run this to regenerate the docstrings when they eventually go out
of date.

Example usage:

    (append
     (eldoc-cmake--extract-commands \"~/software/CMake/Help/command\")
     (eldoc-cmake--extract-commands \"~/software/CMake/Help/variable\"))

Argument PATH is the path to a directory full of .rst doc files
in CMake's source."
  (cl-loop
   for fn in (directory-files path)
   when (string-match-p (rx ".rst" string-end) fn)
   append (eldoc-cmake--extract-command (concat (file-name-as-directory path) fn))))

;; (insert (format "\n\n%S" (eldoc-cmake--extract-commands "~/software/CMake/Help/command")))
;; (insert (format "\n\n%S" (eldoc-cmake--extract-commands "~/software/CMake/Help/variable")))

(defconst eldoc-cmake--docstrings
  '(
    ("add_compile_definitions" "Add preprocessor definitions to the compilation of source files." "  add_compile_definitions(<definition> ...)")
    ("add_compile_options" "Add options to the compilation of source files." "  add_compile_options(<option> ...)")
    ("add_custom_command" "Add a custom build rule to the generated build system." "  add_custom_command(OUTPUT output1 [output2 ...]
                     COMMAND command1 [ARGS] [args1...]
                     [COMMAND command2 [ARGS] [args2...] ...]
                     [MAIN_DEPENDENCY depend]
                     [DEPENDS [depends...]]
                     [BYPRODUCTS [files...]]
                     [IMPLICIT_DEPENDS <lang1> depend1
                                      [<lang2> depend2] ...]
                     [WORKING_DIRECTORY dir]
                     [COMMENT comment]
                     [DEPFILE depfile]
                     [JOB_POOL job_pool]
                     [JOB_SERVER_AWARE <bool>]
                     [VERBATIM] [APPEND] [USES_TERMINAL]
                     [CODEGEN]
                     [COMMAND_EXPAND_LISTS]
                     [DEPENDS_EXPLICIT_ONLY])")
    ("add_custom_target" "Add a target with no output so it will always be built." "  add_custom_target(Name [ALL] [command1 [args1...]]
                    [COMMAND command2 [args2...] ...]
                    [DEPENDS depend depend depend ...]
                    [BYPRODUCTS [files...]]
                    [WORKING_DIRECTORY dir]
                    [COMMENT comment]
                    [JOB_POOL job_pool]
                    [JOB_SERVER_AWARE <bool>]
                    [VERBATIM] [USES_TERMINAL]
                    [COMMAND_EXPAND_LISTS]
                    [SOURCES src1 [src2...]])")
    ("add_definitions" "Add ``-D`` define flags to the compilation of source files." "  add_definitions(-DFOO -DBAR ...)")
    ("add_dependencies" "Add a dependency between top-level targets." "  add_dependencies(<target> <target-dependency>...)")
    ("add_executable" "Add an executable to the project using the specified source files." "  add_executable(<name> <options>... <sources>...)
  :target: normal")
    ("add_library" "Add a library to the project using the specified source files." "  add_library(<name> [<type>] [EXCLUDE_FROM_ALL] <sources>...)
  :target: normal")
    ("add_link_options" "Add options to the link step for executable, shared library or module
library targets in the current directory and below that are added after
this command is invoked." "  add_link_options(<option> ...)")
    ("add_subdirectory" "Add a subdirectory to the build." "  add_subdirectory(source_dir [binary_dir] [EXCLUDE_FROM_ALL] [SYSTEM])")
    ("add_test" "Add a test to the project to be run by :manual:`ctest(1)`." "  add_test(NAME <name> COMMAND <command> [<arg>...]
           [CONFIGURATIONS <config>...]
           [WORKING_DIRECTORY <dir>]
           [COMMAND_EXPAND_LISTS])")
    ("aux_source_directory" "Find all source files in a directory." "  aux_source_directory(<dir> <variable>)")
    ("block" "Evaluate a group of commands with a dedicated variable and/or policy scope." "  block([SCOPE_FOR [POLICIES] [VARIABLES]] [PROPAGATE <var-name>...])
    <commands>
  endblock()")
    ("break" "Break from an enclosing foreach or while loop." "  break()")
    ("build_command" "Get a command line to build the current project." "  build_command(<variable>
                [CONFIGURATION <config>]
                [PARALLEL_LEVEL <parallel>]
                [TARGET <target>]
                [PROJECT_NAME <projname>] # legacy, causes warning
               )")
    ("build_name" "Disallowed since version 3.0." "  build_name(variable)")
    ("cmake_file_api" "Enables interacting with the :manual:`CMake file API <cmake-file-api(7)>`." "  cmake_file_api(QUERY ...)")
    ("cmake_host_system_information" "Query various host system information." "  `Query host system specific information`_
    cmake_host_system_information(RESULT <variable> QUERY <key> ...)")
    ("cmake_instrumentation" "Enables interacting with the
:manual:`CMake Instrumentation API <cmake-instrumentation(7)>`." "  cmake_instrumentation(
    API_VERSION <version>
    DATA_VERSION <version>
    [HOOKS <hooks>...]
    [QUERIES <queries>...]
    [CALLBACK <callback>]
  )")
    ("cmake_language" "Call meta-operations on CMake commands." "  cmake_language(`CALL`_ <command> [<arg>...])
  cmake_language(`EVAL`_ CODE <code>...)
  cmake_language(`DEFER`_ <options>... CALL <command> [<arg>...])
  cmake_language(`SET_DEPENDENCY_PROVIDER`_ <command> SUPPORTED_METHODS <methods>...)
  cmake_language(`GET_MESSAGE_LOG_LEVEL`_ <out-var>)
  cmake_language(`EXIT`_ <exit-code>)")
    ("cmake_minimum_required" "Require a minimum version of cmake." "  cmake_minimum_required(VERSION <min>[...<policy_max>] [FATAL_ERROR])")
    ("cmake_parse_arguments" "Parse function or macro arguments." "  cmake_parse_arguments(<prefix> <options> <one_value_keywords>
                        <multi_value_keywords> <args>...)")
    ("cmake_path" "This command is for the manipulation of paths." "  The ``cmake_path`` command handles paths in the format of the build system
  (i.e. the host platform), not the target system.  When cross-compiling,
  if the path contains elements that are not representable on the host
  platform (e.g. a drive letter when the host is not Windows), the results
  will be unpredictable.")
    ("cmake_pkg_config" "Process pkg-config format package files." "  cmake_pkg_config(EXTRACT <package> [<version>] [...])")
    ("cmake_policy" "Manage CMake Policy settings." "  :target: VERSION")
    ("configure_file" "Copy a file to another location and modify its contents." "  configure_file(<input> <output>
                 [NO_SOURCE_PERMISSIONS | USE_SOURCE_PERMISSIONS |
                  FILE_PERMISSIONS <permissions>...]
                 [COPYONLY] [ESCAPE_QUOTES] [@ONLY]
                 [NEWLINE_STYLE [UNIX|DOS|WIN32|LF|CRLF]])")
    ("continue" "Continue to the top of enclosing foreach or while loop." "  continue()")
    ("create_test_sourcelist" "Create a test driver program that links together many small tests into a
single executable." "  create_test_sourcelist(<sourceListName> <driverName> <test>... <options>...)
  :target: original")
    ("ctest_build" "Perform the :ref:`CTest Build Step` as a :ref:`Dashboard Client`." "  ctest_build([BUILD <build-dir>] [APPEND]
              [CONFIGURATION <config>]
              [PARALLEL_LEVEL <parallel>]
              [FLAGS <flags>]
              [PROJECT_NAME <project-name>]
              [TARGET <target-name>]
              [NUMBER_ERRORS <num-err-var>]
              [NUMBER_WARNINGS <num-warn-var>]
              [RETURN_VALUE <result-var>]
              [CAPTURE_CMAKE_ERROR <result-var>]
              )")
    ("ctest_configure" "Perform the :ref:`CTest Configure Step` as a :ref:`Dashboard Client`." "  ctest_configure([BUILD <build-dir>] [SOURCE <source-dir>] [APPEND]
                  [OPTIONS <options>] [RETURN_VALUE <result-var>] [QUIET]
                  [CAPTURE_CMAKE_ERROR <result-var>])")
    ("ctest_coverage" "Perform the :ref:`CTest Coverage Step` as a :ref:`Dashboard Client`." "  ctest_coverage([BUILD <build-dir>] [APPEND]
                 [LABELS <label>...]
                 [RETURN_VALUE <result-var>]
                 [CAPTURE_CMAKE_ERROR <result-var>]
                 [QUIET]
                 )")
    ("ctest_empty_binary_directory" "empties the binary directory" "  ctest_empty_binary_directory(<directory>)")
    ("ctest_memcheck" "Perform the :ref:`CTest MemCheck Step` as a :ref:`Dashboard Client`." "  ctest_memcheck([BUILD <build-dir>] [APPEND]
                 [START <start-number>]
                 [END <end-number>]
                 [STRIDE <stride-number>]
                 [EXCLUDE <exclude-regex>]
                 [INCLUDE <include-regex>]
                 [EXCLUDE_LABEL <label-exclude-regex>]
                 [INCLUDE_LABEL <label-include-regex>]
                 [EXCLUDE_FIXTURE <regex>]
                 [EXCLUDE_FIXTURE_SETUP <regex>]
                 [EXCLUDE_FIXTURE_CLEANUP <regex>]
                 [PARALLEL_LEVEL <level>]
                 [RESOURCE_SPEC_FILE <file>]
                 [TEST_LOAD <threshold>]
                 [SCHEDULE_RANDOM <ON|OFF>]
                 [STOP_ON_FAILURE]
                 [STOP_TIME <time-of-day>]
                 [RETURN_VALUE <result-var>]
                 [CAPTURE_CMAKE_ERROR <result-var>]
                 [REPEAT <mode>:<n>]
                 [OUTPUT_JUNIT <file>]
                 [DEFECT_COUNT <defect-count-var>]
                 [QUIET]
                 )")
    ("ctest_read_custom_files" "read CTestCustom files." "  ctest_read_custom_files(<directory>...)")
    ("ctest_run_script" "runs a :option:`ctest -S` script" "  ctest_run_script([NEW_PROCESS] script_file_name script_file_name1
              script_file_name2 ... [RETURN_VALUE var])")
    ("ctest_sleep" "sleeps for some amount of time" "  ctest_sleep(<seconds>)")
    ("ctest_start" "Starts the testing for a given model" "  ctest_start(<model> [<source> [<binary>]] [GROUP <group>] [QUIET])")
    ("ctest_submit" "Perform the :ref:`CTest Submit Step` as a :ref:`Dashboard Client`." "  ctest_submit([PARTS <part>...] [FILES <file>...]
               [SUBMIT_URL <url>]
               [BUILD_ID <result-var>]
               [HTTPHEADER <header>]
               [RETRY_COUNT <count>]
               [RETRY_DELAY <delay>]
               [RETURN_VALUE <result-var>]
               [CAPTURE_CMAKE_ERROR <result-var>]
               [QUIET]
               )")
    ("ctest_test" "Perform the :ref:`CTest Test Step` as a :ref:`Dashboard Client`." "  ctest_test([BUILD <build-dir>] [APPEND]
             [START <start-number>]
             [END <end-number>]
             [STRIDE <stride-number>]
             [EXCLUDE <exclude-regex>]
             [INCLUDE <include-regex>]
             [EXCLUDE_LABEL <label-exclude-regex>]
             [INCLUDE_LABEL <label-include-regex>]
             [EXCLUDE_FROM_FILE <filename>]
             [INCLUDE_FROM_FILE <filename>]
             [EXCLUDE_FIXTURE <regex>]
             [EXCLUDE_FIXTURE_SETUP <regex>]
             [EXCLUDE_FIXTURE_CLEANUP <regex>]
             [PARALLEL_LEVEL [<level>]]
             [RESOURCE_SPEC_FILE <file>]
             [TEST_LOAD <threshold>]
             [SCHEDULE_RANDOM <ON|OFF>]
             [STOP_ON_FAILURE]
             [STOP_TIME <time-of-day>]
             [RETURN_VALUE <result-var>]
             [CAPTURE_CMAKE_ERROR <result-var>]
             [REPEAT <mode>:<n>]
             [OUTPUT_JUNIT <file>]
             [QUIET]
             )")
    ("ctest_update" "Perform the :ref:`CTest Update Step` as a :ref:`Dashboard Client`." "  ctest_update([SOURCE <source-dir>]
               [RETURN_VALUE <result-var>]
               [CAPTURE_CMAKE_ERROR <result-var>]
               [QUIET])")
    ("ctest_upload" "Upload files to a dashboard server as a :ref:`Dashboard Client`." "  ctest_upload(FILES <file>... [QUIET] [CAPTURE_CMAKE_ERROR <result-var>])")
    ("define_property" "Define and document custom properties." "  define_property(<GLOBAL | DIRECTORY | TARGET | SOURCE |
                   TEST | VARIABLE | CACHED_VARIABLE>
                   PROPERTY <name> [INHERITED]
                   [BRIEF_DOCS <brief-doc> [docs...]]
                   [FULL_DOCS <full-doc> [docs...]]
                   [INITIALIZE_FROM_VARIABLE <variable>])")
    ("else" "Starts the else portion of an if block." "  else([<condition>])")
    ("elseif" "Starts an elseif portion of an if block." "  elseif(<condition>)")
    ("enable_language" "Enable languages (CXX/C/OBJC/OBJCXX/Fortran/etc)" "  enable_language(<lang>... [OPTIONAL])")
    ("enable_testing" "Enable testing for current directory and below." "  enable_testing()")
    ("endblock" "Ends a list of commands in a :command:`block` and removes the scopes
created by the :command:`block` command." nil)
    ("endforeach" "Ends a list of commands in a foreach block." "  endforeach([<loop_var>])")
    ("endfunction" "Ends a list of commands in a function block." "  endfunction([<name>])")
    ("endif" "Ends a list of commands in an if block." "  endif([<condition>])")
    ("endmacro" "Ends a list of commands in a macro block." "  endmacro([<name>])")
    ("endwhile" "Ends a list of commands in a while block." "  endwhile([<condition>])")
    ("exec_program" "Run an executable program during the processing of the CMakeList.txt
file." "  exec_program(Executable [directory in which to run]
               [ARGS <arguments to executable>]
               [OUTPUT_VARIABLE <var>]
               [RETURN_VALUE <var>])")
    ("execute_process" "Execute one or more child processes." "  execute_process(COMMAND <cmd1> [<arguments>]
                  [COMMAND <cmd2> [<arguments>]]...
                  [WORKING_DIRECTORY <directory>]
                  [TIMEOUT <seconds>]
                  [RESULT_VARIABLE <variable>]
                  [RESULTS_VARIABLE <variable>]
                  [OUTPUT_VARIABLE <variable>]
                  [ERROR_VARIABLE <variable>]
                  [INPUT_FILE <file>]
                  [OUTPUT_FILE <file>]
                  [ERROR_FILE <file>]
                  [OUTPUT_QUIET]
                  [ERROR_QUIET]
                  [COMMAND_ECHO <where>]
                  [OUTPUT_STRIP_TRAILING_WHITESPACE]
                  [ERROR_STRIP_TRAILING_WHITESPACE]
                  [ENCODING <name>]
                  [ECHO_OUTPUT_VARIABLE]
                  [ECHO_ERROR_VARIABLE]
                  [COMMAND_ERROR_IS_FATAL <ANY|LAST|NONE>])")
    ("export" "Export targets or packages for outside projects to use them directly
from the current project's build tree, without installation." "  export(`TARGETS`_ <target>... [...])
  export(`EXPORT`_ <export-name> [...])
  export(`PACKAGE`_ <PackageName>)
  export(`SETUP`_ <export-name> [...])")
    ("export_library_dependencies" "Disallowed since version 3.0." "  export_library_dependencies(<file> [APPEND])")
    ("file" "File manipulation command." "  The sub-commands `RELATIVE_PATH`_, `TO_CMAKE_PATH`_ and `TO_NATIVE_PATH`_ has
  been superseded, respectively, by sub-commands
  :ref:`RELATIVE_PATH <cmake_path-RELATIVE_PATH>`,
  :ref:`CONVERT ... TO_CMAKE_PATH_LIST <cmake_path-TO_CMAKE_PATH_LIST>` and
  :ref:`CONVERT ... TO_NATIVE_PATH_LIST <cmake_path-TO_NATIVE_PATH_LIST>` of
  :command:`cmake_path` command.")
    ("find_file" nil nil)
    ("find_library" "When more than one value is given to the ``NAMES`` option this command by
default will consider one name at a time and search every directory
for it." "  The library found can now be a ``.xcframework`` folder.")
    ("find_package" "Find a package (usually provided by something external to the project),
and load its package-specific details." "  find_package(<PackageName> [<version>] [REQUIRED] [COMPONENTS <components>...])")
    ("find_path" "When searching for frameworks, if the file is specified as ``A/b.h``, then
the framework search will look for ``A.framework/Headers/b.h``." nil)
    ("find_program" "When more than one value is given to the ``NAMES`` option this command by
default will consider one name at a time and search every directory
for it." "  if(WIN32)
    set(_script_suffix .bat)
  else()
    set(_script_suffix .sh)
  endif()")
    ("fltk_wrap_ui" "Create FLTK user interfaces Wrappers." "  fltk_wrap_ui(resultingLibraryName source1
               source2 ... sourceN)")
    ("foreach" "Evaluate a group of commands for each value in a list." "  foreach(<loop_var> <items>)
    <commands>
  endforeach()")
    ("function" "Start recording a function for later invocation as a command." "  function(<name> [<arg1> ...])
    <commands>
  endfunction()")
    ("get_cmake_property" "Get a global property of the CMake instance." "  get_cmake_property(<variable> <property>)")
    ("get_directory_property" "Get a property of ``DIRECTORY`` scope." "  get_directory_property(<variable> [DIRECTORY <dir>] <prop-name>)")
    ("get_filename_component" "Get a specific component of a full filename." "  This command has been superseded by the :command:`cmake_path` command, except
  for ``REALPATH``, which is now offered by :command:`file(REAL_PATH)`, and
  ``PROGRAM``, now available in :command:`separate_arguments(PROGRAM)`.")
    ("get_property" "Get a property." "  get_property(<variable>
               <GLOBAL             |
                DIRECTORY [<dir>]  |
                TARGET    <target> |
                SOURCE    <source>
                          [DIRECTORY <dir> | TARGET_DIRECTORY <target>] |
                INSTALL   <file>   |
                TEST      <test>
                          [DIRECTORY <dir>] |
                CACHE     <entry>  |
                VARIABLE           >
               PROPERTY <name>
               [SET | DEFINED | BRIEF_DOCS | FULL_DOCS])")
    ("get_source_file_property" "Get a property for a source file." "  get_source_file_property(<variable> <file>
                           [DIRECTORY <dir> | TARGET_DIRECTORY <target>]
                           <property>)")
    ("get_target_property" "Get a property from a target." "  get_target_property(<variable> <target> <property>)")
    ("get_test_property" "Get a property of the test." "  get_test_property(<test> <property> [DIRECTORY <dir>] <variable>)")
    ("if" "Conditionally execute a group of commands." "  if(<condition>)
    <commands>
  elseif(<condition>) # optional block, can be repeated
    <commands>
  else()              # optional block
    <commands>
  endif()")
    ("include" "Load and run CMake code from a file or module." "  include(<file|module> [OPTIONAL] [RESULT_VARIABLE <var>]
                        [NO_POLICY_SCOPE])")
    ("include_directories" "Add include directories to the build." "  include_directories([AFTER|BEFORE] [SYSTEM] dir1 [dir2 ...])")
    ("include_external_msproject" "Include an external Microsoft project file in the solution file produced
by :ref:`Visual Studio Generators`. Ignored on other generators." "  include_external_msproject(projectname location
                             [TYPE projectTypeGUID]
                             [GUID projectGUID]
                             [PLATFORM platformName]
                             dep1 dep2 ...)")
    ("include_guard" "Provides an include guard for the file currently being processed by CMake." "  include_guard([DIRECTORY|GLOBAL])")
    ("include_regular_expression" "Set the regular expression used for dependency checking." "  include_regular_expression(regex_match [regex_complain])")
    ("install" "Specify rules to run at install time." "  install(`TARGETS`_ <target>... [...])
  install(`IMPORTED_RUNTIME_ARTIFACTS`_ <target>... [...])
  install({`FILES`_ | `PROGRAMS`_} <file>... [...])
  install(`DIRECTORY`_ <dir>... [...])
  install(`SCRIPT`_ <file> [...])
  install(`CODE`_ <code> [...])
  install(`EXPORT`_ <export-name> [...])
  install(`PACKAGE_INFO`_ <package-name> [...])
  install(`RUNTIME_DEPENDENCY_SET`_ <set-name> [...])")
    ("install_files" "This command has been superseded by the :command:`install` command." "  install_files(<dir> extension file file ...)")
    ("install_programs" "This command has been superseded by the :command:`install` command." "  install_programs(<dir> file1 file2 [file3 ...])
  install_programs(<dir> FILES file1 [file2 ...])")
    ("install_targets" "This command has been superseded by the :command:`install` command." "  install_targets(<dir> [RUNTIME_DIRECTORY dir] target target)")
    ("link_directories" "Add directories in which the linker will look for libraries." "  link_directories([AFTER|BEFORE] directory1 [directory2 ...])")
    ("link_libraries" "Link libraries to all targets added later." "  link_libraries([item1 [item2 [...]]]
                 [[debug|optimized|general] <item>] ...)")
    ("list" "Operations on :ref:`semicolon-separated lists <CMake Language Lists>`." "  `Reading`_
    list(`LENGTH`_ <list> <out-var>)
    list(`GET`_ <list> <element index> [<index> ...] <out-var>)
    list(`JOIN`_ <list> <glue> <out-var>)
    list(`SUBLIST`_ <list> <begin> <length> <out-var>)")
    ("load_cache" "Load in the values from another project's ``CMakeCache.txt`` cache file." "  load_cache(<build-dir> READ_WITH_PREFIX <prefix> <entry>...)
  :target: READ_WITH_PREFIX")
    ("load_command" "Disallowed since version 3.0." "  load_command(COMMAND_NAME <loc1> [loc2 ...])")
    ("macro" "Start recording a macro for later invocation as a command" "  macro(<name> [<arg1> ...])
    <commands>
  endmacro()")
    ("make_directory" "Creates the specified directory." nil)
    ("mark_as_advanced" "Mark cmake cached variables as advanced." "  mark_as_advanced([CLEAR|FORCE] <var1> ...)")
    ("math" "Evaluate a mathematical expression." "  math(EXPR <variable> \"<expression>\" [OUTPUT_FORMAT <format>])")
    ("message" "Log a message." "  `General messages`_
    message([<mode>] \"message text\" ...)")
    ("option" "Provide a boolean option that the user can optionally select." "  option(<variable> \"<help_text>\" [value])")
    ("output_required_files" "Disallowed since version 3.0." "  output_required_files(srcfile outputfile)")
    ("project" "Set the name of the project." " project(<PROJECT-NAME> [<language-name>...])
 project(<PROJECT-NAME>
         [VERSION <major>[.<minor>[.<patch>[.<tweak>]]]]
         [DESCRIPTION <project-description-string>]
         [HOMEPAGE_URL <url-string>]
         [LANGUAGES <language-name>...])")
    ("qt_wrap_cpp" "Manually create Qt Wrappers." "  qt_wrap_cpp(resultingLibraryName DestName SourceLists ...)")
    ("qt_wrap_ui" "Manually create Qt user interfaces Wrappers." "  qt_wrap_ui(resultingLibraryName HeadersDestName
             SourcesDestName SourceLists ...)")
    ("remove" "Removes ``VALUE`` from the variable ``VAR``." nil)
    ("remove_definitions" "Remove -D define flags added by :command:`add_definitions`." "  remove_definitions(-DFOO -DBAR ...)")
    ("return" "Return from a file, directory or function." "  return([PROPAGATE <var-name>...])")
    ("separate_arguments" "Parse command-line arguments into a semicolon-separated list." "  separate_arguments(<variable> <mode> [PROGRAM [SEPARATE_ARGS]] <args>)")
    ("set" "Set a normal, cache, or environment variable to a given value." "  set(<variable> <value>... [PARENT_SCOPE])
  :target: normal")
    ("set_directory_properties" "Set properties of the current directory and subdirectories." "  set_directory_properties(PROPERTIES <prop1> <value1> [<prop2> <value2>] ...)")
    ("set_property" "Set a named property in a given scope." "  set_property(<GLOBAL                      |
                DIRECTORY [<dir>]           |
                TARGET    [<target1> ...]   |
                SOURCE    [<src1> ...]
                          [DIRECTORY <dirs> ...]
                          [TARGET_DIRECTORY <targets> ...] |
                INSTALL   [<file1> ...]     |
                TEST      [<test1> ...]
                          [DIRECTORY <dir>] |
                CACHE     [<entry1> ...]    >
               [APPEND] [APPEND_STRING]
               PROPERTY <name> [<value1> ...])")
    ("set_source_files_properties" "Source files can have properties that affect how they are built." "  set_source_files_properties(<files> ...
                              [DIRECTORY <dirs> ...]
                              [TARGET_DIRECTORY <targets> ...]
                              PROPERTIES <prop1> <value1>
                              [<prop2> <value2>] ...)")
    ("set_target_properties" "Targets can have properties that affect how they are built." "  set_target_properties(<targets> ...
                        PROPERTIES <prop1> <value1>
                        [<prop2> <value2>] ...)")
    ("set_tests_properties" "Set a property of the tests." "  set_tests_properties(<tests>...
                       [DIRECTORY <dir>]
                       PROPERTIES <prop1> <value1>
                       [<prop2> <value2>]...)")
    ("site_name" "Set the given variable to the name of the computer." "  site_name(variable)")
    ("source_group" "Define a grouping for source files in IDE project generation." "  source_group(<name> [FILES <src>...] [REGULAR_EXPRESSION <regex>])
  source_group(TREE <root> [PREFIX <prefix>] [FILES <src>...])")
    ("string" "String operations." "  `Search and Replace`_
    string(`FIND`_ <string> <substring> <out-var> [...])
    string(`REPLACE`_ <match-string> <replace-string> <out-var> <input>...)
    string(`REGEX MATCH`_ <match-regex> <out-var> <input>...)
    string(`REGEX MATCHALL`_ <match-regex> <out-var> <input>...)
    string(`REGEX REPLACE`_ <match-regex> <replace-expr> <out-var> <input>...)")
    ("subdir_depends" "Disallowed since version 3.0." "  subdir_depends(subdir dep1 dep2 ...)")
    ("subdirs" "Add a list of subdirectories to the build." "  subdirs(dir1 dir2 ...[EXCLUDE_FROM_ALL exclude_dir1 exclude_dir2 ...]
          [PREORDER])")
    ("target_compile_definitions" "Add compile definitions to a target." "  target_compile_definitions(<target>
    <INTERFACE|PUBLIC|PRIVATE> [items1...]
    [<INTERFACE|PUBLIC|PRIVATE> [items2...] ...])")
    ("target_compile_features" "Add expected compiler features to a target." "  target_compile_features(<target> <PRIVATE|PUBLIC|INTERFACE> <feature> [...])")
    ("target_compile_options" "Add compile options to a target." "  target_compile_options(<target> [BEFORE]
    <INTERFACE|PUBLIC|PRIVATE> [items1...]
    [<INTERFACE|PUBLIC|PRIVATE> [items2...] ...])")
    ("target_include_directories" "Add include directories to a target." "  target_include_directories(<target> [SYSTEM] [AFTER|BEFORE]
    <INTERFACE|PUBLIC|PRIVATE> [items1...]
    [<INTERFACE|PUBLIC|PRIVATE> [items2...] ...])")
    ("target_link_directories" "Add link directories to a target." "  target_link_directories(<target> [BEFORE]
    <INTERFACE|PUBLIC|PRIVATE> [items1...]
    [<INTERFACE|PUBLIC|PRIVATE> [items2...] ...])")
    ("target_link_libraries" "Specify libraries or flags to use when linking a given target and/or
its dependents." "  target_link_libraries(<target> ... <item>... ...)")
    ("target_link_options" "Add options to the link step for an executable, shared library or module
library target." "  target_link_options(<target> [BEFORE]
    <INTERFACE|PUBLIC|PRIVATE> [items1...]
    [<INTERFACE|PUBLIC|PRIVATE> [items2...] ...])")
    ("target_precompile_headers" "Add a list of header files to precompile." "  target_precompile_headers(<target>
    <INTERFACE|PUBLIC|PRIVATE> [header1...]
    [<INTERFACE|PUBLIC|PRIVATE> [header2...] ...])")
    ("target_sources" "Add sources to a target." "  target_sources(<target>
    <INTERFACE|PUBLIC|PRIVATE> [items1...]
    [<INTERFACE|PUBLIC|PRIVATE> [items2...] ...])")
    ("try_compile" "Try building some code." "  try_compile(<compileResultVar> PROJECT <projectName>
              SOURCE_DIR <srcdir>
              [BINARY_DIR <bindir>]
              [TARGET <targetName>]
              [LOG_DESCRIPTION <text>]
              [NO_CACHE]
              [NO_LOG]
              [CMAKE_FLAGS <flags>...]
              [OUTPUT_VARIABLE <var>])")
    ("try_run" "Try compiling and then running some code." "  try_run(<runResultVar> <compileResultVar>
          [SOURCES_TYPE <type>]
          <SOURCES <srcfile...>                 |
           SOURCE_FROM_CONTENT <name> <content> |
           SOURCE_FROM_VAR <name> <var>         |
           SOURCE_FROM_FILE <name> <path>       >...
          [LOG_DESCRIPTION <text>]
          [NO_CACHE]
          [NO_LOG]
          [CMAKE_FLAGS <flags>...]
          [COMPILE_DEFINITIONS <defs>...]
          [LINK_OPTIONS <options>...]
          [LINK_LIBRARIES <libs>...]
          [COMPILE_OUTPUT_VARIABLE <var>]
          [COPY_FILE <fileName> [COPY_FILE_ERROR <var>]]
          [<LANG>_STANDARD <std>]
          [<LANG>_STANDARD_REQUIRED <bool>]
          [<LANG>_EXTENSIONS <bool>]
          [RUN_OUTPUT_VARIABLE <var>]
          [RUN_OUTPUT_STDOUT_VARIABLE <var>]
          [RUN_OUTPUT_STDERR_VARIABLE <var>]
          [WORKING_DIRECTORY <var>]
          [ARGS <args>...]
          )")
    ("unset" "Unset a variable, cache variable, or environment variable." "  unset(<variable> [CACHE | PARENT_SCOPE])")
    ("use_mangled_mesa" "Disallowed since version 3.0." "  use_mangled_mesa(PATH_TO_MESA OUTPUT_DIRECTORY)")
    ("utility_source" "Disallowed since version 3.0." "  utility_source(cache_entry executable_name
                 path_to_source [file1 file2 ...])")
    ("variable_requires" "Disallowed since version 3.0." "  variable_requires(TEST_VARIABLE RESULT_VARIABLE
                    REQUIRED_VARIABLE1
                    REQUIRED_VARIABLE2 ...)")
    ("variable_watch" "Watch the CMake variable for change." "  variable_watch(<variable> [<command>])")
    ("while" "Evaluate a group of commands while a condition is true" "  while(<condition>)
    <commands>
  endwhile()")
    ("write_file" "The first argument is the file name, the rest of the arguments are
messages to write." nil)
    ("AIX" "Set to true when the target system is AIX." nil)
    ("ANDROID" "Set to ``1`` when the target system (:variable:`CMAKE_SYSTEM_NAME`) is
``Android``." nil)
    ("APPLE" "Set to ``True`` when the target system is an Apple platform
(macOS, iOS, tvOS, visionOS or watchOS)." nil)
    ("BORLAND" "``True`` if the Borland compiler is being used." nil)
    ("BSD" "Set to a string value when the target system is BSD. This value can be one of
the following: DragonFlyBSD, FreeBSD, OpenBSD, or NetBSD." nil)
    ("BUILD_SHARED_LIBS" "Tell :command:`add_library` to default to ``SHARED`` libraries,
instead of ``STATIC`` libraries, when called with no explicit library type." "  add_library(example ${sources})")
    ("BUILD_TESTING" "Control whether the :module:`CTest` module invokes :command:`enable_testing`." "  option(BUILD_TESTING \"...\" ON)
  if (BUILD_TESTING)
     # ...
     enable_testing()
     # ...
  endif()")
    ("CACHE" "Operator to read cache variables." nil)
    ("CMAKE_ABSOLUTE_DESTINATION_FILES" "List of files which have been installed using an ``ABSOLUTE DESTINATION`` path." nil)
    ("CMAKE_ADD_CUSTOM_COMMAND_DEPENDS_EXPLICIT_ONLY" "Whether to enable the ``DEPENDS_EXPLICIT_ONLY`` option by default in
:command:`add_custom_command`." nil)
    ("CMAKE_ADSP_ROOT" "When :ref:`Cross Compiling for ADSP SHARC/Blackfin`,
this variable holds the absolute path to the latest CCES or VDSP++ install." nil)
    ("CMAKE_AIX_EXPORT_ALL_SYMBOLS" "Default value for :prop_tgt:`AIX_EXPORT_ALL_SYMBOLS` target property." nil)
    ("CMAKE_AIX_SHARED_LIBRARY_ARCHIVE" "On AIX, enable or disable creation of shared library archives." nil)
    ("CMAKE_ANDROID_ANT_ADDITIONAL_OPTIONS" "Default value for the :prop_tgt:`ANDROID_ANT_ADDITIONAL_OPTIONS` target property." nil)
    ("CMAKE_ANDROID_API" "When :ref:`Cross Compiling for Android with NVIDIA Nsight Tegra Visual Studio
Edition`, this variable may be set to specify the default value for the
:prop_tgt:`ANDROID_API` target property." nil)
    ("CMAKE_ANDROID_API_MIN" "Default value for the :prop_tgt:`ANDROID_API_MIN` target property." nil)
    ("CMAKE_ANDROID_ARCH" "When :ref:`Cross Compiling for Android with NVIDIA Nsight Tegra Visual Studio
Edition`, this variable may be set to specify the default value for the
:prop_tgt:`ANDROID_ARCH` target property." nil)
    ("CMAKE_ANDROID_ARCH_ABI" "When :ref:`Cross Compiling for Android`, this variable specifies the
target architecture and ABI to be used." nil)
    ("CMAKE_ANDROID_ARM_MODE" "When :ref:`Cross Compiling for Android` and :variable:`CMAKE_ANDROID_ARCH_ABI`
is set to one of the ``armeabi`` architectures, set ``CMAKE_ANDROID_ARM_MODE``
to ``ON`` to target 32-bit ARM processors (``-marm``)." nil)
    ("CMAKE_ANDROID_ARM_NEON" "When :ref:`Cross Compiling for Android` and :variable:`CMAKE_ANDROID_ARCH_ABI`
is set to ``armeabi-v7a`` set ``CMAKE_ANDROID_ARM_NEON`` to ``ON`` to target
ARM NEON devices." nil)
    ("CMAKE_ANDROID_ASSETS_DIRECTORIES" "Default value for the :prop_tgt:`ANDROID_ASSETS_DIRECTORIES` target property." nil)
    ("CMAKE_ANDROID_EXCEPTIONS" "When :ref:`Cross Compiling for Android with the NDK`, this variable may be set
to specify whether exceptions are enabled." nil)
    ("CMAKE_ANDROID_GUI" "Default value for the :prop_tgt:`ANDROID_GUI` target property of
executables." nil)
    ("CMAKE_ANDROID_JAR_DEPENDENCIES" "Default value for the :prop_tgt:`ANDROID_JAR_DEPENDENCIES` target property." nil)
    ("CMAKE_ANDROID_JAR_DIRECTORIES" "Default value for the :prop_tgt:`ANDROID_JAR_DIRECTORIES` target property." nil)
    ("CMAKE_ANDROID_JAVA_SOURCE_DIR" "Default value for the :prop_tgt:`ANDROID_JAVA_SOURCE_DIR` target property." nil)
    ("CMAKE_ANDROID_NATIVE_LIB_DEPENDENCIES" "Default value for the :prop_tgt:`ANDROID_NATIVE_LIB_DEPENDENCIES` target
property." nil)
    ("CMAKE_ANDROID_NATIVE_LIB_DIRECTORIES" "Default value for the :prop_tgt:`ANDROID_NATIVE_LIB_DIRECTORIES` target
property." nil)
    ("CMAKE_ANDROID_NDK" "When :ref:`Cross Compiling for Android with the NDK`, this variable holds
the absolute path to the root directory of the NDK." nil)
    ("CMAKE_ANDROID_NDK_DEPRECATED_HEADERS" "When :ref:`Cross Compiling for Android with the NDK`, this variable
may be set to specify whether to use the deprecated per-api-level
headers instead of the unified headers." nil)
    ("CMAKE_ANDROID_NDK_TOOLCHAIN_HOST_TAG" "When :ref:`Cross Compiling for Android with the NDK`, this variable
provides the NDK's \"host tag\" used to construct the path to prebuilt
toolchains that run on the host." nil)
    ("CMAKE_ANDROID_NDK_TOOLCHAIN_VERSION" "When :ref:`Cross Compiling for Android with the NDK`, this variable
may be set to specify the version of the toolchain to be used
as the compiler." nil)
    ("CMAKE_ANDROID_NDK_VERSION" "When :ref:`Cross Compiling for Android with the NDK` and using an
Android NDK version 11 or higher, this variable is provided by
CMake to report the NDK version number." nil)
    ("CMAKE_ANDROID_PROCESS_MAX" "Default value for the :prop_tgt:`ANDROID_PROCESS_MAX` target property." nil)
    ("CMAKE_ANDROID_PROGUARD" "Default value for the :prop_tgt:`ANDROID_PROGUARD` target property." nil)
    ("CMAKE_ANDROID_PROGUARD_CONFIG_PATH" "Default value for the :prop_tgt:`ANDROID_PROGUARD_CONFIG_PATH` target property." nil)
    ("CMAKE_ANDROID_RTTI" "When :ref:`Cross Compiling for Android with the NDK`, this variable may be set
to specify whether RTTI is enabled." nil)
    ("CMAKE_ANDROID_SECURE_PROPS_PATH" "Default value for the :prop_tgt:`ANDROID_SECURE_PROPS_PATH` target property." nil)
    ("CMAKE_ANDROID_SKIP_ANT_STEP" "Default value for the :prop_tgt:`ANDROID_SKIP_ANT_STEP` target property." nil)
    ("CMAKE_ANDROID_STANDALONE_TOOLCHAIN" "When :ref:`Cross Compiling for Android with a Standalone Toolchain`, this
variable holds the absolute path to the root directory of the toolchain." nil)
    ("CMAKE_ANDROID_STL_TYPE" "When :ref:`Cross Compiling for Android with NVIDIA Nsight Tegra Visual Studio
Edition`, this variable may be set to specify the default value for the
:prop_tgt:`ANDROID_STL_TYPE` target property." nil)
    ("CMAKE_APPBUNDLE_PATH" ":ref:`Semicolon-separated list <CMake Language Lists>` of directories specifying a search path
for macOS application bundles used by the :command:`find_program`, and
:command:`find_package` commands." nil)
    ("CMAKE_APPLE_SILICON_PROCESSOR" "On Apple Silicon hosts running macOS, set this variable to tell
CMake what architecture to use for :variable:`CMAKE_HOST_SYSTEM_PROCESSOR`." nil)
    ("CMAKE_AR" "Name of archiving tool for static libraries." nil)
    ("CMAKE_ARCHIVE_OUTPUT_DIRECTORY" "Where to put all the :ref:`ARCHIVE <Archive Output Artifacts>`
target files when built." nil)
    ("CMAKE_ARCHIVE_OUTPUT_DIRECTORY_CONFIG" "Where to put all the :ref:`ARCHIVE <Archive Output Artifacts>`
target files when built for a specific configuration." nil)
    ("CMAKE_ARGC" "Number of command line arguments passed to CMake in script mode." nil)
    ("CMAKE_ARGV0" "Command line argument passed to CMake in script mode." nil)
    ("CMAKE_AUTOGEN_BETTER_GRAPH_MULTI_CONFIG" "This variable is used to initialize the
:prop_tgt:`AUTOGEN_BETTER_GRAPH_MULTI_CONFIG` property on all targets as they
are created." nil)
    ("CMAKE_AUTOGEN_COMMAND_LINE_LENGTH_MAX" "Command line length limit for autogen targets, i.e. ``moc`` or ``uic``,
that triggers the use of response files on Windows instead of passing all
arguments to the command line." nil)
    ("CMAKE_AUTOGEN_ORIGIN_DEPENDS" "Switch for forwarding origin target dependencies to the corresponding
:ref:`<ORIGIN>_autogen` targets." "    If Qt 5.15 or later is used and the generator is either :generator:`Ninja`
    or :ref:`Makefile Generators`, additional target dependencies are added to
    the :ref:`<ORIGIN>_autogen_timestamp_deps` target instead of the
    :ref:`<ORIGIN>_autogen` target.")
    ("CMAKE_AUTOGEN_PARALLEL" "Number of parallel ``moc`` or ``uic`` processes to start when using
:prop_tgt:`AUTOMOC` and :prop_tgt:`AUTOUIC`." nil)
    ("CMAKE_AUTOGEN_USE_SYSTEM_INCLUDE" "This variable is used to initialize the :prop_tgt:`AUTOGEN_USE_SYSTEM_INCLUDE`
property on all targets as they are created." nil)
    ("CMAKE_AUTOGEN_VERBOSE" "Sets the verbosity of :prop_tgt:`AUTOMOC`, :prop_tgt:`AUTOUIC` and
:prop_tgt:`AUTORCC`." nil)
    ("CMAKE_AUTOMOC" "Whether to handle ``moc`` automatically for Qt targets." nil)
    ("CMAKE_AUTOMOC_COMPILER_PREDEFINES" "This variable is used to initialize the :prop_tgt:`AUTOMOC_COMPILER_PREDEFINES`
property on all the targets. See that target property for additional
information." nil)
    ("CMAKE_AUTOMOC_DEPEND_FILTERS" "Filter definitions used by :variable:`CMAKE_AUTOMOC`
to extract file names from source code as additional dependencies
for the ``moc`` file." nil)
    ("CMAKE_AUTOMOC_EXECUTABLE" "This variable is used to initialize the :prop_tgt:`AUTOMOC_EXECUTABLE`
property on all the targets. See that target property for additional
information." nil)
    ("CMAKE_AUTOMOC_MACRO_NAMES" ":ref:`Semicolon-separated list <CMake Language Lists>` list of macro names used by
:variable:`CMAKE_AUTOMOC` to determine if a C++ file needs to be
processed by ``moc``." nil)
    ("CMAKE_AUTOMOC_MOC_OPTIONS" "Additional options for ``moc`` when using :variable:`CMAKE_AUTOMOC`." nil)
    ("CMAKE_AUTOMOC_PATH_PREFIX" "Whether to generate the ``-p`` path prefix option for ``moc`` on
:prop_tgt:`AUTOMOC` enabled Qt targets." nil)
    ("CMAKE_AUTOMOC_RELAXED_MODE" "Switch between strict and relaxed automoc mode." nil)
    ("CMAKE_AUTORCC" "Whether to handle ``rcc`` automatically for Qt targets." nil)
    ("CMAKE_AUTORCC_EXECUTABLE" "This variable is used to initialize the :prop_tgt:`AUTORCC_EXECUTABLE`
property on all the targets. See that target property for additional
information." nil)
    ("CMAKE_AUTORCC_OPTIONS" "Additional options for ``rcc`` when using :variable:`CMAKE_AUTORCC`." nil)
    ("CMAKE_AUTOUIC" "Whether to handle ``uic`` automatically for Qt targets." nil)
    ("CMAKE_AUTOUIC_EXECUTABLE" "This variable is used to initialize the :prop_tgt:`AUTOUIC_EXECUTABLE`
property on all the targets. See that target property for additional
information." nil)
    ("CMAKE_AUTOUIC_OPTIONS" "Additional options for ``uic`` when using :variable:`CMAKE_AUTOUIC`." nil)
    ("CMAKE_AUTOUIC_SEARCH_PATHS" "Search path list used by :variable:`CMAKE_AUTOUIC` to find included
``.ui`` files." nil)
    ("CMAKE_BACKWARDS_COMPATIBILITY" "Removed." nil)
    ("CMAKE_BINARY_DIR" "The path to the top level of the build tree." nil)
    ("CMAKE_BUILD_RPATH" ":ref:`Semicolon-separated list <CMake Language Lists>` specifying runtime path (``RPATH``)
entries to add to binaries linked in the build tree (for platforms that
support it)." nil)
    ("CMAKE_BUILD_RPATH_USE_ORIGIN" "Whether to use relative paths for the build ``RPATH``." nil)
    ("CMAKE_BUILD_TOOL" "This variable exists only for backwards compatibility." nil)
    ("CMAKE_BUILD_TYPE" "Specifies the build type on single-configuration generators (e.g." nil)
    ("CMAKE_BUILD_WITH_INSTALL_NAME_DIR" "Whether to use :prop_tgt:`INSTALL_NAME_DIR` on targets in the build tree." nil)
    ("CMAKE_BUILD_WITH_INSTALL_RPATH" "Use the install path for the ``RPATH``." nil)
    ("CMAKE_CACHEFILE_DIR" "This variable is used internally by CMake, and may not be set during
the first configuration of a build tree." nil)
    ("CMAKE_CACHE_MAJOR_VERSION" "Major version of CMake used to create the ``CMakeCache.txt`` file" nil)
    ("CMAKE_CACHE_MINOR_VERSION" "Minor version of CMake used to create the ``CMakeCache.txt`` file" nil)
    ("CMAKE_CACHE_PATCH_VERSION" "Patch version of CMake used to create the ``CMakeCache.txt`` file" nil)
    ("CMAKE_CFG_INTDIR" "Build-time reference to per-configuration output subdirectory." "  :align: left")
    ("CMAKE_CLANG_VFS_OVERLAY" "When cross compiling for windows with clang-cl, this variable can be an
absolute path pointing to a clang virtual file system yaml file, which
will enable clang-cl to resolve windows header names on a case sensitive
file system." nil)
    ("CMAKE_CL_64" "Discouraged." nil)
    ("CMAKE_CODEBLOCKS_COMPILER_ID" "Change the compiler id in the generated CodeBlocks project files." nil)
    ("CMAKE_CODEBLOCKS_EXCLUDE_EXTERNAL_FILES" "Change the way the CodeBlocks generator creates project files." nil)
    ("CMAKE_CODELITE_USE_TARGETS" "Change the way the CodeLite generator creates projectfiles." nil)
    ("CMAKE_COLOR_DIAGNOSTICS" "Enable color diagnostics throughout the generated build system." nil)
    ("CMAKE_COLOR_MAKEFILE" "Enables color output when using the :ref:`Makefile Generators`." nil)
    ("CMAKE_COMMAND" "The full path to the :manual:`cmake(1)` executable." nil)
    ("CMAKE_COMPILER_2005" "Using the Visual Studio 2005 compiler from Microsoft" nil)
    ("CMAKE_COMPILER_IS_GNUCC" "True if the ``C`` compiler is GNU." nil)
    ("CMAKE_COMPILER_IS_GNUCXX" "True if the C++ (``CXX``) compiler is GNU." nil)
    ("CMAKE_COMPILER_IS_GNUG77" "True if the ``Fortran`` compiler is GNU." nil)
    ("CMAKE_COMPILE_PDB_OUTPUT_DIRECTORY" "Output directory for MS debug symbol ``.pdb`` files
generated by the compiler while building source files." nil)
    ("CMAKE_COMPILE_PDB_OUTPUT_DIRECTORY_CONFIG" "Per-configuration output directory for MS debug symbol ``.pdb`` files
generated by the compiler while building source files." nil)
    ("CMAKE_COMPILE_WARNING_AS_ERROR" "Specify whether to treat warnings on compile as errors." nil)
    ("CMAKE_CONFIGURATION_TYPES" "Specifies the available build types (configurations) on multi-config
generators (e.g. :ref:`Visual Studio <Visual Studio Generators>`,
:generator:`Xcode`, or :generator:`Ninja Multi-Config`) as a
:ref:`semicolon-separated list <CMake Language Lists>`." nil)
    ("CMAKE_CONFIG_POSTFIX" "Default filename postfix for libraries under configuration ``<CONFIG>``." nil)
    ("CMAKE_CPACK_COMMAND" "Full path to :manual:`cpack(1)` command installed with CMake." nil)
    ("CMAKE_CROSSCOMPILING" "This variable is set by CMake to indicate whether it is cross compiling,
but note limitations discussed below." nil)
    ("CMAKE_CROSSCOMPILING_EMULATOR" "This variable is only used when :variable:`CMAKE_CROSSCOMPILING` is on. It
should point to a command on the host system that can run executable built
for the target system." "  If this variable contains a :ref:`semicolon-separated list <CMake Language
  Lists>`, then the first value is the command and remaining values are its
  arguments.")
    ("CMAKE_CROSS_CONFIGS" "Specifies a :ref:`semicolon-separated list <CMake Language Lists>` of
configurations available from all ``build-<Config>.ninja`` files in the
:generator:`Ninja Multi-Config` generator." nil)
    ("CMAKE_CTEST_ARGUMENTS" "Set this to a :ref:`semicolon-separated list <CMake Language Lists>` of
command-line arguments to pass to :manual:`ctest(1)` when running tests
through the ``test`` (or ``RUN_TESTS``) target of the generated build system." nil)
    ("CMAKE_CTEST_COMMAND" "Full path to :manual:`ctest(1)` command installed with CMake." nil)
    ("CMAKE_CUDA_ARCHITECTURES" "Default value for :prop_tgt:`CUDA_ARCHITECTURES` property of targets." "  cmake_minimum_required(VERSION)")
    ("CMAKE_CUDA_COMPILE_FEATURES" "List of features known to the CUDA compiler" nil)
    ("CMAKE_CUDA_EXTENSIONS" "Default value for :prop_tgt:`CUDA_EXTENSIONS` target property if set when a
target is created." nil)
    ("CMAKE_CUDA_HOST_COMPILER" "This is the original CUDA-specific name for the more general
:variable:`CMAKE_<LANG>_HOST_COMPILER` variable." nil)
    ("CMAKE_CUDA_RESOLVE_DEVICE_SYMBOLS" "Default value for :prop_tgt:`CUDA_RESOLVE_DEVICE_SYMBOLS` target
property when defined. By default this variable is not defined." nil)
    ("CMAKE_CUDA_RUNTIME_LIBRARY" "Select the CUDA runtime library for use when compiling and linking CUDA." "Contents of ``CMAKE_CUDA_RUNTIME_LIBRARY`` may use
:manual:`generator expressions <cmake-generator-expressions(7)>`.")
    ("CMAKE_CUDA_SEPARABLE_COMPILATION" "Default value for :prop_tgt:`CUDA_SEPARABLE_COMPILATION` target property." nil)
    ("CMAKE_CUDA_STANDARD" "Default value for :prop_tgt:`CUDA_STANDARD` target property if set when a
target is created." nil)
    ("CMAKE_CUDA_STANDARD_REQUIRED" "Default value for :prop_tgt:`CUDA_STANDARD_REQUIRED` target property if set
when a target is created." nil)
    ("CMAKE_CUDA_TOOLKIT_INCLUDE_DIRECTORIES" "When the ``CUDA`` language has been enabled, this provides a
:ref:`semicolon-separated list <CMake Language Lists>` of include directories provided
by the CUDA Toolkit." nil)
    ("CMAKE_CURRENT_BINARY_DIR" "The path to the binary directory currently being processed." nil)
    ("CMAKE_CURRENT_FUNCTION" "When executing code inside a :command:`function`, this variable
contains the name of the current function." nil)
    ("CMAKE_CURRENT_FUNCTION_LIST_DIR" "When executing code inside a :command:`function`, this variable
contains the full directory of the listfile that defined the current function." "  set(_THIS_MODULE_BASE_DIR \"${CMAKE_CURRENT_LIST_DIR}\")")
    ("CMAKE_CURRENT_FUNCTION_LIST_FILE" "When executing code inside a :command:`function`, this variable
contains the full path to the listfile that defined the current function." nil)
    ("CMAKE_CURRENT_FUNCTION_LIST_LINE" "When executing code inside a :command:`function`, this variable
contains the line number in the listfile where the current function
was defined." nil)
    ("CMAKE_CURRENT_LIST_DIR" "Full directory of the listfile currently being processed." nil)
    ("CMAKE_CURRENT_LIST_FILE" "Full path to the listfile currently being processed." nil)
    ("CMAKE_CURRENT_LIST_LINE" "The line number of the current file being processed." nil)
    ("CMAKE_CURRENT_SOURCE_DIR" "The path to the source directory currently being processed." nil)
    ("CMAKE_CXX_COMPILER_IMPORT_STD" "A list of C++ standard levels for which ``import std`` support exists for the
current C++ toolchain." nil)
    ("CMAKE_CXX_COMPILE_FEATURES" "List of features known to the C++ compiler" nil)
    ("CMAKE_CXX_EXTENSIONS" "Default value for :prop_tgt:`CXX_EXTENSIONS` target property if set when a
target is created." nil)
    ("CMAKE_CXX_MODULE_STD" "Whether to add utility targets as dependencies to targets with at least
``cxx_std_23`` or not." "   This setting is meaningful only when experimental support for ``import
   std;`` has been enabled by the ``CMAKE_EXPERIMENTAL_CXX_IMPORT_STD`` gate.")
    ("CMAKE_CXX_SCAN_FOR_MODULES" "Whether to scan C++ source files for module dependencies." nil)
    ("CMAKE_CXX_STANDARD" "Default value for :prop_tgt:`CXX_STANDARD` target property if set when a target
is created." nil)
    ("CMAKE_CXX_STANDARD_REQUIRED" "Default value for :prop_tgt:`CXX_STANDARD_REQUIRED` target property if set when
a target is created." nil)
    ("CMAKE_C_COMPILE_FEATURES" "List of features known to the C compiler" nil)
    ("CMAKE_C_EXTENSIONS" "Default value for :prop_tgt:`C_EXTENSIONS` target property if set when a target
is created." nil)
    ("CMAKE_C_STANDARD" "Default value for :prop_tgt:`C_STANDARD` target property if set when a target
is created." nil)
    ("CMAKE_C_STANDARD_REQUIRED" "Default value for :prop_tgt:`C_STANDARD_REQUIRED` target property if set when
a target is created." nil)
    ("CMAKE_DEBUGGER_WORKING_DIRECTORY" "This variable is used to initialize the :prop_tgt:`DEBUGGER_WORKING_DIRECTORY`
property on each target as it is created." nil)
    ("CMAKE_DEBUG_POSTFIX" "See variable :variable:`CMAKE_<CONFIG>_POSTFIX`." nil)
    ("CMAKE_DEBUG_TARGET_PROPERTIES" "Enables tracing output for target properties." nil)
    ("CMAKE_DEFAULT_BUILD_TYPE" "Specifies the configuration to use by default in a ``build.ninja`` file in the
:generator:`Ninja Multi-Config` generator. If this variable is specified,
``build.ninja`` uses build rules from ``build-<Config>.ninja`` by default. All
custom commands are executed with this configuration. If the variable is not
specified, the first item from :variable:`CMAKE_CONFIGURATION_TYPES` is used
instead." nil)
    ("CMAKE_DEFAULT_CONFIGS" "Specifies a :ref:`semicolon-separated list <CMake Language Lists>` of configurations
to build for a target in ``build.ninja`` if no ``:<Config>`` suffix is specified in
the :generator:`Ninja Multi-Config` generator. If it is set to ``all``, all
configurations from :variable:`CMAKE_CROSS_CONFIGS` are used. If it is not
specified, it defaults to :variable:`CMAKE_DEFAULT_BUILD_TYPE`." nil)
    ("CMAKE_DEPENDS_IN_PROJECT_ONLY" "When set to ``TRUE`` in a directory, the build system produced by the
:ref:`Makefile Generators` is set up to only consider dependencies on source
files that appear either in the source or in the binary directories." nil)
    ("CMAKE_DEPENDS_USE_COMPILER" "For the :ref:`Makefile Generators`, source dependencies are now, for a
selection of compilers, generated by the compiler itself. By defining this
variable with value ``FALSE``, you can restore the legacy behavior (i.e. using
CMake for dependencies discovery)." nil)
    ("CMAKE_DIRECTORY_LABELS" "Specify labels for the current directory." nil)
    ("CMAKE_DISABLE_FIND_PACKAGE_PackageName" "Variable for disabling :command:`find_package` calls." nil)
    ("CMAKE_DISABLE_PRECOMPILE_HEADERS" "Default value for :prop_tgt:`DISABLE_PRECOMPILE_HEADERS` of targets." nil)
    ("CMAKE_DLL_NAME_WITH_SOVERSION" "This variable is used to initialize the :prop_tgt:`DLL_NAME_WITH_SOVERSION`
property on shared library targets for the Windows platform, which is selected
when the :variable:`WIN32` variable is set." nil)
    ("CMAKE_DL_LIBS" "Name of library containing ``dlopen`` and ``dlclose``." nil)
    ("CMAKE_DOTNET_SDK" "Default value for :prop_tgt:`DOTNET_SDK` property of targets." nil)
    ("CMAKE_DOTNET_TARGET_FRAMEWORK" "Default value for :prop_tgt:`DOTNET_TARGET_FRAMEWORK` property of
targets." nil)
    ("CMAKE_DOTNET_TARGET_FRAMEWORK_VERSION" "Default value for :prop_tgt:`DOTNET_TARGET_FRAMEWORK_VERSION`
property of targets." nil)
    ("CMAKE_ECLIPSE_GENERATE_LINKED_RESOURCES" "This cache variable is used by the Eclipse project generator." nil)
    ("CMAKE_ECLIPSE_GENERATE_SOURCE_PROJECT" "This cache variable is used by the Eclipse project generator." nil)
    ("CMAKE_ECLIPSE_MAKE_ARGUMENTS" "This cache variable is used by the Eclipse project generator." nil)
    ("CMAKE_ECLIPSE_RESOURCE_ENCODING" "This cache variable tells the :generator:`Eclipse CDT4` project generator
to set the resource encoding to the given value in generated project files." nil)
    ("CMAKE_ECLIPSE_VERSION" "This cache variable is used by the Eclipse project generator." nil)
    ("CMAKE_EDIT_COMMAND" "Full path to :manual:`cmake-gui(1)` or :manual:`ccmake(1)`." nil)
    ("CMAKE_ENABLE_EXPORTS" "Specify whether executables export symbols for loadable modules." nil)
    ("CMAKE_ERROR_DEPRECATED" "Whether to issue errors for deprecated functionality." nil)
    ("CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION" "Ask ``cmake_install.cmake`` script to error out as soon as a file with
absolute ``INSTALL DESTINATION`` is encountered." nil)
    ("CMAKE_EXECUTABLE_ENABLE_EXPORTS" "Specify whether executables export symbols for loadable modules." nil)
    ("CMAKE_EXECUTABLE_SUFFIX" "The suffix for executables on the target platform." nil)
    ("CMAKE_EXECUTABLE_SUFFIX_LANG" "The suffix to use for the end of an executable filename of ``<LANG>``
compiler target architecture, if any." nil)
    ("CMAKE_EXECUTE_PROCESS_COMMAND_ECHO" "If this variable is set to ``STDERR``, ``STDOUT`` or ``NONE`` then commands
in :command:`execute_process` calls will be printed to either stderr or
stdout or not at all." nil)
    ("CMAKE_EXECUTE_PROCESS_COMMAND_ERROR_IS_FATAL" "Specify a default for the :command:`execute_process` command's
``COMMAND_ERROR_IS_FATAL`` option. This variable is ignored when a
``RESULTS_VARIABLE`` or ``RESULT_VARIABLE`` keyword is supplied to
the command." nil)
    ("CMAKE_EXE_LINKER_FLAGS" "Linker flags to be used to create executables." nil)
    ("CMAKE_EXE_LINKER_FLAGS_CONFIG" "Flags to be used when linking an executable." nil)
    ("CMAKE_EXE_LINKER_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_EXE_LINKER_FLAGS_<CONFIG>`
cache entry the first time a build tree is configured." nil)
    ("CMAKE_EXE_LINKER_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_EXE_LINKER_FLAGS`
cache entry the first time a build tree is configured." nil)
    ("CMAKE_EXPORT_BUILD_DATABASE" "Enable/Disable output of module compile commands during the build." "  {
    \"version\": 1,
    \"revision\": 0,
    \"sets\": [
      {
        \"family-name\" : \"export_build_database\",
        \"name\" : \"export_build_database@Debug\",
        \"translation-units\" : [
          {
            \"arguments\": [
              \"/path/to/compiler\",
              \"...\",
            ],
            \"baseline-arguments\" :
            [
              \"...\",
            ],
            \"local-arguments\" :
            [
              \"...\",
            ],
            \"object\": \"CMakeFiles/target.dir/source.cxx.o\",
            \"private\": true,
            \"provides\": {
              \"importable\": \"path/to/bmi\"
            },
            \"requires\" : [],
            \"source\": \"path/to/source.cxx\",
            \"work-directory\": \"/path/to/working/directory\"
          }
        ],
        \"visible-sets\" : []
      }
    ]
  }")
    ("CMAKE_EXPORT_COMPILE_COMMANDS" "Enable/Disable output of compile commands during generation." "  [
    {
      \"directory\": \"/home/user/development/project\",
      \"command\": \"/usr/bin/c++ ... -c ../foo/foo.cc\",
      \"file\": \"../foo/foo.cc\",
      \"output\": \"../foo.dir/foo.cc.o\"
    },")
    ("CMAKE_EXPORT_FIND_PACKAGE_NAME" "Initializes the value of :prop_tgt:`EXPORT_FIND_PACKAGE_NAME`." nil)
    ("CMAKE_EXPORT_NO_PACKAGE_REGISTRY" "Disable the :command:`export(PACKAGE)` command when :policy:`CMP0090`
is not set to ``NEW``." nil)
    ("CMAKE_EXPORT_PACKAGE_REGISTRY" "Enables the :command:`export(PACKAGE)` command when :policy:`CMP0090`
is set to ``NEW``." nil)
    ("CMAKE_EXPORT_SARIF" "Enable or disable CMake diagnostics output in SARIF format for a project." nil)
    ("CMAKE_EXTRA_GENERATOR" "The extra generator used to build the project." nil)
    ("CMAKE_EXTRA_SHARED_LIBRARY_SUFFIXES" "Additional suffixes for shared libraries." nil)
    ("CMAKE_FIND_APPBUNDLE" "This variable affects how ``find_*`` commands choose between
macOS Application Bundles and unix-style package components." nil)
    ("CMAKE_FIND_DEBUG_MODE" "Print extra find call information for the following commands to standard
error:" "  set(CMAKE_FIND_DEBUG_MODE TRUE)
  find_program(...)
  set(CMAKE_FIND_DEBUG_MODE FALSE)")
    ("CMAKE_FIND_FRAMEWORK" "This variable affects how ``find_*`` commands choose between
macOS Frameworks and unix-style package components." nil)
    ("CMAKE_FIND_LIBRARY_CUSTOM_LIB_SUFFIX" "Specify a ``<suffix>`` to tell the :command:`find_library` command to
search in a ``lib<suffix>`` directory before each ``lib`` directory that
would normally be searched." nil)
    ("CMAKE_FIND_LIBRARY_PREFIXES" "Prefixes to prepend when looking for libraries." nil)
    ("CMAKE_FIND_LIBRARY_SUFFIXES" "Suffixes to append when looking for libraries." nil)
    ("CMAKE_FIND_NO_INSTALL_PREFIX" "Exclude the values of the :variable:`CMAKE_INSTALL_PREFIX` and
:variable:`CMAKE_STAGING_PREFIX` variables from
:variable:`CMAKE_SYSTEM_PREFIX_PATH`." nil)
    ("CMAKE_FIND_PACKAGE_NAME" "Defined by the :command:`find_package` command while loading
a find module to record the caller-specified package name." nil)
    ("CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY" "By default this variable is not set. If neither
:variable:`CMAKE_FIND_USE_PACKAGE_REGISTRY` nor
``CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY`` is set, then
:command:`find_package()` will use the :ref:`User Package Registry`
unless the ``NO_CMAKE_PACKAGE_REGISTRY`` option is provided." nil)
    ("CMAKE_FIND_PACKAGE_NO_SYSTEM_PACKAGE_REGISTRY" "By default this variable is not set. If neither
:variable:`CMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY` nor
``CMAKE_FIND_PACKAGE_NO_SYSTEM_PACKAGE_REGISTRY`` is set, then
:command:`find_package()` will use the :ref:`System Package Registry`
unless the ``NO_CMAKE_SYSTEM_PACKAGE_REGISTRY`` option is provided." nil)
    ("CMAKE_FIND_PACKAGE_PREFER_CONFIG" "Tell :command:`find_package` to try \"Config\" mode before \"Module\" mode if no
mode was specified." nil)
    ("CMAKE_FIND_PACKAGE_REDIRECTS_DIR" "This read-only variable specifies a directory that the :command:`find_package`
command will check first before searching anywhere else for a module or config
package file." nil)
    ("CMAKE_FIND_PACKAGE_RESOLVE_SYMLINKS" "Set to ``TRUE`` to tell :command:`find_package` calls to resolve symbolic
links in the value of ``<PackageName>_DIR``." nil)
    ("CMAKE_FIND_PACKAGE_SORT_DIRECTION" "The sorting direction used by :variable:`CMAKE_FIND_PACKAGE_SORT_ORDER`." nil)
    ("CMAKE_FIND_PACKAGE_SORT_ORDER" "The default order for sorting directories which match a search path containing
a glob expression found using :command:`find_package`." "  set(CMAKE_FIND_PACKAGE_SORT_ORDER NATURAL)
  find_package(libX CONFIG)")
    ("CMAKE_FIND_PACKAGE_TARGETS_GLOBAL" "Setting to ``TRUE`` promotes all :prop_tgt:`IMPORTED` targets discovered
by :command:`find_package` to a ``GLOBAL`` scope." nil)
    ("CMAKE_FIND_PACKAGE_WARN_NO_MODULE" "Tell :command:`find_package` to warn if called without an explicit mode." nil)
    ("CMAKE_FIND_ROOT_PATH" "This variable is most useful when cross-compiling. CMake uses the paths in
this list as alternative roots to find filesystem items with
:command:`find_package`, :command:`find_library` etc." nil)
    ("CMAKE_FIND_ROOT_PATH_MODE_INCLUDE" nil nil)
    ("CMAKE_FIND_ROOT_PATH_MODE_LIBRARY" nil nil)
    ("CMAKE_FIND_ROOT_PATH_MODE_PACKAGE" nil nil)
    ("CMAKE_FIND_ROOT_PATH_MODE_PROGRAM" nil nil)
    ("CMAKE_FIND_USE_CMAKE_ENVIRONMENT_PATH" "Controls the default behavior of the following commands for whether or not to
search paths provided by cmake-specific environment variables:" nil)
    ("CMAKE_FIND_USE_CMAKE_PATH" "Controls the default behavior of the following commands for whether or not to
search paths provided by cmake-specific cache variables:" nil)
    ("CMAKE_FIND_USE_CMAKE_SYSTEM_PATH" "Controls the default behavior of the following commands for whether or not to
search paths provided by platform-specific cmake variables:" nil)
    ("CMAKE_FIND_USE_INSTALL_PREFIX" "Controls the default behavior of the following commands for whether or not to
search the locations in the :variable:`CMAKE_INSTALL_PREFIX` and
:variable:`CMAKE_STAGING_PREFIX` variables." nil)
    ("CMAKE_FIND_USE_PACKAGE_REGISTRY" "Controls the default behavior of the :command:`find_package` command for
whether or not to search paths provided by the :ref:`User Package Registry`." nil)
    ("CMAKE_FIND_USE_PACKAGE_ROOT_PATH" "Controls the default behavior of the following commands for whether or not to
search paths provided by :variable:`<PackageName>_ROOT` variables:" nil)
    ("CMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH" "Controls the default behavior of the following commands for whether or not to
search paths provided by standard system environment variables:" nil)
    ("CMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY" "Controls searching the :ref:`System Package Registry` by the
:command:`find_package` command." nil)
    ("CMAKE_FOLDER" "Set the folder name. Use to organize targets in an IDE." nil)
    ("CMAKE_FRAMEWORK" "Default value for :prop_tgt:`FRAMEWORK` of targets." nil)
    ("CMAKE_FRAMEWORK_MULTI_CONFIG_POSTFIX_CONFIG" "Default framework filename postfix under configuration ``<CONFIG>`` when
using a multi-config generator." nil)
    ("CMAKE_FRAMEWORK_PATH" ":ref:`Semicolon-separated list <CMake Language Lists>` of directories specifying a search path
for macOS frameworks used by the :command:`find_library`,
:command:`find_package`, :command:`find_path`, and :command:`find_file`
commands." nil)
    ("CMAKE_Fortran_FORMAT" "Set to ``FIXED`` or ``FREE`` to indicate the Fortran source layout." nil)
    ("CMAKE_Fortran_MODDIR_DEFAULT" "Fortran default module output directory." nil)
    ("CMAKE_Fortran_MODDIR_FLAG" "Fortran flag for module output directory." nil)
    ("CMAKE_Fortran_MODOUT_FLAG" "Fortran flag to enable module output." nil)
    ("CMAKE_Fortran_MODULE_DIRECTORY" "Fortran module output directory." nil)
    ("CMAKE_Fortran_PREPROCESS" "Default value for :prop_tgt:`Fortran_PREPROCESS` of targets." nil)
    ("CMAKE_GENERATOR" "The generator used to build the project." nil)
    ("CMAKE_GENERATOR_INSTANCE" "Generator-specific instance specification provided by user." "  Specify the 4-component VS Build Version, a.k.a. Build Number.")
    ("CMAKE_GENERATOR_PLATFORM" "Generator-specific target platform specification provided by user." "  Specify the Windows SDK version to use.  This is supported by VS 2015 and
  above when targeting Windows or Windows Store.  CMake will set the
  :variable:`CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION` variable to the
  selected SDK version.")
    ("CMAKE_GENERATOR_TOOLSET" "Native build system toolset specification provided by user." "  Specify the Fortran compiler to use, among those that have the required
  Visual Studio Integration feature installed.  The value may be one of:")
    ("CMAKE_GHS_NO_SOURCE_GROUP_FILE" "``ON`` / ``OFF`` boolean to control if the project file for a target should
be one single file or multiple files." nil)
    ("CMAKE_GLOBAL_AUTOGEN_TARGET" "Switch to enable generation of a global ``autogen`` target." nil)
    ("CMAKE_GLOBAL_AUTOGEN_TARGET_NAME" "Change the name of the global ``autogen`` target." nil)
    ("CMAKE_GLOBAL_AUTORCC_TARGET" "Switch to enable generation of a global ``autorcc`` target." nil)
    ("CMAKE_GLOBAL_AUTORCC_TARGET_NAME" "Change the name of the global ``autorcc`` target." nil)
    ("CMAKE_GNUtoMS" "Convert GNU import libraries (``.dll.a``) to MS format (``.lib``)." nil)
    ("CMAKE_HIP_ARCHITECTURES" "List of GPU architectures to for which to generate device code." nil)
    ("CMAKE_HIP_COMPILE_FEATURES" "List of features known to the HIP compiler" nil)
    ("CMAKE_HIP_EXTENSIONS" "Default value for :prop_tgt:`HIP_EXTENSIONS` target property if set when a
target is created." nil)
    ("CMAKE_HIP_PLATFORM" "GPU platform for which HIP language sources are to be compiled." nil)
    ("CMAKE_HIP_STANDARD" "Default value for :prop_tgt:`HIP_STANDARD` target property if set when a target
is created." nil)
    ("CMAKE_HIP_STANDARD_REQUIRED" "Default value for :prop_tgt:`HIP_STANDARD_REQUIRED` target property if set when
a target is created." nil)
    ("CMAKE_HOME_DIRECTORY" "Path to top of source tree. Same as :variable:`CMAKE_SOURCE_DIR`." nil)
    ("CMAKE_HOST_AIX" "Set to true when the host system is AIX." nil)
    ("CMAKE_HOST_APPLE" "``True`` for Apple macOS operating systems." nil)
    ("CMAKE_HOST_BSD" "Set to a string value when the host system is BSD. This value can be one of
the following: DragonFlyBSD, FreeBSD, OpenBSD, or NetBSD." nil)
    ("CMAKE_HOST_EXECUTABLE_SUFFIX" "The suffix for executables on the host platform." nil)
    ("CMAKE_HOST_LINUX" "Set to true when the host system is Linux." nil)
    ("CMAKE_HOST_SOLARIS" "``True`` for Oracle Solaris operating systems." nil)
    ("CMAKE_HOST_SYSTEM" "Composite Name of OS CMake is being run on." nil)
    ("CMAKE_HOST_SYSTEM_NAME" "Name of the OS CMake is running on." nil)
    ("CMAKE_HOST_SYSTEM_PROCESSOR" "The name of the CPU CMake is running on." "  On Apple Silicon hosts:")
    ("CMAKE_HOST_SYSTEM_VERSION" "The OS version CMake is running on." nil)
    ("CMAKE_HOST_UNIX" "``True`` for UNIX and UNIX like operating systems." nil)
    ("CMAKE_HOST_WIN32" "``True`` if the host system is running Windows, including Windows 64-bit and MSYS." nil)
    ("CMAKE_IGNORE_PATH" "See also the following variables:" nil)
    ("CMAKE_IGNORE_PREFIX_PATH" "See also the following variables:" nil)
    ("CMAKE_IMPORT_LIBRARY_PREFIX" "The prefix for import libraries that you link to." nil)
    ("CMAKE_IMPORT_LIBRARY_SUFFIX" "The suffix for import libraries that you link to." nil)
    ("CMAKE_INCLUDE_CURRENT_DIR" "Automatically add the current source and build directories to the include path." nil)
    ("CMAKE_INCLUDE_CURRENT_DIR_IN_INTERFACE" "Automatically add the current source and build directories to the
:prop_tgt:`INTERFACE_INCLUDE_DIRECTORIES` target property." nil)
    ("CMAKE_INCLUDE_DIRECTORIES_BEFORE" "Whether to append or prepend directories by default in
:command:`include_directories`." nil)
    ("CMAKE_INCLUDE_DIRECTORIES_PROJECT_BEFORE" "Whether to force prepending of project include directories." nil)
    ("CMAKE_INCLUDE_PATH" ":ref:`Semicolon-separated list <CMake Language Lists>` of directories specifying a search path
for the :command:`find_file` and :command:`find_path` commands." nil)
    ("CMAKE_INSTALL_DEFAULT_COMPONENT_NAME" "Default component used in :command:`install` commands." nil)
    ("CMAKE_INSTALL_DEFAULT_DIRECTORY_PERMISSIONS" "Default permissions for directories created implicitly during installation
of files by :command:`install` and :command:`file(INSTALL)`." nil)
    ("CMAKE_INSTALL_MESSAGE" "Specify verbosity of installation script code generated by the
:command:`install` command (using the :command:`file(INSTALL)` command)." "  -- Installing: /some/destination/path")
    ("CMAKE_INSTALL_NAME_DIR" "Directory name for installed targets on Apple platforms." nil)
    ("CMAKE_INSTALL_PREFIX" "Install directory used by :command:`install`." "    If the :envvar:`CMAKE_INSTALL_PREFIX` environment variable is set,
    its value is used as default for this variable.")
    ("CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT" "CMake sets this variable to a ``TRUE`` value when the
:variable:`CMAKE_INSTALL_PREFIX` has just been initialized to
its default value, typically on the first
run of CMake within a new build tree and the :envvar:`CMAKE_INSTALL_PREFIX`
environment variable is not set on the first run of CMake. This can be used
by project code to change the default without overriding a user-provided value:" nil)
    ("CMAKE_INSTALL_REMOVE_ENVIRONMENT_RPATH" "Sets the default for whether toolchain-defined rpaths should be removed during
installation." nil)
    ("CMAKE_INSTALL_RPATH" "The rpath to use for installed targets." nil)
    ("CMAKE_INSTALL_RPATH_USE_LINK_PATH" "Add paths to linker search and installed rpath." nil)
    ("CMAKE_INTERNAL_PLATFORM_ABI" "An internal variable subject to change." nil)
    ("CMAKE_INTERPROCEDURAL_OPTIMIZATION" "Default value for :prop_tgt:`INTERPROCEDURAL_OPTIMIZATION` of targets." nil)
    ("CMAKE_INTERPROCEDURAL_OPTIMIZATION_CONFIG" "Default value for :prop_tgt:`INTERPROCEDURAL_OPTIMIZATION_<CONFIG>` of targets." nil)
    ("CMAKE_IOS_INSTALL_COMBINED" "Default value for :prop_tgt:`IOS_INSTALL_COMBINED` of targets." nil)
    ("CMAKE_ISPC_HEADER_DIRECTORY" "ISPC generated header output directory." nil)
    ("CMAKE_ISPC_HEADER_SUFFIX" "Output suffix to be used for ISPC generated headers." nil)
    ("CMAKE_ISPC_INSTRUCTION_SETS" "Default value for :prop_tgt:`ISPC_INSTRUCTION_SETS` property of targets." nil)
    ("CMAKE_JOB_POOLS" "If the :prop_gbl:`JOB_POOLS` global property is not set, the value
of this variable is used in its place." nil)
    ("CMAKE_JOB_POOL_COMPILE" "This variable is used to initialize the :prop_tgt:`JOB_POOL_COMPILE`
property on all the targets. See :prop_tgt:`JOB_POOL_COMPILE`
for additional information." nil)
    ("CMAKE_JOB_POOL_LINK" "This variable is used to initialize the :prop_tgt:`JOB_POOL_LINK`
property on all the targets. See :prop_tgt:`JOB_POOL_LINK`
for additional information." nil)
    ("CMAKE_JOB_POOL_PRECOMPILE_HEADER" "This variable is used to initialize the :prop_tgt:`JOB_POOL_PRECOMPILE_HEADER`
property on all the targets. See :prop_tgt:`JOB_POOL_PRECOMPILE_HEADER`
for additional information." nil)
    ("CMAKE_KATE_FILES_MODE" "This cache variable is used by the Kate project generator and controls
to what mode the ``files`` entry in the project file will be set." nil)
    ("CMAKE_KATE_MAKE_ARGUMENTS" "This cache variable is used by the Kate project generator." nil)
    ("CMAKE_ASM_ANDROID_TOOLCHAIN_MACHINE" "When :ref:`Cross Compiling for Android` this variable contains the
toolchain binutils machine name (e.g. ``gcc -dumpmachine``)." nil)
    ("CMAKE_ASM_ATT_ANDROID_TOOLCHAIN_MACHINE" "When :ref:`Cross Compiling for Android` this variable contains the
toolchain binutils machine name (e.g. ``gcc -dumpmachine``)." nil)
    ("CMAKE_ASM_MARMASM_ANDROID_TOOLCHAIN_MACHINE" "When :ref:`Cross Compiling for Android` this variable contains the
toolchain binutils machine name (e.g. ``gcc -dumpmachine``)." nil)
    ("CMAKE_ASM_MASM_ANDROID_TOOLCHAIN_MACHINE" "When :ref:`Cross Compiling for Android` this variable contains the
toolchain binutils machine name (e.g. ``gcc -dumpmachine``)." nil)
    ("CMAKE_ASM_NASM_ANDROID_TOOLCHAIN_MACHINE" "When :ref:`Cross Compiling for Android` this variable contains the
toolchain binutils machine name (e.g. ``gcc -dumpmachine``)." nil)
    ("CMAKE_C_ANDROID_TOOLCHAIN_MACHINE" "When :ref:`Cross Compiling for Android` this variable contains the
toolchain binutils machine name (e.g. ``gcc -dumpmachine``)." nil)
    ("CMAKE_CSharp_ANDROID_TOOLCHAIN_MACHINE" "When :ref:`Cross Compiling for Android` this variable contains the
toolchain binutils machine name (e.g. ``gcc -dumpmachine``)." nil)
    ("CMAKE_CUDA_ANDROID_TOOLCHAIN_MACHINE" "When :ref:`Cross Compiling for Android` this variable contains the
toolchain binutils machine name (e.g. ``gcc -dumpmachine``)." nil)
    ("CMAKE_CXX_ANDROID_TOOLCHAIN_MACHINE" "When :ref:`Cross Compiling for Android` this variable contains the
toolchain binutils machine name (e.g. ``gcc -dumpmachine``)." nil)
    ("CMAKE_Fortran_ANDROID_TOOLCHAIN_MACHINE" "When :ref:`Cross Compiling for Android` this variable contains the
toolchain binutils machine name (e.g. ``gcc -dumpmachine``)." nil)
    ("CMAKE_HIP_ANDROID_TOOLCHAIN_MACHINE" "When :ref:`Cross Compiling for Android` this variable contains the
toolchain binutils machine name (e.g. ``gcc -dumpmachine``)." nil)
    ("CMAKE_ISPC_ANDROID_TOOLCHAIN_MACHINE" "When :ref:`Cross Compiling for Android` this variable contains the
toolchain binutils machine name (e.g. ``gcc -dumpmachine``)." nil)
    ("CMAKE_OBJC_ANDROID_TOOLCHAIN_MACHINE" "When :ref:`Cross Compiling for Android` this variable contains the
toolchain binutils machine name (e.g. ``gcc -dumpmachine``)." nil)
    ("CMAKE_OBJCXX_ANDROID_TOOLCHAIN_MACHINE" "When :ref:`Cross Compiling for Android` this variable contains the
toolchain binutils machine name (e.g. ``gcc -dumpmachine``)." nil)
    ("CMAKE_Swift_ANDROID_TOOLCHAIN_MACHINE" "When :ref:`Cross Compiling for Android` this variable contains the
toolchain binutils machine name (e.g. ``gcc -dumpmachine``)." nil)
    ("CMAKE_ASM_ANDROID_TOOLCHAIN_PREFIX" "When :ref:`Cross Compiling for Android` this variable contains the absolute
path prefixing the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_ASM_ATT_ANDROID_TOOLCHAIN_PREFIX" "When :ref:`Cross Compiling for Android` this variable contains the absolute
path prefixing the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_ASM_MARMASM_ANDROID_TOOLCHAIN_PREFIX" "When :ref:`Cross Compiling for Android` this variable contains the absolute
path prefixing the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_ASM_MASM_ANDROID_TOOLCHAIN_PREFIX" "When :ref:`Cross Compiling for Android` this variable contains the absolute
path prefixing the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_ASM_NASM_ANDROID_TOOLCHAIN_PREFIX" "When :ref:`Cross Compiling for Android` this variable contains the absolute
path prefixing the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_C_ANDROID_TOOLCHAIN_PREFIX" "When :ref:`Cross Compiling for Android` this variable contains the absolute
path prefixing the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_CSharp_ANDROID_TOOLCHAIN_PREFIX" "When :ref:`Cross Compiling for Android` this variable contains the absolute
path prefixing the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_CUDA_ANDROID_TOOLCHAIN_PREFIX" "When :ref:`Cross Compiling for Android` this variable contains the absolute
path prefixing the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_CXX_ANDROID_TOOLCHAIN_PREFIX" "When :ref:`Cross Compiling for Android` this variable contains the absolute
path prefixing the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_Fortran_ANDROID_TOOLCHAIN_PREFIX" "When :ref:`Cross Compiling for Android` this variable contains the absolute
path prefixing the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_HIP_ANDROID_TOOLCHAIN_PREFIX" "When :ref:`Cross Compiling for Android` this variable contains the absolute
path prefixing the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_ISPC_ANDROID_TOOLCHAIN_PREFIX" "When :ref:`Cross Compiling for Android` this variable contains the absolute
path prefixing the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_OBJC_ANDROID_TOOLCHAIN_PREFIX" "When :ref:`Cross Compiling for Android` this variable contains the absolute
path prefixing the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_OBJCXX_ANDROID_TOOLCHAIN_PREFIX" "When :ref:`Cross Compiling for Android` this variable contains the absolute
path prefixing the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_Swift_ANDROID_TOOLCHAIN_PREFIX" "When :ref:`Cross Compiling for Android` this variable contains the absolute
path prefixing the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_ASM_ANDROID_TOOLCHAIN_SUFFIX" "When :ref:`Cross Compiling for Android` this variable contains the
host platform suffix of the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_ASM_ATT_ANDROID_TOOLCHAIN_SUFFIX" "When :ref:`Cross Compiling for Android` this variable contains the
host platform suffix of the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_ASM_MARMASM_ANDROID_TOOLCHAIN_SUFFIX" "When :ref:`Cross Compiling for Android` this variable contains the
host platform suffix of the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_ASM_MASM_ANDROID_TOOLCHAIN_SUFFIX" "When :ref:`Cross Compiling for Android` this variable contains the
host platform suffix of the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_ASM_NASM_ANDROID_TOOLCHAIN_SUFFIX" "When :ref:`Cross Compiling for Android` this variable contains the
host platform suffix of the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_C_ANDROID_TOOLCHAIN_SUFFIX" "When :ref:`Cross Compiling for Android` this variable contains the
host platform suffix of the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_CSharp_ANDROID_TOOLCHAIN_SUFFIX" "When :ref:`Cross Compiling for Android` this variable contains the
host platform suffix of the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_CUDA_ANDROID_TOOLCHAIN_SUFFIX" "When :ref:`Cross Compiling for Android` this variable contains the
host platform suffix of the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_CXX_ANDROID_TOOLCHAIN_SUFFIX" "When :ref:`Cross Compiling for Android` this variable contains the
host platform suffix of the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_Fortran_ANDROID_TOOLCHAIN_SUFFIX" "When :ref:`Cross Compiling for Android` this variable contains the
host platform suffix of the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_HIP_ANDROID_TOOLCHAIN_SUFFIX" "When :ref:`Cross Compiling for Android` this variable contains the
host platform suffix of the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_ISPC_ANDROID_TOOLCHAIN_SUFFIX" "When :ref:`Cross Compiling for Android` this variable contains the
host platform suffix of the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_OBJC_ANDROID_TOOLCHAIN_SUFFIX" "When :ref:`Cross Compiling for Android` this variable contains the
host platform suffix of the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_OBJCXX_ANDROID_TOOLCHAIN_SUFFIX" "When :ref:`Cross Compiling for Android` this variable contains the
host platform suffix of the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_Swift_ANDROID_TOOLCHAIN_SUFFIX" "When :ref:`Cross Compiling for Android` this variable contains the
host platform suffix of the toolchain GNU compiler and its binutils." nil)
    ("CMAKE_ASM_ARCHIVER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the archiver
tool. It will be used to translate the ``ARCHIVER:`` prefix in the static
library options (see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_ASM_ATT_ARCHIVER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the archiver
tool. It will be used to translate the ``ARCHIVER:`` prefix in the static
library options (see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_ASM_MARMASM_ARCHIVER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the archiver
tool. It will be used to translate the ``ARCHIVER:`` prefix in the static
library options (see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_ASM_MASM_ARCHIVER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the archiver
tool. It will be used to translate the ``ARCHIVER:`` prefix in the static
library options (see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_ASM_NASM_ARCHIVER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the archiver
tool. It will be used to translate the ``ARCHIVER:`` prefix in the static
library options (see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_C_ARCHIVER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the archiver
tool. It will be used to translate the ``ARCHIVER:`` prefix in the static
library options (see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_CSharp_ARCHIVER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the archiver
tool. It will be used to translate the ``ARCHIVER:`` prefix in the static
library options (see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_CUDA_ARCHIVER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the archiver
tool. It will be used to translate the ``ARCHIVER:`` prefix in the static
library options (see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_CXX_ARCHIVER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the archiver
tool. It will be used to translate the ``ARCHIVER:`` prefix in the static
library options (see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_Fortran_ARCHIVER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the archiver
tool. It will be used to translate the ``ARCHIVER:`` prefix in the static
library options (see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_HIP_ARCHIVER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the archiver
tool. It will be used to translate the ``ARCHIVER:`` prefix in the static
library options (see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_ISPC_ARCHIVER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the archiver
tool. It will be used to translate the ``ARCHIVER:`` prefix in the static
library options (see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_OBJC_ARCHIVER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the archiver
tool. It will be used to translate the ``ARCHIVER:`` prefix in the static
library options (see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_OBJCXX_ARCHIVER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the archiver
tool. It will be used to translate the ``ARCHIVER:`` prefix in the static
library options (see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_Swift_ARCHIVER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the archiver
tool. It will be used to translate the ``ARCHIVER:`` prefix in the static
library options (see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_ASM_ARCHIVER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_ARCHIVER_WRAPPER_FLAG`
variable to format ``ARCHIVER:`` prefix in the static library options
(see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_ASM_ATT_ARCHIVER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_ARCHIVER_WRAPPER_FLAG`
variable to format ``ARCHIVER:`` prefix in the static library options
(see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_ASM_MARMASM_ARCHIVER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_ARCHIVER_WRAPPER_FLAG`
variable to format ``ARCHIVER:`` prefix in the static library options
(see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_ASM_MASM_ARCHIVER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_ARCHIVER_WRAPPER_FLAG`
variable to format ``ARCHIVER:`` prefix in the static library options
(see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_ASM_NASM_ARCHIVER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_ARCHIVER_WRAPPER_FLAG`
variable to format ``ARCHIVER:`` prefix in the static library options
(see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_C_ARCHIVER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_ARCHIVER_WRAPPER_FLAG`
variable to format ``ARCHIVER:`` prefix in the static library options
(see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_CSharp_ARCHIVER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_ARCHIVER_WRAPPER_FLAG`
variable to format ``ARCHIVER:`` prefix in the static library options
(see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_CUDA_ARCHIVER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_ARCHIVER_WRAPPER_FLAG`
variable to format ``ARCHIVER:`` prefix in the static library options
(see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_CXX_ARCHIVER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_ARCHIVER_WRAPPER_FLAG`
variable to format ``ARCHIVER:`` prefix in the static library options
(see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_Fortran_ARCHIVER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_ARCHIVER_WRAPPER_FLAG`
variable to format ``ARCHIVER:`` prefix in the static library options
(see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_HIP_ARCHIVER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_ARCHIVER_WRAPPER_FLAG`
variable to format ``ARCHIVER:`` prefix in the static library options
(see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_ISPC_ARCHIVER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_ARCHIVER_WRAPPER_FLAG`
variable to format ``ARCHIVER:`` prefix in the static library options
(see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_OBJC_ARCHIVER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_ARCHIVER_WRAPPER_FLAG`
variable to format ``ARCHIVER:`` prefix in the static library options
(see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_OBJCXX_ARCHIVER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_ARCHIVER_WRAPPER_FLAG`
variable to format ``ARCHIVER:`` prefix in the static library options
(see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_Swift_ARCHIVER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_ARCHIVER_WRAPPER_FLAG`
variable to format ``ARCHIVER:`` prefix in the static library options
(see :prop_tgt:`STATIC_LIBRARY_OPTIONS`)." nil)
    ("CMAKE_ASM_ARCHIVE_APPEND" "Rule variable to append to a static archive." nil)
    ("CMAKE_ASM_ATT_ARCHIVE_APPEND" "Rule variable to append to a static archive." nil)
    ("CMAKE_ASM_MARMASM_ARCHIVE_APPEND" "Rule variable to append to a static archive." nil)
    ("CMAKE_ASM_MASM_ARCHIVE_APPEND" "Rule variable to append to a static archive." nil)
    ("CMAKE_ASM_NASM_ARCHIVE_APPEND" "Rule variable to append to a static archive." nil)
    ("CMAKE_C_ARCHIVE_APPEND" "Rule variable to append to a static archive." nil)
    ("CMAKE_CSharp_ARCHIVE_APPEND" "Rule variable to append to a static archive." nil)
    ("CMAKE_CUDA_ARCHIVE_APPEND" "Rule variable to append to a static archive." nil)
    ("CMAKE_CXX_ARCHIVE_APPEND" "Rule variable to append to a static archive." nil)
    ("CMAKE_Fortran_ARCHIVE_APPEND" "Rule variable to append to a static archive." nil)
    ("CMAKE_HIP_ARCHIVE_APPEND" "Rule variable to append to a static archive." nil)
    ("CMAKE_ISPC_ARCHIVE_APPEND" "Rule variable to append to a static archive." nil)
    ("CMAKE_OBJC_ARCHIVE_APPEND" "Rule variable to append to a static archive." nil)
    ("CMAKE_OBJCXX_ARCHIVE_APPEND" "Rule variable to append to a static archive." nil)
    ("CMAKE_Swift_ARCHIVE_APPEND" "Rule variable to append to a static archive." nil)
    ("CMAKE_ASM_ARCHIVE_CREATE" "Rule variable to create a new static archive." nil)
    ("CMAKE_ASM_ATT_ARCHIVE_CREATE" "Rule variable to create a new static archive." nil)
    ("CMAKE_ASM_MARMASM_ARCHIVE_CREATE" "Rule variable to create a new static archive." nil)
    ("CMAKE_ASM_MASM_ARCHIVE_CREATE" "Rule variable to create a new static archive." nil)
    ("CMAKE_ASM_NASM_ARCHIVE_CREATE" "Rule variable to create a new static archive." nil)
    ("CMAKE_C_ARCHIVE_CREATE" "Rule variable to create a new static archive." nil)
    ("CMAKE_CSharp_ARCHIVE_CREATE" "Rule variable to create a new static archive." nil)
    ("CMAKE_CUDA_ARCHIVE_CREATE" "Rule variable to create a new static archive." nil)
    ("CMAKE_CXX_ARCHIVE_CREATE" "Rule variable to create a new static archive." nil)
    ("CMAKE_Fortran_ARCHIVE_CREATE" "Rule variable to create a new static archive." nil)
    ("CMAKE_HIP_ARCHIVE_CREATE" "Rule variable to create a new static archive." nil)
    ("CMAKE_ISPC_ARCHIVE_CREATE" "Rule variable to create a new static archive." nil)
    ("CMAKE_OBJC_ARCHIVE_CREATE" "Rule variable to create a new static archive." nil)
    ("CMAKE_OBJCXX_ARCHIVE_CREATE" "Rule variable to create a new static archive." nil)
    ("CMAKE_Swift_ARCHIVE_CREATE" "Rule variable to create a new static archive." nil)
    ("CMAKE_ASM_ARCHIVE_FINISH" "Rule variable to finish an existing static archive." nil)
    ("CMAKE_ASM_ATT_ARCHIVE_FINISH" "Rule variable to finish an existing static archive." nil)
    ("CMAKE_ASM_MARMASM_ARCHIVE_FINISH" "Rule variable to finish an existing static archive." nil)
    ("CMAKE_ASM_MASM_ARCHIVE_FINISH" "Rule variable to finish an existing static archive." nil)
    ("CMAKE_ASM_NASM_ARCHIVE_FINISH" "Rule variable to finish an existing static archive." nil)
    ("CMAKE_C_ARCHIVE_FINISH" "Rule variable to finish an existing static archive." nil)
    ("CMAKE_CSharp_ARCHIVE_FINISH" "Rule variable to finish an existing static archive." nil)
    ("CMAKE_CUDA_ARCHIVE_FINISH" "Rule variable to finish an existing static archive." nil)
    ("CMAKE_CXX_ARCHIVE_FINISH" "Rule variable to finish an existing static archive." nil)
    ("CMAKE_Fortran_ARCHIVE_FINISH" "Rule variable to finish an existing static archive." nil)
    ("CMAKE_HIP_ARCHIVE_FINISH" "Rule variable to finish an existing static archive." nil)
    ("CMAKE_ISPC_ARCHIVE_FINISH" "Rule variable to finish an existing static archive." nil)
    ("CMAKE_OBJC_ARCHIVE_FINISH" "Rule variable to finish an existing static archive." nil)
    ("CMAKE_OBJCXX_ARCHIVE_FINISH" "Rule variable to finish an existing static archive." nil)
    ("CMAKE_Swift_ARCHIVE_FINISH" "Rule variable to finish an existing static archive." nil)
    ("CMAKE_ASM_BYTE_ORDER" "Byte order of ``<LANG>`` compiler target architecture, if known." nil)
    ("CMAKE_ASM_ATT_BYTE_ORDER" "Byte order of ``<LANG>`` compiler target architecture, if known." nil)
    ("CMAKE_ASM_MARMASM_BYTE_ORDER" "Byte order of ``<LANG>`` compiler target architecture, if known." nil)
    ("CMAKE_ASM_MASM_BYTE_ORDER" "Byte order of ``<LANG>`` compiler target architecture, if known." nil)
    ("CMAKE_ASM_NASM_BYTE_ORDER" "Byte order of ``<LANG>`` compiler target architecture, if known." nil)
    ("CMAKE_C_BYTE_ORDER" "Byte order of ``<LANG>`` compiler target architecture, if known." nil)
    ("CMAKE_CSharp_BYTE_ORDER" "Byte order of ``<LANG>`` compiler target architecture, if known." nil)
    ("CMAKE_CUDA_BYTE_ORDER" "Byte order of ``<LANG>`` compiler target architecture, if known." nil)
    ("CMAKE_CXX_BYTE_ORDER" "Byte order of ``<LANG>`` compiler target architecture, if known." nil)
    ("CMAKE_Fortran_BYTE_ORDER" "Byte order of ``<LANG>`` compiler target architecture, if known." nil)
    ("CMAKE_HIP_BYTE_ORDER" "Byte order of ``<LANG>`` compiler target architecture, if known." nil)
    ("CMAKE_ISPC_BYTE_ORDER" "Byte order of ``<LANG>`` compiler target architecture, if known." nil)
    ("CMAKE_OBJC_BYTE_ORDER" "Byte order of ``<LANG>`` compiler target architecture, if known." nil)
    ("CMAKE_OBJCXX_BYTE_ORDER" "Byte order of ``<LANG>`` compiler target architecture, if known." nil)
    ("CMAKE_Swift_BYTE_ORDER" "Byte order of ``<LANG>`` compiler target architecture, if known." nil)
    ("CMAKE_ASM_CLANG_TIDY" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY` target property
when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_ASM_ATT_CLANG_TIDY" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY` target property
when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_ASM_MARMASM_CLANG_TIDY" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY` target property
when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_ASM_MASM_CLANG_TIDY" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY` target property
when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_ASM_NASM_CLANG_TIDY" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY` target property
when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_C_CLANG_TIDY" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY` target property
when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_CSharp_CLANG_TIDY" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY` target property
when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_CUDA_CLANG_TIDY" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY` target property
when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_CXX_CLANG_TIDY" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY` target property
when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_Fortran_CLANG_TIDY" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY` target property
when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_HIP_CLANG_TIDY" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY` target property
when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_ISPC_CLANG_TIDY" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY` target property
when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_OBJC_CLANG_TIDY" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY` target property
when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_OBJCXX_CLANG_TIDY" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY` target property
when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_Swift_CLANG_TIDY" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY` target property
when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_ASM_CLANG_TIDY_EXPORT_FIXES_DIR" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR` target
property when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_ASM_ATT_CLANG_TIDY_EXPORT_FIXES_DIR" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR` target
property when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_ASM_MARMASM_CLANG_TIDY_EXPORT_FIXES_DIR" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR` target
property when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_ASM_MASM_CLANG_TIDY_EXPORT_FIXES_DIR" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR` target
property when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_ASM_NASM_CLANG_TIDY_EXPORT_FIXES_DIR" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR` target
property when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_C_CLANG_TIDY_EXPORT_FIXES_DIR" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR` target
property when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_CSharp_CLANG_TIDY_EXPORT_FIXES_DIR" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR` target
property when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_CUDA_CLANG_TIDY_EXPORT_FIXES_DIR" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR` target
property when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_CXX_CLANG_TIDY_EXPORT_FIXES_DIR" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR` target
property when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_Fortran_CLANG_TIDY_EXPORT_FIXES_DIR" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR` target
property when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_HIP_CLANG_TIDY_EXPORT_FIXES_DIR" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR` target
property when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_ISPC_CLANG_TIDY_EXPORT_FIXES_DIR" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR` target
property when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_OBJC_CLANG_TIDY_EXPORT_FIXES_DIR" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR` target
property when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_OBJCXX_CLANG_TIDY_EXPORT_FIXES_DIR" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR` target
property when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_Swift_CLANG_TIDY_EXPORT_FIXES_DIR" "Default value for :prop_tgt:`<LANG>_CLANG_TIDY_EXPORT_FIXES_DIR` target
property when ``<LANG>`` is ``C``, ``CXX``, ``OBJC`` or ``OBJCXX``." nil)
    ("CMAKE_ASM_COMPILER" "The full path to the compiler for ``LANG``." "  Options that are required to make the compiler work correctly can be included
  as items in a list; they can not be changed.")
    ("CMAKE_ASM_ATT_COMPILER" "The full path to the compiler for ``LANG``." "  Options that are required to make the compiler work correctly can be included
  as items in a list; they can not be changed.")
    ("CMAKE_ASM_MARMASM_COMPILER" "The full path to the compiler for ``LANG``." "  Options that are required to make the compiler work correctly can be included
  as items in a list; they can not be changed.")
    ("CMAKE_ASM_MASM_COMPILER" "The full path to the compiler for ``LANG``." "  Options that are required to make the compiler work correctly can be included
  as items in a list; they can not be changed.")
    ("CMAKE_ASM_NASM_COMPILER" "The full path to the compiler for ``LANG``." "  Options that are required to make the compiler work correctly can be included
  as items in a list; they can not be changed.")
    ("CMAKE_C_COMPILER" "The full path to the compiler for ``LANG``." "  Options that are required to make the compiler work correctly can be included
  as items in a list; they can not be changed.")
    ("CMAKE_CSharp_COMPILER" "The full path to the compiler for ``LANG``." "  Options that are required to make the compiler work correctly can be included
  as items in a list; they can not be changed.")
    ("CMAKE_CUDA_COMPILER" "The full path to the compiler for ``LANG``." "  Options that are required to make the compiler work correctly can be included
  as items in a list; they can not be changed.")
    ("CMAKE_CXX_COMPILER" "The full path to the compiler for ``LANG``." "  Options that are required to make the compiler work correctly can be included
  as items in a list; they can not be changed.")
    ("CMAKE_Fortran_COMPILER" "The full path to the compiler for ``LANG``." "  Options that are required to make the compiler work correctly can be included
  as items in a list; they can not be changed.")
    ("CMAKE_HIP_COMPILER" "The full path to the compiler for ``LANG``." "  Options that are required to make the compiler work correctly can be included
  as items in a list; they can not be changed.")
    ("CMAKE_ISPC_COMPILER" "The full path to the compiler for ``LANG``." "  Options that are required to make the compiler work correctly can be included
  as items in a list; they can not be changed.")
    ("CMAKE_OBJC_COMPILER" "The full path to the compiler for ``LANG``." "  Options that are required to make the compiler work correctly can be included
  as items in a list; they can not be changed.")
    ("CMAKE_OBJCXX_COMPILER" "The full path to the compiler for ``LANG``." "  Options that are required to make the compiler work correctly can be included
  as items in a list; they can not be changed.")
    ("CMAKE_Swift_COMPILER" "The full path to the compiler for ``LANG``." "  Options that are required to make the compiler work correctly can be included
  as items in a list; they can not be changed.")
    ("CMAKE_ASM_COMPILER_ABI" "An internal variable subject to change." nil)
    ("CMAKE_ASM_ATT_COMPILER_ABI" "An internal variable subject to change." nil)
    ("CMAKE_ASM_MARMASM_COMPILER_ABI" "An internal variable subject to change." nil)
    ("CMAKE_ASM_MASM_COMPILER_ABI" "An internal variable subject to change." nil)
    ("CMAKE_ASM_NASM_COMPILER_ABI" "An internal variable subject to change." nil)
    ("CMAKE_C_COMPILER_ABI" "An internal variable subject to change." nil)
    ("CMAKE_CSharp_COMPILER_ABI" "An internal variable subject to change." nil)
    ("CMAKE_CUDA_COMPILER_ABI" "An internal variable subject to change." nil)
    ("CMAKE_CXX_COMPILER_ABI" "An internal variable subject to change." nil)
    ("CMAKE_Fortran_COMPILER_ABI" "An internal variable subject to change." nil)
    ("CMAKE_HIP_COMPILER_ABI" "An internal variable subject to change." nil)
    ("CMAKE_ISPC_COMPILER_ABI" "An internal variable subject to change." nil)
    ("CMAKE_OBJC_COMPILER_ABI" "An internal variable subject to change." nil)
    ("CMAKE_OBJCXX_COMPILER_ABI" "An internal variable subject to change." nil)
    ("CMAKE_Swift_COMPILER_ABI" "An internal variable subject to change." nil)
    ("CMAKE_ASM_COMPILER_AR" "A wrapper around ``ar`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_ASM_ATT_COMPILER_AR" "A wrapper around ``ar`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_ASM_MARMASM_COMPILER_AR" "A wrapper around ``ar`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_ASM_MASM_COMPILER_AR" "A wrapper around ``ar`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_ASM_NASM_COMPILER_AR" "A wrapper around ``ar`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_C_COMPILER_AR" "A wrapper around ``ar`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_CSharp_COMPILER_AR" "A wrapper around ``ar`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_CUDA_COMPILER_AR" "A wrapper around ``ar`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_CXX_COMPILER_AR" "A wrapper around ``ar`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_Fortran_COMPILER_AR" "A wrapper around ``ar`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_HIP_COMPILER_AR" "A wrapper around ``ar`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_ISPC_COMPILER_AR" "A wrapper around ``ar`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_OBJC_COMPILER_AR" "A wrapper around ``ar`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_OBJCXX_COMPILER_AR" "A wrapper around ``ar`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_Swift_COMPILER_AR" "A wrapper around ``ar`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_ASM_COMPILER_ARCHITECTURE_ID" "An internal variable subject to change." nil)
    ("CMAKE_ASM_ATT_COMPILER_ARCHITECTURE_ID" "An internal variable subject to change." nil)
    ("CMAKE_ASM_MARMASM_COMPILER_ARCHITECTURE_ID" "An internal variable subject to change." nil)
    ("CMAKE_ASM_MASM_COMPILER_ARCHITECTURE_ID" "An internal variable subject to change." nil)
    ("CMAKE_ASM_NASM_COMPILER_ARCHITECTURE_ID" "An internal variable subject to change." nil)
    ("CMAKE_C_COMPILER_ARCHITECTURE_ID" "An internal variable subject to change." nil)
    ("CMAKE_CSharp_COMPILER_ARCHITECTURE_ID" "An internal variable subject to change." nil)
    ("CMAKE_CUDA_COMPILER_ARCHITECTURE_ID" "An internal variable subject to change." nil)
    ("CMAKE_CXX_COMPILER_ARCHITECTURE_ID" "An internal variable subject to change." nil)
    ("CMAKE_Fortran_COMPILER_ARCHITECTURE_ID" "An internal variable subject to change." nil)
    ("CMAKE_HIP_COMPILER_ARCHITECTURE_ID" "An internal variable subject to change." nil)
    ("CMAKE_ISPC_COMPILER_ARCHITECTURE_ID" "An internal variable subject to change." nil)
    ("CMAKE_OBJC_COMPILER_ARCHITECTURE_ID" "An internal variable subject to change." nil)
    ("CMAKE_OBJCXX_COMPILER_ARCHITECTURE_ID" "An internal variable subject to change." nil)
    ("CMAKE_Swift_COMPILER_ARCHITECTURE_ID" "An internal variable subject to change." nil)
    ("CMAKE_ASM_COMPILER_EXTERNAL_TOOLCHAIN" "The external toolchain for cross-compiling, if supported." nil)
    ("CMAKE_ASM_ATT_COMPILER_EXTERNAL_TOOLCHAIN" "The external toolchain for cross-compiling, if supported." nil)
    ("CMAKE_ASM_MARMASM_COMPILER_EXTERNAL_TOOLCHAIN" "The external toolchain for cross-compiling, if supported." nil)
    ("CMAKE_ASM_MASM_COMPILER_EXTERNAL_TOOLCHAIN" "The external toolchain for cross-compiling, if supported." nil)
    ("CMAKE_ASM_NASM_COMPILER_EXTERNAL_TOOLCHAIN" "The external toolchain for cross-compiling, if supported." nil)
    ("CMAKE_C_COMPILER_EXTERNAL_TOOLCHAIN" "The external toolchain for cross-compiling, if supported." nil)
    ("CMAKE_CSharp_COMPILER_EXTERNAL_TOOLCHAIN" "The external toolchain for cross-compiling, if supported." nil)
    ("CMAKE_CUDA_COMPILER_EXTERNAL_TOOLCHAIN" "The external toolchain for cross-compiling, if supported." nil)
    ("CMAKE_CXX_COMPILER_EXTERNAL_TOOLCHAIN" "The external toolchain for cross-compiling, if supported." nil)
    ("CMAKE_Fortran_COMPILER_EXTERNAL_TOOLCHAIN" "The external toolchain for cross-compiling, if supported." nil)
    ("CMAKE_HIP_COMPILER_EXTERNAL_TOOLCHAIN" "The external toolchain for cross-compiling, if supported." nil)
    ("CMAKE_ISPC_COMPILER_EXTERNAL_TOOLCHAIN" "The external toolchain for cross-compiling, if supported." nil)
    ("CMAKE_OBJC_COMPILER_EXTERNAL_TOOLCHAIN" "The external toolchain for cross-compiling, if supported." nil)
    ("CMAKE_OBJCXX_COMPILER_EXTERNAL_TOOLCHAIN" "The external toolchain for cross-compiling, if supported." nil)
    ("CMAKE_Swift_COMPILER_EXTERNAL_TOOLCHAIN" "The external toolchain for cross-compiling, if supported." nil)
    ("CMAKE_ASM_COMPILER_FRONTEND_VARIANT" "Identification string of the compiler frontend variant." "  In other words, this variable describes what command line options
  and language extensions the compiler frontend expects.")
    ("CMAKE_ASM_ATT_COMPILER_FRONTEND_VARIANT" "Identification string of the compiler frontend variant." "  In other words, this variable describes what command line options
  and language extensions the compiler frontend expects.")
    ("CMAKE_ASM_MARMASM_COMPILER_FRONTEND_VARIANT" "Identification string of the compiler frontend variant." "  In other words, this variable describes what command line options
  and language extensions the compiler frontend expects.")
    ("CMAKE_ASM_MASM_COMPILER_FRONTEND_VARIANT" "Identification string of the compiler frontend variant." "  In other words, this variable describes what command line options
  and language extensions the compiler frontend expects.")
    ("CMAKE_ASM_NASM_COMPILER_FRONTEND_VARIANT" "Identification string of the compiler frontend variant." "  In other words, this variable describes what command line options
  and language extensions the compiler frontend expects.")
    ("CMAKE_C_COMPILER_FRONTEND_VARIANT" "Identification string of the compiler frontend variant." "  In other words, this variable describes what command line options
  and language extensions the compiler frontend expects.")
    ("CMAKE_CSharp_COMPILER_FRONTEND_VARIANT" "Identification string of the compiler frontend variant." "  In other words, this variable describes what command line options
  and language extensions the compiler frontend expects.")
    ("CMAKE_CUDA_COMPILER_FRONTEND_VARIANT" "Identification string of the compiler frontend variant." "  In other words, this variable describes what command line options
  and language extensions the compiler frontend expects.")
    ("CMAKE_CXX_COMPILER_FRONTEND_VARIANT" "Identification string of the compiler frontend variant." "  In other words, this variable describes what command line options
  and language extensions the compiler frontend expects.")
    ("CMAKE_Fortran_COMPILER_FRONTEND_VARIANT" "Identification string of the compiler frontend variant." "  In other words, this variable describes what command line options
  and language extensions the compiler frontend expects.")
    ("CMAKE_HIP_COMPILER_FRONTEND_VARIANT" "Identification string of the compiler frontend variant." "  In other words, this variable describes what command line options
  and language extensions the compiler frontend expects.")
    ("CMAKE_ISPC_COMPILER_FRONTEND_VARIANT" "Identification string of the compiler frontend variant." "  In other words, this variable describes what command line options
  and language extensions the compiler frontend expects.")
    ("CMAKE_OBJC_COMPILER_FRONTEND_VARIANT" "Identification string of the compiler frontend variant." "  In other words, this variable describes what command line options
  and language extensions the compiler frontend expects.")
    ("CMAKE_OBJCXX_COMPILER_FRONTEND_VARIANT" "Identification string of the compiler frontend variant." "  In other words, this variable describes what command line options
  and language extensions the compiler frontend expects.")
    ("CMAKE_Swift_COMPILER_FRONTEND_VARIANT" "Identification string of the compiler frontend variant." "  In other words, this variable describes what command line options
  and language extensions the compiler frontend expects.")
    ("CMAKE_ASM_COMPILER_ID" "Compiler identification string." nil)
    ("CMAKE_ASM_ATT_COMPILER_ID" "Compiler identification string." nil)
    ("CMAKE_ASM_MARMASM_COMPILER_ID" "Compiler identification string." nil)
    ("CMAKE_ASM_MASM_COMPILER_ID" "Compiler identification string." nil)
    ("CMAKE_ASM_NASM_COMPILER_ID" "Compiler identification string." nil)
    ("CMAKE_C_COMPILER_ID" "Compiler identification string." nil)
    ("CMAKE_CSharp_COMPILER_ID" "Compiler identification string." nil)
    ("CMAKE_CUDA_COMPILER_ID" "Compiler identification string." nil)
    ("CMAKE_CXX_COMPILER_ID" "Compiler identification string." nil)
    ("CMAKE_Fortran_COMPILER_ID" "Compiler identification string." nil)
    ("CMAKE_HIP_COMPILER_ID" "Compiler identification string." nil)
    ("CMAKE_ISPC_COMPILER_ID" "Compiler identification string." nil)
    ("CMAKE_OBJC_COMPILER_ID" "Compiler identification string." nil)
    ("CMAKE_OBJCXX_COMPILER_ID" "Compiler identification string." nil)
    ("CMAKE_Swift_COMPILER_ID" "Compiler identification string." nil)
    ("CMAKE_ASM_COMPILER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_COMPILER_LAUNCHER` target property." nil)
    ("CMAKE_ASM_ATT_COMPILER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_COMPILER_LAUNCHER` target property." nil)
    ("CMAKE_ASM_MARMASM_COMPILER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_COMPILER_LAUNCHER` target property." nil)
    ("CMAKE_ASM_MASM_COMPILER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_COMPILER_LAUNCHER` target property." nil)
    ("CMAKE_ASM_NASM_COMPILER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_COMPILER_LAUNCHER` target property." nil)
    ("CMAKE_C_COMPILER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_COMPILER_LAUNCHER` target property." nil)
    ("CMAKE_CSharp_COMPILER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_COMPILER_LAUNCHER` target property." nil)
    ("CMAKE_CUDA_COMPILER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_COMPILER_LAUNCHER` target property." nil)
    ("CMAKE_CXX_COMPILER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_COMPILER_LAUNCHER` target property." nil)
    ("CMAKE_Fortran_COMPILER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_COMPILER_LAUNCHER` target property." nil)
    ("CMAKE_HIP_COMPILER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_COMPILER_LAUNCHER` target property." nil)
    ("CMAKE_ISPC_COMPILER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_COMPILER_LAUNCHER` target property." nil)
    ("CMAKE_OBJC_COMPILER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_COMPILER_LAUNCHER` target property." nil)
    ("CMAKE_OBJCXX_COMPILER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_COMPILER_LAUNCHER` target property." nil)
    ("CMAKE_Swift_COMPILER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_COMPILER_LAUNCHER` target property." nil)
    ("CMAKE_ASM_COMPILER_LINKER" "The full path to the linker for ``LANG``." nil)
    ("CMAKE_ASM_ATT_COMPILER_LINKER" "The full path to the linker for ``LANG``." nil)
    ("CMAKE_ASM_MARMASM_COMPILER_LINKER" "The full path to the linker for ``LANG``." nil)
    ("CMAKE_ASM_MASM_COMPILER_LINKER" "The full path to the linker for ``LANG``." nil)
    ("CMAKE_ASM_NASM_COMPILER_LINKER" "The full path to the linker for ``LANG``." nil)
    ("CMAKE_C_COMPILER_LINKER" "The full path to the linker for ``LANG``." nil)
    ("CMAKE_CSharp_COMPILER_LINKER" "The full path to the linker for ``LANG``." nil)
    ("CMAKE_CUDA_COMPILER_LINKER" "The full path to the linker for ``LANG``." nil)
    ("CMAKE_CXX_COMPILER_LINKER" "The full path to the linker for ``LANG``." nil)
    ("CMAKE_Fortran_COMPILER_LINKER" "The full path to the linker for ``LANG``." nil)
    ("CMAKE_HIP_COMPILER_LINKER" "The full path to the linker for ``LANG``." nil)
    ("CMAKE_ISPC_COMPILER_LINKER" "The full path to the linker for ``LANG``." nil)
    ("CMAKE_OBJC_COMPILER_LINKER" "The full path to the linker for ``LANG``." nil)
    ("CMAKE_OBJCXX_COMPILER_LINKER" "The full path to the linker for ``LANG``." nil)
    ("CMAKE_Swift_COMPILER_LINKER" "The full path to the linker for ``LANG``." nil)
    ("CMAKE_ASM_COMPILER_LINKER_FRONTEND_VARIANT" "Identification string of the linker frontend variant." nil)
    ("CMAKE_ASM_ATT_COMPILER_LINKER_FRONTEND_VARIANT" "Identification string of the linker frontend variant." nil)
    ("CMAKE_ASM_MARMASM_COMPILER_LINKER_FRONTEND_VARIANT" "Identification string of the linker frontend variant." nil)
    ("CMAKE_ASM_MASM_COMPILER_LINKER_FRONTEND_VARIANT" "Identification string of the linker frontend variant." nil)
    ("CMAKE_ASM_NASM_COMPILER_LINKER_FRONTEND_VARIANT" "Identification string of the linker frontend variant." nil)
    ("CMAKE_C_COMPILER_LINKER_FRONTEND_VARIANT" "Identification string of the linker frontend variant." nil)
    ("CMAKE_CSharp_COMPILER_LINKER_FRONTEND_VARIANT" "Identification string of the linker frontend variant." nil)
    ("CMAKE_CUDA_COMPILER_LINKER_FRONTEND_VARIANT" "Identification string of the linker frontend variant." nil)
    ("CMAKE_CXX_COMPILER_LINKER_FRONTEND_VARIANT" "Identification string of the linker frontend variant." nil)
    ("CMAKE_Fortran_COMPILER_LINKER_FRONTEND_VARIANT" "Identification string of the linker frontend variant." nil)
    ("CMAKE_HIP_COMPILER_LINKER_FRONTEND_VARIANT" "Identification string of the linker frontend variant." nil)
    ("CMAKE_ISPC_COMPILER_LINKER_FRONTEND_VARIANT" "Identification string of the linker frontend variant." nil)
    ("CMAKE_OBJC_COMPILER_LINKER_FRONTEND_VARIANT" "Identification string of the linker frontend variant." nil)
    ("CMAKE_OBJCXX_COMPILER_LINKER_FRONTEND_VARIANT" "Identification string of the linker frontend variant." nil)
    ("CMAKE_Swift_COMPILER_LINKER_FRONTEND_VARIANT" "Identification string of the linker frontend variant." nil)
    ("CMAKE_ASM_COMPILER_LINKER_ID" "Linker identification string." nil)
    ("CMAKE_ASM_ATT_COMPILER_LINKER_ID" "Linker identification string." nil)
    ("CMAKE_ASM_MARMASM_COMPILER_LINKER_ID" "Linker identification string." nil)
    ("CMAKE_ASM_MASM_COMPILER_LINKER_ID" "Linker identification string." nil)
    ("CMAKE_ASM_NASM_COMPILER_LINKER_ID" "Linker identification string." nil)
    ("CMAKE_C_COMPILER_LINKER_ID" "Linker identification string." nil)
    ("CMAKE_CSharp_COMPILER_LINKER_ID" "Linker identification string." nil)
    ("CMAKE_CUDA_COMPILER_LINKER_ID" "Linker identification string." nil)
    ("CMAKE_CXX_COMPILER_LINKER_ID" "Linker identification string." nil)
    ("CMAKE_Fortran_COMPILER_LINKER_ID" "Linker identification string." nil)
    ("CMAKE_HIP_COMPILER_LINKER_ID" "Linker identification string." nil)
    ("CMAKE_ISPC_COMPILER_LINKER_ID" "Linker identification string." nil)
    ("CMAKE_OBJC_COMPILER_LINKER_ID" "Linker identification string." nil)
    ("CMAKE_OBJCXX_COMPILER_LINKER_ID" "Linker identification string." nil)
    ("CMAKE_Swift_COMPILER_LINKER_ID" "Linker identification string." nil)
    ("CMAKE_ASM_COMPILER_LINKER_VERSION" "Linker version string." nil)
    ("CMAKE_ASM_ATT_COMPILER_LINKER_VERSION" "Linker version string." nil)
    ("CMAKE_ASM_MARMASM_COMPILER_LINKER_VERSION" "Linker version string." nil)
    ("CMAKE_ASM_MASM_COMPILER_LINKER_VERSION" "Linker version string." nil)
    ("CMAKE_ASM_NASM_COMPILER_LINKER_VERSION" "Linker version string." nil)
    ("CMAKE_C_COMPILER_LINKER_VERSION" "Linker version string." nil)
    ("CMAKE_CSharp_COMPILER_LINKER_VERSION" "Linker version string." nil)
    ("CMAKE_CUDA_COMPILER_LINKER_VERSION" "Linker version string." nil)
    ("CMAKE_CXX_COMPILER_LINKER_VERSION" "Linker version string." nil)
    ("CMAKE_Fortran_COMPILER_LINKER_VERSION" "Linker version string." nil)
    ("CMAKE_HIP_COMPILER_LINKER_VERSION" "Linker version string." nil)
    ("CMAKE_ISPC_COMPILER_LINKER_VERSION" "Linker version string." nil)
    ("CMAKE_OBJC_COMPILER_LINKER_VERSION" "Linker version string." nil)
    ("CMAKE_OBJCXX_COMPILER_LINKER_VERSION" "Linker version string." nil)
    ("CMAKE_Swift_COMPILER_LINKER_VERSION" "Linker version string." nil)
    ("CMAKE_ASM_COMPILER_LOADED" "Defined to true if the language is enabled." nil)
    ("CMAKE_ASM_ATT_COMPILER_LOADED" "Defined to true if the language is enabled." nil)
    ("CMAKE_ASM_MARMASM_COMPILER_LOADED" "Defined to true if the language is enabled." nil)
    ("CMAKE_ASM_MASM_COMPILER_LOADED" "Defined to true if the language is enabled." nil)
    ("CMAKE_ASM_NASM_COMPILER_LOADED" "Defined to true if the language is enabled." nil)
    ("CMAKE_C_COMPILER_LOADED" "Defined to true if the language is enabled." nil)
    ("CMAKE_CSharp_COMPILER_LOADED" "Defined to true if the language is enabled." nil)
    ("CMAKE_CUDA_COMPILER_LOADED" "Defined to true if the language is enabled." nil)
    ("CMAKE_CXX_COMPILER_LOADED" "Defined to true if the language is enabled." nil)
    ("CMAKE_Fortran_COMPILER_LOADED" "Defined to true if the language is enabled." nil)
    ("CMAKE_HIP_COMPILER_LOADED" "Defined to true if the language is enabled." nil)
    ("CMAKE_ISPC_COMPILER_LOADED" "Defined to true if the language is enabled." nil)
    ("CMAKE_OBJC_COMPILER_LOADED" "Defined to true if the language is enabled." nil)
    ("CMAKE_OBJCXX_COMPILER_LOADED" "Defined to true if the language is enabled." nil)
    ("CMAKE_Swift_COMPILER_LOADED" "Defined to true if the language is enabled." nil)
    ("CMAKE_ASM_COMPILER_PREDEFINES_COMMAND" "Command that outputs the compiler pre definitions." nil)
    ("CMAKE_ASM_ATT_COMPILER_PREDEFINES_COMMAND" "Command that outputs the compiler pre definitions." nil)
    ("CMAKE_ASM_MARMASM_COMPILER_PREDEFINES_COMMAND" "Command that outputs the compiler pre definitions." nil)
    ("CMAKE_ASM_MASM_COMPILER_PREDEFINES_COMMAND" "Command that outputs the compiler pre definitions." nil)
    ("CMAKE_ASM_NASM_COMPILER_PREDEFINES_COMMAND" "Command that outputs the compiler pre definitions." nil)
    ("CMAKE_C_COMPILER_PREDEFINES_COMMAND" "Command that outputs the compiler pre definitions." nil)
    ("CMAKE_CSharp_COMPILER_PREDEFINES_COMMAND" "Command that outputs the compiler pre definitions." nil)
    ("CMAKE_CUDA_COMPILER_PREDEFINES_COMMAND" "Command that outputs the compiler pre definitions." nil)
    ("CMAKE_CXX_COMPILER_PREDEFINES_COMMAND" "Command that outputs the compiler pre definitions." nil)
    ("CMAKE_Fortran_COMPILER_PREDEFINES_COMMAND" "Command that outputs the compiler pre definitions." nil)
    ("CMAKE_HIP_COMPILER_PREDEFINES_COMMAND" "Command that outputs the compiler pre definitions." nil)
    ("CMAKE_ISPC_COMPILER_PREDEFINES_COMMAND" "Command that outputs the compiler pre definitions." nil)
    ("CMAKE_OBJC_COMPILER_PREDEFINES_COMMAND" "Command that outputs the compiler pre definitions." nil)
    ("CMAKE_OBJCXX_COMPILER_PREDEFINES_COMMAND" "Command that outputs the compiler pre definitions." nil)
    ("CMAKE_Swift_COMPILER_PREDEFINES_COMMAND" "Command that outputs the compiler pre definitions." nil)
    ("CMAKE_ASM_COMPILER_RANLIB" "A wrapper around ``ranlib`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_ASM_ATT_COMPILER_RANLIB" "A wrapper around ``ranlib`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_ASM_MARMASM_COMPILER_RANLIB" "A wrapper around ``ranlib`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_ASM_MASM_COMPILER_RANLIB" "A wrapper around ``ranlib`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_ASM_NASM_COMPILER_RANLIB" "A wrapper around ``ranlib`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_C_COMPILER_RANLIB" "A wrapper around ``ranlib`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_CSharp_COMPILER_RANLIB" "A wrapper around ``ranlib`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_CUDA_COMPILER_RANLIB" "A wrapper around ``ranlib`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_CXX_COMPILER_RANLIB" "A wrapper around ``ranlib`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_Fortran_COMPILER_RANLIB" "A wrapper around ``ranlib`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_HIP_COMPILER_RANLIB" "A wrapper around ``ranlib`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_ISPC_COMPILER_RANLIB" "A wrapper around ``ranlib`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_OBJC_COMPILER_RANLIB" "A wrapper around ``ranlib`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_OBJCXX_COMPILER_RANLIB" "A wrapper around ``ranlib`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_Swift_COMPILER_RANLIB" "A wrapper around ``ranlib`` adding the appropriate ``--plugin`` option for the
compiler." nil)
    ("CMAKE_ASM_COMPILER_TARGET" "The target for cross-compiling, if supported." nil)
    ("CMAKE_ASM_ATT_COMPILER_TARGET" "The target for cross-compiling, if supported." nil)
    ("CMAKE_ASM_MARMASM_COMPILER_TARGET" "The target for cross-compiling, if supported." nil)
    ("CMAKE_ASM_MASM_COMPILER_TARGET" "The target for cross-compiling, if supported." nil)
    ("CMAKE_ASM_NASM_COMPILER_TARGET" "The target for cross-compiling, if supported." nil)
    ("CMAKE_C_COMPILER_TARGET" "The target for cross-compiling, if supported." nil)
    ("CMAKE_CSharp_COMPILER_TARGET" "The target for cross-compiling, if supported." nil)
    ("CMAKE_CUDA_COMPILER_TARGET" "The target for cross-compiling, if supported." nil)
    ("CMAKE_CXX_COMPILER_TARGET" "The target for cross-compiling, if supported." nil)
    ("CMAKE_Fortran_COMPILER_TARGET" "The target for cross-compiling, if supported." nil)
    ("CMAKE_HIP_COMPILER_TARGET" "The target for cross-compiling, if supported." nil)
    ("CMAKE_ISPC_COMPILER_TARGET" "The target for cross-compiling, if supported." nil)
    ("CMAKE_OBJC_COMPILER_TARGET" "The target for cross-compiling, if supported." nil)
    ("CMAKE_OBJCXX_COMPILER_TARGET" "The target for cross-compiling, if supported." nil)
    ("CMAKE_Swift_COMPILER_TARGET" "The target for cross-compiling, if supported." nil)
    ("CMAKE_ASM_COMPILER_VERSION" "Compiler version string." nil)
    ("CMAKE_ASM_ATT_COMPILER_VERSION" "Compiler version string." nil)
    ("CMAKE_ASM_MARMASM_COMPILER_VERSION" "Compiler version string." nil)
    ("CMAKE_ASM_MASM_COMPILER_VERSION" "Compiler version string." nil)
    ("CMAKE_ASM_NASM_COMPILER_VERSION" "Compiler version string." nil)
    ("CMAKE_C_COMPILER_VERSION" "Compiler version string." nil)
    ("CMAKE_CSharp_COMPILER_VERSION" "Compiler version string." nil)
    ("CMAKE_CUDA_COMPILER_VERSION" "Compiler version string." nil)
    ("CMAKE_CXX_COMPILER_VERSION" "Compiler version string." nil)
    ("CMAKE_Fortran_COMPILER_VERSION" "Compiler version string." nil)
    ("CMAKE_HIP_COMPILER_VERSION" "Compiler version string." nil)
    ("CMAKE_ISPC_COMPILER_VERSION" "Compiler version string." nil)
    ("CMAKE_OBJC_COMPILER_VERSION" "Compiler version string." nil)
    ("CMAKE_OBJCXX_COMPILER_VERSION" "Compiler version string." nil)
    ("CMAKE_Swift_COMPILER_VERSION" "Compiler version string." nil)
    ("CMAKE_ASM_COMPILER_VERSION_INTERNAL" "An internal variable subject to change." nil)
    ("CMAKE_ASM_ATT_COMPILER_VERSION_INTERNAL" "An internal variable subject to change." nil)
    ("CMAKE_ASM_MARMASM_COMPILER_VERSION_INTERNAL" "An internal variable subject to change." nil)
    ("CMAKE_ASM_MASM_COMPILER_VERSION_INTERNAL" "An internal variable subject to change." nil)
    ("CMAKE_ASM_NASM_COMPILER_VERSION_INTERNAL" "An internal variable subject to change." nil)
    ("CMAKE_C_COMPILER_VERSION_INTERNAL" "An internal variable subject to change." nil)
    ("CMAKE_CSharp_COMPILER_VERSION_INTERNAL" "An internal variable subject to change." nil)
    ("CMAKE_CUDA_COMPILER_VERSION_INTERNAL" "An internal variable subject to change." nil)
    ("CMAKE_CXX_COMPILER_VERSION_INTERNAL" "An internal variable subject to change." nil)
    ("CMAKE_Fortran_COMPILER_VERSION_INTERNAL" "An internal variable subject to change." nil)
    ("CMAKE_HIP_COMPILER_VERSION_INTERNAL" "An internal variable subject to change." nil)
    ("CMAKE_ISPC_COMPILER_VERSION_INTERNAL" "An internal variable subject to change." nil)
    ("CMAKE_OBJC_COMPILER_VERSION_INTERNAL" "An internal variable subject to change." nil)
    ("CMAKE_OBJCXX_COMPILER_VERSION_INTERNAL" "An internal variable subject to change." nil)
    ("CMAKE_Swift_COMPILER_VERSION_INTERNAL" "An internal variable subject to change." nil)
    ("CMAKE_ASM_COMPILE_OBJECT" "Rule variable to compile a single object file." nil)
    ("CMAKE_ASM_ATT_COMPILE_OBJECT" "Rule variable to compile a single object file." nil)
    ("CMAKE_ASM_MARMASM_COMPILE_OBJECT" "Rule variable to compile a single object file." nil)
    ("CMAKE_ASM_MASM_COMPILE_OBJECT" "Rule variable to compile a single object file." nil)
    ("CMAKE_ASM_NASM_COMPILE_OBJECT" "Rule variable to compile a single object file." nil)
    ("CMAKE_C_COMPILE_OBJECT" "Rule variable to compile a single object file." nil)
    ("CMAKE_CSharp_COMPILE_OBJECT" "Rule variable to compile a single object file." nil)
    ("CMAKE_CUDA_COMPILE_OBJECT" "Rule variable to compile a single object file." nil)
    ("CMAKE_CXX_COMPILE_OBJECT" "Rule variable to compile a single object file." nil)
    ("CMAKE_Fortran_COMPILE_OBJECT" "Rule variable to compile a single object file." nil)
    ("CMAKE_HIP_COMPILE_OBJECT" "Rule variable to compile a single object file." nil)
    ("CMAKE_ISPC_COMPILE_OBJECT" "Rule variable to compile a single object file." nil)
    ("CMAKE_OBJC_COMPILE_OBJECT" "Rule variable to compile a single object file." nil)
    ("CMAKE_OBJCXX_COMPILE_OBJECT" "Rule variable to compile a single object file." nil)
    ("CMAKE_Swift_COMPILE_OBJECT" "Rule variable to compile a single object file." nil)
    ("CMAKE_ASM_CPPCHECK" "Default value for :prop_tgt:`<LANG>_CPPCHECK` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ASM_ATT_CPPCHECK" "Default value for :prop_tgt:`<LANG>_CPPCHECK` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ASM_MARMASM_CPPCHECK" "Default value for :prop_tgt:`<LANG>_CPPCHECK` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ASM_MASM_CPPCHECK" "Default value for :prop_tgt:`<LANG>_CPPCHECK` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ASM_NASM_CPPCHECK" "Default value for :prop_tgt:`<LANG>_CPPCHECK` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_C_CPPCHECK" "Default value for :prop_tgt:`<LANG>_CPPCHECK` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_CSharp_CPPCHECK" "Default value for :prop_tgt:`<LANG>_CPPCHECK` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_CUDA_CPPCHECK" "Default value for :prop_tgt:`<LANG>_CPPCHECK` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_CXX_CPPCHECK" "Default value for :prop_tgt:`<LANG>_CPPCHECK` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_Fortran_CPPCHECK" "Default value for :prop_tgt:`<LANG>_CPPCHECK` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_HIP_CPPCHECK" "Default value for :prop_tgt:`<LANG>_CPPCHECK` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ISPC_CPPCHECK" "Default value for :prop_tgt:`<LANG>_CPPCHECK` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_OBJC_CPPCHECK" "Default value for :prop_tgt:`<LANG>_CPPCHECK` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_OBJCXX_CPPCHECK" "Default value for :prop_tgt:`<LANG>_CPPCHECK` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_Swift_CPPCHECK" "Default value for :prop_tgt:`<LANG>_CPPCHECK` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ASM_CPPLINT" "Default value for :prop_tgt:`<LANG>_CPPLINT` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ASM_ATT_CPPLINT" "Default value for :prop_tgt:`<LANG>_CPPLINT` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ASM_MARMASM_CPPLINT" "Default value for :prop_tgt:`<LANG>_CPPLINT` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ASM_MASM_CPPLINT" "Default value for :prop_tgt:`<LANG>_CPPLINT` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ASM_NASM_CPPLINT" "Default value for :prop_tgt:`<LANG>_CPPLINT` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_C_CPPLINT" "Default value for :prop_tgt:`<LANG>_CPPLINT` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_CSharp_CPPLINT" "Default value for :prop_tgt:`<LANG>_CPPLINT` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_CUDA_CPPLINT" "Default value for :prop_tgt:`<LANG>_CPPLINT` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_CXX_CPPLINT" "Default value for :prop_tgt:`<LANG>_CPPLINT` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_Fortran_CPPLINT" "Default value for :prop_tgt:`<LANG>_CPPLINT` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_HIP_CPPLINT" "Default value for :prop_tgt:`<LANG>_CPPLINT` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ISPC_CPPLINT" "Default value for :prop_tgt:`<LANG>_CPPLINT` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_OBJC_CPPLINT" "Default value for :prop_tgt:`<LANG>_CPPLINT` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_OBJCXX_CPPLINT" "Default value for :prop_tgt:`<LANG>_CPPLINT` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_Swift_CPPLINT" "Default value for :prop_tgt:`<LANG>_CPPLINT` target property. This variable
is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ASM_CREATE_SHARED_LIBRARY" "Rule variable to create a shared library." nil)
    ("CMAKE_ASM_ATT_CREATE_SHARED_LIBRARY" "Rule variable to create a shared library." nil)
    ("CMAKE_ASM_MARMASM_CREATE_SHARED_LIBRARY" "Rule variable to create a shared library." nil)
    ("CMAKE_ASM_MASM_CREATE_SHARED_LIBRARY" "Rule variable to create a shared library." nil)
    ("CMAKE_ASM_NASM_CREATE_SHARED_LIBRARY" "Rule variable to create a shared library." nil)
    ("CMAKE_C_CREATE_SHARED_LIBRARY" "Rule variable to create a shared library." nil)
    ("CMAKE_CSharp_CREATE_SHARED_LIBRARY" "Rule variable to create a shared library." nil)
    ("CMAKE_CUDA_CREATE_SHARED_LIBRARY" "Rule variable to create a shared library." nil)
    ("CMAKE_CXX_CREATE_SHARED_LIBRARY" "Rule variable to create a shared library." nil)
    ("CMAKE_Fortran_CREATE_SHARED_LIBRARY" "Rule variable to create a shared library." nil)
    ("CMAKE_HIP_CREATE_SHARED_LIBRARY" "Rule variable to create a shared library." nil)
    ("CMAKE_ISPC_CREATE_SHARED_LIBRARY" "Rule variable to create a shared library." nil)
    ("CMAKE_OBJC_CREATE_SHARED_LIBRARY" "Rule variable to create a shared library." nil)
    ("CMAKE_OBJCXX_CREATE_SHARED_LIBRARY" "Rule variable to create a shared library." nil)
    ("CMAKE_Swift_CREATE_SHARED_LIBRARY" "Rule variable to create a shared library." nil)
    ("CMAKE_ASM_CREATE_SHARED_LIBRARY_ARCHIVE" "Rule variable to create a shared library with archive." nil)
    ("CMAKE_ASM_ATT_CREATE_SHARED_LIBRARY_ARCHIVE" "Rule variable to create a shared library with archive." nil)
    ("CMAKE_ASM_MARMASM_CREATE_SHARED_LIBRARY_ARCHIVE" "Rule variable to create a shared library with archive." nil)
    ("CMAKE_ASM_MASM_CREATE_SHARED_LIBRARY_ARCHIVE" "Rule variable to create a shared library with archive." nil)
    ("CMAKE_ASM_NASM_CREATE_SHARED_LIBRARY_ARCHIVE" "Rule variable to create a shared library with archive." nil)
    ("CMAKE_C_CREATE_SHARED_LIBRARY_ARCHIVE" "Rule variable to create a shared library with archive." nil)
    ("CMAKE_CSharp_CREATE_SHARED_LIBRARY_ARCHIVE" "Rule variable to create a shared library with archive." nil)
    ("CMAKE_CUDA_CREATE_SHARED_LIBRARY_ARCHIVE" "Rule variable to create a shared library with archive." nil)
    ("CMAKE_CXX_CREATE_SHARED_LIBRARY_ARCHIVE" "Rule variable to create a shared library with archive." nil)
    ("CMAKE_Fortran_CREATE_SHARED_LIBRARY_ARCHIVE" "Rule variable to create a shared library with archive." nil)
    ("CMAKE_HIP_CREATE_SHARED_LIBRARY_ARCHIVE" "Rule variable to create a shared library with archive." nil)
    ("CMAKE_ISPC_CREATE_SHARED_LIBRARY_ARCHIVE" "Rule variable to create a shared library with archive." nil)
    ("CMAKE_OBJC_CREATE_SHARED_LIBRARY_ARCHIVE" "Rule variable to create a shared library with archive." nil)
    ("CMAKE_OBJCXX_CREATE_SHARED_LIBRARY_ARCHIVE" "Rule variable to create a shared library with archive." nil)
    ("CMAKE_Swift_CREATE_SHARED_LIBRARY_ARCHIVE" "Rule variable to create a shared library with archive." nil)
    ("CMAKE_ASM_CREATE_SHARED_MODULE" "Rule variable to create a shared module." nil)
    ("CMAKE_ASM_ATT_CREATE_SHARED_MODULE" "Rule variable to create a shared module." nil)
    ("CMAKE_ASM_MARMASM_CREATE_SHARED_MODULE" "Rule variable to create a shared module." nil)
    ("CMAKE_ASM_MASM_CREATE_SHARED_MODULE" "Rule variable to create a shared module." nil)
    ("CMAKE_ASM_NASM_CREATE_SHARED_MODULE" "Rule variable to create a shared module." nil)
    ("CMAKE_C_CREATE_SHARED_MODULE" "Rule variable to create a shared module." nil)
    ("CMAKE_CSharp_CREATE_SHARED_MODULE" "Rule variable to create a shared module." nil)
    ("CMAKE_CUDA_CREATE_SHARED_MODULE" "Rule variable to create a shared module." nil)
    ("CMAKE_CXX_CREATE_SHARED_MODULE" "Rule variable to create a shared module." nil)
    ("CMAKE_Fortran_CREATE_SHARED_MODULE" "Rule variable to create a shared module." nil)
    ("CMAKE_HIP_CREATE_SHARED_MODULE" "Rule variable to create a shared module." nil)
    ("CMAKE_ISPC_CREATE_SHARED_MODULE" "Rule variable to create a shared module." nil)
    ("CMAKE_OBJC_CREATE_SHARED_MODULE" "Rule variable to create a shared module." nil)
    ("CMAKE_OBJCXX_CREATE_SHARED_MODULE" "Rule variable to create a shared module." nil)
    ("CMAKE_Swift_CREATE_SHARED_MODULE" "Rule variable to create a shared module." nil)
    ("CMAKE_ASM_CREATE_STATIC_LIBRARY" "Rule variable to create a static library." nil)
    ("CMAKE_ASM_ATT_CREATE_STATIC_LIBRARY" "Rule variable to create a static library." nil)
    ("CMAKE_ASM_MARMASM_CREATE_STATIC_LIBRARY" "Rule variable to create a static library." nil)
    ("CMAKE_ASM_MASM_CREATE_STATIC_LIBRARY" "Rule variable to create a static library." nil)
    ("CMAKE_ASM_NASM_CREATE_STATIC_LIBRARY" "Rule variable to create a static library." nil)
    ("CMAKE_C_CREATE_STATIC_LIBRARY" "Rule variable to create a static library." nil)
    ("CMAKE_CSharp_CREATE_STATIC_LIBRARY" "Rule variable to create a static library." nil)
    ("CMAKE_CUDA_CREATE_STATIC_LIBRARY" "Rule variable to create a static library." nil)
    ("CMAKE_CXX_CREATE_STATIC_LIBRARY" "Rule variable to create a static library." nil)
    ("CMAKE_Fortran_CREATE_STATIC_LIBRARY" "Rule variable to create a static library." nil)
    ("CMAKE_HIP_CREATE_STATIC_LIBRARY" "Rule variable to create a static library." nil)
    ("CMAKE_ISPC_CREATE_STATIC_LIBRARY" "Rule variable to create a static library." nil)
    ("CMAKE_OBJC_CREATE_STATIC_LIBRARY" "Rule variable to create a static library." nil)
    ("CMAKE_OBJCXX_CREATE_STATIC_LIBRARY" "Rule variable to create a static library." nil)
    ("CMAKE_Swift_CREATE_STATIC_LIBRARY" "Rule variable to create a static library." nil)
    ("CMAKE_ASM_DEVICE_LINK_MODE" "Defines how the device link step is done. The possible values are:" nil)
    ("CMAKE_ASM_ATT_DEVICE_LINK_MODE" "Defines how the device link step is done. The possible values are:" nil)
    ("CMAKE_ASM_MARMASM_DEVICE_LINK_MODE" "Defines how the device link step is done. The possible values are:" nil)
    ("CMAKE_ASM_MASM_DEVICE_LINK_MODE" "Defines how the device link step is done. The possible values are:" nil)
    ("CMAKE_ASM_NASM_DEVICE_LINK_MODE" "Defines how the device link step is done. The possible values are:" nil)
    ("CMAKE_C_DEVICE_LINK_MODE" "Defines how the device link step is done. The possible values are:" nil)
    ("CMAKE_CSharp_DEVICE_LINK_MODE" "Defines how the device link step is done. The possible values are:" nil)
    ("CMAKE_CUDA_DEVICE_LINK_MODE" "Defines how the device link step is done. The possible values are:" nil)
    ("CMAKE_CXX_DEVICE_LINK_MODE" "Defines how the device link step is done. The possible values are:" nil)
    ("CMAKE_Fortran_DEVICE_LINK_MODE" "Defines how the device link step is done. The possible values are:" nil)
    ("CMAKE_HIP_DEVICE_LINK_MODE" "Defines how the device link step is done. The possible values are:" nil)
    ("CMAKE_ISPC_DEVICE_LINK_MODE" "Defines how the device link step is done. The possible values are:" nil)
    ("CMAKE_OBJC_DEVICE_LINK_MODE" "Defines how the device link step is done. The possible values are:" nil)
    ("CMAKE_OBJCXX_DEVICE_LINK_MODE" "Defines how the device link step is done. The possible values are:" nil)
    ("CMAKE_Swift_DEVICE_LINK_MODE" "Defines how the device link step is done. The possible values are:" nil)
    ("CMAKE_ASM_EXTENSIONS" "The variations are:" nil)
    ("CMAKE_ASM_ATT_EXTENSIONS" "The variations are:" nil)
    ("CMAKE_ASM_MARMASM_EXTENSIONS" "The variations are:" nil)
    ("CMAKE_ASM_MASM_EXTENSIONS" "The variations are:" nil)
    ("CMAKE_ASM_NASM_EXTENSIONS" "The variations are:" nil)
    ("CMAKE_C_EXTENSIONS" "The variations are:" nil)
    ("CMAKE_CSharp_EXTENSIONS" "The variations are:" nil)
    ("CMAKE_CUDA_EXTENSIONS" "The variations are:" nil)
    ("CMAKE_CXX_EXTENSIONS" "The variations are:" nil)
    ("CMAKE_Fortran_EXTENSIONS" "The variations are:" nil)
    ("CMAKE_HIP_EXTENSIONS" "The variations are:" nil)
    ("CMAKE_ISPC_EXTENSIONS" "The variations are:" nil)
    ("CMAKE_OBJC_EXTENSIONS" "The variations are:" nil)
    ("CMAKE_OBJCXX_EXTENSIONS" "The variations are:" nil)
    ("CMAKE_Swift_EXTENSIONS" "The variations are:" nil)
    ("CMAKE_ASM_EXTENSIONS_DEFAULT" "Compiler's default extensions mode. Used as the default for the
:prop_tgt:`<LANG>_EXTENSIONS` target property when
:variable:`CMAKE_<LANG>_EXTENSIONS` is not set (see :policy:`CMP0128`)." nil)
    ("CMAKE_ASM_ATT_EXTENSIONS_DEFAULT" "Compiler's default extensions mode. Used as the default for the
:prop_tgt:`<LANG>_EXTENSIONS` target property when
:variable:`CMAKE_<LANG>_EXTENSIONS` is not set (see :policy:`CMP0128`)." nil)
    ("CMAKE_ASM_MARMASM_EXTENSIONS_DEFAULT" "Compiler's default extensions mode. Used as the default for the
:prop_tgt:`<LANG>_EXTENSIONS` target property when
:variable:`CMAKE_<LANG>_EXTENSIONS` is not set (see :policy:`CMP0128`)." nil)
    ("CMAKE_ASM_MASM_EXTENSIONS_DEFAULT" "Compiler's default extensions mode. Used as the default for the
:prop_tgt:`<LANG>_EXTENSIONS` target property when
:variable:`CMAKE_<LANG>_EXTENSIONS` is not set (see :policy:`CMP0128`)." nil)
    ("CMAKE_ASM_NASM_EXTENSIONS_DEFAULT" "Compiler's default extensions mode. Used as the default for the
:prop_tgt:`<LANG>_EXTENSIONS` target property when
:variable:`CMAKE_<LANG>_EXTENSIONS` is not set (see :policy:`CMP0128`)." nil)
    ("CMAKE_C_EXTENSIONS_DEFAULT" "Compiler's default extensions mode. Used as the default for the
:prop_tgt:`<LANG>_EXTENSIONS` target property when
:variable:`CMAKE_<LANG>_EXTENSIONS` is not set (see :policy:`CMP0128`)." nil)
    ("CMAKE_CSharp_EXTENSIONS_DEFAULT" "Compiler's default extensions mode. Used as the default for the
:prop_tgt:`<LANG>_EXTENSIONS` target property when
:variable:`CMAKE_<LANG>_EXTENSIONS` is not set (see :policy:`CMP0128`)." nil)
    ("CMAKE_CUDA_EXTENSIONS_DEFAULT" "Compiler's default extensions mode. Used as the default for the
:prop_tgt:`<LANG>_EXTENSIONS` target property when
:variable:`CMAKE_<LANG>_EXTENSIONS` is not set (see :policy:`CMP0128`)." nil)
    ("CMAKE_CXX_EXTENSIONS_DEFAULT" "Compiler's default extensions mode. Used as the default for the
:prop_tgt:`<LANG>_EXTENSIONS` target property when
:variable:`CMAKE_<LANG>_EXTENSIONS` is not set (see :policy:`CMP0128`)." nil)
    ("CMAKE_Fortran_EXTENSIONS_DEFAULT" "Compiler's default extensions mode. Used as the default for the
:prop_tgt:`<LANG>_EXTENSIONS` target property when
:variable:`CMAKE_<LANG>_EXTENSIONS` is not set (see :policy:`CMP0128`)." nil)
    ("CMAKE_HIP_EXTENSIONS_DEFAULT" "Compiler's default extensions mode. Used as the default for the
:prop_tgt:`<LANG>_EXTENSIONS` target property when
:variable:`CMAKE_<LANG>_EXTENSIONS` is not set (see :policy:`CMP0128`)." nil)
    ("CMAKE_ISPC_EXTENSIONS_DEFAULT" "Compiler's default extensions mode. Used as the default for the
:prop_tgt:`<LANG>_EXTENSIONS` target property when
:variable:`CMAKE_<LANG>_EXTENSIONS` is not set (see :policy:`CMP0128`)." nil)
    ("CMAKE_OBJC_EXTENSIONS_DEFAULT" "Compiler's default extensions mode. Used as the default for the
:prop_tgt:`<LANG>_EXTENSIONS` target property when
:variable:`CMAKE_<LANG>_EXTENSIONS` is not set (see :policy:`CMP0128`)." nil)
    ("CMAKE_OBJCXX_EXTENSIONS_DEFAULT" "Compiler's default extensions mode. Used as the default for the
:prop_tgt:`<LANG>_EXTENSIONS` target property when
:variable:`CMAKE_<LANG>_EXTENSIONS` is not set (see :policy:`CMP0128`)." nil)
    ("CMAKE_Swift_EXTENSIONS_DEFAULT" "Compiler's default extensions mode. Used as the default for the
:prop_tgt:`<LANG>_EXTENSIONS` target property when
:variable:`CMAKE_<LANG>_EXTENSIONS` is not set (see :policy:`CMP0128`)." nil)
    ("CMAKE_ASM_FLAGS" "Language-wide flags for language ``<LANG>`` used when building for
all configurations." nil)
    ("CMAKE_ASM_ATT_FLAGS" "Language-wide flags for language ``<LANG>`` used when building for
all configurations." nil)
    ("CMAKE_ASM_MARMASM_FLAGS" "Language-wide flags for language ``<LANG>`` used when building for
all configurations." nil)
    ("CMAKE_ASM_MASM_FLAGS" "Language-wide flags for language ``<LANG>`` used when building for
all configurations." nil)
    ("CMAKE_ASM_NASM_FLAGS" "Language-wide flags for language ``<LANG>`` used when building for
all configurations." nil)
    ("CMAKE_C_FLAGS" "Language-wide flags for language ``<LANG>`` used when building for
all configurations." nil)
    ("CMAKE_CSharp_FLAGS" "Language-wide flags for language ``<LANG>`` used when building for
all configurations." nil)
    ("CMAKE_CUDA_FLAGS" "Language-wide flags for language ``<LANG>`` used when building for
all configurations." nil)
    ("CMAKE_CXX_FLAGS" "Language-wide flags for language ``<LANG>`` used when building for
all configurations." nil)
    ("CMAKE_Fortran_FLAGS" "Language-wide flags for language ``<LANG>`` used when building for
all configurations." nil)
    ("CMAKE_HIP_FLAGS" "Language-wide flags for language ``<LANG>`` used when building for
all configurations." nil)
    ("CMAKE_ISPC_FLAGS" "Language-wide flags for language ``<LANG>`` used when building for
all configurations." nil)
    ("CMAKE_OBJC_FLAGS" "Language-wide flags for language ``<LANG>`` used when building for
all configurations." nil)
    ("CMAKE_OBJCXX_FLAGS" "Language-wide flags for language ``<LANG>`` used when building for
all configurations." nil)
    ("CMAKE_Swift_FLAGS" "Language-wide flags for language ``<LANG>`` used when building for
all configurations." nil)
    ("CMAKE_ASM_FLAGS_CONFIG" "Language-wide flags for language ``<LANG>`` used when building for
the ``<CONFIG>`` configuration." nil)
    ("CMAKE_ASM_ATT_FLAGS_CONFIG" "Language-wide flags for language ``<LANG>`` used when building for
the ``<CONFIG>`` configuration." nil)
    ("CMAKE_ASM_MARMASM_FLAGS_CONFIG" "Language-wide flags for language ``<LANG>`` used when building for
the ``<CONFIG>`` configuration." nil)
    ("CMAKE_ASM_MASM_FLAGS_CONFIG" "Language-wide flags for language ``<LANG>`` used when building for
the ``<CONFIG>`` configuration." nil)
    ("CMAKE_ASM_NASM_FLAGS_CONFIG" "Language-wide flags for language ``<LANG>`` used when building for
the ``<CONFIG>`` configuration." nil)
    ("CMAKE_C_FLAGS_CONFIG" "Language-wide flags for language ``<LANG>`` used when building for
the ``<CONFIG>`` configuration." nil)
    ("CMAKE_CSharp_FLAGS_CONFIG" "Language-wide flags for language ``<LANG>`` used when building for
the ``<CONFIG>`` configuration." nil)
    ("CMAKE_CUDA_FLAGS_CONFIG" "Language-wide flags for language ``<LANG>`` used when building for
the ``<CONFIG>`` configuration." nil)
    ("CMAKE_CXX_FLAGS_CONFIG" "Language-wide flags for language ``<LANG>`` used when building for
the ``<CONFIG>`` configuration." nil)
    ("CMAKE_Fortran_FLAGS_CONFIG" "Language-wide flags for language ``<LANG>`` used when building for
the ``<CONFIG>`` configuration." nil)
    ("CMAKE_HIP_FLAGS_CONFIG" "Language-wide flags for language ``<LANG>`` used when building for
the ``<CONFIG>`` configuration." nil)
    ("CMAKE_ISPC_FLAGS_CONFIG" "Language-wide flags for language ``<LANG>`` used when building for
the ``<CONFIG>`` configuration." nil)
    ("CMAKE_OBJC_FLAGS_CONFIG" "Language-wide flags for language ``<LANG>`` used when building for
the ``<CONFIG>`` configuration." nil)
    ("CMAKE_OBJCXX_FLAGS_CONFIG" "Language-wide flags for language ``<LANG>`` used when building for
the ``<CONFIG>`` configuration." nil)
    ("CMAKE_Swift_FLAGS_CONFIG" "Language-wide flags for language ``<LANG>`` used when building for
the ``<CONFIG>`` configuration." nil)
    ("CMAKE_ASM_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` cache
entry the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_ASM_ATT_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` cache
entry the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_ASM_MARMASM_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` cache
entry the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_ASM_MASM_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` cache
entry the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_ASM_NASM_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` cache
entry the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_C_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` cache
entry the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_CSharp_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` cache
entry the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_CUDA_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` cache
entry the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_CXX_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` cache
entry the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_Fortran_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` cache
entry the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_HIP_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` cache
entry the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_ISPC_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` cache
entry the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_OBJC_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` cache
entry the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_OBJCXX_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` cache
entry the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_Swift_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` cache
entry the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_ASM_FLAGS_DEBUG" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_ATT_FLAGS_DEBUG" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_MARMASM_FLAGS_DEBUG" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_MASM_FLAGS_DEBUG" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_NASM_FLAGS_DEBUG" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_C_FLAGS_DEBUG" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_CSharp_FLAGS_DEBUG" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_CUDA_FLAGS_DEBUG" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_CXX_FLAGS_DEBUG" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_Fortran_FLAGS_DEBUG" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_HIP_FLAGS_DEBUG" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ISPC_FLAGS_DEBUG" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_OBJC_FLAGS_DEBUG" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_OBJCXX_FLAGS_DEBUG" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_Swift_FLAGS_DEBUG" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_FLAGS_DEBUG_INIT" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_ATT_FLAGS_DEBUG_INIT" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_MARMASM_FLAGS_DEBUG_INIT" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_MASM_FLAGS_DEBUG_INIT" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_NASM_FLAGS_DEBUG_INIT" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_C_FLAGS_DEBUG_INIT" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_CSharp_FLAGS_DEBUG_INIT" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_CUDA_FLAGS_DEBUG_INIT" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_CXX_FLAGS_DEBUG_INIT" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_Fortran_FLAGS_DEBUG_INIT" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_HIP_FLAGS_DEBUG_INIT" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ISPC_FLAGS_DEBUG_INIT" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_OBJC_FLAGS_DEBUG_INIT" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_OBJCXX_FLAGS_DEBUG_INIT" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_Swift_FLAGS_DEBUG_INIT" "This variable is the ``Debug`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS` cache entry
the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_ASM_ATT_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS` cache entry
the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_ASM_MARMASM_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS` cache entry
the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_ASM_MASM_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS` cache entry
the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_ASM_NASM_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS` cache entry
the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_C_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS` cache entry
the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_CSharp_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS` cache entry
the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_CUDA_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS` cache entry
the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_CXX_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS` cache entry
the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_Fortran_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS` cache entry
the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_HIP_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS` cache entry
the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_ISPC_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS` cache entry
the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_OBJC_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS` cache entry
the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_OBJCXX_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS` cache entry
the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_Swift_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_<LANG>_FLAGS` cache entry
the first time a build tree is configured for language ``<LANG>``." nil)
    ("CMAKE_ASM_FLAGS_MINSIZEREL" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_ATT_FLAGS_MINSIZEREL" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_MARMASM_FLAGS_MINSIZEREL" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_MASM_FLAGS_MINSIZEREL" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_NASM_FLAGS_MINSIZEREL" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_C_FLAGS_MINSIZEREL" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_CSharp_FLAGS_MINSIZEREL" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_CUDA_FLAGS_MINSIZEREL" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_CXX_FLAGS_MINSIZEREL" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_Fortran_FLAGS_MINSIZEREL" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_HIP_FLAGS_MINSIZEREL" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ISPC_FLAGS_MINSIZEREL" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_OBJC_FLAGS_MINSIZEREL" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_OBJCXX_FLAGS_MINSIZEREL" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_Swift_FLAGS_MINSIZEREL" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_FLAGS_MINSIZEREL_INIT" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_ATT_FLAGS_MINSIZEREL_INIT" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_MARMASM_FLAGS_MINSIZEREL_INIT" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_MASM_FLAGS_MINSIZEREL_INIT" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_NASM_FLAGS_MINSIZEREL_INIT" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_C_FLAGS_MINSIZEREL_INIT" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_CSharp_FLAGS_MINSIZEREL_INIT" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_CUDA_FLAGS_MINSIZEREL_INIT" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_CXX_FLAGS_MINSIZEREL_INIT" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_Fortran_FLAGS_MINSIZEREL_INIT" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_HIP_FLAGS_MINSIZEREL_INIT" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ISPC_FLAGS_MINSIZEREL_INIT" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_OBJC_FLAGS_MINSIZEREL_INIT" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_OBJCXX_FLAGS_MINSIZEREL_INIT" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_Swift_FLAGS_MINSIZEREL_INIT" "This variable is the ``MinSizeRel`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_FLAGS_RELEASE" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_ATT_FLAGS_RELEASE" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_MARMASM_FLAGS_RELEASE" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_MASM_FLAGS_RELEASE" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_NASM_FLAGS_RELEASE" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_C_FLAGS_RELEASE" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_CSharp_FLAGS_RELEASE" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_CUDA_FLAGS_RELEASE" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_CXX_FLAGS_RELEASE" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_Fortran_FLAGS_RELEASE" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_HIP_FLAGS_RELEASE" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ISPC_FLAGS_RELEASE" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_OBJC_FLAGS_RELEASE" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_OBJCXX_FLAGS_RELEASE" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_Swift_FLAGS_RELEASE" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_FLAGS_RELEASE_INIT" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_ATT_FLAGS_RELEASE_INIT" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_MARMASM_FLAGS_RELEASE_INIT" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_MASM_FLAGS_RELEASE_INIT" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_NASM_FLAGS_RELEASE_INIT" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_C_FLAGS_RELEASE_INIT" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_CSharp_FLAGS_RELEASE_INIT" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_CUDA_FLAGS_RELEASE_INIT" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_CXX_FLAGS_RELEASE_INIT" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_Fortran_FLAGS_RELEASE_INIT" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_HIP_FLAGS_RELEASE_INIT" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ISPC_FLAGS_RELEASE_INIT" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_OBJC_FLAGS_RELEASE_INIT" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_OBJCXX_FLAGS_RELEASE_INIT" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_Swift_FLAGS_RELEASE_INIT" "This variable is the ``Release`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_FLAGS_RELWITHDEBINFO" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_ATT_FLAGS_RELWITHDEBINFO" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_MARMASM_FLAGS_RELWITHDEBINFO" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_MASM_FLAGS_RELWITHDEBINFO" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_NASM_FLAGS_RELWITHDEBINFO" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_C_FLAGS_RELWITHDEBINFO" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_CSharp_FLAGS_RELWITHDEBINFO" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_CUDA_FLAGS_RELWITHDEBINFO" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_CXX_FLAGS_RELWITHDEBINFO" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_Fortran_FLAGS_RELWITHDEBINFO" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_HIP_FLAGS_RELWITHDEBINFO" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ISPC_FLAGS_RELWITHDEBINFO" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_OBJC_FLAGS_RELWITHDEBINFO" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_OBJCXX_FLAGS_RELWITHDEBINFO" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_Swift_FLAGS_RELWITHDEBINFO" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>` variable." nil)
    ("CMAKE_ASM_FLAGS_RELWITHDEBINFO_INIT" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_ATT_FLAGS_RELWITHDEBINFO_INIT" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_MARMASM_FLAGS_RELWITHDEBINFO_INIT" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_MASM_FLAGS_RELWITHDEBINFO_INIT" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_NASM_FLAGS_RELWITHDEBINFO_INIT" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_C_FLAGS_RELWITHDEBINFO_INIT" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_CSharp_FLAGS_RELWITHDEBINFO_INIT" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_CUDA_FLAGS_RELWITHDEBINFO_INIT" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_CXX_FLAGS_RELWITHDEBINFO_INIT" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_Fortran_FLAGS_RELWITHDEBINFO_INIT" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_HIP_FLAGS_RELWITHDEBINFO_INIT" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ISPC_FLAGS_RELWITHDEBINFO_INIT" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_OBJC_FLAGS_RELWITHDEBINFO_INIT" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_OBJCXX_FLAGS_RELWITHDEBINFO_INIT" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_Swift_FLAGS_RELWITHDEBINFO_INIT" "This variable is the ``RelWithDebInfo`` variant of the
:variable:`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT` variable." nil)
    ("CMAKE_ASM_HOST_COMPILER" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``." "  Since ``CMAKE_<LANG>_HOST_COMPILER`` is meaningful only when the
  :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``,
  it does not make sense to set ``CMAKE_<LANG>_HOST_COMPILER`` without also
  setting ``CMAKE_<LANG>_COMPILER`` to NVCC.")
    ("CMAKE_ASM_ATT_HOST_COMPILER" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``." "  Since ``CMAKE_<LANG>_HOST_COMPILER`` is meaningful only when the
  :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``,
  it does not make sense to set ``CMAKE_<LANG>_HOST_COMPILER`` without also
  setting ``CMAKE_<LANG>_COMPILER`` to NVCC.")
    ("CMAKE_ASM_MARMASM_HOST_COMPILER" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``." "  Since ``CMAKE_<LANG>_HOST_COMPILER`` is meaningful only when the
  :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``,
  it does not make sense to set ``CMAKE_<LANG>_HOST_COMPILER`` without also
  setting ``CMAKE_<LANG>_COMPILER`` to NVCC.")
    ("CMAKE_ASM_MASM_HOST_COMPILER" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``." "  Since ``CMAKE_<LANG>_HOST_COMPILER`` is meaningful only when the
  :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``,
  it does not make sense to set ``CMAKE_<LANG>_HOST_COMPILER`` without also
  setting ``CMAKE_<LANG>_COMPILER`` to NVCC.")
    ("CMAKE_ASM_NASM_HOST_COMPILER" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``." "  Since ``CMAKE_<LANG>_HOST_COMPILER`` is meaningful only when the
  :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``,
  it does not make sense to set ``CMAKE_<LANG>_HOST_COMPILER`` without also
  setting ``CMAKE_<LANG>_COMPILER`` to NVCC.")
    ("CMAKE_C_HOST_COMPILER" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``." "  Since ``CMAKE_<LANG>_HOST_COMPILER`` is meaningful only when the
  :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``,
  it does not make sense to set ``CMAKE_<LANG>_HOST_COMPILER`` without also
  setting ``CMAKE_<LANG>_COMPILER`` to NVCC.")
    ("CMAKE_CSharp_HOST_COMPILER" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``." "  Since ``CMAKE_<LANG>_HOST_COMPILER`` is meaningful only when the
  :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``,
  it does not make sense to set ``CMAKE_<LANG>_HOST_COMPILER`` without also
  setting ``CMAKE_<LANG>_COMPILER`` to NVCC.")
    ("CMAKE_CUDA_HOST_COMPILER" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``." "  Since ``CMAKE_<LANG>_HOST_COMPILER`` is meaningful only when the
  :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``,
  it does not make sense to set ``CMAKE_<LANG>_HOST_COMPILER`` without also
  setting ``CMAKE_<LANG>_COMPILER`` to NVCC.")
    ("CMAKE_CXX_HOST_COMPILER" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``." "  Since ``CMAKE_<LANG>_HOST_COMPILER`` is meaningful only when the
  :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``,
  it does not make sense to set ``CMAKE_<LANG>_HOST_COMPILER`` without also
  setting ``CMAKE_<LANG>_COMPILER`` to NVCC.")
    ("CMAKE_Fortran_HOST_COMPILER" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``." "  Since ``CMAKE_<LANG>_HOST_COMPILER`` is meaningful only when the
  :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``,
  it does not make sense to set ``CMAKE_<LANG>_HOST_COMPILER`` without also
  setting ``CMAKE_<LANG>_COMPILER`` to NVCC.")
    ("CMAKE_HIP_HOST_COMPILER" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``." "  Since ``CMAKE_<LANG>_HOST_COMPILER`` is meaningful only when the
  :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``,
  it does not make sense to set ``CMAKE_<LANG>_HOST_COMPILER`` without also
  setting ``CMAKE_<LANG>_COMPILER`` to NVCC.")
    ("CMAKE_ISPC_HOST_COMPILER" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``." "  Since ``CMAKE_<LANG>_HOST_COMPILER`` is meaningful only when the
  :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``,
  it does not make sense to set ``CMAKE_<LANG>_HOST_COMPILER`` without also
  setting ``CMAKE_<LANG>_COMPILER`` to NVCC.")
    ("CMAKE_OBJC_HOST_COMPILER" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``." "  Since ``CMAKE_<LANG>_HOST_COMPILER`` is meaningful only when the
  :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``,
  it does not make sense to set ``CMAKE_<LANG>_HOST_COMPILER`` without also
  setting ``CMAKE_<LANG>_COMPILER`` to NVCC.")
    ("CMAKE_OBJCXX_HOST_COMPILER" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``." "  Since ``CMAKE_<LANG>_HOST_COMPILER`` is meaningful only when the
  :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``,
  it does not make sense to set ``CMAKE_<LANG>_HOST_COMPILER`` without also
  setting ``CMAKE_<LANG>_COMPILER`` to NVCC.")
    ("CMAKE_Swift_HOST_COMPILER" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``." "  Since ``CMAKE_<LANG>_HOST_COMPILER`` is meaningful only when the
  :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``,
  it does not make sense to set ``CMAKE_<LANG>_HOST_COMPILER`` without also
  setting ``CMAKE_<LANG>_COMPILER`` to NVCC.")
    ("CMAKE_ASM_HOST_COMPILER_ID" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_ASM_ATT_HOST_COMPILER_ID" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_ASM_MARMASM_HOST_COMPILER_ID" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_ASM_MASM_HOST_COMPILER_ID" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_ASM_NASM_HOST_COMPILER_ID" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_C_HOST_COMPILER_ID" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_CSharp_HOST_COMPILER_ID" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_CUDA_HOST_COMPILER_ID" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_CXX_HOST_COMPILER_ID" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_Fortran_HOST_COMPILER_ID" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_HIP_HOST_COMPILER_ID" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_ISPC_HOST_COMPILER_ID" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_OBJC_HOST_COMPILER_ID" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_OBJCXX_HOST_COMPILER_ID" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_Swift_HOST_COMPILER_ID" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_ASM_HOST_COMPILER_VERSION" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_ASM_ATT_HOST_COMPILER_VERSION" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_ASM_MARMASM_HOST_COMPILER_VERSION" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_ASM_MASM_HOST_COMPILER_VERSION" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_ASM_NASM_HOST_COMPILER_VERSION" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_C_HOST_COMPILER_VERSION" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_CSharp_HOST_COMPILER_VERSION" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_CUDA_HOST_COMPILER_VERSION" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_CXX_HOST_COMPILER_VERSION" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_Fortran_HOST_COMPILER_VERSION" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_HIP_HOST_COMPILER_VERSION" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_ISPC_HOST_COMPILER_VERSION" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_OBJC_HOST_COMPILER_VERSION" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_OBJCXX_HOST_COMPILER_VERSION" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_Swift_HOST_COMPILER_VERSION" "This variable is available when ``<LANG>`` is ``CUDA`` or ``HIP``
and :variable:`CMAKE_<LANG>_COMPILER_ID` is ``NVIDIA``." nil)
    ("CMAKE_ASM_IGNORE_EXTENSIONS" "File extensions that should be ignored by the build." nil)
    ("CMAKE_ASM_ATT_IGNORE_EXTENSIONS" "File extensions that should be ignored by the build." nil)
    ("CMAKE_ASM_MARMASM_IGNORE_EXTENSIONS" "File extensions that should be ignored by the build." nil)
    ("CMAKE_ASM_MASM_IGNORE_EXTENSIONS" "File extensions that should be ignored by the build." nil)
    ("CMAKE_ASM_NASM_IGNORE_EXTENSIONS" "File extensions that should be ignored by the build." nil)
    ("CMAKE_C_IGNORE_EXTENSIONS" "File extensions that should be ignored by the build." nil)
    ("CMAKE_CSharp_IGNORE_EXTENSIONS" "File extensions that should be ignored by the build." nil)
    ("CMAKE_CUDA_IGNORE_EXTENSIONS" "File extensions that should be ignored by the build." nil)
    ("CMAKE_CXX_IGNORE_EXTENSIONS" "File extensions that should be ignored by the build." nil)
    ("CMAKE_Fortran_IGNORE_EXTENSIONS" "File extensions that should be ignored by the build." nil)
    ("CMAKE_HIP_IGNORE_EXTENSIONS" "File extensions that should be ignored by the build." nil)
    ("CMAKE_ISPC_IGNORE_EXTENSIONS" "File extensions that should be ignored by the build." nil)
    ("CMAKE_OBJC_IGNORE_EXTENSIONS" "File extensions that should be ignored by the build." nil)
    ("CMAKE_OBJCXX_IGNORE_EXTENSIONS" "File extensions that should be ignored by the build." nil)
    ("CMAKE_Swift_IGNORE_EXTENSIONS" "File extensions that should be ignored by the build." nil)
    ("CMAKE_ASM_IMPLICIT_INCLUDE_DIRECTORIES" "Directories implicitly searched by the compiler for header files." nil)
    ("CMAKE_ASM_ATT_IMPLICIT_INCLUDE_DIRECTORIES" "Directories implicitly searched by the compiler for header files." nil)
    ("CMAKE_ASM_MARMASM_IMPLICIT_INCLUDE_DIRECTORIES" "Directories implicitly searched by the compiler for header files." nil)
    ("CMAKE_ASM_MASM_IMPLICIT_INCLUDE_DIRECTORIES" "Directories implicitly searched by the compiler for header files." nil)
    ("CMAKE_ASM_NASM_IMPLICIT_INCLUDE_DIRECTORIES" "Directories implicitly searched by the compiler for header files." nil)
    ("CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES" "Directories implicitly searched by the compiler for header files." nil)
    ("CMAKE_CSharp_IMPLICIT_INCLUDE_DIRECTORIES" "Directories implicitly searched by the compiler for header files." nil)
    ("CMAKE_CUDA_IMPLICIT_INCLUDE_DIRECTORIES" "Directories implicitly searched by the compiler for header files." nil)
    ("CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES" "Directories implicitly searched by the compiler for header files." nil)
    ("CMAKE_Fortran_IMPLICIT_INCLUDE_DIRECTORIES" "Directories implicitly searched by the compiler for header files." nil)
    ("CMAKE_HIP_IMPLICIT_INCLUDE_DIRECTORIES" "Directories implicitly searched by the compiler for header files." nil)
    ("CMAKE_ISPC_IMPLICIT_INCLUDE_DIRECTORIES" "Directories implicitly searched by the compiler for header files." nil)
    ("CMAKE_OBJC_IMPLICIT_INCLUDE_DIRECTORIES" "Directories implicitly searched by the compiler for header files." nil)
    ("CMAKE_OBJCXX_IMPLICIT_INCLUDE_DIRECTORIES" "Directories implicitly searched by the compiler for header files." nil)
    ("CMAKE_Swift_IMPLICIT_INCLUDE_DIRECTORIES" "Directories implicitly searched by the compiler for header files." nil)
    ("CMAKE_ASM_IMPLICIT_LINK_DIRECTORIES" "Implicit linker search path detected for language ``<LANG>``." nil)
    ("CMAKE_ASM_ATT_IMPLICIT_LINK_DIRECTORIES" "Implicit linker search path detected for language ``<LANG>``." nil)
    ("CMAKE_ASM_MARMASM_IMPLICIT_LINK_DIRECTORIES" "Implicit linker search path detected for language ``<LANG>``." nil)
    ("CMAKE_ASM_MASM_IMPLICIT_LINK_DIRECTORIES" "Implicit linker search path detected for language ``<LANG>``." nil)
    ("CMAKE_ASM_NASM_IMPLICIT_LINK_DIRECTORIES" "Implicit linker search path detected for language ``<LANG>``." nil)
    ("CMAKE_C_IMPLICIT_LINK_DIRECTORIES" "Implicit linker search path detected for language ``<LANG>``." nil)
    ("CMAKE_CSharp_IMPLICIT_LINK_DIRECTORIES" "Implicit linker search path detected for language ``<LANG>``." nil)
    ("CMAKE_CUDA_IMPLICIT_LINK_DIRECTORIES" "Implicit linker search path detected for language ``<LANG>``." nil)
    ("CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES" "Implicit linker search path detected for language ``<LANG>``." nil)
    ("CMAKE_Fortran_IMPLICIT_LINK_DIRECTORIES" "Implicit linker search path detected for language ``<LANG>``." nil)
    ("CMAKE_HIP_IMPLICIT_LINK_DIRECTORIES" "Implicit linker search path detected for language ``<LANG>``." nil)
    ("CMAKE_ISPC_IMPLICIT_LINK_DIRECTORIES" "Implicit linker search path detected for language ``<LANG>``." nil)
    ("CMAKE_OBJC_IMPLICIT_LINK_DIRECTORIES" "Implicit linker search path detected for language ``<LANG>``." nil)
    ("CMAKE_OBJCXX_IMPLICIT_LINK_DIRECTORIES" "Implicit linker search path detected for language ``<LANG>``." nil)
    ("CMAKE_Swift_IMPLICIT_LINK_DIRECTORIES" "Implicit linker search path detected for language ``<LANG>``." nil)
    ("CMAKE_ASM_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES" "Implicit linker framework search path detected for language ``<LANG>``." nil)
    ("CMAKE_ASM_ATT_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES" "Implicit linker framework search path detected for language ``<LANG>``." nil)
    ("CMAKE_ASM_MARMASM_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES" "Implicit linker framework search path detected for language ``<LANG>``." nil)
    ("CMAKE_ASM_MASM_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES" "Implicit linker framework search path detected for language ``<LANG>``." nil)
    ("CMAKE_ASM_NASM_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES" "Implicit linker framework search path detected for language ``<LANG>``." nil)
    ("CMAKE_C_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES" "Implicit linker framework search path detected for language ``<LANG>``." nil)
    ("CMAKE_CSharp_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES" "Implicit linker framework search path detected for language ``<LANG>``." nil)
    ("CMAKE_CUDA_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES" "Implicit linker framework search path detected for language ``<LANG>``." nil)
    ("CMAKE_CXX_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES" "Implicit linker framework search path detected for language ``<LANG>``." nil)
    ("CMAKE_Fortran_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES" "Implicit linker framework search path detected for language ``<LANG>``." nil)
    ("CMAKE_HIP_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES" "Implicit linker framework search path detected for language ``<LANG>``." nil)
    ("CMAKE_ISPC_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES" "Implicit linker framework search path detected for language ``<LANG>``." nil)
    ("CMAKE_OBJC_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES" "Implicit linker framework search path detected for language ``<LANG>``." nil)
    ("CMAKE_OBJCXX_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES" "Implicit linker framework search path detected for language ``<LANG>``." nil)
    ("CMAKE_Swift_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES" "Implicit linker framework search path detected for language ``<LANG>``." nil)
    ("CMAKE_ASM_IMPLICIT_LINK_LIBRARIES" "Implicit link libraries and flags detected for language ``<LANG>``." nil)
    ("CMAKE_ASM_ATT_IMPLICIT_LINK_LIBRARIES" "Implicit link libraries and flags detected for language ``<LANG>``." nil)
    ("CMAKE_ASM_MARMASM_IMPLICIT_LINK_LIBRARIES" "Implicit link libraries and flags detected for language ``<LANG>``." nil)
    ("CMAKE_ASM_MASM_IMPLICIT_LINK_LIBRARIES" "Implicit link libraries and flags detected for language ``<LANG>``." nil)
    ("CMAKE_ASM_NASM_IMPLICIT_LINK_LIBRARIES" "Implicit link libraries and flags detected for language ``<LANG>``." nil)
    ("CMAKE_C_IMPLICIT_LINK_LIBRARIES" "Implicit link libraries and flags detected for language ``<LANG>``." nil)
    ("CMAKE_CSharp_IMPLICIT_LINK_LIBRARIES" "Implicit link libraries and flags detected for language ``<LANG>``." nil)
    ("CMAKE_CUDA_IMPLICIT_LINK_LIBRARIES" "Implicit link libraries and flags detected for language ``<LANG>``." nil)
    ("CMAKE_CXX_IMPLICIT_LINK_LIBRARIES" "Implicit link libraries and flags detected for language ``<LANG>``." nil)
    ("CMAKE_Fortran_IMPLICIT_LINK_LIBRARIES" "Implicit link libraries and flags detected for language ``<LANG>``." nil)
    ("CMAKE_HIP_IMPLICIT_LINK_LIBRARIES" "Implicit link libraries and flags detected for language ``<LANG>``." nil)
    ("CMAKE_ISPC_IMPLICIT_LINK_LIBRARIES" "Implicit link libraries and flags detected for language ``<LANG>``." nil)
    ("CMAKE_OBJC_IMPLICIT_LINK_LIBRARIES" "Implicit link libraries and flags detected for language ``<LANG>``." nil)
    ("CMAKE_OBJCXX_IMPLICIT_LINK_LIBRARIES" "Implicit link libraries and flags detected for language ``<LANG>``." nil)
    ("CMAKE_Swift_IMPLICIT_LINK_LIBRARIES" "Implicit link libraries and flags detected for language ``<LANG>``." nil)
    ("CMAKE_ASM_INCLUDE_WHAT_YOU_USE" "Default value for :prop_tgt:`<LANG>_INCLUDE_WHAT_YOU_USE` target property." nil)
    ("CMAKE_ASM_ATT_INCLUDE_WHAT_YOU_USE" "Default value for :prop_tgt:`<LANG>_INCLUDE_WHAT_YOU_USE` target property." nil)
    ("CMAKE_ASM_MARMASM_INCLUDE_WHAT_YOU_USE" "Default value for :prop_tgt:`<LANG>_INCLUDE_WHAT_YOU_USE` target property." nil)
    ("CMAKE_ASM_MASM_INCLUDE_WHAT_YOU_USE" "Default value for :prop_tgt:`<LANG>_INCLUDE_WHAT_YOU_USE` target property." nil)
    ("CMAKE_ASM_NASM_INCLUDE_WHAT_YOU_USE" "Default value for :prop_tgt:`<LANG>_INCLUDE_WHAT_YOU_USE` target property." nil)
    ("CMAKE_C_INCLUDE_WHAT_YOU_USE" "Default value for :prop_tgt:`<LANG>_INCLUDE_WHAT_YOU_USE` target property." nil)
    ("CMAKE_CSharp_INCLUDE_WHAT_YOU_USE" "Default value for :prop_tgt:`<LANG>_INCLUDE_WHAT_YOU_USE` target property." nil)
    ("CMAKE_CUDA_INCLUDE_WHAT_YOU_USE" "Default value for :prop_tgt:`<LANG>_INCLUDE_WHAT_YOU_USE` target property." nil)
    ("CMAKE_CXX_INCLUDE_WHAT_YOU_USE" "Default value for :prop_tgt:`<LANG>_INCLUDE_WHAT_YOU_USE` target property." nil)
    ("CMAKE_Fortran_INCLUDE_WHAT_YOU_USE" "Default value for :prop_tgt:`<LANG>_INCLUDE_WHAT_YOU_USE` target property." nil)
    ("CMAKE_HIP_INCLUDE_WHAT_YOU_USE" "Default value for :prop_tgt:`<LANG>_INCLUDE_WHAT_YOU_USE` target property." nil)
    ("CMAKE_ISPC_INCLUDE_WHAT_YOU_USE" "Default value for :prop_tgt:`<LANG>_INCLUDE_WHAT_YOU_USE` target property." nil)
    ("CMAKE_OBJC_INCLUDE_WHAT_YOU_USE" "Default value for :prop_tgt:`<LANG>_INCLUDE_WHAT_YOU_USE` target property." nil)
    ("CMAKE_OBJCXX_INCLUDE_WHAT_YOU_USE" "Default value for :prop_tgt:`<LANG>_INCLUDE_WHAT_YOU_USE` target property." nil)
    ("CMAKE_Swift_INCLUDE_WHAT_YOU_USE" "Default value for :prop_tgt:`<LANG>_INCLUDE_WHAT_YOU_USE` target property." nil)
    ("CMAKE_ASM_LIBRARY_ARCHITECTURE" "Target architecture library directory name detected for ``<LANG>``." nil)
    ("CMAKE_ASM_ATT_LIBRARY_ARCHITECTURE" "Target architecture library directory name detected for ``<LANG>``." nil)
    ("CMAKE_ASM_MARMASM_LIBRARY_ARCHITECTURE" "Target architecture library directory name detected for ``<LANG>``." nil)
    ("CMAKE_ASM_MASM_LIBRARY_ARCHITECTURE" "Target architecture library directory name detected for ``<LANG>``." nil)
    ("CMAKE_ASM_NASM_LIBRARY_ARCHITECTURE" "Target architecture library directory name detected for ``<LANG>``." nil)
    ("CMAKE_C_LIBRARY_ARCHITECTURE" "Target architecture library directory name detected for ``<LANG>``." nil)
    ("CMAKE_CSharp_LIBRARY_ARCHITECTURE" "Target architecture library directory name detected for ``<LANG>``." nil)
    ("CMAKE_CUDA_LIBRARY_ARCHITECTURE" "Target architecture library directory name detected for ``<LANG>``." nil)
    ("CMAKE_CXX_LIBRARY_ARCHITECTURE" "Target architecture library directory name detected for ``<LANG>``." nil)
    ("CMAKE_Fortran_LIBRARY_ARCHITECTURE" "Target architecture library directory name detected for ``<LANG>``." nil)
    ("CMAKE_HIP_LIBRARY_ARCHITECTURE" "Target architecture library directory name detected for ``<LANG>``." nil)
    ("CMAKE_ISPC_LIBRARY_ARCHITECTURE" "Target architecture library directory name detected for ``<LANG>``." nil)
    ("CMAKE_OBJC_LIBRARY_ARCHITECTURE" "Target architecture library directory name detected for ``<LANG>``." nil)
    ("CMAKE_OBJCXX_LIBRARY_ARCHITECTURE" "Target architecture library directory name detected for ``<LANG>``." nil)
    ("CMAKE_Swift_LIBRARY_ARCHITECTURE" "Target architecture library directory name detected for ``<LANG>``." nil)
    ("CMAKE_ASM_LINKER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_LINKER_LAUNCHER` target property. This
variable is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ASM_ATT_LINKER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_LINKER_LAUNCHER` target property. This
variable is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ASM_MARMASM_LINKER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_LINKER_LAUNCHER` target property. This
variable is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ASM_MASM_LINKER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_LINKER_LAUNCHER` target property. This
variable is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ASM_NASM_LINKER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_LINKER_LAUNCHER` target property. This
variable is used to initialize the property on each target as it is created." nil)
    ("CMAKE_C_LINKER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_LINKER_LAUNCHER` target property. This
variable is used to initialize the property on each target as it is created." nil)
    ("CMAKE_CSharp_LINKER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_LINKER_LAUNCHER` target property. This
variable is used to initialize the property on each target as it is created." nil)
    ("CMAKE_CUDA_LINKER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_LINKER_LAUNCHER` target property. This
variable is used to initialize the property on each target as it is created." nil)
    ("CMAKE_CXX_LINKER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_LINKER_LAUNCHER` target property. This
variable is used to initialize the property on each target as it is created." nil)
    ("CMAKE_Fortran_LINKER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_LINKER_LAUNCHER` target property. This
variable is used to initialize the property on each target as it is created." nil)
    ("CMAKE_HIP_LINKER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_LINKER_LAUNCHER` target property. This
variable is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ISPC_LINKER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_LINKER_LAUNCHER` target property. This
variable is used to initialize the property on each target as it is created." nil)
    ("CMAKE_OBJC_LINKER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_LINKER_LAUNCHER` target property. This
variable is used to initialize the property on each target as it is created." nil)
    ("CMAKE_OBJCXX_LINKER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_LINKER_LAUNCHER` target property. This
variable is used to initialize the property on each target as it is created." nil)
    ("CMAKE_Swift_LINKER_LAUNCHER" "Default value for :prop_tgt:`<LANG>_LINKER_LAUNCHER` target property. This
variable is used to initialize the property on each target as it is created." nil)
    ("CMAKE_ASM_LINKER_PREFERENCE" "An internal variable subject to change." nil)
    ("CMAKE_ASM_ATT_LINKER_PREFERENCE" "An internal variable subject to change." nil)
    ("CMAKE_ASM_MARMASM_LINKER_PREFERENCE" "An internal variable subject to change." nil)
    ("CMAKE_ASM_MASM_LINKER_PREFERENCE" "An internal variable subject to change." nil)
    ("CMAKE_ASM_NASM_LINKER_PREFERENCE" "An internal variable subject to change." nil)
    ("CMAKE_C_LINKER_PREFERENCE" "An internal variable subject to change." nil)
    ("CMAKE_CSharp_LINKER_PREFERENCE" "An internal variable subject to change." nil)
    ("CMAKE_CUDA_LINKER_PREFERENCE" "An internal variable subject to change." nil)
    ("CMAKE_CXX_LINKER_PREFERENCE" "An internal variable subject to change." nil)
    ("CMAKE_Fortran_LINKER_PREFERENCE" "An internal variable subject to change." nil)
    ("CMAKE_HIP_LINKER_PREFERENCE" "An internal variable subject to change." nil)
    ("CMAKE_ISPC_LINKER_PREFERENCE" "An internal variable subject to change." nil)
    ("CMAKE_OBJC_LINKER_PREFERENCE" "An internal variable subject to change." nil)
    ("CMAKE_OBJCXX_LINKER_PREFERENCE" "An internal variable subject to change." nil)
    ("CMAKE_Swift_LINKER_PREFERENCE" "An internal variable subject to change." nil)
    ("CMAKE_ASM_LINKER_PREFERENCE_PROPAGATES" "An internal variable subject to change." nil)
    ("CMAKE_ASM_ATT_LINKER_PREFERENCE_PROPAGATES" "An internal variable subject to change." nil)
    ("CMAKE_ASM_MARMASM_LINKER_PREFERENCE_PROPAGATES" "An internal variable subject to change." nil)
    ("CMAKE_ASM_MASM_LINKER_PREFERENCE_PROPAGATES" "An internal variable subject to change." nil)
    ("CMAKE_ASM_NASM_LINKER_PREFERENCE_PROPAGATES" "An internal variable subject to change." nil)
    ("CMAKE_C_LINKER_PREFERENCE_PROPAGATES" "An internal variable subject to change." nil)
    ("CMAKE_CSharp_LINKER_PREFERENCE_PROPAGATES" "An internal variable subject to change." nil)
    ("CMAKE_CUDA_LINKER_PREFERENCE_PROPAGATES" "An internal variable subject to change." nil)
    ("CMAKE_CXX_LINKER_PREFERENCE_PROPAGATES" "An internal variable subject to change." nil)
    ("CMAKE_Fortran_LINKER_PREFERENCE_PROPAGATES" "An internal variable subject to change." nil)
    ("CMAKE_HIP_LINKER_PREFERENCE_PROPAGATES" "An internal variable subject to change." nil)
    ("CMAKE_ISPC_LINKER_PREFERENCE_PROPAGATES" "An internal variable subject to change." nil)
    ("CMAKE_OBJC_LINKER_PREFERENCE_PROPAGATES" "An internal variable subject to change." nil)
    ("CMAKE_OBJCXX_LINKER_PREFERENCE_PROPAGATES" "An internal variable subject to change." nil)
    ("CMAKE_Swift_LINKER_PREFERENCE_PROPAGATES" "An internal variable subject to change." nil)
    ("CMAKE_ASM_LINKER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the linker
tool. It will be used to translate the ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." "  set (CMAKE_C_LINKER_WRAPPER_FLAG \"-Xlinker\" \" \")")
    ("CMAKE_ASM_ATT_LINKER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the linker
tool. It will be used to translate the ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." "  set (CMAKE_C_LINKER_WRAPPER_FLAG \"-Xlinker\" \" \")")
    ("CMAKE_ASM_MARMASM_LINKER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the linker
tool. It will be used to translate the ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." "  set (CMAKE_C_LINKER_WRAPPER_FLAG \"-Xlinker\" \" \")")
    ("CMAKE_ASM_MASM_LINKER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the linker
tool. It will be used to translate the ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." "  set (CMAKE_C_LINKER_WRAPPER_FLAG \"-Xlinker\" \" \")")
    ("CMAKE_ASM_NASM_LINKER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the linker
tool. It will be used to translate the ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." "  set (CMAKE_C_LINKER_WRAPPER_FLAG \"-Xlinker\" \" \")")
    ("CMAKE_C_LINKER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the linker
tool. It will be used to translate the ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." "  set (CMAKE_C_LINKER_WRAPPER_FLAG \"-Xlinker\" \" \")")
    ("CMAKE_CSharp_LINKER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the linker
tool. It will be used to translate the ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." "  set (CMAKE_C_LINKER_WRAPPER_FLAG \"-Xlinker\" \" \")")
    ("CMAKE_CUDA_LINKER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the linker
tool. It will be used to translate the ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." "  set (CMAKE_C_LINKER_WRAPPER_FLAG \"-Xlinker\" \" \")")
    ("CMAKE_CXX_LINKER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the linker
tool. It will be used to translate the ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." "  set (CMAKE_C_LINKER_WRAPPER_FLAG \"-Xlinker\" \" \")")
    ("CMAKE_Fortran_LINKER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the linker
tool. It will be used to translate the ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." "  set (CMAKE_C_LINKER_WRAPPER_FLAG \"-Xlinker\" \" \")")
    ("CMAKE_HIP_LINKER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the linker
tool. It will be used to translate the ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." "  set (CMAKE_C_LINKER_WRAPPER_FLAG \"-Xlinker\" \" \")")
    ("CMAKE_ISPC_LINKER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the linker
tool. It will be used to translate the ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." "  set (CMAKE_C_LINKER_WRAPPER_FLAG \"-Xlinker\" \" \")")
    ("CMAKE_OBJC_LINKER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the linker
tool. It will be used to translate the ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." "  set (CMAKE_C_LINKER_WRAPPER_FLAG \"-Xlinker\" \" \")")
    ("CMAKE_OBJCXX_LINKER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the linker
tool. It will be used to translate the ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." "  set (CMAKE_C_LINKER_WRAPPER_FLAG \"-Xlinker\" \" \")")
    ("CMAKE_Swift_LINKER_WRAPPER_FLAG" "Defines the syntax of compiler driver option to pass options to the linker
tool. It will be used to translate the ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." "  set (CMAKE_C_LINKER_WRAPPER_FLAG \"-Xlinker\" \" \")")
    ("CMAKE_ASM_LINKER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_LINKER_WRAPPER_FLAG`
variable to format ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." nil)
    ("CMAKE_ASM_ATT_LINKER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_LINKER_WRAPPER_FLAG`
variable to format ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." nil)
    ("CMAKE_ASM_MARMASM_LINKER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_LINKER_WRAPPER_FLAG`
variable to format ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." nil)
    ("CMAKE_ASM_MASM_LINKER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_LINKER_WRAPPER_FLAG`
variable to format ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." nil)
    ("CMAKE_ASM_NASM_LINKER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_LINKER_WRAPPER_FLAG`
variable to format ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." nil)
    ("CMAKE_C_LINKER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_LINKER_WRAPPER_FLAG`
variable to format ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." nil)
    ("CMAKE_CSharp_LINKER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_LINKER_WRAPPER_FLAG`
variable to format ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." nil)
    ("CMAKE_CUDA_LINKER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_LINKER_WRAPPER_FLAG`
variable to format ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." nil)
    ("CMAKE_CXX_LINKER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_LINKER_WRAPPER_FLAG`
variable to format ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." nil)
    ("CMAKE_Fortran_LINKER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_LINKER_WRAPPER_FLAG`
variable to format ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." nil)
    ("CMAKE_HIP_LINKER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_LINKER_WRAPPER_FLAG`
variable to format ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." nil)
    ("CMAKE_ISPC_LINKER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_LINKER_WRAPPER_FLAG`
variable to format ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." nil)
    ("CMAKE_OBJC_LINKER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_LINKER_WRAPPER_FLAG`
variable to format ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." nil)
    ("CMAKE_OBJCXX_LINKER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_LINKER_WRAPPER_FLAG`
variable to format ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." nil)
    ("CMAKE_Swift_LINKER_WRAPPER_FLAG_SEP" "This variable is used with :variable:`CMAKE_<LANG>_LINKER_WRAPPER_FLAG`
variable to format ``LINKER:`` prefix in the link options
(see :command:`add_link_options` and :command:`target_link_options`)." nil)
    ("CMAKE_ASM_LINK_EXECUTABLE" "Rule variable to link an executable." nil)
    ("CMAKE_ASM_ATT_LINK_EXECUTABLE" "Rule variable to link an executable." nil)
    ("CMAKE_ASM_MARMASM_LINK_EXECUTABLE" "Rule variable to link an executable." nil)
    ("CMAKE_ASM_MASM_LINK_EXECUTABLE" "Rule variable to link an executable." nil)
    ("CMAKE_ASM_NASM_LINK_EXECUTABLE" "Rule variable to link an executable." nil)
    ("CMAKE_C_LINK_EXECUTABLE" "Rule variable to link an executable." nil)
    ("CMAKE_CSharp_LINK_EXECUTABLE" "Rule variable to link an executable." nil)
    ("CMAKE_CUDA_LINK_EXECUTABLE" "Rule variable to link an executable." nil)
    ("CMAKE_CXX_LINK_EXECUTABLE" "Rule variable to link an executable." nil)
    ("CMAKE_Fortran_LINK_EXECUTABLE" "Rule variable to link an executable." nil)
    ("CMAKE_HIP_LINK_EXECUTABLE" "Rule variable to link an executable." nil)
    ("CMAKE_ISPC_LINK_EXECUTABLE" "Rule variable to link an executable." nil)
    ("CMAKE_OBJC_LINK_EXECUTABLE" "Rule variable to link an executable." nil)
    ("CMAKE_OBJCXX_LINK_EXECUTABLE" "Rule variable to link an executable." nil)
    ("CMAKE_Swift_LINK_EXECUTABLE" "Rule variable to link an executable." nil)
    ("CMAKE_ASM_LINK_GROUP_USING_FEATURE" "This variable defines how to link a group of libraries for the specified
``<FEATURE>`` when a :genex:`LINK_GROUP` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_ASM_ATT_LINK_GROUP_USING_FEATURE" "This variable defines how to link a group of libraries for the specified
``<FEATURE>`` when a :genex:`LINK_GROUP` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_ASM_MARMASM_LINK_GROUP_USING_FEATURE" "This variable defines how to link a group of libraries for the specified
``<FEATURE>`` when a :genex:`LINK_GROUP` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_ASM_MASM_LINK_GROUP_USING_FEATURE" "This variable defines how to link a group of libraries for the specified
``<FEATURE>`` when a :genex:`LINK_GROUP` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_ASM_NASM_LINK_GROUP_USING_FEATURE" "This variable defines how to link a group of libraries for the specified
``<FEATURE>`` when a :genex:`LINK_GROUP` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_C_LINK_GROUP_USING_FEATURE" "This variable defines how to link a group of libraries for the specified
``<FEATURE>`` when a :genex:`LINK_GROUP` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_CSharp_LINK_GROUP_USING_FEATURE" "This variable defines how to link a group of libraries for the specified
``<FEATURE>`` when a :genex:`LINK_GROUP` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_CUDA_LINK_GROUP_USING_FEATURE" "This variable defines how to link a group of libraries for the specified
``<FEATURE>`` when a :genex:`LINK_GROUP` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_CXX_LINK_GROUP_USING_FEATURE" "This variable defines how to link a group of libraries for the specified
``<FEATURE>`` when a :genex:`LINK_GROUP` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_Fortran_LINK_GROUP_USING_FEATURE" "This variable defines how to link a group of libraries for the specified
``<FEATURE>`` when a :genex:`LINK_GROUP` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_HIP_LINK_GROUP_USING_FEATURE" "This variable defines how to link a group of libraries for the specified
``<FEATURE>`` when a :genex:`LINK_GROUP` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_ISPC_LINK_GROUP_USING_FEATURE" "This variable defines how to link a group of libraries for the specified
``<FEATURE>`` when a :genex:`LINK_GROUP` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_OBJC_LINK_GROUP_USING_FEATURE" "This variable defines how to link a group of libraries for the specified
``<FEATURE>`` when a :genex:`LINK_GROUP` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_OBJCXX_LINK_GROUP_USING_FEATURE" "This variable defines how to link a group of libraries for the specified
``<FEATURE>`` when a :genex:`LINK_GROUP` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_Swift_LINK_GROUP_USING_FEATURE" "This variable defines how to link a group of libraries for the specified
``<FEATURE>`` when a :genex:`LINK_GROUP` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_ASM_LINK_GROUP_USING_FEATURE_SUPPORTED" "This variable specifies whether the ``<FEATURE>`` is supported for the link
language ``<LANG>``." nil)
    ("CMAKE_ASM_ATT_LINK_GROUP_USING_FEATURE_SUPPORTED" "This variable specifies whether the ``<FEATURE>`` is supported for the link
language ``<LANG>``." nil)
    ("CMAKE_ASM_MARMASM_LINK_GROUP_USING_FEATURE_SUPPORTED" "This variable specifies whether the ``<FEATURE>`` is supported for the link
language ``<LANG>``." nil)
    ("CMAKE_ASM_MASM_LINK_GROUP_USING_FEATURE_SUPPORTED" "This variable specifies whether the ``<FEATURE>`` is supported for the link
language ``<LANG>``." nil)
    ("CMAKE_ASM_NASM_LINK_GROUP_USING_FEATURE_SUPPORTED" "This variable specifies whether the ``<FEATURE>`` is supported for the link
language ``<LANG>``." nil)
    ("CMAKE_C_LINK_GROUP_USING_FEATURE_SUPPORTED" "This variable specifies whether the ``<FEATURE>`` is supported for the link
language ``<LANG>``." nil)
    ("CMAKE_CSharp_LINK_GROUP_USING_FEATURE_SUPPORTED" "This variable specifies whether the ``<FEATURE>`` is supported for the link
language ``<LANG>``." nil)
    ("CMAKE_CUDA_LINK_GROUP_USING_FEATURE_SUPPORTED" "This variable specifies whether the ``<FEATURE>`` is supported for the link
language ``<LANG>``." nil)
    ("CMAKE_CXX_LINK_GROUP_USING_FEATURE_SUPPORTED" "This variable specifies whether the ``<FEATURE>`` is supported for the link
language ``<LANG>``." nil)
    ("CMAKE_Fortran_LINK_GROUP_USING_FEATURE_SUPPORTED" "This variable specifies whether the ``<FEATURE>`` is supported for the link
language ``<LANG>``." nil)
    ("CMAKE_HIP_LINK_GROUP_USING_FEATURE_SUPPORTED" "This variable specifies whether the ``<FEATURE>`` is supported for the link
language ``<LANG>``." nil)
    ("CMAKE_ISPC_LINK_GROUP_USING_FEATURE_SUPPORTED" "This variable specifies whether the ``<FEATURE>`` is supported for the link
language ``<LANG>``." nil)
    ("CMAKE_OBJC_LINK_GROUP_USING_FEATURE_SUPPORTED" "This variable specifies whether the ``<FEATURE>`` is supported for the link
language ``<LANG>``." nil)
    ("CMAKE_OBJCXX_LINK_GROUP_USING_FEATURE_SUPPORTED" "This variable specifies whether the ``<FEATURE>`` is supported for the link
language ``<LANG>``." nil)
    ("CMAKE_Swift_LINK_GROUP_USING_FEATURE_SUPPORTED" "This variable specifies whether the ``<FEATURE>`` is supported for the link
language ``<LANG>``." nil)
    ("CMAKE_ASM_LINK_LIBRARY_FEATURE_ATTRIBUTES" "This variable defines the semantics of the specified link library ``<FEATURE>``
when linking with the link language ``<LANG>``. It takes precedence over
:variable:`CMAKE_LINK_LIBRARY_<FEATURE>_ATTRIBUTES` if that variable is also
defined for the same ``<FEATURE>``, but otherwise has similar effects." nil)
    ("CMAKE_ASM_ATT_LINK_LIBRARY_FEATURE_ATTRIBUTES" "This variable defines the semantics of the specified link library ``<FEATURE>``
when linking with the link language ``<LANG>``. It takes precedence over
:variable:`CMAKE_LINK_LIBRARY_<FEATURE>_ATTRIBUTES` if that variable is also
defined for the same ``<FEATURE>``, but otherwise has similar effects." nil)
    ("CMAKE_ASM_MARMASM_LINK_LIBRARY_FEATURE_ATTRIBUTES" "This variable defines the semantics of the specified link library ``<FEATURE>``
when linking with the link language ``<LANG>``. It takes precedence over
:variable:`CMAKE_LINK_LIBRARY_<FEATURE>_ATTRIBUTES` if that variable is also
defined for the same ``<FEATURE>``, but otherwise has similar effects." nil)
    ("CMAKE_ASM_MASM_LINK_LIBRARY_FEATURE_ATTRIBUTES" "This variable defines the semantics of the specified link library ``<FEATURE>``
when linking with the link language ``<LANG>``. It takes precedence over
:variable:`CMAKE_LINK_LIBRARY_<FEATURE>_ATTRIBUTES` if that variable is also
defined for the same ``<FEATURE>``, but otherwise has similar effects." nil)
    ("CMAKE_ASM_NASM_LINK_LIBRARY_FEATURE_ATTRIBUTES" "This variable defines the semantics of the specified link library ``<FEATURE>``
when linking with the link language ``<LANG>``. It takes precedence over
:variable:`CMAKE_LINK_LIBRARY_<FEATURE>_ATTRIBUTES` if that variable is also
defined for the same ``<FEATURE>``, but otherwise has similar effects." nil)
    ("CMAKE_C_LINK_LIBRARY_FEATURE_ATTRIBUTES" "This variable defines the semantics of the specified link library ``<FEATURE>``
when linking with the link language ``<LANG>``. It takes precedence over
:variable:`CMAKE_LINK_LIBRARY_<FEATURE>_ATTRIBUTES` if that variable is also
defined for the same ``<FEATURE>``, but otherwise has similar effects." nil)
    ("CMAKE_CSharp_LINK_LIBRARY_FEATURE_ATTRIBUTES" "This variable defines the semantics of the specified link library ``<FEATURE>``
when linking with the link language ``<LANG>``. It takes precedence over
:variable:`CMAKE_LINK_LIBRARY_<FEATURE>_ATTRIBUTES` if that variable is also
defined for the same ``<FEATURE>``, but otherwise has similar effects." nil)
    ("CMAKE_CUDA_LINK_LIBRARY_FEATURE_ATTRIBUTES" "This variable defines the semantics of the specified link library ``<FEATURE>``
when linking with the link language ``<LANG>``. It takes precedence over
:variable:`CMAKE_LINK_LIBRARY_<FEATURE>_ATTRIBUTES` if that variable is also
defined for the same ``<FEATURE>``, but otherwise has similar effects." nil)
    ("CMAKE_CXX_LINK_LIBRARY_FEATURE_ATTRIBUTES" "This variable defines the semantics of the specified link library ``<FEATURE>``
when linking with the link language ``<LANG>``. It takes precedence over
:variable:`CMAKE_LINK_LIBRARY_<FEATURE>_ATTRIBUTES` if that variable is also
defined for the same ``<FEATURE>``, but otherwise has similar effects." nil)
    ("CMAKE_Fortran_LINK_LIBRARY_FEATURE_ATTRIBUTES" "This variable defines the semantics of the specified link library ``<FEATURE>``
when linking with the link language ``<LANG>``. It takes precedence over
:variable:`CMAKE_LINK_LIBRARY_<FEATURE>_ATTRIBUTES` if that variable is also
defined for the same ``<FEATURE>``, but otherwise has similar effects." nil)
    ("CMAKE_HIP_LINK_LIBRARY_FEATURE_ATTRIBUTES" "This variable defines the semantics of the specified link library ``<FEATURE>``
when linking with the link language ``<LANG>``. It takes precedence over
:variable:`CMAKE_LINK_LIBRARY_<FEATURE>_ATTRIBUTES` if that variable is also
defined for the same ``<FEATURE>``, but otherwise has similar effects." nil)
    ("CMAKE_ISPC_LINK_LIBRARY_FEATURE_ATTRIBUTES" "This variable defines the semantics of the specified link library ``<FEATURE>``
when linking with the link language ``<LANG>``. It takes precedence over
:variable:`CMAKE_LINK_LIBRARY_<FEATURE>_ATTRIBUTES` if that variable is also
defined for the same ``<FEATURE>``, but otherwise has similar effects." nil)
    ("CMAKE_OBJC_LINK_LIBRARY_FEATURE_ATTRIBUTES" "This variable defines the semantics of the specified link library ``<FEATURE>``
when linking with the link language ``<LANG>``. It takes precedence over
:variable:`CMAKE_LINK_LIBRARY_<FEATURE>_ATTRIBUTES` if that variable is also
defined for the same ``<FEATURE>``, but otherwise has similar effects." nil)
    ("CMAKE_OBJCXX_LINK_LIBRARY_FEATURE_ATTRIBUTES" "This variable defines the semantics of the specified link library ``<FEATURE>``
when linking with the link language ``<LANG>``. It takes precedence over
:variable:`CMAKE_LINK_LIBRARY_<FEATURE>_ATTRIBUTES` if that variable is also
defined for the same ``<FEATURE>``, but otherwise has similar effects." nil)
    ("CMAKE_Swift_LINK_LIBRARY_FEATURE_ATTRIBUTES" "This variable defines the semantics of the specified link library ``<FEATURE>``
when linking with the link language ``<LANG>``. It takes precedence over
:variable:`CMAKE_LINK_LIBRARY_<FEATURE>_ATTRIBUTES` if that variable is also
defined for the same ``<FEATURE>``, but otherwise has similar effects." nil)
    ("CMAKE_ASM_LINK_LIBRARY_FILE_FLAG" "Language-specific flag to be used to link a library specified by
a path to its file." nil)
    ("CMAKE_ASM_ATT_LINK_LIBRARY_FILE_FLAG" "Language-specific flag to be used to link a library specified by
a path to its file." nil)
    ("CMAKE_ASM_MARMASM_LINK_LIBRARY_FILE_FLAG" "Language-specific flag to be used to link a library specified by
a path to its file." nil)
    ("CMAKE_ASM_MASM_LINK_LIBRARY_FILE_FLAG" "Language-specific flag to be used to link a library specified by
a path to its file." nil)
    ("CMAKE_ASM_NASM_LINK_LIBRARY_FILE_FLAG" "Language-specific flag to be used to link a library specified by
a path to its file." nil)
    ("CMAKE_C_LINK_LIBRARY_FILE_FLAG" "Language-specific flag to be used to link a library specified by
a path to its file." nil)
    ("CMAKE_CSharp_LINK_LIBRARY_FILE_FLAG" "Language-specific flag to be used to link a library specified by
a path to its file." nil)
    ("CMAKE_CUDA_LINK_LIBRARY_FILE_FLAG" "Language-specific flag to be used to link a library specified by
a path to its file." nil)
    ("CMAKE_CXX_LINK_LIBRARY_FILE_FLAG" "Language-specific flag to be used to link a library specified by
a path to its file." nil)
    ("CMAKE_Fortran_LINK_LIBRARY_FILE_FLAG" "Language-specific flag to be used to link a library specified by
a path to its file." nil)
    ("CMAKE_HIP_LINK_LIBRARY_FILE_FLAG" "Language-specific flag to be used to link a library specified by
a path to its file." nil)
    ("CMAKE_ISPC_LINK_LIBRARY_FILE_FLAG" "Language-specific flag to be used to link a library specified by
a path to its file." nil)
    ("CMAKE_OBJC_LINK_LIBRARY_FILE_FLAG" "Language-specific flag to be used to link a library specified by
a path to its file." nil)
    ("CMAKE_OBJCXX_LINK_LIBRARY_FILE_FLAG" "Language-specific flag to be used to link a library specified by
a path to its file." nil)
    ("CMAKE_Swift_LINK_LIBRARY_FILE_FLAG" "Language-specific flag to be used to link a library specified by
a path to its file." nil)
    ("CMAKE_ASM_LINK_LIBRARY_FLAG" "Flag to be used to link a library into a shared library or executable." nil)
    ("CMAKE_ASM_ATT_LINK_LIBRARY_FLAG" "Flag to be used to link a library into a shared library or executable." nil)
    ("CMAKE_ASM_MARMASM_LINK_LIBRARY_FLAG" "Flag to be used to link a library into a shared library or executable." nil)
    ("CMAKE_ASM_MASM_LINK_LIBRARY_FLAG" "Flag to be used to link a library into a shared library or executable." nil)
    ("CMAKE_ASM_NASM_LINK_LIBRARY_FLAG" "Flag to be used to link a library into a shared library or executable." nil)
    ("CMAKE_C_LINK_LIBRARY_FLAG" "Flag to be used to link a library into a shared library or executable." nil)
    ("CMAKE_CSharp_LINK_LIBRARY_FLAG" "Flag to be used to link a library into a shared library or executable." nil)
    ("CMAKE_CUDA_LINK_LIBRARY_FLAG" "Flag to be used to link a library into a shared library or executable." nil)
    ("CMAKE_CXX_LINK_LIBRARY_FLAG" "Flag to be used to link a library into a shared library or executable." nil)
    ("CMAKE_Fortran_LINK_LIBRARY_FLAG" "Flag to be used to link a library into a shared library or executable." nil)
    ("CMAKE_HIP_LINK_LIBRARY_FLAG" "Flag to be used to link a library into a shared library or executable." nil)
    ("CMAKE_ISPC_LINK_LIBRARY_FLAG" "Flag to be used to link a library into a shared library or executable." nil)
    ("CMAKE_OBJC_LINK_LIBRARY_FLAG" "Flag to be used to link a library into a shared library or executable." nil)
    ("CMAKE_OBJCXX_LINK_LIBRARY_FLAG" "Flag to be used to link a library into a shared library or executable." nil)
    ("CMAKE_Swift_LINK_LIBRARY_FLAG" "Flag to be used to link a library into a shared library or executable." nil)
    ("CMAKE_ASM_LINK_LIBRARY_SUFFIX" "Language-specific suffix for libraries that you link to." nil)
    ("CMAKE_ASM_ATT_LINK_LIBRARY_SUFFIX" "Language-specific suffix for libraries that you link to." nil)
    ("CMAKE_ASM_MARMASM_LINK_LIBRARY_SUFFIX" "Language-specific suffix for libraries that you link to." nil)
    ("CMAKE_ASM_MASM_LINK_LIBRARY_SUFFIX" "Language-specific suffix for libraries that you link to." nil)
    ("CMAKE_ASM_NASM_LINK_LIBRARY_SUFFIX" "Language-specific suffix for libraries that you link to." nil)
    ("CMAKE_C_LINK_LIBRARY_SUFFIX" "Language-specific suffix for libraries that you link to." nil)
    ("CMAKE_CSharp_LINK_LIBRARY_SUFFIX" "Language-specific suffix for libraries that you link to." nil)
    ("CMAKE_CUDA_LINK_LIBRARY_SUFFIX" "Language-specific suffix for libraries that you link to." nil)
    ("CMAKE_CXX_LINK_LIBRARY_SUFFIX" "Language-specific suffix for libraries that you link to." nil)
    ("CMAKE_Fortran_LINK_LIBRARY_SUFFIX" "Language-specific suffix for libraries that you link to." nil)
    ("CMAKE_HIP_LINK_LIBRARY_SUFFIX" "Language-specific suffix for libraries that you link to." nil)
    ("CMAKE_ISPC_LINK_LIBRARY_SUFFIX" "Language-specific suffix for libraries that you link to." nil)
    ("CMAKE_OBJC_LINK_LIBRARY_SUFFIX" "Language-specific suffix for libraries that you link to." nil)
    ("CMAKE_OBJCXX_LINK_LIBRARY_SUFFIX" "Language-specific suffix for libraries that you link to." nil)
    ("CMAKE_Swift_LINK_LIBRARY_SUFFIX" "Language-specific suffix for libraries that you link to." nil)
    ("CMAKE_ASM_LINK_LIBRARY_USING_FEATURE" "This variable defines how to link a library or framework for the specified
``<FEATURE>`` when a :genex:`LINK_LIBRARY` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_ASM_ATT_LINK_LIBRARY_USING_FEATURE" "This variable defines how to link a library or framework for the specified
``<FEATURE>`` when a :genex:`LINK_LIBRARY` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_ASM_MARMASM_LINK_LIBRARY_USING_FEATURE" "This variable defines how to link a library or framework for the specified
``<FEATURE>`` when a :genex:`LINK_LIBRARY` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_ASM_MASM_LINK_LIBRARY_USING_FEATURE" "This variable defines how to link a library or framework for the specified
``<FEATURE>`` when a :genex:`LINK_LIBRARY` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_ASM_NASM_LINK_LIBRARY_USING_FEATURE" "This variable defines how to link a library or framework for the specified
``<FEATURE>`` when a :genex:`LINK_LIBRARY` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_C_LINK_LIBRARY_USING_FEATURE" "This variable defines how to link a library or framework for the specified
``<FEATURE>`` when a :genex:`LINK_LIBRARY` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_CSharp_LINK_LIBRARY_USING_FEATURE" "This variable defines how to link a library or framework for the specified
``<FEATURE>`` when a :genex:`LINK_LIBRARY` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_CUDA_LINK_LIBRARY_USING_FEATURE" "This variable defines how to link a library or framework for the specified
``<FEATURE>`` when a :genex:`LINK_LIBRARY` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_CXX_LINK_LIBRARY_USING_FEATURE" "This variable defines how to link a library or framework for the specified
``<FEATURE>`` when a :genex:`LINK_LIBRARY` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_Fortran_LINK_LIBRARY_USING_FEATURE" "This variable defines how to link a library or framework for the specified
``<FEATURE>`` when a :genex:`LINK_LIBRARY` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_HIP_LINK_LIBRARY_USING_FEATURE" "This variable defines how to link a library or framework for the specified
``<FEATURE>`` when a :genex:`LINK_LIBRARY` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_ISPC_LINK_LIBRARY_USING_FEATURE" "This variable defines how to link a library or framework for the specified
``<FEATURE>`` when a :genex:`LINK_LIBRARY` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_OBJC_LINK_LIBRARY_USING_FEATURE" "This variable defines how to link a library or framework for the specified
``<FEATURE>`` when a :genex:`LINK_LIBRARY` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_OBJCXX_LINK_LIBRARY_USING_FEATURE" "This variable defines how to link a library or framework for the specified
``<FEATURE>`` when a :genex:`LINK_LIBRARY` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_Swift_LINK_LIBRARY_USING_FEATURE" "This variable defines how to link a library or framework for the specified
``<FEATURE>`` when a :genex:`LINK_LIBRARY` generator expression is used and
the link language for the target is ``<LANG>``." nil)
    ("CMAKE_ASM_LINK_LIBRARY_USING_FEATURE_SUPPORTED" "Set to ``TRUE`` if the ``<FEATURE>``, as defined by variable
:variable:`CMAKE_<LANG>_LINK_LIBRARY_USING_<FEATURE>`, is supported for the
linker language ``<LANG>``." nil)
    ("CMAKE_ASM_ATT_LINK_LIBRARY_USING_FEATURE_SUPPORTED" "Set to ``TRUE`` if the ``<FEATURE>``, as defined by variable
:variable:`CMAKE_<LANG>_LINK_LIBRARY_USING_<FEATURE>`, is supported for the
linker language ``<LANG>``." nil)
    ("CMAKE_ASM_MARMASM_LINK_LIBRARY_USING_FEATURE_SUPPORTED" "Set to ``TRUE`` if the ``<FEATURE>``, as defined by variable
:variable:`CMAKE_<LANG>_LINK_LIBRARY_USING_<FEATURE>`, is supported for the
linker language ``<LANG>``." nil)
    ("CMAKE_ASM_MASM_LINK_LIBRARY_USING_FEATURE_SUPPORTED" "Set to ``TRUE`` if the ``<FEATURE>``, as defined by variable
:variable:`CMAKE_<LANG>_LINK_LIBRARY_USING_<FEATURE>`, is supported for the
linker language ``<LANG>``." nil)
    ("CMAKE_ASM_NASM_LINK_LIBRARY_USING_FEATURE_SUPPORTED" "Set to ``TRUE`` if the ``<FEATURE>``, as defined by variable
:variable:`CMAKE_<LANG>_LINK_LIBRARY_USING_<FEATURE>`, is supported for the
linker language ``<LANG>``." nil)
    ("CMAKE_C_LINK_LIBRARY_USING_FEATURE_SUPPORTED" "Set to ``TRUE`` if the ``<FEATURE>``, as defined by variable
:variable:`CMAKE_<LANG>_LINK_LIBRARY_USING_<FEATURE>`, is supported for the
linker language ``<LANG>``." nil)
    ("CMAKE_CSharp_LINK_LIBRARY_USING_FEATURE_SUPPORTED" "Set to ``TRUE`` if the ``<FEATURE>``, as defined by variable
:variable:`CMAKE_<LANG>_LINK_LIBRARY_USING_<FEATURE>`, is supported for the
linker language ``<LANG>``." nil)
    ("CMAKE_CUDA_LINK_LIBRARY_USING_FEATURE_SUPPORTED" "Set to ``TRUE`` if the ``<FEATURE>``, as defined by variable
:variable:`CMAKE_<LANG>_LINK_LIBRARY_USING_<FEATURE>`, is supported for the
linker language ``<LANG>``." nil)
    ("CMAKE_CXX_LINK_LIBRARY_USING_FEATURE_SUPPORTED" "Set to ``TRUE`` if the ``<FEATURE>``, as defined by variable
:variable:`CMAKE_<LANG>_LINK_LIBRARY_USING_<FEATURE>`, is supported for the
linker language ``<LANG>``." nil)
    ("CMAKE_Fortran_LINK_LIBRARY_USING_FEATURE_SUPPORTED" "Set to ``TRUE`` if the ``<FEATURE>``, as defined by variable
:variable:`CMAKE_<LANG>_LINK_LIBRARY_USING_<FEATURE>`, is supported for the
linker language ``<LANG>``." nil)
    ("CMAKE_HIP_LINK_LIBRARY_USING_FEATURE_SUPPORTED" "Set to ``TRUE`` if the ``<FEATURE>``, as defined by variable
:variable:`CMAKE_<LANG>_LINK_LIBRARY_USING_<FEATURE>`, is supported for the
linker language ``<LANG>``." nil)
    ("CMAKE_ISPC_LINK_LIBRARY_USING_FEATURE_SUPPORTED" "Set to ``TRUE`` if the ``<FEATURE>``, as defined by variable
:variable:`CMAKE_<LANG>_LINK_LIBRARY_USING_<FEATURE>`, is supported for the
linker language ``<LANG>``." nil)
    ("CMAKE_OBJC_LINK_LIBRARY_USING_FEATURE_SUPPORTED" "Set to ``TRUE`` if the ``<FEATURE>``, as defined by variable
:variable:`CMAKE_<LANG>_LINK_LIBRARY_USING_<FEATURE>`, is supported for the
linker language ``<LANG>``." nil)
    ("CMAKE_OBJCXX_LINK_LIBRARY_USING_FEATURE_SUPPORTED" "Set to ``TRUE`` if the ``<FEATURE>``, as defined by variable
:variable:`CMAKE_<LANG>_LINK_LIBRARY_USING_<FEATURE>`, is supported for the
linker language ``<LANG>``." nil)
    ("CMAKE_Swift_LINK_LIBRARY_USING_FEATURE_SUPPORTED" "Set to ``TRUE`` if the ``<FEATURE>``, as defined by variable
:variable:`CMAKE_<LANG>_LINK_LIBRARY_USING_<FEATURE>`, is supported for the
linker language ``<LANG>``." nil)
    ("CMAKE_ASM_LINK_MODE" "Defines how the link step is done. The possible values are:" nil)
    ("CMAKE_ASM_ATT_LINK_MODE" "Defines how the link step is done. The possible values are:" nil)
    ("CMAKE_ASM_MARMASM_LINK_MODE" "Defines how the link step is done. The possible values are:" nil)
    ("CMAKE_ASM_MASM_LINK_MODE" "Defines how the link step is done. The possible values are:" nil)
    ("CMAKE_ASM_NASM_LINK_MODE" "Defines how the link step is done. The possible values are:" nil)
    ("CMAKE_C_LINK_MODE" "Defines how the link step is done. The possible values are:" nil)
    ("CMAKE_CSharp_LINK_MODE" "Defines how the link step is done. The possible values are:" nil)
    ("CMAKE_CUDA_LINK_MODE" "Defines how the link step is done. The possible values are:" nil)
    ("CMAKE_CXX_LINK_MODE" "Defines how the link step is done. The possible values are:" nil)
    ("CMAKE_Fortran_LINK_MODE" "Defines how the link step is done. The possible values are:" nil)
    ("CMAKE_HIP_LINK_MODE" "Defines how the link step is done. The possible values are:" nil)
    ("CMAKE_ISPC_LINK_MODE" "Defines how the link step is done. The possible values are:" nil)
    ("CMAKE_OBJC_LINK_MODE" "Defines how the link step is done. The possible values are:" nil)
    ("CMAKE_OBJCXX_LINK_MODE" "Defines how the link step is done. The possible values are:" nil)
    ("CMAKE_Swift_LINK_MODE" "Defines how the link step is done. The possible values are:" nil)
    ("CMAKE_ASM_LINK_WHAT_YOU_USE_FLAG" "Linker flag used by :prop_tgt:`LINK_WHAT_YOU_USE` to tell the linker to
link all shared libraries specified on the command line even if none
of their symbols is needed." nil)
    ("CMAKE_ASM_ATT_LINK_WHAT_YOU_USE_FLAG" "Linker flag used by :prop_tgt:`LINK_WHAT_YOU_USE` to tell the linker to
link all shared libraries specified on the command line even if none
of their symbols is needed." nil)
    ("CMAKE_ASM_MARMASM_LINK_WHAT_YOU_USE_FLAG" "Linker flag used by :prop_tgt:`LINK_WHAT_YOU_USE` to tell the linker to
link all shared libraries specified on the command line even if none
of their symbols is needed." nil)
    ("CMAKE_ASM_MASM_LINK_WHAT_YOU_USE_FLAG" "Linker flag used by :prop_tgt:`LINK_WHAT_YOU_USE` to tell the linker to
link all shared libraries specified on the command line even if none
of their symbols is needed." nil)
    ("CMAKE_ASM_NASM_LINK_WHAT_YOU_USE_FLAG" "Linker flag used by :prop_tgt:`LINK_WHAT_YOU_USE` to tell the linker to
link all shared libraries specified on the command line even if none
of their symbols is needed." nil)
    ("CMAKE_C_LINK_WHAT_YOU_USE_FLAG" "Linker flag used by :prop_tgt:`LINK_WHAT_YOU_USE` to tell the linker to
link all shared libraries specified on the command line even if none
of their symbols is needed." nil)
    ("CMAKE_CSharp_LINK_WHAT_YOU_USE_FLAG" "Linker flag used by :prop_tgt:`LINK_WHAT_YOU_USE` to tell the linker to
link all shared libraries specified on the command line even if none
of their symbols is needed." nil)
    ("CMAKE_CUDA_LINK_WHAT_YOU_USE_FLAG" "Linker flag used by :prop_tgt:`LINK_WHAT_YOU_USE` to tell the linker to
link all shared libraries specified on the command line even if none
of their symbols is needed." nil)
    ("CMAKE_CXX_LINK_WHAT_YOU_USE_FLAG" "Linker flag used by :prop_tgt:`LINK_WHAT_YOU_USE` to tell the linker to
link all shared libraries specified on the command line even if none
of their symbols is needed." nil)
    ("CMAKE_Fortran_LINK_WHAT_YOU_USE_FLAG" "Linker flag used by :prop_tgt:`LINK_WHAT_YOU_USE` to tell the linker to
link all shared libraries specified on the command line even if none
of their symbols is needed." nil)
    ("CMAKE_HIP_LINK_WHAT_YOU_USE_FLAG" "Linker flag used by :prop_tgt:`LINK_WHAT_YOU_USE` to tell the linker to
link all shared libraries specified on the command line even if none
of their symbols is needed." nil)
    ("CMAKE_ISPC_LINK_WHAT_YOU_USE_FLAG" "Linker flag used by :prop_tgt:`LINK_WHAT_YOU_USE` to tell the linker to
link all shared libraries specified on the command line even if none
of their symbols is needed." nil)
    ("CMAKE_OBJC_LINK_WHAT_YOU_USE_FLAG" "Linker flag used by :prop_tgt:`LINK_WHAT_YOU_USE` to tell the linker to
link all shared libraries specified on the command line even if none
of their symbols is needed." nil)
    ("CMAKE_OBJCXX_LINK_WHAT_YOU_USE_FLAG" "Linker flag used by :prop_tgt:`LINK_WHAT_YOU_USE` to tell the linker to
link all shared libraries specified on the command line even if none
of their symbols is needed." nil)
    ("CMAKE_Swift_LINK_WHAT_YOU_USE_FLAG" "Linker flag used by :prop_tgt:`LINK_WHAT_YOU_USE` to tell the linker to
link all shared libraries specified on the command line even if none
of their symbols is needed." nil)
    ("CMAKE_ASM_OUTPUT_EXTENSION" "Extension for the output of a compile for a single file." nil)
    ("CMAKE_ASM_ATT_OUTPUT_EXTENSION" "Extension for the output of a compile for a single file." nil)
    ("CMAKE_ASM_MARMASM_OUTPUT_EXTENSION" "Extension for the output of a compile for a single file." nil)
    ("CMAKE_ASM_MASM_OUTPUT_EXTENSION" "Extension for the output of a compile for a single file." nil)
    ("CMAKE_ASM_NASM_OUTPUT_EXTENSION" "Extension for the output of a compile for a single file." nil)
    ("CMAKE_C_OUTPUT_EXTENSION" "Extension for the output of a compile for a single file." nil)
    ("CMAKE_CSharp_OUTPUT_EXTENSION" "Extension for the output of a compile for a single file." nil)
    ("CMAKE_CUDA_OUTPUT_EXTENSION" "Extension for the output of a compile for a single file." nil)
    ("CMAKE_CXX_OUTPUT_EXTENSION" "Extension for the output of a compile for a single file." nil)
    ("CMAKE_Fortran_OUTPUT_EXTENSION" "Extension for the output of a compile for a single file." nil)
    ("CMAKE_HIP_OUTPUT_EXTENSION" "Extension for the output of a compile for a single file." nil)
    ("CMAKE_ISPC_OUTPUT_EXTENSION" "Extension for the output of a compile for a single file." nil)
    ("CMAKE_OBJC_OUTPUT_EXTENSION" "Extension for the output of a compile for a single file." nil)
    ("CMAKE_OBJCXX_OUTPUT_EXTENSION" "Extension for the output of a compile for a single file." nil)
    ("CMAKE_Swift_OUTPUT_EXTENSION" "Extension for the output of a compile for a single file." nil)
    ("CMAKE_ASM_PLATFORM_ID" "An internal variable subject to change." nil)
    ("CMAKE_ASM_ATT_PLATFORM_ID" "An internal variable subject to change." nil)
    ("CMAKE_ASM_MARMASM_PLATFORM_ID" "An internal variable subject to change." nil)
    ("CMAKE_ASM_MASM_PLATFORM_ID" "An internal variable subject to change." nil)
    ("CMAKE_ASM_NASM_PLATFORM_ID" "An internal variable subject to change." nil)
    ("CMAKE_C_PLATFORM_ID" "An internal variable subject to change." nil)
    ("CMAKE_CSharp_PLATFORM_ID" "An internal variable subject to change." nil)
    ("CMAKE_CUDA_PLATFORM_ID" "An internal variable subject to change." nil)
    ("CMAKE_CXX_PLATFORM_ID" "An internal variable subject to change." nil)
    ("CMAKE_Fortran_PLATFORM_ID" "An internal variable subject to change." nil)
    ("CMAKE_HIP_PLATFORM_ID" "An internal variable subject to change." nil)
    ("CMAKE_ISPC_PLATFORM_ID" "An internal variable subject to change." nil)
    ("CMAKE_OBJC_PLATFORM_ID" "An internal variable subject to change." nil)
    ("CMAKE_OBJCXX_PLATFORM_ID" "An internal variable subject to change." nil)
    ("CMAKE_Swift_PLATFORM_ID" "An internal variable subject to change." nil)
    ("CMAKE_ASM_SIMULATE_ID" "Identification string of the \"simulated\" compiler." nil)
    ("CMAKE_ASM_ATT_SIMULATE_ID" "Identification string of the \"simulated\" compiler." nil)
    ("CMAKE_ASM_MARMASM_SIMULATE_ID" "Identification string of the \"simulated\" compiler." nil)
    ("CMAKE_ASM_MASM_SIMULATE_ID" "Identification string of the \"simulated\" compiler." nil)
    ("CMAKE_ASM_NASM_SIMULATE_ID" "Identification string of the \"simulated\" compiler." nil)
    ("CMAKE_C_SIMULATE_ID" "Identification string of the \"simulated\" compiler." nil)
    ("CMAKE_CSharp_SIMULATE_ID" "Identification string of the \"simulated\" compiler." nil)
    ("CMAKE_CUDA_SIMULATE_ID" "Identification string of the \"simulated\" compiler." nil)
    ("CMAKE_CXX_SIMULATE_ID" "Identification string of the \"simulated\" compiler." nil)
    ("CMAKE_Fortran_SIMULATE_ID" "Identification string of the \"simulated\" compiler." nil)
    ("CMAKE_HIP_SIMULATE_ID" "Identification string of the \"simulated\" compiler." nil)
    ("CMAKE_ISPC_SIMULATE_ID" "Identification string of the \"simulated\" compiler." nil)
    ("CMAKE_OBJC_SIMULATE_ID" "Identification string of the \"simulated\" compiler." nil)
    ("CMAKE_OBJCXX_SIMULATE_ID" "Identification string of the \"simulated\" compiler." nil)
    ("CMAKE_Swift_SIMULATE_ID" "Identification string of the \"simulated\" compiler." nil)
    ("CMAKE_ASM_SIMULATE_VERSION" "Version string of \"simulated\" compiler." nil)
    ("CMAKE_ASM_ATT_SIMULATE_VERSION" "Version string of \"simulated\" compiler." nil)
    ("CMAKE_ASM_MARMASM_SIMULATE_VERSION" "Version string of \"simulated\" compiler." nil)
    ("CMAKE_ASM_MASM_SIMULATE_VERSION" "Version string of \"simulated\" compiler." nil)
    ("CMAKE_ASM_NASM_SIMULATE_VERSION" "Version string of \"simulated\" compiler." nil)
    ("CMAKE_C_SIMULATE_VERSION" "Version string of \"simulated\" compiler." nil)
    ("CMAKE_CSharp_SIMULATE_VERSION" "Version string of \"simulated\" compiler." nil)
    ("CMAKE_CUDA_SIMULATE_VERSION" "Version string of \"simulated\" compiler." nil)
    ("CMAKE_CXX_SIMULATE_VERSION" "Version string of \"simulated\" compiler." nil)
    ("CMAKE_Fortran_SIMULATE_VERSION" "Version string of \"simulated\" compiler." nil)
    ("CMAKE_HIP_SIMULATE_VERSION" "Version string of \"simulated\" compiler." nil)
    ("CMAKE_ISPC_SIMULATE_VERSION" "Version string of \"simulated\" compiler." nil)
    ("CMAKE_OBJC_SIMULATE_VERSION" "Version string of \"simulated\" compiler." nil)
    ("CMAKE_OBJCXX_SIMULATE_VERSION" "Version string of \"simulated\" compiler." nil)
    ("CMAKE_Swift_SIMULATE_VERSION" "Version string of \"simulated\" compiler." nil)
    ("CMAKE_ASM_SIZEOF_DATA_PTR" "Size of pointer-to-data types for language ``<LANG>``." nil)
    ("CMAKE_ASM_ATT_SIZEOF_DATA_PTR" "Size of pointer-to-data types for language ``<LANG>``." nil)
    ("CMAKE_ASM_MARMASM_SIZEOF_DATA_PTR" "Size of pointer-to-data types for language ``<LANG>``." nil)
    ("CMAKE_ASM_MASM_SIZEOF_DATA_PTR" "Size of pointer-to-data types for language ``<LANG>``." nil)
    ("CMAKE_ASM_NASM_SIZEOF_DATA_PTR" "Size of pointer-to-data types for language ``<LANG>``." nil)
    ("CMAKE_C_SIZEOF_DATA_PTR" "Size of pointer-to-data types for language ``<LANG>``." nil)
    ("CMAKE_CSharp_SIZEOF_DATA_PTR" "Size of pointer-to-data types for language ``<LANG>``." nil)
    ("CMAKE_CUDA_SIZEOF_DATA_PTR" "Size of pointer-to-data types for language ``<LANG>``." nil)
    ("CMAKE_CXX_SIZEOF_DATA_PTR" "Size of pointer-to-data types for language ``<LANG>``." nil)
    ("CMAKE_Fortran_SIZEOF_DATA_PTR" "Size of pointer-to-data types for language ``<LANG>``." nil)
    ("CMAKE_HIP_SIZEOF_DATA_PTR" "Size of pointer-to-data types for language ``<LANG>``." nil)
    ("CMAKE_ISPC_SIZEOF_DATA_PTR" "Size of pointer-to-data types for language ``<LANG>``." nil)
    ("CMAKE_OBJC_SIZEOF_DATA_PTR" "Size of pointer-to-data types for language ``<LANG>``." nil)
    ("CMAKE_OBJCXX_SIZEOF_DATA_PTR" "Size of pointer-to-data types for language ``<LANG>``." nil)
    ("CMAKE_Swift_SIZEOF_DATA_PTR" "Size of pointer-to-data types for language ``<LANG>``." nil)
    ("CMAKE_ASM_SOURCE_FILE_EXTENSIONS" "Extensions of source files for the given language." nil)
    ("CMAKE_ASM_ATT_SOURCE_FILE_EXTENSIONS" "Extensions of source files for the given language." nil)
    ("CMAKE_ASM_MARMASM_SOURCE_FILE_EXTENSIONS" "Extensions of source files for the given language." nil)
    ("CMAKE_ASM_MASM_SOURCE_FILE_EXTENSIONS" "Extensions of source files for the given language." nil)
    ("CMAKE_ASM_NASM_SOURCE_FILE_EXTENSIONS" "Extensions of source files for the given language." nil)
    ("CMAKE_C_SOURCE_FILE_EXTENSIONS" "Extensions of source files for the given language." nil)
    ("CMAKE_CSharp_SOURCE_FILE_EXTENSIONS" "Extensions of source files for the given language." nil)
    ("CMAKE_CUDA_SOURCE_FILE_EXTENSIONS" "Extensions of source files for the given language." nil)
    ("CMAKE_CXX_SOURCE_FILE_EXTENSIONS" "Extensions of source files for the given language." nil)
    ("CMAKE_Fortran_SOURCE_FILE_EXTENSIONS" "Extensions of source files for the given language." nil)
    ("CMAKE_HIP_SOURCE_FILE_EXTENSIONS" "Extensions of source files for the given language." nil)
    ("CMAKE_ISPC_SOURCE_FILE_EXTENSIONS" "Extensions of source files for the given language." nil)
    ("CMAKE_OBJC_SOURCE_FILE_EXTENSIONS" "Extensions of source files for the given language." nil)
    ("CMAKE_OBJCXX_SOURCE_FILE_EXTENSIONS" "Extensions of source files for the given language." nil)
    ("CMAKE_Swift_SOURCE_FILE_EXTENSIONS" "Extensions of source files for the given language." nil)
    ("CMAKE_ASM_STANDARD" "The variations are:" nil)
    ("CMAKE_ASM_ATT_STANDARD" "The variations are:" nil)
    ("CMAKE_ASM_MARMASM_STANDARD" "The variations are:" nil)
    ("CMAKE_ASM_MASM_STANDARD" "The variations are:" nil)
    ("CMAKE_ASM_NASM_STANDARD" "The variations are:" nil)
    ("CMAKE_C_STANDARD" "The variations are:" nil)
    ("CMAKE_CSharp_STANDARD" "The variations are:" nil)
    ("CMAKE_CUDA_STANDARD" "The variations are:" nil)
    ("CMAKE_CXX_STANDARD" "The variations are:" nil)
    ("CMAKE_Fortran_STANDARD" "The variations are:" nil)
    ("CMAKE_HIP_STANDARD" "The variations are:" nil)
    ("CMAKE_ISPC_STANDARD" "The variations are:" nil)
    ("CMAKE_OBJC_STANDARD" "The variations are:" nil)
    ("CMAKE_OBJCXX_STANDARD" "The variations are:" nil)
    ("CMAKE_Swift_STANDARD" "The variations are:" nil)
    ("CMAKE_ASM_STANDARD_DEFAULT" "The compiler's default standard for the language ``<LANG>``. Empty if the
compiler has no conception of standard levels." nil)
    ("CMAKE_ASM_ATT_STANDARD_DEFAULT" "The compiler's default standard for the language ``<LANG>``. Empty if the
compiler has no conception of standard levels." nil)
    ("CMAKE_ASM_MARMASM_STANDARD_DEFAULT" "The compiler's default standard for the language ``<LANG>``. Empty if the
compiler has no conception of standard levels." nil)
    ("CMAKE_ASM_MASM_STANDARD_DEFAULT" "The compiler's default standard for the language ``<LANG>``. Empty if the
compiler has no conception of standard levels." nil)
    ("CMAKE_ASM_NASM_STANDARD_DEFAULT" "The compiler's default standard for the language ``<LANG>``. Empty if the
compiler has no conception of standard levels." nil)
    ("CMAKE_C_STANDARD_DEFAULT" "The compiler's default standard for the language ``<LANG>``. Empty if the
compiler has no conception of standard levels." nil)
    ("CMAKE_CSharp_STANDARD_DEFAULT" "The compiler's default standard for the language ``<LANG>``. Empty if the
compiler has no conception of standard levels." nil)
    ("CMAKE_CUDA_STANDARD_DEFAULT" "The compiler's default standard for the language ``<LANG>``. Empty if the
compiler has no conception of standard levels." nil)
    ("CMAKE_CXX_STANDARD_DEFAULT" "The compiler's default standard for the language ``<LANG>``. Empty if the
compiler has no conception of standard levels." nil)
    ("CMAKE_Fortran_STANDARD_DEFAULT" "The compiler's default standard for the language ``<LANG>``. Empty if the
compiler has no conception of standard levels." nil)
    ("CMAKE_HIP_STANDARD_DEFAULT" "The compiler's default standard for the language ``<LANG>``. Empty if the
compiler has no conception of standard levels." nil)
    ("CMAKE_ISPC_STANDARD_DEFAULT" "The compiler's default standard for the language ``<LANG>``. Empty if the
compiler has no conception of standard levels." nil)
    ("CMAKE_OBJC_STANDARD_DEFAULT" "The compiler's default standard for the language ``<LANG>``. Empty if the
compiler has no conception of standard levels." nil)
    ("CMAKE_OBJCXX_STANDARD_DEFAULT" "The compiler's default standard for the language ``<LANG>``. Empty if the
compiler has no conception of standard levels." nil)
    ("CMAKE_Swift_STANDARD_DEFAULT" "The compiler's default standard for the language ``<LANG>``. Empty if the
compiler has no conception of standard levels." nil)
    ("CMAKE_ASM_STANDARD_INCLUDE_DIRECTORIES" "Include directories to be used for every source file compiled with
the ``<LANG>`` compiler." nil)
    ("CMAKE_ASM_ATT_STANDARD_INCLUDE_DIRECTORIES" "Include directories to be used for every source file compiled with
the ``<LANG>`` compiler." nil)
    ("CMAKE_ASM_MARMASM_STANDARD_INCLUDE_DIRECTORIES" "Include directories to be used for every source file compiled with
the ``<LANG>`` compiler." nil)
    ("CMAKE_ASM_MASM_STANDARD_INCLUDE_DIRECTORIES" "Include directories to be used for every source file compiled with
the ``<LANG>`` compiler." nil)
    ("CMAKE_ASM_NASM_STANDARD_INCLUDE_DIRECTORIES" "Include directories to be used for every source file compiled with
the ``<LANG>`` compiler." nil)
    ("CMAKE_C_STANDARD_INCLUDE_DIRECTORIES" "Include directories to be used for every source file compiled with
the ``<LANG>`` compiler." nil)
    ("CMAKE_CSharp_STANDARD_INCLUDE_DIRECTORIES" "Include directories to be used for every source file compiled with
the ``<LANG>`` compiler." nil)
    ("CMAKE_CUDA_STANDARD_INCLUDE_DIRECTORIES" "Include directories to be used for every source file compiled with
the ``<LANG>`` compiler." nil)
    ("CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES" "Include directories to be used for every source file compiled with
the ``<LANG>`` compiler." nil)
    ("CMAKE_Fortran_STANDARD_INCLUDE_DIRECTORIES" "Include directories to be used for every source file compiled with
the ``<LANG>`` compiler." nil)
    ("CMAKE_HIP_STANDARD_INCLUDE_DIRECTORIES" "Include directories to be used for every source file compiled with
the ``<LANG>`` compiler." nil)
    ("CMAKE_ISPC_STANDARD_INCLUDE_DIRECTORIES" "Include directories to be used for every source file compiled with
the ``<LANG>`` compiler." nil)
    ("CMAKE_OBJC_STANDARD_INCLUDE_DIRECTORIES" "Include directories to be used for every source file compiled with
the ``<LANG>`` compiler." nil)
    ("CMAKE_OBJCXX_STANDARD_INCLUDE_DIRECTORIES" "Include directories to be used for every source file compiled with
the ``<LANG>`` compiler." nil)
    ("CMAKE_Swift_STANDARD_INCLUDE_DIRECTORIES" "Include directories to be used for every source file compiled with
the ``<LANG>`` compiler." nil)
    ("CMAKE_ASM_STANDARD_LATEST" "This variable represents the minimum between the latest version of the
standard for language ``<LANG>`` which is supported by the current compiler
and the latest version which is supported by CMake. Its value will be set to
one of the supported values of the corresponding :prop_tgt:`<LANG>_STANDARD`
target property; see the documentation of that property for a list of
supported languages." "  ``CMAKE_<LANG>_STANDARD_LATEST`` will never be set to a language standard
  which CMake recognizes but provides no support for. Unless explicitly
  stated otherwise, every value which is supported by the corresponding
  :prop_tgt:`<LANG>_STANDARD` target property represents a standard of
  language ``<LANG>`` which is both recognized and supported by CMake.")
    ("CMAKE_ASM_ATT_STANDARD_LATEST" "This variable represents the minimum between the latest version of the
standard for language ``<LANG>`` which is supported by the current compiler
and the latest version which is supported by CMake. Its value will be set to
one of the supported values of the corresponding :prop_tgt:`<LANG>_STANDARD`
target property; see the documentation of that property for a list of
supported languages." "  ``CMAKE_<LANG>_STANDARD_LATEST`` will never be set to a language standard
  which CMake recognizes but provides no support for. Unless explicitly
  stated otherwise, every value which is supported by the corresponding
  :prop_tgt:`<LANG>_STANDARD` target property represents a standard of
  language ``<LANG>`` which is both recognized and supported by CMake.")
    ("CMAKE_ASM_MARMASM_STANDARD_LATEST" "This variable represents the minimum between the latest version of the
standard for language ``<LANG>`` which is supported by the current compiler
and the latest version which is supported by CMake. Its value will be set to
one of the supported values of the corresponding :prop_tgt:`<LANG>_STANDARD`
target property; see the documentation of that property for a list of
supported languages." "  ``CMAKE_<LANG>_STANDARD_LATEST`` will never be set to a language standard
  which CMake recognizes but provides no support for. Unless explicitly
  stated otherwise, every value which is supported by the corresponding
  :prop_tgt:`<LANG>_STANDARD` target property represents a standard of
  language ``<LANG>`` which is both recognized and supported by CMake.")
    ("CMAKE_ASM_MASM_STANDARD_LATEST" "This variable represents the minimum between the latest version of the
standard for language ``<LANG>`` which is supported by the current compiler
and the latest version which is supported by CMake. Its value will be set to
one of the supported values of the corresponding :prop_tgt:`<LANG>_STANDARD`
target property; see the documentation of that property for a list of
supported languages." "  ``CMAKE_<LANG>_STANDARD_LATEST`` will never be set to a language standard
  which CMake recognizes but provides no support for. Unless explicitly
  stated otherwise, every value which is supported by the corresponding
  :prop_tgt:`<LANG>_STANDARD` target property represents a standard of
  language ``<LANG>`` which is both recognized and supported by CMake.")
    ("CMAKE_ASM_NASM_STANDARD_LATEST" "This variable represents the minimum between the latest version of the
standard for language ``<LANG>`` which is supported by the current compiler
and the latest version which is supported by CMake. Its value will be set to
one of the supported values of the corresponding :prop_tgt:`<LANG>_STANDARD`
target property; see the documentation of that property for a list of
supported languages." "  ``CMAKE_<LANG>_STANDARD_LATEST`` will never be set to a language standard
  which CMake recognizes but provides no support for. Unless explicitly
  stated otherwise, every value which is supported by the corresponding
  :prop_tgt:`<LANG>_STANDARD` target property represents a standard of
  language ``<LANG>`` which is both recognized and supported by CMake.")
    ("CMAKE_C_STANDARD_LATEST" "This variable represents the minimum between the latest version of the
standard for language ``<LANG>`` which is supported by the current compiler
and the latest version which is supported by CMake. Its value will be set to
one of the supported values of the corresponding :prop_tgt:`<LANG>_STANDARD`
target property; see the documentation of that property for a list of
supported languages." "  ``CMAKE_<LANG>_STANDARD_LATEST`` will never be set to a language standard
  which CMake recognizes but provides no support for. Unless explicitly
  stated otherwise, every value which is supported by the corresponding
  :prop_tgt:`<LANG>_STANDARD` target property represents a standard of
  language ``<LANG>`` which is both recognized and supported by CMake.")
    ("CMAKE_CSharp_STANDARD_LATEST" "This variable represents the minimum between the latest version of the
standard for language ``<LANG>`` which is supported by the current compiler
and the latest version which is supported by CMake. Its value will be set to
one of the supported values of the corresponding :prop_tgt:`<LANG>_STANDARD`
target property; see the documentation of that property for a list of
supported languages." "  ``CMAKE_<LANG>_STANDARD_LATEST`` will never be set to a language standard
  which CMake recognizes but provides no support for. Unless explicitly
  stated otherwise, every value which is supported by the corresponding
  :prop_tgt:`<LANG>_STANDARD` target property represents a standard of
  language ``<LANG>`` which is both recognized and supported by CMake.")
    ("CMAKE_CUDA_STANDARD_LATEST" "This variable represents the minimum between the latest version of the
standard for language ``<LANG>`` which is supported by the current compiler
and the latest version which is supported by CMake. Its value will be set to
one of the supported values of the corresponding :prop_tgt:`<LANG>_STANDARD`
target property; see the documentation of that property for a list of
supported languages." "  ``CMAKE_<LANG>_STANDARD_LATEST`` will never be set to a language standard
  which CMake recognizes but provides no support for. Unless explicitly
  stated otherwise, every value which is supported by the corresponding
  :prop_tgt:`<LANG>_STANDARD` target property represents a standard of
  language ``<LANG>`` which is both recognized and supported by CMake.")
    ("CMAKE_CXX_STANDARD_LATEST" "This variable represents the minimum between the latest version of the
standard for language ``<LANG>`` which is supported by the current compiler
and the latest version which is supported by CMake. Its value will be set to
one of the supported values of the corresponding :prop_tgt:`<LANG>_STANDARD`
target property; see the documentation of that property for a list of
supported languages." "  ``CMAKE_<LANG>_STANDARD_LATEST`` will never be set to a language standard
  which CMake recognizes but provides no support for. Unless explicitly
  stated otherwise, every value which is supported by the corresponding
  :prop_tgt:`<LANG>_STANDARD` target property represents a standard of
  language ``<LANG>`` which is both recognized and supported by CMake.")
    ("CMAKE_Fortran_STANDARD_LATEST" "This variable represents the minimum between the latest version of the
standard for language ``<LANG>`` which is supported by the current compiler
and the latest version which is supported by CMake. Its value will be set to
one of the supported values of the corresponding :prop_tgt:`<LANG>_STANDARD`
target property; see the documentation of that property for a list of
supported languages." "  ``CMAKE_<LANG>_STANDARD_LATEST`` will never be set to a language standard
  which CMake recognizes but provides no support for. Unless explicitly
  stated otherwise, every value which is supported by the corresponding
  :prop_tgt:`<LANG>_STANDARD` target property represents a standard of
  language ``<LANG>`` which is both recognized and supported by CMake.")
    ("CMAKE_HIP_STANDARD_LATEST" "This variable represents the minimum between the latest version of the
standard for language ``<LANG>`` which is supported by the current compiler
and the latest version which is supported by CMake. Its value will be set to
one of the supported values of the corresponding :prop_tgt:`<LANG>_STANDARD`
target property; see the documentation of that property for a list of
supported languages." "  ``CMAKE_<LANG>_STANDARD_LATEST`` will never be set to a language standard
  which CMake recognizes but provides no support for. Unless explicitly
  stated otherwise, every value which is supported by the corresponding
  :prop_tgt:`<LANG>_STANDARD` target property represents a standard of
  language ``<LANG>`` which is both recognized and supported by CMake.")
    ("CMAKE_ISPC_STANDARD_LATEST" "This variable represents the minimum between the latest version of the
standard for language ``<LANG>`` which is supported by the current compiler
and the latest version which is supported by CMake. Its value will be set to
one of the supported values of the corresponding :prop_tgt:`<LANG>_STANDARD`
target property; see the documentation of that property for a list of
supported languages." "  ``CMAKE_<LANG>_STANDARD_LATEST`` will never be set to a language standard
  which CMake recognizes but provides no support for. Unless explicitly
  stated otherwise, every value which is supported by the corresponding
  :prop_tgt:`<LANG>_STANDARD` target property represents a standard of
  language ``<LANG>`` which is both recognized and supported by CMake.")
    ("CMAKE_OBJC_STANDARD_LATEST" "This variable represents the minimum between the latest version of the
standard for language ``<LANG>`` which is supported by the current compiler
and the latest version which is supported by CMake. Its value will be set to
one of the supported values of the corresponding :prop_tgt:`<LANG>_STANDARD`
target property; see the documentation of that property for a list of
supported languages." "  ``CMAKE_<LANG>_STANDARD_LATEST`` will never be set to a language standard
  which CMake recognizes but provides no support for. Unless explicitly
  stated otherwise, every value which is supported by the corresponding
  :prop_tgt:`<LANG>_STANDARD` target property represents a standard of
  language ``<LANG>`` which is both recognized and supported by CMake.")
    ("CMAKE_OBJCXX_STANDARD_LATEST" "This variable represents the minimum between the latest version of the
standard for language ``<LANG>`` which is supported by the current compiler
and the latest version which is supported by CMake. Its value will be set to
one of the supported values of the corresponding :prop_tgt:`<LANG>_STANDARD`
target property; see the documentation of that property for a list of
supported languages." "  ``CMAKE_<LANG>_STANDARD_LATEST`` will never be set to a language standard
  which CMake recognizes but provides no support for. Unless explicitly
  stated otherwise, every value which is supported by the corresponding
  :prop_tgt:`<LANG>_STANDARD` target property represents a standard of
  language ``<LANG>`` which is both recognized and supported by CMake.")
    ("CMAKE_Swift_STANDARD_LATEST" "This variable represents the minimum between the latest version of the
standard for language ``<LANG>`` which is supported by the current compiler
and the latest version which is supported by CMake. Its value will be set to
one of the supported values of the corresponding :prop_tgt:`<LANG>_STANDARD`
target property; see the documentation of that property for a list of
supported languages." "  ``CMAKE_<LANG>_STANDARD_LATEST`` will never be set to a language standard
  which CMake recognizes but provides no support for. Unless explicitly
  stated otherwise, every value which is supported by the corresponding
  :prop_tgt:`<LANG>_STANDARD` target property represents a standard of
  language ``<LANG>`` which is both recognized and supported by CMake.")
    ("CMAKE_ASM_STANDARD_LIBRARIES" "Libraries linked into every executable and shared library linked
for language ``<LANG>``." nil)
    ("CMAKE_ASM_ATT_STANDARD_LIBRARIES" "Libraries linked into every executable and shared library linked
for language ``<LANG>``." nil)
    ("CMAKE_ASM_MARMASM_STANDARD_LIBRARIES" "Libraries linked into every executable and shared library linked
for language ``<LANG>``." nil)
    ("CMAKE_ASM_MASM_STANDARD_LIBRARIES" "Libraries linked into every executable and shared library linked
for language ``<LANG>``." nil)
    ("CMAKE_ASM_NASM_STANDARD_LIBRARIES" "Libraries linked into every executable and shared library linked
for language ``<LANG>``." nil)
    ("CMAKE_C_STANDARD_LIBRARIES" "Libraries linked into every executable and shared library linked
for language ``<LANG>``." nil)
    ("CMAKE_CSharp_STANDARD_LIBRARIES" "Libraries linked into every executable and shared library linked
for language ``<LANG>``." nil)
    ("CMAKE_CUDA_STANDARD_LIBRARIES" "Libraries linked into every executable and shared library linked
for language ``<LANG>``." nil)
    ("CMAKE_CXX_STANDARD_LIBRARIES" "Libraries linked into every executable and shared library linked
for language ``<LANG>``." nil)
    ("CMAKE_Fortran_STANDARD_LIBRARIES" "Libraries linked into every executable and shared library linked
for language ``<LANG>``." nil)
    ("CMAKE_HIP_STANDARD_LIBRARIES" "Libraries linked into every executable and shared library linked
for language ``<LANG>``." nil)
    ("CMAKE_ISPC_STANDARD_LIBRARIES" "Libraries linked into every executable and shared library linked
for language ``<LANG>``." nil)
    ("CMAKE_OBJC_STANDARD_LIBRARIES" "Libraries linked into every executable and shared library linked
for language ``<LANG>``." nil)
    ("CMAKE_OBJCXX_STANDARD_LIBRARIES" "Libraries linked into every executable and shared library linked
for language ``<LANG>``." nil)
    ("CMAKE_Swift_STANDARD_LIBRARIES" "Libraries linked into every executable and shared library linked
for language ``<LANG>``." nil)
    ("CMAKE_ASM_STANDARD_LINK_DIRECTORIES" "Link directories specified for every executable and library linked
for language ``<LANG>``." nil)
    ("CMAKE_ASM_ATT_STANDARD_LINK_DIRECTORIES" "Link directories specified for every executable and library linked
for language ``<LANG>``." nil)
    ("CMAKE_ASM_MARMASM_STANDARD_LINK_DIRECTORIES" "Link directories specified for every executable and library linked
for language ``<LANG>``." nil)
    ("CMAKE_ASM_MASM_STANDARD_LINK_DIRECTORIES" "Link directories specified for every executable and library linked
for language ``<LANG>``." nil)
    ("CMAKE_ASM_NASM_STANDARD_LINK_DIRECTORIES" "Link directories specified for every executable and library linked
for language ``<LANG>``." nil)
    ("CMAKE_C_STANDARD_LINK_DIRECTORIES" "Link directories specified for every executable and library linked
for language ``<LANG>``." nil)
    ("CMAKE_CSharp_STANDARD_LINK_DIRECTORIES" "Link directories specified for every executable and library linked
for language ``<LANG>``." nil)
    ("CMAKE_CUDA_STANDARD_LINK_DIRECTORIES" "Link directories specified for every executable and library linked
for language ``<LANG>``." nil)
    ("CMAKE_CXX_STANDARD_LINK_DIRECTORIES" "Link directories specified for every executable and library linked
for language ``<LANG>``." nil)
    ("CMAKE_Fortran_STANDARD_LINK_DIRECTORIES" "Link directories specified for every executable and library linked
for language ``<LANG>``." nil)
    ("CMAKE_HIP_STANDARD_LINK_DIRECTORIES" "Link directories specified for every executable and library linked
for language ``<LANG>``." nil)
    ("CMAKE_ISPC_STANDARD_LINK_DIRECTORIES" "Link directories specified for every executable and library linked
for language ``<LANG>``." nil)
    ("CMAKE_OBJC_STANDARD_LINK_DIRECTORIES" "Link directories specified for every executable and library linked
for language ``<LANG>``." nil)
    ("CMAKE_OBJCXX_STANDARD_LINK_DIRECTORIES" "Link directories specified for every executable and library linked
for language ``<LANG>``." nil)
    ("CMAKE_Swift_STANDARD_LINK_DIRECTORIES" "Link directories specified for every executable and library linked
for language ``<LANG>``." nil)
    ("CMAKE_ASM_STANDARD_REQUIRED" "The variations are:" nil)
    ("CMAKE_ASM_ATT_STANDARD_REQUIRED" "The variations are:" nil)
    ("CMAKE_ASM_MARMASM_STANDARD_REQUIRED" "The variations are:" nil)
    ("CMAKE_ASM_MASM_STANDARD_REQUIRED" "The variations are:" nil)
    ("CMAKE_ASM_NASM_STANDARD_REQUIRED" "The variations are:" nil)
    ("CMAKE_C_STANDARD_REQUIRED" "The variations are:" nil)
    ("CMAKE_CSharp_STANDARD_REQUIRED" "The variations are:" nil)
    ("CMAKE_CUDA_STANDARD_REQUIRED" "The variations are:" nil)
    ("CMAKE_CXX_STANDARD_REQUIRED" "The variations are:" nil)
    ("CMAKE_Fortran_STANDARD_REQUIRED" "The variations are:" nil)
    ("CMAKE_HIP_STANDARD_REQUIRED" "The variations are:" nil)
    ("CMAKE_ISPC_STANDARD_REQUIRED" "The variations are:" nil)
    ("CMAKE_OBJC_STANDARD_REQUIRED" "The variations are:" nil)
    ("CMAKE_OBJCXX_STANDARD_REQUIRED" "The variations are:" nil)
    ("CMAKE_Swift_STANDARD_REQUIRED" "The variations are:" nil)
    ("CMAKE_ASM_USING_LINKER_MODE" "This controls how the value of the :variable:`CMAKE_<LANG>_USING_LINKER_<TYPE>`
variable should be interpreted. The supported linker mode values are:" "  The variable must be set accordingly to how CMake manage the link step:")
    ("CMAKE_ASM_ATT_USING_LINKER_MODE" "This controls how the value of the :variable:`CMAKE_<LANG>_USING_LINKER_<TYPE>`
variable should be interpreted. The supported linker mode values are:" "  The variable must be set accordingly to how CMake manage the link step:")
    ("CMAKE_ASM_MARMASM_USING_LINKER_MODE" "This controls how the value of the :variable:`CMAKE_<LANG>_USING_LINKER_<TYPE>`
variable should be interpreted. The supported linker mode values are:" "  The variable must be set accordingly to how CMake manage the link step:")
    ("CMAKE_ASM_MASM_USING_LINKER_MODE" "This controls how the value of the :variable:`CMAKE_<LANG>_USING_LINKER_<TYPE>`
variable should be interpreted. The supported linker mode values are:" "  The variable must be set accordingly to how CMake manage the link step:")
    ("CMAKE_ASM_NASM_USING_LINKER_MODE" "This controls how the value of the :variable:`CMAKE_<LANG>_USING_LINKER_<TYPE>`
variable should be interpreted. The supported linker mode values are:" "  The variable must be set accordingly to how CMake manage the link step:")
    ("CMAKE_C_USING_LINKER_MODE" "This controls how the value of the :variable:`CMAKE_<LANG>_USING_LINKER_<TYPE>`
variable should be interpreted. The supported linker mode values are:" "  The variable must be set accordingly to how CMake manage the link step:")
    ("CMAKE_CSharp_USING_LINKER_MODE" "This controls how the value of the :variable:`CMAKE_<LANG>_USING_LINKER_<TYPE>`
variable should be interpreted. The supported linker mode values are:" "  The variable must be set accordingly to how CMake manage the link step:")
    ("CMAKE_CUDA_USING_LINKER_MODE" "This controls how the value of the :variable:`CMAKE_<LANG>_USING_LINKER_<TYPE>`
variable should be interpreted. The supported linker mode values are:" "  The variable must be set accordingly to how CMake manage the link step:")
    ("CMAKE_CXX_USING_LINKER_MODE" "This controls how the value of the :variable:`CMAKE_<LANG>_USING_LINKER_<TYPE>`
variable should be interpreted. The supported linker mode values are:" "  The variable must be set accordingly to how CMake manage the link step:")
    ("CMAKE_Fortran_USING_LINKER_MODE" "This controls how the value of the :variable:`CMAKE_<LANG>_USING_LINKER_<TYPE>`
variable should be interpreted. The supported linker mode values are:" "  The variable must be set accordingly to how CMake manage the link step:")
    ("CMAKE_HIP_USING_LINKER_MODE" "This controls how the value of the :variable:`CMAKE_<LANG>_USING_LINKER_<TYPE>`
variable should be interpreted. The supported linker mode values are:" "  The variable must be set accordingly to how CMake manage the link step:")
    ("CMAKE_ISPC_USING_LINKER_MODE" "This controls how the value of the :variable:`CMAKE_<LANG>_USING_LINKER_<TYPE>`
variable should be interpreted. The supported linker mode values are:" "  The variable must be set accordingly to how CMake manage the link step:")
    ("CMAKE_OBJC_USING_LINKER_MODE" "This controls how the value of the :variable:`CMAKE_<LANG>_USING_LINKER_<TYPE>`
variable should be interpreted. The supported linker mode values are:" "  The variable must be set accordingly to how CMake manage the link step:")
    ("CMAKE_OBJCXX_USING_LINKER_MODE" "This controls how the value of the :variable:`CMAKE_<LANG>_USING_LINKER_<TYPE>`
variable should be interpreted. The supported linker mode values are:" "  The variable must be set accordingly to how CMake manage the link step:")
    ("CMAKE_Swift_USING_LINKER_MODE" "This controls how the value of the :variable:`CMAKE_<LANG>_USING_LINKER_<TYPE>`
variable should be interpreted. The supported linker mode values are:" "  The variable must be set accordingly to how CMake manage the link step:")
    ("CMAKE_ASM_USING_LINKER_TYPE" "This variable defines how to specify the ``<TYPE>`` linker for the link step,
as controlled by the :variable:`CMAKE_LINKER_TYPE` variable or the
:prop_tgt:`LINKER_TYPE` target property. Depending on the value of the
:variable:`CMAKE_<LANG>_LINK_MODE` variable,
``CMAKE_<LANG>_USING_LINKER_<TYPE>`` can hold compiler flags for the link step,
or the path to the linker tool." "The type of information stored in this variable is now determined by the
:variable:`CMAKE_<LANG>_LINK_MODE` variable instead of the
:variable:`CMAKE_<LANG>_USING_LINKER_MODE` variable.")
    ("CMAKE_ASM_ATT_USING_LINKER_TYPE" "This variable defines how to specify the ``<TYPE>`` linker for the link step,
as controlled by the :variable:`CMAKE_LINKER_TYPE` variable or the
:prop_tgt:`LINKER_TYPE` target property. Depending on the value of the
:variable:`CMAKE_<LANG>_LINK_MODE` variable,
``CMAKE_<LANG>_USING_LINKER_<TYPE>`` can hold compiler flags for the link step,
or the path to the linker tool." "The type of information stored in this variable is now determined by the
:variable:`CMAKE_<LANG>_LINK_MODE` variable instead of the
:variable:`CMAKE_<LANG>_USING_LINKER_MODE` variable.")
    ("CMAKE_ASM_MARMASM_USING_LINKER_TYPE" "This variable defines how to specify the ``<TYPE>`` linker for the link step,
as controlled by the :variable:`CMAKE_LINKER_TYPE` variable or the
:prop_tgt:`LINKER_TYPE` target property. Depending on the value of the
:variable:`CMAKE_<LANG>_LINK_MODE` variable,
``CMAKE_<LANG>_USING_LINKER_<TYPE>`` can hold compiler flags for the link step,
or the path to the linker tool." "The type of information stored in this variable is now determined by the
:variable:`CMAKE_<LANG>_LINK_MODE` variable instead of the
:variable:`CMAKE_<LANG>_USING_LINKER_MODE` variable.")
    ("CMAKE_ASM_MASM_USING_LINKER_TYPE" "This variable defines how to specify the ``<TYPE>`` linker for the link step,
as controlled by the :variable:`CMAKE_LINKER_TYPE` variable or the
:prop_tgt:`LINKER_TYPE` target property. Depending on the value of the
:variable:`CMAKE_<LANG>_LINK_MODE` variable,
``CMAKE_<LANG>_USING_LINKER_<TYPE>`` can hold compiler flags for the link step,
or the path to the linker tool." "The type of information stored in this variable is now determined by the
:variable:`CMAKE_<LANG>_LINK_MODE` variable instead of the
:variable:`CMAKE_<LANG>_USING_LINKER_MODE` variable.")
    ("CMAKE_ASM_NASM_USING_LINKER_TYPE" "This variable defines how to specify the ``<TYPE>`` linker for the link step,
as controlled by the :variable:`CMAKE_LINKER_TYPE` variable or the
:prop_tgt:`LINKER_TYPE` target property. Depending on the value of the
:variable:`CMAKE_<LANG>_LINK_MODE` variable,
``CMAKE_<LANG>_USING_LINKER_<TYPE>`` can hold compiler flags for the link step,
or the path to the linker tool." "The type of information stored in this variable is now determined by the
:variable:`CMAKE_<LANG>_LINK_MODE` variable instead of the
:variable:`CMAKE_<LANG>_USING_LINKER_MODE` variable.")
    ("CMAKE_C_USING_LINKER_TYPE" "This variable defines how to specify the ``<TYPE>`` linker for the link step,
as controlled by the :variable:`CMAKE_LINKER_TYPE` variable or the
:prop_tgt:`LINKER_TYPE` target property. Depending on the value of the
:variable:`CMAKE_<LANG>_LINK_MODE` variable,
``CMAKE_<LANG>_USING_LINKER_<TYPE>`` can hold compiler flags for the link step,
or the path to the linker tool." "The type of information stored in this variable is now determined by the
:variable:`CMAKE_<LANG>_LINK_MODE` variable instead of the
:variable:`CMAKE_<LANG>_USING_LINKER_MODE` variable.")
    ("CMAKE_CSharp_USING_LINKER_TYPE" "This variable defines how to specify the ``<TYPE>`` linker for the link step,
as controlled by the :variable:`CMAKE_LINKER_TYPE` variable or the
:prop_tgt:`LINKER_TYPE` target property. Depending on the value of the
:variable:`CMAKE_<LANG>_LINK_MODE` variable,
``CMAKE_<LANG>_USING_LINKER_<TYPE>`` can hold compiler flags for the link step,
or the path to the linker tool." "The type of information stored in this variable is now determined by the
:variable:`CMAKE_<LANG>_LINK_MODE` variable instead of the
:variable:`CMAKE_<LANG>_USING_LINKER_MODE` variable.")
    ("CMAKE_CUDA_USING_LINKER_TYPE" "This variable defines how to specify the ``<TYPE>`` linker for the link step,
as controlled by the :variable:`CMAKE_LINKER_TYPE` variable or the
:prop_tgt:`LINKER_TYPE` target property. Depending on the value of the
:variable:`CMAKE_<LANG>_LINK_MODE` variable,
``CMAKE_<LANG>_USING_LINKER_<TYPE>`` can hold compiler flags for the link step,
or the path to the linker tool." "The type of information stored in this variable is now determined by the
:variable:`CMAKE_<LANG>_LINK_MODE` variable instead of the
:variable:`CMAKE_<LANG>_USING_LINKER_MODE` variable.")
    ("CMAKE_CXX_USING_LINKER_TYPE" "This variable defines how to specify the ``<TYPE>`` linker for the link step,
as controlled by the :variable:`CMAKE_LINKER_TYPE` variable or the
:prop_tgt:`LINKER_TYPE` target property. Depending on the value of the
:variable:`CMAKE_<LANG>_LINK_MODE` variable,
``CMAKE_<LANG>_USING_LINKER_<TYPE>`` can hold compiler flags for the link step,
or the path to the linker tool." "The type of information stored in this variable is now determined by the
:variable:`CMAKE_<LANG>_LINK_MODE` variable instead of the
:variable:`CMAKE_<LANG>_USING_LINKER_MODE` variable.")
    ("CMAKE_Fortran_USING_LINKER_TYPE" "This variable defines how to specify the ``<TYPE>`` linker for the link step,
as controlled by the :variable:`CMAKE_LINKER_TYPE` variable or the
:prop_tgt:`LINKER_TYPE` target property. Depending on the value of the
:variable:`CMAKE_<LANG>_LINK_MODE` variable,
``CMAKE_<LANG>_USING_LINKER_<TYPE>`` can hold compiler flags for the link step,
or the path to the linker tool." "The type of information stored in this variable is now determined by the
:variable:`CMAKE_<LANG>_LINK_MODE` variable instead of the
:variable:`CMAKE_<LANG>_USING_LINKER_MODE` variable.")
    ("CMAKE_HIP_USING_LINKER_TYPE" "This variable defines how to specify the ``<TYPE>`` linker for the link step,
as controlled by the :variable:`CMAKE_LINKER_TYPE` variable or the
:prop_tgt:`LINKER_TYPE` target property. Depending on the value of the
:variable:`CMAKE_<LANG>_LINK_MODE` variable,
``CMAKE_<LANG>_USING_LINKER_<TYPE>`` can hold compiler flags for the link step,
or the path to the linker tool." "The type of information stored in this variable is now determined by the
:variable:`CMAKE_<LANG>_LINK_MODE` variable instead of the
:variable:`CMAKE_<LANG>_USING_LINKER_MODE` variable.")
    ("CMAKE_ISPC_USING_LINKER_TYPE" "This variable defines how to specify the ``<TYPE>`` linker for the link step,
as controlled by the :variable:`CMAKE_LINKER_TYPE` variable or the
:prop_tgt:`LINKER_TYPE` target property. Depending on the value of the
:variable:`CMAKE_<LANG>_LINK_MODE` variable,
``CMAKE_<LANG>_USING_LINKER_<TYPE>`` can hold compiler flags for the link step,
or the path to the linker tool." "The type of information stored in this variable is now determined by the
:variable:`CMAKE_<LANG>_LINK_MODE` variable instead of the
:variable:`CMAKE_<LANG>_USING_LINKER_MODE` variable.")
    ("CMAKE_OBJC_USING_LINKER_TYPE" "This variable defines how to specify the ``<TYPE>`` linker for the link step,
as controlled by the :variable:`CMAKE_LINKER_TYPE` variable or the
:prop_tgt:`LINKER_TYPE` target property. Depending on the value of the
:variable:`CMAKE_<LANG>_LINK_MODE` variable,
``CMAKE_<LANG>_USING_LINKER_<TYPE>`` can hold compiler flags for the link step,
or the path to the linker tool." "The type of information stored in this variable is now determined by the
:variable:`CMAKE_<LANG>_LINK_MODE` variable instead of the
:variable:`CMAKE_<LANG>_USING_LINKER_MODE` variable.")
    ("CMAKE_OBJCXX_USING_LINKER_TYPE" "This variable defines how to specify the ``<TYPE>`` linker for the link step,
as controlled by the :variable:`CMAKE_LINKER_TYPE` variable or the
:prop_tgt:`LINKER_TYPE` target property. Depending on the value of the
:variable:`CMAKE_<LANG>_LINK_MODE` variable,
``CMAKE_<LANG>_USING_LINKER_<TYPE>`` can hold compiler flags for the link step,
or the path to the linker tool." "The type of information stored in this variable is now determined by the
:variable:`CMAKE_<LANG>_LINK_MODE` variable instead of the
:variable:`CMAKE_<LANG>_USING_LINKER_MODE` variable.")
    ("CMAKE_Swift_USING_LINKER_TYPE" "This variable defines how to specify the ``<TYPE>`` linker for the link step,
as controlled by the :variable:`CMAKE_LINKER_TYPE` variable or the
:prop_tgt:`LINKER_TYPE` target property. Depending on the value of the
:variable:`CMAKE_<LANG>_LINK_MODE` variable,
``CMAKE_<LANG>_USING_LINKER_<TYPE>`` can hold compiler flags for the link step,
or the path to the linker tool." "The type of information stored in this variable is now determined by the
:variable:`CMAKE_<LANG>_LINK_MODE` variable instead of the
:variable:`CMAKE_<LANG>_USING_LINKER_MODE` variable.")
    ("CMAKE_ASM_VISIBILITY_PRESET" "Default value for the :prop_tgt:`<LANG>_VISIBILITY_PRESET` target
property when a target is created." nil)
    ("CMAKE_ASM_ATT_VISIBILITY_PRESET" "Default value for the :prop_tgt:`<LANG>_VISIBILITY_PRESET` target
property when a target is created." nil)
    ("CMAKE_ASM_MARMASM_VISIBILITY_PRESET" "Default value for the :prop_tgt:`<LANG>_VISIBILITY_PRESET` target
property when a target is created." nil)
    ("CMAKE_ASM_MASM_VISIBILITY_PRESET" "Default value for the :prop_tgt:`<LANG>_VISIBILITY_PRESET` target
property when a target is created." nil)
    ("CMAKE_ASM_NASM_VISIBILITY_PRESET" "Default value for the :prop_tgt:`<LANG>_VISIBILITY_PRESET` target
property when a target is created." nil)
    ("CMAKE_C_VISIBILITY_PRESET" "Default value for the :prop_tgt:`<LANG>_VISIBILITY_PRESET` target
property when a target is created." nil)
    ("CMAKE_CSharp_VISIBILITY_PRESET" "Default value for the :prop_tgt:`<LANG>_VISIBILITY_PRESET` target
property when a target is created." nil)
    ("CMAKE_CUDA_VISIBILITY_PRESET" "Default value for the :prop_tgt:`<LANG>_VISIBILITY_PRESET` target
property when a target is created." nil)
    ("CMAKE_CXX_VISIBILITY_PRESET" "Default value for the :prop_tgt:`<LANG>_VISIBILITY_PRESET` target
property when a target is created." nil)
    ("CMAKE_Fortran_VISIBILITY_PRESET" "Default value for the :prop_tgt:`<LANG>_VISIBILITY_PRESET` target
property when a target is created." nil)
    ("CMAKE_HIP_VISIBILITY_PRESET" "Default value for the :prop_tgt:`<LANG>_VISIBILITY_PRESET` target
property when a target is created." nil)
    ("CMAKE_ISPC_VISIBILITY_PRESET" "Default value for the :prop_tgt:`<LANG>_VISIBILITY_PRESET` target
property when a target is created." nil)
    ("CMAKE_OBJC_VISIBILITY_PRESET" "Default value for the :prop_tgt:`<LANG>_VISIBILITY_PRESET` target
property when a target is created." nil)
    ("CMAKE_OBJCXX_VISIBILITY_PRESET" "Default value for the :prop_tgt:`<LANG>_VISIBILITY_PRESET` target
property when a target is created." nil)
    ("CMAKE_Swift_VISIBILITY_PRESET" "Default value for the :prop_tgt:`<LANG>_VISIBILITY_PRESET` target
property when a target is created." nil)
    ("CMAKE_LIBRARY_ARCHITECTURE" "Target architecture library directory name, if detected." nil)
    ("CMAKE_LIBRARY_ARCHITECTURE_REGEX" "Regex matching possible target architecture library directory names." nil)
    ("CMAKE_LIBRARY_OUTPUT_DIRECTORY" "Where to put all the :ref:`LIBRARY <Library Output Artifacts>`
target files when built." nil)
    ("CMAKE_LIBRARY_OUTPUT_DIRECTORY_CONFIG" "Where to put all the :ref:`LIBRARY <Library Output Artifacts>`
target files when built for a specific configuration." nil)
    ("CMAKE_LIBRARY_PATH" ":ref:`Semicolon-separated list <CMake Language Lists>` of directories specifying a search path
for the :command:`find_library` command." nil)
    ("CMAKE_LIBRARY_PATH_FLAG" "The flag to be used to add a library search path to a compiler." nil)
    ("CMAKE_LINKER_TYPE" "Specify which linker will be used for the link step." nil)
    ("CMAKE_LINK_DEF_FILE_FLAG" "Linker flag to be used to specify a ``.def`` file for dll creation." nil)
    ("CMAKE_LINK_DEPENDS_NO_SHARED" "Whether to skip link dependencies on shared library files." nil)
    ("CMAKE_LINK_DEPENDS_USE_LINKER" "For the :ref:`Makefile <Makefile Generators>` and
:ref:`Ninja <Ninja Generators>` generators, link dependencies are now, for a
selection of linkers, generated by the linker itself. By defining this
variable with value ``FALSE``, you can deactivate this feature." "  CMake version |release| defaults this variable to ``FALSE`` if the linker is
  one from the GNU binutils linkers (``ld`` and ``ld.bfd`` for version less
  than 2.41 or ``ld.gold`` for any version) because it generate spurious
  dependencies on temporary files when LTO is enabled.  See `GNU bug 30568`_.")
    ("CMAKE_LINK_DIRECTORIES_BEFORE" "Whether to append or prepend directories by default in
:command:`link_directories`." nil)
    ("CMAKE_LINK_GROUP_USING_FEATURE" "This variable defines how to link a group of libraries for the specified
``<FEATURE>`` when a :genex:`LINK_GROUP` generator expression is used." nil)
    ("CMAKE_LINK_GROUP_USING_FEATURE_SUPPORTED" "This variable specifies whether the ``<FEATURE>`` is supported regardless of
the link language." nil)
    ("CMAKE_LINK_INTERFACE_LIBRARIES" "Default value for :prop_tgt:`LINK_INTERFACE_LIBRARIES` of targets." nil)
    ("CMAKE_LINK_LIBRARIES_ONLY_TARGETS" "Set this variable to initialize the :prop_tgt:`LINK_LIBRARIES_ONLY_TARGETS`
property of non-imported targets when they are created." nil)
    ("CMAKE_LINK_LIBRARIES_STRATEGY" "Specify a strategy for ordering targets' direct link dependencies
on linker command lines." nil)
    ("CMAKE_LINK_LIBRARY_FEATURE_ATTRIBUTES" "This variable defines the behavior of the specified link library
``<FEATURE>``. It specifies how the ``<FEATURE>`` interacts with other
features, when the ``<FEATURE>`` should be applied, and aspects of how the
``<FEATURE>`` should be handled when CMake assembles the final linker
command line (e.g. de-duplication)." "  set(CMAKE_LINK_LIBRARY_WHOLE_ARCHIVE_ATTRIBUTES
    LIBRARY_TYPE=STATIC
    OVERRIDE=DEFAULT
    DEDUPLICATION=YES
  )")
    ("CMAKE_LINK_LIBRARY_FILE_FLAG" "Flag to be used to link a library specified by a path to its file." nil)
    ("CMAKE_LINK_LIBRARY_FLAG" "Flag to be used to link a library into an executable." nil)
    ("CMAKE_LINK_LIBRARY_SUFFIX" "The suffix for libraries that you link to." nil)
    ("CMAKE_LINK_LIBRARY_USING_FEATURE" "This variable defines how to link a library or framework for the specified
``<FEATURE>`` when a :genex:`LINK_LIBRARY` generator expression is used." nil)
    ("CMAKE_LINK_LIBRARY_USING_FEATURE_SUPPORTED" "Set to ``TRUE`` if the ``<FEATURE>``, as defined by variable
:variable:`CMAKE_LINK_LIBRARY_USING_<FEATURE>`, is supported regardless the
linker language." nil)
    ("CMAKE_LINK_SEARCH_END_STATIC" "End a link line such that static system libraries are used." nil)
    ("CMAKE_LINK_SEARCH_START_STATIC" "Assume the linker looks for static libraries by default." nil)
    ("CMAKE_LINK_WARNING_AS_ERROR" "Specify whether to treat warnings on link as errors." nil)
    ("CMAKE_LINK_WHAT_YOU_USE" "Default value for :prop_tgt:`LINK_WHAT_YOU_USE` target property." nil)
    ("CMAKE_LINK_WHAT_YOU_USE_CHECK" "Command executed by :prop_tgt:`LINK_WHAT_YOU_USE` after the linker to
check for unnecessarily-linked shared libraries." nil)
    ("CMAKE_LIST_FILE_NAME" "The name of the CMake project files. This determines the top-level file
processed when CMake is configured, and the file processed by
:command:`add_subdirectory`." nil)
    ("CMAKE_MACOSX_BUNDLE" "Default value for :prop_tgt:`MACOSX_BUNDLE` of targets." nil)
    ("CMAKE_MACOSX_RPATH" "Whether to use rpaths on macOS and iOS." nil)
    ("CMAKE_MAJOR_VERSION" "First version number component of the :variable:`CMAKE_VERSION`
variable." nil)
    ("CMAKE_MAKE_PROGRAM" "Tool that can launch the native build system." nil)
    ("CMAKE_MAP_IMPORTED_CONFIG_CONFIG" "Default value for :prop_tgt:`MAP_IMPORTED_CONFIG_<CONFIG>` of targets." nil)
    ("CMAKE_MATCH_COUNT" "The number of matches with the last regular expression." nil)
    ("CMAKE_MATCH_n" "Capture group ``<n>`` matched by the last regular expression, for groups
0 through 9." nil)
    ("CMAKE_MAXIMUM_RECURSION_DEPTH" "Maximum recursion depth for CMake scripts. It is intended to be set on the
command line with ``-DCMAKE_MAXIMUM_RECURSION_DEPTH=<x>``, or within
``CMakeLists.txt`` by projects that require a large recursion depth. Projects
that set this variable should provide the user with a way to override it. For
example:" "  # About to perform deeply recursive actions
  if(NOT CMAKE_MAXIMUM_RECURSION_DEPTH)
    set(CMAKE_MAXIMUM_RECURSION_DEPTH 2000)
  endif()")
    ("CMAKE_MESSAGE_CONTEXT" "When enabled by the :option:`cmake --log-context` command line
option or the :variable:`CMAKE_MESSAGE_CONTEXT_SHOW` variable, the
:command:`message` command converts the ``CMAKE_MESSAGE_CONTEXT`` list into a
dot-separated string surrounded by square brackets and prepends it to each line
for messages of log levels ``NOTICE`` and below." "  Valid context names are restricted to anything that could be used
  as a CMake variable name.  All names that begin with an underscore
  or the string ``cmake_`` are also reserved for use by CMake and
  should not be used by projects.")
    ("CMAKE_MESSAGE_CONTEXT_SHOW" "Setting this variable to true enables showing a context with each line
logged by the :command:`message` command (see :variable:`CMAKE_MESSAGE_CONTEXT`
for how the context itself is specified)." nil)
    ("CMAKE_MESSAGE_INDENT" "The :command:`message` command joins the strings from this list and for
log levels of ``NOTICE`` and below, it prepends the resultant string to
each line of the message." "  list(APPEND listVar one two three)")
    ("CMAKE_MESSAGE_LOG_LEVEL" "When set, this variable specifies the logging level used by the
:command:`message` command." nil)
    ("CMAKE_MFC_FLAG" "Use the MFC library for an executable or dll." "  add_definitions(-D_AFXDLL)
  set(CMAKE_MFC_FLAG 2)
  add_executable(CMakeSetup WIN32 ${SRCS})")
    ("CMAKE_MINIMUM_REQUIRED_VERSION" "The ``<min>`` version of CMake given to the most recent call to the
:command:`cmake_minimum_required(VERSION)` command in the current
variable scope or any parent variable scope." nil)
    ("CMAKE_MINOR_VERSION" "Second version number component of the :variable:`CMAKE_VERSION`
variable." nil)
    ("CMAKE_MODULE_LINKER_FLAGS" "Linker flags to be used to create modules." nil)
    ("CMAKE_MODULE_LINKER_FLAGS_CONFIG" "Flags to be used when linking a module." nil)
    ("CMAKE_MODULE_LINKER_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_MODULE_LINKER_FLAGS_<CONFIG>`
cache entry the first time a build tree is configured." nil)
    ("CMAKE_MODULE_LINKER_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_MODULE_LINKER_FLAGS`
cache entry the first time a build tree is configured." nil)
    ("CMAKE_MODULE_PATH" ":ref:`Semicolon-separated list <CMake Language Lists>` of directories,
represented using forward slashes, specifying a search path for CMake modules
to be loaded by the :command:`include` or :command:`find_package` commands
before checking the default modules that come with CMake. By default it is
empty. It is intended to be set by the project." "  list(APPEND CMAKE_MODULE_PATH \"${CMAKE_CURRENT_SOURCE_DIR}/cmake\")")
    ("CMAKE_MSVCIDE_RUN_PATH" "Extra PATH locations that should be used when executing
:command:`add_custom_command` or :command:`add_custom_target` when using
:ref:`Visual Studio Generators`." nil)
    ("CMAKE_MSVC_DEBUG_INFORMATION_FORMAT" "Select the MSVC debug information format targeting the MSVC ABI." "Use :manual:`generator expressions <cmake-generator-expressions(7)>` to
support per-configuration specification.  For example, the code:")
    ("CMAKE_MSVC_RUNTIME_CHECKS" "Select the list of enabled runtime checks when targeting the MSVC ABI." "Use :manual:`generator expressions <cmake-generator-expressions(7)>` to
support per-configuration specification. For example, the code:")
    ("CMAKE_MSVC_RUNTIME_LIBRARY" "Select the MSVC runtime library for use by compilers targeting the MSVC ABI." "Use :manual:`generator expressions <cmake-generator-expressions(7)>` to
support per-configuration specification.  For example, the code:")
    ("CMAKE_NETRC" "This variable is used to initialize the ``NETRC`` option for the
:command:`file(DOWNLOAD)` and :command:`file(UPLOAD)` commands." nil)
    ("CMAKE_NETRC_FILE" "This variable is used to initialize the ``NETRC_FILE`` option for the
:command:`file(DOWNLOAD)` and :command:`file(UPLOAD)` commands." nil)
    ("CMAKE_NINJA_OUTPUT_PATH_PREFIX" "Tell the :ref:`Ninja Generators` to add a prefix to every output path in
``build.ninja``." "  cd super-build-dir &&
  cmake -G Ninja -S /path/to/src -B sub -DCMAKE_NINJA_OUTPUT_PATH_PREFIX=sub/
  #                                 ^^^---------- these match -----------^^^")
    ("CMAKE_NOT_USING_CONFIG_FLAGS" "Skip ``_BUILD_TYPE`` flags if true." nil)
    ("CMAKE_NO_BUILTIN_CHRPATH" "Do not use the builtin binary editor to fix runtime library search
paths on installation." nil)
    ("CMAKE_NO_SYSTEM_FROM_IMPORTED" "Default value for :prop_tgt:`NO_SYSTEM_FROM_IMPORTED` of targets." nil)
    ("CMAKE_OBJCXX_EXTENSIONS" "Default value for :prop_tgt:`OBJCXX_EXTENSIONS` target property if set when a
target is created." nil)
    ("CMAKE_OBJCXX_STANDARD" "Default value for :prop_tgt:`OBJCXX_STANDARD` target property if set when a
target is created." nil)
    ("CMAKE_OBJCXX_STANDARD_REQUIRED" "Default value for :prop_tgt:`OBJCXX_STANDARD_REQUIRED` target property if set
when a target is created." nil)
    ("CMAKE_OBJC_EXTENSIONS" "Default value for :prop_tgt:`OBJC_EXTENSIONS` target property if set when a
target is created." nil)
    ("CMAKE_OBJC_STANDARD" "Default value for :prop_tgt:`OBJC_STANDARD` target property if set when a
target is created." nil)
    ("CMAKE_OBJC_STANDARD_REQUIRED" "Default value for :prop_tgt:`OBJC_STANDARD_REQUIRED` target property if set
when a target is created." nil)
    ("CMAKE_OBJDUMP" "Path to the ``objdump`` executable on the host system." nil)
    ("CMAKE_OBJECT_PATH_MAX" "Maximum object file full-path length allowed by native build tools." nil)
    ("CMAKE_OPTIMIZE_DEPENDENCIES" "Initializes the :prop_tgt:`OPTIMIZE_DEPENDENCIES` target property." nil)
    ("CMAKE_OSX_ARCHITECTURES" "Target specific architectures for macOS and iOS." nil)
    ("CMAKE_OSX_DEPLOYMENT_TARGET" "Specify the minimum version of the target platform (e.g. macOS or iOS)
on which the target binaries are to be deployed." nil)
    ("CMAKE_OSX_SYSROOT" "Specify the location or name of the macOS platform SDK to be used." nil)
    ("CMAKE_PARENT_LIST_FILE" "Full path to the CMake file that included the current one." nil)
    ("CMAKE_PATCH_VERSION" "Third version number component of the :variable:`CMAKE_VERSION`
variable." nil)
    ("CMAKE_PCH_INSTANTIATE_TEMPLATES" "This variable is used to initialize the :prop_tgt:`PCH_INSTANTIATE_TEMPLATES`
property of targets when they are created." nil)
    ("CMAKE_PCH_WARN_INVALID" "This variable is used to initialize the :prop_tgt:`PCH_WARN_INVALID`
property of targets when they are created." nil)
    ("CMAKE_PDB_OUTPUT_DIRECTORY" "Output directory for MS debug symbol ``.pdb`` files generated by the
linker for executable and shared library targets." nil)
    ("CMAKE_PDB_OUTPUT_DIRECTORY_CONFIG" "Per-configuration output directory for MS debug symbol ``.pdb`` files
generated by the linker for executable and shared library targets." nil)
    ("CMAKE_PLATFORM_NO_VERSIONED_SONAME" "This variable is used to globally control whether the
:prop_tgt:`VERSION` and :prop_tgt:`SOVERSION` target
properties should be used for shared libraries." nil)
    ("CMAKE_POLICY_DEFAULT_CMPNNNN" "Default for CMake Policy ``CMP<NNNN>`` when it is otherwise left unset." nil)
    ("CMAKE_POLICY_VERSION_MINIMUM" "Specify a minimum :ref:`Policy Version` for a project without modifying
its calls to :command:`cmake_minimum_required(VERSION)` and
:command:`cmake_policy(VERSION)`." nil)
    ("CMAKE_POLICY_WARNING_CMPNNNN" "Explicitly enable or disable the warning when CMake Policy ``CMP<NNNN>``
has not been set explicitly by :command:`cmake_policy` or implicitly
by :command:`cmake_minimum_required`. This is meaningful
only for the policies that do not warn by default:" nil)
    ("CMAKE_POSITION_INDEPENDENT_CODE" "Default value for :prop_tgt:`POSITION_INDEPENDENT_CODE` of targets." nil)
    ("CMAKE_PREFIX_PATH" "Each command will add appropriate
subdirectories (like ``bin``, ``lib``, or ``include``) as specified in its own
documentation." nil)
    ("CMAKE_PROGRAM_PATH" ":ref:`Semicolon-separated list <CMake Language Lists>` of directories specifying a search path
for the :command:`find_program` command." nil)
    ("CMAKE_PROJECT_DESCRIPTION" "The description of the top level project." "  cmake_minimum_required(VERSION 3.0)
  project(First DESCRIPTION \"I am First\")
  project(Second DESCRIPTION \"I am Second\")
  add_subdirectory(sub)
  project(Third DESCRIPTION \"I am Third\")")
    ("CMAKE_PROJECT_HOMEPAGE_URL" "The homepage URL of the top level project." "  cmake_minimum_required(VERSION 3.0)
  project(First HOMEPAGE_URL \"https://first.example.com\")
  project(Second HOMEPAGE_URL \"https://second.example.com\")
  add_subdirectory(sub)
  project(Third HOMEPAGE_URL \"https://third.example.com\")")
    ("CMAKE_PROJECT_INCLUDE" "A CMake language file to be included as the last step of all
:command:`project` command calls." "  This variable can be a :ref:`semicolon-separated list <CMake Language Lists>`
  of CMake language files to be included sequentially. It can also now refer to
  module names to be found in :variable:`CMAKE_MODULE_PATH` or as a builtin
  CMake module.")
    ("CMAKE_PROJECT_INCLUDE_BEFORE" "A CMake language file to be included as the first step of all
:command:`project` command calls." "  This variable can be a :ref:`semicolon-separated list <CMake Language Lists>`
  of CMake language files to be included sequentially. It can also now refer to
  module names to be found in :variable:`CMAKE_MODULE_PATH` or as a builtin
  CMake module.")
    ("CMAKE_PROJECT_NAME" "The name of the top level project." "  cmake_minimum_required(VERSION 3.0)
  project(First)
  project(Second)
  add_subdirectory(sub)
  project(Third)")
    ("CMAKE_PROJECT_PROJECT-NAME_INCLUDE" "A CMake language file to be included as the last step of any
:command:`project` command calls that specify ``<PROJECT-NAME>`` as the project
name." "  This variable can be a :ref:`semicolon-separated list <CMake Language Lists>`
  of CMake language files to be included sequentially. It can also now refer to
  module names to be found in :variable:`CMAKE_MODULE_PATH` or as a builtin
  CMake module.")
    ("CMAKE_PROJECT_PROJECT-NAME_INCLUDE_BEFORE" "A CMake language file to be included as the first step of any
:command:`project` command calls that specify ``<PROJECT-NAME>`` as the project
name." "  This variable can be a :ref:`semicolon-separated list <CMake Language Lists>`
  of CMake language files to be included sequentially. It can also now refer to
  module names to be found in :variable:`CMAKE_MODULE_PATH` or as a builtin
  CMake module.")
    ("CMAKE_PROJECT_TOP_LEVEL_INCLUDES" ":ref:`Semicolon-separated list <CMake Language Lists>` of CMake language
files to include as part of the very first :command:`project` call." "  This variable can also now refer to module names to be found in
  :variable:`CMAKE_MODULE_PATH` or builtin to CMake.")
    ("CMAKE_PROJECT_VERSION" "The version of the top level project." "  cmake_minimum_required(VERSION 3.0)
  project(First VERSION 1.2.3)
  project(Second VERSION 3.4.5)
  add_subdirectory(sub)
  project(Third VERSION 6.7.8)")
    ("CMAKE_PROJECT_VERSION_MAJOR" "The major version of the top level project." nil)
    ("CMAKE_PROJECT_VERSION_MINOR" "The minor version of the top level project." nil)
    ("CMAKE_PROJECT_VERSION_PATCH" "The patch version of the top level project." nil)
    ("CMAKE_PROJECT_VERSION_TWEAK" "The tweak version of the top level project." nil)
    ("CMAKE_RANLIB" "Name of randomizing tool for static libraries." nil)
    ("CMAKE_REQUIRE_FIND_PACKAGE_PackageName" "Variable for making :command:`find_package` call ``REQUIRED``." "  find_package(something PATHS /some/local/path NO_DEFAULT_PATH)
  find_package(something)")
    ("CMAKE_ROOT" "Install directory for running cmake." nil)
    ("CMAKE_RULE_MESSAGES" "Specify whether to report a message for each make rule." nil)
    ("CMAKE_RUNTIME_OUTPUT_DIRECTORY" "Where to put all the :ref:`RUNTIME <Runtime Output Artifacts>`
target files when built." nil)
    ("CMAKE_RUNTIME_OUTPUT_DIRECTORY_CONFIG" "Where to put all the :ref:`RUNTIME <Runtime Output Artifacts>`
target files when built for a specific configuration." nil)
    ("CMAKE_SCRIPT_MODE_FILE" "Full path to the :option:`cmake -P` script file currently being
processed." nil)
    ("CMAKE_SHARED_LIBRARY_ARCHIVE_SUFFIX" "The suffix for archived shared libraries that you link to." nil)
    ("CMAKE_SHARED_LIBRARY_ENABLE_EXPORTS" "Specify whether shared library generates an import file." nil)
    ("CMAKE_SHARED_LIBRARY_PREFIX" "The prefix for shared libraries that you link to." nil)
    ("CMAKE_SHARED_LIBRARY_SUFFIX" "The suffix for shared libraries that you link to." nil)
    ("CMAKE_SHARED_LINKER_FLAGS" "Linker flags to be used to create shared libraries." nil)
    ("CMAKE_SHARED_LINKER_FLAGS_CONFIG" "Flags to be used when linking a shared library." nil)
    ("CMAKE_SHARED_LINKER_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_SHARED_LINKER_FLAGS_<CONFIG>`
cache entry the first time a build tree is configured." nil)
    ("CMAKE_SHARED_LINKER_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_SHARED_LINKER_FLAGS`
cache entry the first time a build tree is configured." nil)
    ("CMAKE_SHARED_MODULE_PREFIX" "The prefix for loadable modules that you link to." nil)
    ("CMAKE_SHARED_MODULE_SUFFIX" "The suffix for shared libraries that you link to." nil)
    ("CMAKE_SIZEOF_VOID_P" "Size of a ``void`` pointer." nil)
    ("CMAKE_SKIP_BUILD_RPATH" "Do not include RPATHs in the build tree." nil)
    ("CMAKE_SKIP_INSTALL_ALL_DEPENDENCY" "Don't make the ``install`` target depend on the ``all`` target." nil)
    ("CMAKE_SKIP_INSTALL_RPATH" "Do not include RPATHs in the install tree." nil)
    ("CMAKE_SKIP_INSTALL_RULES" "Whether to disable generation of installation rules." nil)
    ("CMAKE_SKIP_RPATH" "If true, do not add run time path information." nil)
    ("CMAKE_SKIP_TEST_ALL_DEPENDENCY" "Control whether the ``test`` target depends on the ``all`` target." nil)
    ("CMAKE_SOURCE_DIR" "The path to the top level of the source tree." nil)
    ("CMAKE_STAGING_PREFIX" "This variable may be set to a path to install to when cross-compiling. This can
be useful if the path in :variable:`CMAKE_SYSROOT` is read-only, or otherwise
should remain pristine." nil)
    ("CMAKE_STATIC_LIBRARY_PREFIX" "The prefix for static libraries that you link to." nil)
    ("CMAKE_STATIC_LIBRARY_SUFFIX" "The suffix for static libraries that you link to." nil)
    ("CMAKE_STATIC_LINKER_FLAGS" "Flags to be used to create static libraries." nil)
    ("CMAKE_STATIC_LINKER_FLAGS_CONFIG" "Flags to be used to create static libraries." nil)
    ("CMAKE_STATIC_LINKER_FLAGS_CONFIG_INIT" "Value used to initialize the :variable:`CMAKE_STATIC_LINKER_FLAGS_<CONFIG>`
cache entry the first time a build tree is configured." nil)
    ("CMAKE_STATIC_LINKER_FLAGS_INIT" "Value used to initialize the :variable:`CMAKE_STATIC_LINKER_FLAGS`
cache entry the first time a build tree is configured." nil)
    ("CMAKE_SUBLIME_TEXT_2_ENV_SETTINGS" "This variable contains a list of env vars as a list of tokens with the
syntax ``var=value``." "  set(CMAKE_SUBLIME_TEXT_2_ENV_SETTINGS
     \"FOO=FOO1\\;FOO2\\;FOON\"
     \"BAR=BAR1\\;BAR2\\;BARN\"
     \"BAZ=BAZ1\\;BAZ2\\;BAZN\"
     \"FOOBAR=FOOBAR1\\;FOOBAR2\\;FOOBARN\"
     \"VALID=\"
     )")
    ("CMAKE_SUBLIME_TEXT_2_EXCLUDE_BUILD_TREE" "If this variable evaluates to ``ON`` at the end of the top-level
``CMakeLists.txt`` file, the :generator:`Sublime Text 2` extra generator
excludes the build tree from the ``.sublime-project`` if it is inside the
source tree." nil)
    ("CMAKE_SUPPRESS_REGENERATION" "If ``CMAKE_SUPPRESS_REGENERATION`` is ``OFF``, which is default, then CMake
adds a special target on which all other targets depend that checks the build
system and optionally re-runs CMake to regenerate the build system when
the target specification source changes." nil)
    ("CMAKE_SYSROOT" "Path to pass to the compiler in the ``--sysroot`` flag." nil)
    ("CMAKE_SYSROOT_COMPILE" "Path to pass to the compiler in the ``--sysroot`` flag when compiling source
files." nil)
    ("CMAKE_SYSROOT_LINK" "Path to pass to the compiler in the ``--sysroot`` flag when linking." nil)
    ("CMAKE_SYSTEM" "Composite name of operating system CMake is compiling for." nil)
    ("CMAKE_SYSTEM_APPBUNDLE_PATH" "Search path for macOS application bundles used by the :command:`find_program`,
and :command:`find_package` commands." nil)
    ("CMAKE_SYSTEM_FRAMEWORK_PATH" "Search path for macOS frameworks used by the :command:`find_library`,
:command:`find_package`, :command:`find_path`, and :command:`find_file`
commands." nil)
    ("CMAKE_SYSTEM_IGNORE_PATH" "See also the following variables:" nil)
    ("CMAKE_SYSTEM_IGNORE_PREFIX_PATH" "See also the following variables:" nil)
    ("CMAKE_SYSTEM_INCLUDE_PATH" ":ref:`Semicolon-separated list <CMake Language Lists>` of directories specifying a search path
for the :command:`find_file` and :command:`find_path` commands." nil)
    ("CMAKE_SYSTEM_LIBRARY_PATH" ":ref:`Semicolon-separated list <CMake Language Lists>` of directories specifying a search path
for the :command:`find_library` command." nil)
    ("CMAKE_SYSTEM_NAME" "The name of the operating system for which CMake is to build." nil)
    ("CMAKE_SYSTEM_PREFIX_PATH" "Each command will add appropriate
subdirectories (like ``bin``, ``lib``, or ``include``) as specified in its own
documentation." "  * ``ENV{MSYSTEM_PREFIX}/local``
  * ``ENV{MSYSTEM_PREFIX}``")
    ("CMAKE_SYSTEM_PROCESSOR" "When not cross-compiling, this variable has the same value as the
:variable:`CMAKE_HOST_SYSTEM_PROCESSOR` variable." nil)
    ("CMAKE_SYSTEM_PROGRAM_PATH" ":ref:`Semicolon-separated list <CMake Language Lists>` of directories specifying a search path
for the :command:`find_program` command." nil)
    ("CMAKE_SYSTEM_VERSION" "The version of the operating system for which CMake is to build." nil)
    ("CMAKE_Swift_COMPILATION_MODE" "Specify how Swift compiles a target. This variable is used to initialize the
:prop_tgt:`Swift_COMPILATION_MODE` property on targets as they are created." "Use :manual:`generator expressions <cmake-generator-expressions(7)>` to support
per-configuration specification. For example, the code:")
    ("CMAKE_Swift_LANGUAGE_VERSION" "Set to the Swift language version number." nil)
    ("CMAKE_Swift_MODULE_DIRECTORY" "Swift module output directory." nil)
    ("CMAKE_Swift_NUM_THREADS" "Number of threads for parallel compilation for Swift targets." nil)
    ("CMAKE_TASKING_TOOLSET" "Select the Tasking toolset which provides the compiler" nil)
    ("CMAKE_TEST_LAUNCHER" "This variable is used to initialize the :prop_tgt:`TEST_LAUNCHER` target
property of executable targets as they are created." nil)
    ("CMAKE_TLS_CAINFO" "Specify the default value for the :command:`file(DOWNLOAD)` and
:command:`file(UPLOAD)` commands' ``TLS_CAINFO`` options." nil)
    ("CMAKE_TLS_VERIFY" "Specify the default value for the :command:`file(DOWNLOAD)` and
:command:`file(UPLOAD)` commands' ``TLS_VERIFY`` options." "  The default is on.  Previously, the default was off.
  Users may set the :envvar:`CMAKE_TLS_VERIFY` environment
  variable to ``0`` to restore the old default.")
    ("CMAKE_TLS_VERSION" "Specify the default value for the :command:`file(DOWNLOAD)` and
:command:`file(UPLOAD)` commands' ``TLS_VERSION`` option." "  The default is TLS 1.2.
  Previously, no minimum version was enforced by default.")
    ("CMAKE_TOOLCHAIN_FILE" "Path to toolchain file supplied to :manual:`cmake(1)`." nil)
    ("CMAKE_TRY_COMPILE_CONFIGURATION" "Build configuration used for :command:`try_compile` and :command:`try_run`
projects." nil)
    ("CMAKE_TRY_COMPILE_NO_PLATFORM_VARIABLES" "Set to a true value to tell the :command:`try_compile` command not
to propagate any platform variables into the test project." nil)
    ("CMAKE_TRY_COMPILE_PLATFORM_VARIABLES" "List of variables that the :command:`try_compile` command source file signature
must propagate into the test project in order to target the same platform as
the host project." "  set(CMAKE_SYSTEM_NAME ...)
  set(CMAKE_TRY_COMPILE_PLATFORM_VARIABLES MY_CUSTOM_VARIABLE)
  # ... use MY_CUSTOM_VARIABLE ...")
    ("CMAKE_TRY_COMPILE_TARGET_TYPE" "Type of target generated for :command:`try_compile` calls using the
source file signature." nil)
    ("CMAKE_TWEAK_VERSION" "Defined to ``0`` for compatibility with code written for older
CMake versions that may have defined higher values." nil)
    ("CMAKE_UNITY_BUILD" "This variable is used to initialize the :prop_tgt:`UNITY_BUILD`
property of targets when they are created." nil)
    ("CMAKE_UNITY_BUILD_BATCH_SIZE" "This variable is used to initialize the :prop_tgt:`UNITY_BUILD_BATCH_SIZE`
property of targets when they are created." nil)
    ("CMAKE_UNITY_BUILD_UNIQUE_ID" "This variable is used to initialize the :prop_tgt:`UNITY_BUILD_UNIQUE_ID`
property of targets when they are created." nil)
    ("CMAKE_USER_MAKE_RULES_OVERRIDE" "Specify a CMake file that overrides platform information." nil)
    ("CMAKE_USER_MAKE_RULES_OVERRIDE_LANG" "Specify a CMake file that overrides platform information for ``<LANG>``." nil)
    ("CMAKE_USE_RELATIVE_PATHS" "This variable has no effect." nil)
    ("CMAKE_VERBOSE_MAKEFILE" "Enable verbose output from Makefile builds." nil)
    ("CMAKE_VERIFY_INTERFACE_HEADER_SETS" "This variable is used to initialize the
:prop_tgt:`VERIFY_INTERFACE_HEADER_SETS` property of targets when they are
created." "  # Save original setting so we can restore it later
  set(want_header_set_verification ${CMAKE_VERIFY_INTERFACE_HEADER_SETS})")
    ("CMAKE_VERSION" "The CMake version string as three non-negative integer components
separated by ``.`` and possibly followed by ``-`` and other information." "  <major>.<minor>.<patch>[-rc<n>]")
    ("CMAKE_VISIBILITY_INLINES_HIDDEN" "Default value for the :prop_tgt:`VISIBILITY_INLINES_HIDDEN` target
property when a target is created." nil)
    ("CMAKE_VS_DEBUGGER_COMMAND" "This variable is used to initialize the :prop_tgt:`VS_DEBUGGER_COMMAND`
property on each target as it is created." nil)
    ("CMAKE_VS_DEBUGGER_COMMAND_ARGUMENTS" "This variable is used to initialize the :prop_tgt:`VS_DEBUGGER_COMMAND_ARGUMENTS`
property on each target as it is created." nil)
    ("CMAKE_VS_DEBUGGER_ENVIRONMENT" "This variable is used to initialize the :prop_tgt:`VS_DEBUGGER_ENVIRONMENT`
property on each target as it is created." nil)
    ("CMAKE_VS_DEBUGGER_WORKING_DIRECTORY" "This variable is used to initialize the :prop_tgt:`VS_DEBUGGER_WORKING_DIRECTORY`
property on each target as it is created." nil)
    ("CMAKE_VS_DEVENV_COMMAND" "The :ref:`Visual Studio Generators` set this variable to the ``devenv.com``
command installed with the corresponding Visual Studio version." nil)
    ("CMAKE_VS_GLOBALS" "List of ``Key=Value`` records to be set per target as target properties
:prop_tgt:`VS_GLOBAL_<variable>` with ``variable=Key`` and value ``Value``." "  set(CMAKE_VS_GLOBALS
    \"DefaultLanguage=en-US\"
    \"MinimumVisualStudioVersion=14.0\"
    )")
    ("CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD" "Include ``INSTALL`` target to default build." nil)
    ("CMAKE_VS_INCLUDE_PACKAGE_TO_DEFAULT_BUILD" "Include ``PACKAGE`` target to default build." nil)
    ("CMAKE_VS_INTEL_Fortran_PROJECT_VERSION" "When generating for :generator:`Visual Studio 14 2015` or greater with the Intel
Fortran plugin installed, this specifies the ``.vfproj`` project file format
version." nil)
    ("CMAKE_VS_JUST_MY_CODE_DEBUGGING" "Enable Just My Code with Visual Studio debugger." nil)
    ("CMAKE_VS_MSBUILD_COMMAND" "The :ref:`Visual Studio Generators` set this variable to the ``MSBuild.exe``
command installed with the corresponding Visual Studio version." nil)
    ("CMAKE_VS_NO_COMPILE_BATCHING" "Turn off compile batching when using :ref:`Visual Studio Generators`." nil)
    ("CMAKE_VS_NUGET_PACKAGE_RESTORE" "When using a Visual Studio generator, this cache variable controls
if msbuild should automatically attempt to restore NuGet packages
prior to a build. NuGet packages can be defined using the
:prop_tgt:`VS_PACKAGE_REFERENCES` property on a target. If no
package references are defined, this setting will do nothing." nil)
    ("CMAKE_VS_NsightTegra_VERSION" "When using a Visual Studio generator with the
:variable:`CMAKE_SYSTEM_NAME` variable set to ``Android``,
this variable contains the version number of the
installed NVIDIA Nsight Tegra Visual Studio Edition." nil)
    ("CMAKE_VS_PLATFORM_NAME" "Visual Studio target platform name used by the current generator." nil)
    ("CMAKE_VS_PLATFORM_NAME_DEFAULT" "Default for the Visual Studio target platform name for the current generator
without considering the value of the :variable:`CMAKE_GENERATOR_PLATFORM`
variable." nil)
    ("CMAKE_VS_PLATFORM_TOOLSET" "Visual Studio Platform Toolset name." nil)
    ("CMAKE_VS_PLATFORM_TOOLSET_CUDA" "NVIDIA CUDA Toolkit version whose Visual Studio toolset to use." nil)
    ("CMAKE_VS_PLATFORM_TOOLSET_CUDA_CUSTOM_DIR" "Path to standalone NVIDIA CUDA Toolkit (eg. extracted from installer)." nil)
    ("CMAKE_VS_PLATFORM_TOOLSET_FORTRAN" "Fortran compiler to be used by Visual Studio projects." nil)
    ("CMAKE_VS_PLATFORM_TOOLSET_HOST_ARCHITECTURE" "Visual Studio preferred tool architecture." nil)
    ("CMAKE_VS_PLATFORM_TOOLSET_VERSION" "Visual Studio Platform Toolset version." "   VS 16.9's toolset may also be specified as ``14.28.16.9`` because
   VS 16.10 uses the file name ``Microsoft.VCToolsVersion.14.28.16.9.props``.")
    ("CMAKE_VS_SDK_EXCLUDE_DIRECTORIES" "This variable allows to override Visual Studio default Exclude Directories." nil)
    ("CMAKE_VS_SDK_EXECUTABLE_DIRECTORIES" "This variable allows to override Visual Studio default Executable Directories." nil)
    ("CMAKE_VS_SDK_INCLUDE_DIRECTORIES" "This variable allows to override Visual Studio default Include Directories." nil)
    ("CMAKE_VS_SDK_LIBRARY_DIRECTORIES" "This variable allows to override Visual Studio default Library Directories." nil)
    ("CMAKE_VS_SDK_LIBRARY_WINRT_DIRECTORIES" "This variable allows to override Visual Studio default Library WinRT
Directories." nil)
    ("CMAKE_VS_SDK_REFERENCE_DIRECTORIES" "This variable allows to override Visual Studio default Reference Directories." nil)
    ("CMAKE_VS_SDK_SOURCE_DIRECTORIES" "This variable allows to override Visual Studio default Source Directories." nil)
    ("CMAKE_VS_TARGET_FRAMEWORK_IDENTIFIER" "Visual Studio target framework identifier." nil)
    ("CMAKE_VS_TARGET_FRAMEWORK_TARGETS_VERSION" "Visual Studio target framework targets version." nil)
    ("CMAKE_VS_TARGET_FRAMEWORK_VERSION" "Visual Studio target framework version." nil)
    ("CMAKE_VS_USE_DEBUG_LIBRARIES" "Use :manual:`generator expressions <cmake-generator-expressions(7)>`
for per-configuration specification." "  set(CMAKE_VS_USE_DEBUG_LIBRARIES \"$<CONFIG:Debug,Custom>\")")
    ("CMAKE_VS_VERSION_BUILD_NUMBER" "Visual Studio version." nil)
    ("CMAKE_VS_WINDOWS_TARGET_PLATFORM_MIN_VERSION" "Tell :ref:`Visual Studio Generators` to use the given
Windows Target Platform Minimum Version." nil)
    ("CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION" "Visual Studio Windows Target Platform Version." "    This is enabled by policy :policy:`CMP0149`.")
    ("CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION_MAXIMUM" "Override the :ref:`Windows 10 SDK Maximum Version for VS 2015` and beyond." nil)
    ("CMAKE_VS_WINRT_BY_DEFAULT" "Inform :ref:`Visual Studio Generators` for VS 2010 and above that the
target platform enables WinRT compilation by default and it needs to
be explicitly disabled if ``/ZW`` or :prop_tgt:`VS_WINRT_COMPONENT` is
omitted (as opposed to enabling it when either of those options is
present)" nil)
    ("CMAKE_WARN_DEPRECATED" "Whether to issue warnings for deprecated functionality." nil)
    ("CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION" "Ask ``cmake_install.cmake`` script to warn each time a file with absolute
``INSTALL DESTINATION`` is encountered." nil)
    ("CMAKE_WATCOM_RUNTIME_LIBRARY" "Select the Watcom runtime library for use by compilers targeting the Watcom ABI." "Use :manual:`generator expressions <cmake-generator-expressions(7)>` to
support per-configuration specification.")
    ("CMAKE_WIN32_EXECUTABLE" "Default value for :prop_tgt:`WIN32_EXECUTABLE` of targets." nil)
    ("CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS" "Default value for :prop_tgt:`WINDOWS_EXPORT_ALL_SYMBOLS` target property." nil)
    ("CMAKE_WINDOWS_KMDF_VERSION" "Specify the `Kernel-Mode Drive Framework`_ target version." nil)
    ("CMAKE_XCODE_ATTRIBUTE_an-attribute" "Set Xcode target attributes directly." nil)
    ("CMAKE_XCODE_BUILD_SYSTEM" "Xcode build system selection." nil)
    ("CMAKE_XCODE_GENERATE_SCHEME" "If enabled, the :generator:`Xcode` generator will generate schema files." nil)
    ("CMAKE_XCODE_GENERATE_TOP_LEVEL_PROJECT_ONLY" "If enabled, the :generator:`Xcode` generator will generate only a
single Xcode project file for the topmost :command:`project()` command
instead of generating one for every ``project()`` command." nil)
    ("CMAKE_XCODE_LINK_BUILD_PHASE_MODE" "This variable is used to initialize the
:prop_tgt:`XCODE_LINK_BUILD_PHASE_MODE` property on targets." nil)
    ("CMAKE_XCODE_PLATFORM_TOOLSET" "Xcode compiler selection." nil)
    ("CMAKE_XCODE_SCHEME_ADDRESS_SANITIZER" "Whether to enable ``Address Sanitizer`` in the Diagnostics
section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_ADDRESS_SANITIZER_USE_AFTER_RETURN" "Whether to enable ``Detect use of stack after return``
in the Diagnostics section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_DEBUG_DOCUMENT_VERSIONING" "Whether to enable
``Allow debugging when using document Versions Browser``
in the Options section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_DISABLE_MAIN_THREAD_CHECKER" "Whether to disable the ``Main Thread Checker``
in the Diagnostics section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_DYNAMIC_LIBRARY_LOADS" "Whether to enable ``Dynamic Library Loads``
in the Diagnostics section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_DYNAMIC_LINKER_API_USAGE" "Whether to enable ``Dynamic Linker API usage``
in the Diagnostics section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_ENABLE_GPU_API_VALIDATION" "Property value for ``Metal: API Validation`` in the Options section of
the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_ENABLE_GPU_FRAME_CAPTURE_MODE" "Property value for ``GPU Frame Capture`` in the Options section of
the generated Xcode scheme. Example values are ``Metal`` and
``Disabled``." nil)
    ("CMAKE_XCODE_SCHEME_ENABLE_GPU_SHADER_VALIDATION" "Property value for ``Metal: Shader Validation`` in the Options section of
the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_ENVIRONMENT" "Specify environment variables that should be added to the Arguments
section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_GUARD_MALLOC" "Whether to enable ``Guard Malloc``
in the Diagnostics section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_LAUNCH_CONFIGURATION" "Set the build configuration to run the target." nil)
    ("CMAKE_XCODE_SCHEME_LAUNCH_MODE" "Property value for ``Launch`` in the Info section of the generated Xcode
scheme." nil)
    ("CMAKE_XCODE_SCHEME_LLDB_INIT_FILE" "Property value for ``LLDB Init File`` in the Info section of the generated Xcode
scheme." nil)
    ("CMAKE_XCODE_SCHEME_MAIN_THREAD_CHECKER_STOP" "Whether to enable the ``Main Thread Checker`` option
``Pause on issues``
in the Diagnostics section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_MALLOC_GUARD_EDGES" "Whether to enable ``Malloc Guard Edges``
in the Diagnostics section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_MALLOC_SCRIBBLE" "Whether to enable ``Malloc Scribble``
in the Diagnostics section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_MALLOC_STACK" "Whether to enable ``Malloc Stack`` in the Diagnostics
section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_TEST_CONFIGURATION" "Set the build configuration to test the target." nil)
    ("CMAKE_XCODE_SCHEME_THREAD_SANITIZER" "Whether to enable ``Thread Sanitizer`` in the Diagnostics
section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_THREAD_SANITIZER_STOP" "Whether to enable ``Thread Sanitizer - Pause on issues``
in the Diagnostics section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_UNDEFINED_BEHAVIOUR_SANITIZER" "Whether to enable ``Undefined Behavior Sanitizer``
in the Diagnostics section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_UNDEFINED_BEHAVIOUR_SANITIZER_STOP" "Whether to enable ``Undefined Behavior Sanitizer`` option
``Pause on issues``
in the Diagnostics section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_WORKING_DIRECTORY" "Specify the ``Working Directory`` of the *Run* and *Profile*
actions in the generated Xcode scheme." nil)
    ("CMAKE_XCODE_SCHEME_ZOMBIE_OBJECTS" "Whether to enable ``Zombie Objects``
in the Diagnostics section of the generated Xcode scheme." nil)
    ("CMAKE_XCODE_XCCONFIG" "If set, the :generator:`Xcode` generator will register the specified
file as a global XCConfig file. For target-level XCConfig files see
the :prop_tgt:`XCODE_XCCONFIG` target property." nil)
    ("CPACK_ABSOLUTE_DESTINATION_FILES" "List of files which have been installed using an ``ABSOLUTE DESTINATION`` path." nil)
    ("CPACK_COMPONENT_INCLUDE_TOPLEVEL_DIRECTORY" "Boolean toggle to include/exclude top level directory (component case)." nil)
    ("CPACK_CUSTOM_INSTALL_VARIABLES" "CPack variables (set via e.g. :option:`cpack -D`, ``CPackConfig.cmake`` or
:variable:`CPACK_PROJECT_CONFIG_FILE` scripts) are not directly visible in
installation scripts." "  install(FILES large.txt DESTINATION data)")
    ("CPACK_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION" "Ask CPack to error out as soon as a file with absolute ``INSTALL DESTINATION``
is encountered." nil)
    ("CPACK_INCLUDE_TOPLEVEL_DIRECTORY" "Boolean toggle to include/exclude top level directory." nil)
    ("CPACK_INSTALL_DEFAULT_DIRECTORY_PERMISSIONS" "Default permissions for implicitly created directories during packaging." nil)
    ("CPACK_PACKAGING_INSTALL_PREFIX" "The prefix used in the built package." "  set(CPACK_PACKAGING_INSTALL_PREFIX \"/opt\")")
    ("CPACK_SET_DESTDIR" "Boolean toggle to make CPack use ``DESTDIR`` mechanism when packaging." " make DESTDIR=/home/john install")
    ("CPACK_WARN_ON_ABSOLUTE_INSTALL_DESTINATION" "Ask CPack to warn each time a file with absolute ``INSTALL DESTINATION`` is
encountered." nil)
    ("CTEST_BINARY_DIRECTORY" "Specify the CTest ``BuildDirectory`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_BUILD_COMMAND" "Specify the CTest ``MakeCommand`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_BUILD_NAME" "Specify the CTest ``BuildName`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_BZR_COMMAND" "Specify the CTest ``BZRCommand`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_BZR_UPDATE_OPTIONS" "Specify the CTest ``BZRUpdateOptions`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_CHANGE_ID" "Specify the CTest ``ChangeId`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_CHECKOUT_COMMAND" "Tell the :command:`ctest_start` command how to checkout or initialize
the source directory in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_CONFIGURATION_TYPE" "Specify the CTest ``DefaultCTestConfigurationType`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_CONFIGURE_COMMAND" "Specify the CTest ``ConfigureCommand`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_COVERAGE_COMMAND" "Specify the CTest ``CoverageCommand`` setting
in a :manual:`ctest(1)` dashboard client script." "  set(CTEST_COVERAGE_COMMAND .../run-coverage-and-consolidate.sh)")
    ("CTEST_COVERAGE_EXTRA_FLAGS" "Specify the CTest ``CoverageExtraFlags`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_CURL_OPTIONS" "Specify the CTest ``CurlOptions`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_CUSTOM_COVERAGE_EXCLUDE" "A list of regular expressions which will be used to exclude files by their
path from coverage output by the :command:`ctest_coverage` command." nil)
    ("CTEST_CUSTOM_ERROR_EXCEPTION" "A list of regular expressions which will be used to exclude when detecting
error messages in build outputs by the :command:`ctest_build` command." nil)
    ("CTEST_CUSTOM_ERROR_MATCH" "A list of regular expressions which will be used to detect error messages in
build outputs by the :command:`ctest_build` command." nil)
    ("CTEST_CUSTOM_ERROR_POST_CONTEXT" "The number of lines to include as context which follow an error message by the
:command:`ctest_build` command. The default is 10." nil)
    ("CTEST_CUSTOM_ERROR_PRE_CONTEXT" "The number of lines to include as context which precede an error message by
the :command:`ctest_build` command. The default is 10." nil)
    ("CTEST_CUSTOM_MAXIMUM_FAILED_TEST_OUTPUT_SIZE" "When saving a failing test's output, this is the maximum size, in bytes, that
will be collected by the :command:`ctest_test` command. Defaults to 307200
(300 KiB). See :variable:`CTEST_CUSTOM_TEST_OUTPUT_TRUNCATION` for possible
truncation modes." nil)
    ("CTEST_CUSTOM_MAXIMUM_NUMBER_OF_ERRORS" "The maximum number of errors in a single build step which will be detected." nil)
    ("CTEST_CUSTOM_MAXIMUM_NUMBER_OF_WARNINGS" "The maximum number of warnings in a single build step which will be detected." nil)
    ("CTEST_CUSTOM_MAXIMUM_PASSED_TEST_OUTPUT_SIZE" "When saving a passing test's output, this is the maximum size, in bytes, that
will be collected by the :command:`ctest_test` command. Defaults to 1024
(1 KiB). See :variable:`CTEST_CUSTOM_TEST_OUTPUT_TRUNCATION` for possible
truncation modes." nil)
    ("CTEST_CUSTOM_MEMCHECK_IGNORE" "A list of regular expressions to use to exclude tests during the
:command:`ctest_memcheck` command." nil)
    ("CTEST_CUSTOM_POST_MEMCHECK" "A list of commands to run at the end of the :command:`ctest_memcheck` command." nil)
    ("CTEST_CUSTOM_POST_TEST" "A list of commands to run at the end of the :command:`ctest_test` command." nil)
    ("CTEST_CUSTOM_PRE_MEMCHECK" "A list of commands to run at the start of the :command:`ctest_memcheck`
command." nil)
    ("CTEST_CUSTOM_PRE_TEST" "A list of commands to run at the start of the :command:`ctest_test` command." nil)
    ("CTEST_CUSTOM_TESTS_IGNORE" "A list of test names to be excluded from the set of tests run by the
:command:`ctest_test` command." nil)
    ("CTEST_CUSTOM_TEST_OUTPUT_TRUNCATION" "Set the test output truncation mode in case a maximum size is configured
via the :variable:`CTEST_CUSTOM_MAXIMUM_PASSED_TEST_OUTPUT_SIZE` or
:variable:`CTEST_CUSTOM_MAXIMUM_FAILED_TEST_OUTPUT_SIZE` variables." nil)
    ("CTEST_CUSTOM_WARNING_EXCEPTION" "A list of regular expressions which will be used to exclude when detecting
warning messages in build outputs by the :command:`ctest_build` command." nil)
    ("CTEST_CUSTOM_WARNING_MATCH" "A list of regular expressions which will be used to detect warning messages in
build outputs by the :command:`ctest_build` command." nil)
    ("CTEST_CVS_CHECKOUT" "Deprecated." nil)
    ("CTEST_CVS_COMMAND" "Specify the CTest ``CVSCommand`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_CVS_UPDATE_OPTIONS" "Specify the CTest ``CVSUpdateOptions`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_DROP_LOCATION" "Specify the CTest ``DropLocation`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_DROP_METHOD" "Specify the CTest ``DropMethod`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_DROP_SITE" "Specify the CTest ``DropSite`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_DROP_SITE_CDASH" "Specify the CTest ``IsCDash`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_DROP_SITE_PASSWORD" "Specify the CTest ``DropSitePassword`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_DROP_SITE_USER" "Specify the CTest ``DropSiteUser`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_EXTRA_COVERAGE_GLOB" "A list of regular expressions which will be used to find files which should be
covered by the :command:`ctest_coverage` command." nil)
    ("CTEST_EXTRA_SUBMIT_FILES" "Specify files for :command:`ctest_submit(PARTS ExtraFiles)` to submit
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_GIT_COMMAND" "Specify the CTest ``GITCommand`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_GIT_INIT_SUBMODULES" "Specify the CTest ``GITInitSubmodules`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_GIT_UPDATE_CUSTOM" "Specify the CTest ``GITUpdateCustom`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_GIT_UPDATE_OPTIONS" "Specify the CTest ``GITUpdateOptions`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_HG_COMMAND" "Specify the CTest ``HGCommand`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_HG_UPDATE_OPTIONS" "Specify the CTest ``HGUpdateOptions`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_LABELS_FOR_SUBPROJECTS" "Specify the CTest ``LabelsForSubprojects`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_MEMORYCHECK_COMMAND" "Specify the CTest ``MemoryCheckCommand`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_MEMORYCHECK_COMMAND_OPTIONS" "Specify the CTest ``MemoryCheckCommandOptions`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_MEMORYCHECK_SANITIZER_OPTIONS" "Specify the CTest ``MemoryCheckSanitizerOptions`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_MEMORYCHECK_SUPPRESSIONS_FILE" "Specify the CTest ``MemoryCheckSuppressionFile`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_MEMORYCHECK_TYPE" "Specify the CTest ``MemoryCheckType`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_NIGHTLY_START_TIME" "Specify the CTest ``NightlyStartTime`` setting in a :manual:`ctest(1)`
dashboard client script." nil)
    ("CTEST_NOTES_FILES" "Specify files for :command:`ctest_submit(PARTS Notes)` to submit
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_P4_CLIENT" "Specify the CTest ``P4Client`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_P4_COMMAND" "Specify the CTest ``P4Command`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_P4_OPTIONS" "Specify the CTest ``P4Options`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_P4_UPDATE_OPTIONS" "Specify the CTest ``P4UpdateOptions`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_RESOURCE_SPEC_FILE" "Specify the CTest ``ResourceSpecFile`` setting in a :manual:`ctest(1)`
dashboard client script." nil)
    ("CTEST_RUN_CURRENT_SCRIPT" "Removed." nil)
    ("CTEST_SCP_COMMAND" "Legacy option." nil)
    ("CTEST_SCRIPT_DIRECTORY" "The directory containing the top-level CTest script." nil)
    ("CTEST_SITE" "Specify the CTest ``Site`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_SOURCE_DIRECTORY" "Specify the CTest ``SourceDirectory`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_SUBMIT_INACTIVITY_TIMEOUT" "Specify the CTest ``SubmitInactivityTimeout`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_SUBMIT_URL" "Specify the CTest ``SubmitURL`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_SVN_COMMAND" "Specify the CTest ``SVNCommand`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_SVN_OPTIONS" "Specify the CTest ``SVNOptions`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_SVN_UPDATE_OPTIONS" "Specify the CTest ``SVNUpdateOptions`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_TEST_LOAD" "Specify the ``TestLoad`` setting in the :ref:`CTest Test Step`
of a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_TEST_TIMEOUT" "Specify the CTest ``TimeOut`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_TLS_VERIFY" "Specify the CTest ``TLSVerify`` setting in a :manual:`ctest(1)`
:ref:`Dashboard Client` script or in project ``CMakeLists.txt`` code
before including the :module:`CTest` module." nil)
    ("CTEST_TLS_VERSION" "Specify the CTest ``TLSVersion`` setting in a :manual:`ctest(1)`
:ref:`Dashboard Client` script or in project ``CMakeLists.txt`` code
before including the :module:`CTest` module." nil)
    ("CTEST_TRIGGER_SITE" "Legacy option." nil)
    ("CTEST_UPDATE_COMMAND" "Specify the CTest ``UpdateCommand`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_UPDATE_OPTIONS" "Specify the CTest ``UpdateOptions`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_UPDATE_VERSION_ONLY" "Specify the CTest :ref:`UpdateVersionOnly <UpdateVersionOnly>` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_UPDATE_VERSION_OVERRIDE" "Specify the CTest :ref:`UpdateVersionOverride <UpdateVersionOverride>` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CTEST_USE_LAUNCHERS" "Specify the CTest ``UseLaunchers`` setting
in a :manual:`ctest(1)` dashboard client script." nil)
    ("CYGWIN" "``True`` for Cygwin." nil)
    ("ENV" "Operator to read environment variables." "  Environment variable names containing special characters like parentheses
  may need to be escaped.  (Policy :policy:`CMP0053` must also be enabled.)
  For example, to get the value of the Windows environment variable
  ``ProgramFiles(x86)``, use:")
    ("EXECUTABLE_OUTPUT_PATH" "Old executable location variable." nil)
    ("GHSMULTI" "``1`` when using :generator:`Green Hills MULTI` generator." nil)
    ("IOS" "Set to ``1`` when the target system (:variable:`CMAKE_SYSTEM_NAME`) is ``iOS``." nil)
    ("LIBRARY_OUTPUT_PATH" "Old library location variable." nil)
    ("LINUX" "Set to true when the target system is Linux." nil)
    ("MINGW" "Set to a true value when at least one language is enabled
with a compiler targeting the GNU ABI on Windows (MinGW)." nil)
    ("MSVC" "Set to ``true`` when the compiler is some version of Microsoft Visual C++
or another compiler simulating the Visual C++ ``cl`` command-line syntax." nil)
    ("MSVC10" "Discouraged." nil)
    ("MSVC11" "Discouraged." nil)
    ("MSVC12" "Discouraged." nil)
    ("MSVC14" "Discouraged." nil)
    ("MSVC60" "Discouraged." nil)
    ("MSVC70" "Discouraged." nil)
    ("MSVC71" "Discouraged." nil)
    ("MSVC80" "Discouraged." nil)
    ("MSVC90" "Discouraged." nil)
    ("MSVC_IDE" "``True`` when using the Microsoft Visual C++ IDE." nil)
    ("MSVC_TOOLSET_VERSION" "The toolset version of Microsoft Visual C/C++ being used if any." "  :align: left")
    ("MSVC_VERSION" "The version of Microsoft Visual C/C++ being used if any." "  :align: left")
    ("MSYS" "``True`` when using the :generator:`MSYS Makefiles` generator." nil)
    ("PROJECT-NAME_BINARY_DIR" "Top level binary directory for the named project." nil)
    ("PROJECT-NAME_DESCRIPTION" "Value given to the ``DESCRIPTION`` option of the most recent call to the
:command:`project` command with project name ``<PROJECT-NAME>``, if any." nil)
    ("PROJECT-NAME_HOMEPAGE_URL" "Value given to the ``HOMEPAGE_URL`` option of the most recent call to the
:command:`project` command with project name ``<PROJECT-NAME>``, if any." nil)
    ("PROJECT-NAME_IS_TOP_LEVEL" "A boolean variable indicating whether the named project was called in a top
level ``CMakeLists.txt`` file." nil)
    ("PROJECT-NAME_SOURCE_DIR" "Top level source directory for the named project." nil)
    ("PROJECT-NAME_VERSION" "Value given to the ``VERSION`` option of the most recent call to the
:command:`project` command with project name ``<PROJECT-NAME>``, if any." nil)
    ("PROJECT-NAME_VERSION_MAJOR" "First version number component of the :variable:`<PROJECT-NAME>_VERSION`
variable as set by the :command:`project` command." nil)
    ("PROJECT-NAME_VERSION_MINOR" "Second version number component of the :variable:`<PROJECT-NAME>_VERSION`
variable as set by the :command:`project` command." nil)
    ("PROJECT-NAME_VERSION_PATCH" "Third version number component of the :variable:`<PROJECT-NAME>_VERSION`
variable as set by the :command:`project` command." nil)
    ("PROJECT-NAME_VERSION_TWEAK" "Fourth version number component of the :variable:`<PROJECT-NAME>_VERSION`
variable as set by the :command:`project` command." nil)
    ("PROJECT_BINARY_DIR" "Full path to build directory for project." nil)
    ("PROJECT_DESCRIPTION" "Short project description given to the project command." nil)
    ("PROJECT_HOMEPAGE_URL" "The homepage URL of the project." nil)
    ("PROJECT_IS_TOP_LEVEL" "A boolean variable indicating whether the most recently called
:command:`project` command in the current scope or above was in the top
level ``CMakeLists.txt`` file." "  project(MyProject)
  ...
  if(PROJECT_IS_TOP_LEVEL)
    include(CTest)
  endif()")
    ("PROJECT_NAME" "Name of the project given to the project command." nil)
    ("PROJECT_SOURCE_DIR" "This is the source directory of the last call to the
:command:`project` command made in the current directory scope or one
of its parents. Note, it is not affected by calls to
:command:`project` made within a child directory scope (i.e. from
within a call to :command:`add_subdirectory` from the current scope)." nil)
    ("PROJECT_VERSION" "Value given to the ``VERSION`` option of the most recent call to the
:command:`project` command, if any." nil)
    ("PROJECT_VERSION_MAJOR" "First version number component of the :variable:`PROJECT_VERSION`
variable as set by the :command:`project` command." nil)
    ("PROJECT_VERSION_MINOR" "Second version number component of the :variable:`PROJECT_VERSION`
variable as set by the :command:`project` command." nil)
    ("PROJECT_VERSION_PATCH" "Third version number component of the :variable:`PROJECT_VERSION`
variable as set by the :command:`project` command." nil)
    ("PROJECT_VERSION_TWEAK" "Fourth version number component of the :variable:`PROJECT_VERSION`
variable as set by the :command:`project` command." nil)
    ("PackageName_ROOT" "Calls to :command:`find_package(<PackageName>)` will search in prefixes
specified by the ``<PackageName>_ROOT`` CMake variable, where
``<PackageName>`` is the (case-preserved) name given to the
:command:`find_package` call and ``_ROOT`` is literal." "  .. versionadded:: 3.27")
    ("UNIX" "Set to ``True`` when the target system is UNIX or UNIX-like
(e.g. :variable:`APPLE` and :variable:`CYGWIN`)." nil)
    ("WASI" "Set to ``1`` when the target system is WebAssembly System Interface
(:variable:`CMAKE_SYSTEM_NAME` is ``WASI``)." nil)
    ("WIN32" "Set to ``True`` when the target system is Windows, including Win64." nil)
    ("WINCE" "True when the :variable:`CMAKE_SYSTEM_NAME` variable is set
to ``WindowsCE``." nil)
    ("WINDOWS_PHONE" "True when the :variable:`CMAKE_SYSTEM_NAME` variable is set
to ``WindowsPhone``." nil)
    ("WINDOWS_STORE" "True when the :variable:`CMAKE_SYSTEM_NAME` variable is set
to ``WindowsStore``." nil)
    ("XCODE" "``True`` when using :generator:`Xcode` generator." nil)
    ("XCODE_VERSION" "Version of Xcode (:generator:`Xcode` generator only)." nil)))

(provide 'eldoc-cmake)
;;; eldoc-cmake.el ends here
