#!/bin/bash

##	Purpose: Quick and dirty build script until 'redo' build system implemented.
##	History:
##		- 20200927 JC: Created.
##		- 20220501 JC: Updated to work in updated project environment as a real project.
##	Notes:
##		- fHook_Build() and fHook_PostBuild(), while they exist in this script, are intended to live by themselves and used thusly:
##			x9go-build  ## This script
##				function fMain(){
##				}
##				## And the rest of the code
##			build.sh    ## Custom per-project script
##				function fHook_Build(){
##				}
##				function fHook_PostBuild(){
##				}
##				. x9go-build $1


function fHook_Build(){

	## Go environment variables
#	declare -r GOOS=linux
#	declare -r GOARCH=amd64
	declare -r CGO_ENABLED=1

	## Go environment variables: CGo compiler flags
#	declare CGO_CFLAGS=""
#	CGO_CFLAGS="${CGO_CFLAGS} "
#	CGO_CFLAGS="$(fStrNormalize_byecho "${CGO_CFLAGS}")"  #.........: Normalize string

	## Go environment variables: CGo linker flags
#	declare CGO_LDFLAGS=""
#	CGO_LDFLAGS="${CGO_LDFLAGS} "
#	CGO_LDFLAGS="$(fStrNormalize_byecho "${CGO_LDFLAGS}")"  #.........: Normalize string

	## -ldflags
	local ldFlags=""
	ldFlags="${ldFlags} -s -w"  #.........................................................: Disable debugging symbols.
	ldFlags="${ldFlags} -X main.Version=${version}"  #....................................: Inject value
	ldFlags="${ldFlags} -X main.GitCommitHash=${gitCommitHash}"  #........................: Inject value
	ldFlags="${ldFlags} -X main.BuildDateTime=${buildDateTime}"  #........................: Inject value
#	ldFlags="${ldFlags} -H=windowsgui"  #.................................................: No console in Windows
#	ldFlags="${ldFlags} -linkmode external"  #............................................: Options: internal, external, auto (external for static linking?)
#	ldFlags="${ldFlags} -extldflags=-static"  #...........................................: Flags to external linker (?)
	ldFlags="$(fStrNormalize_byecho "${ldFlags}")"  #.....................................: Normalize string

	## General Go tags
	local goTags=""
#	goTags="${goTags} linux"  #.......................: Specify cross-compile environment
#	goTags="${goTags} netgo"  #.......................: Use built-in network library, rather than C's (C versions have more features but require gcc and CGO_ENABLED=1).
#	goTags="${goTags} osusergo"  #....................: Use built-in user library, rather than C's (C versions have more features but require gcc and CGO_ENABLED=1).
#	goTags="$(fStrNormalize_byecho "${goTags}")"  #...: Normalize string

	## go-sqlite3 Tags (NOTE: Don't include 'libsqlite3', as this will cause go-sqlite3 to use system-installed sqlite3 instead of custom-compiled)
	local goTags_Sqlite3=""
	goTags_Sqlite3="${goTags_Sqlite3} sqlite_omit_load_extension"  #..................: Solves a Go problem related to static linking.
	goTags_Sqlite3="${goTags_Sqlite3} sqlite_foreign_keys=1"  #.......................: 1=Enable foreign key constraints by defualt. (0 is default only for backward compatibility.)
#	goTags_Sqlite3="${goTags_Sqlite3} sqlite_fts5"  #.................................: Version 5 of the full-text search engine (fts5) is added to the build
#	goTags_Sqlite3="${goTags_Sqlite3} sqlite_json  #..................................:
	goTags_Sqlite3="${goTags_Sqlite3} sqlite_icu"  #..................................: Unicode
	goTags_Sqlite3="$(fStrNormalize_byecho "${goTags_Sqlite3}")"  #...................: Normalize string

	## Gather up gotags
	goTags="${goTags} ${goTags_Sqlite3}"
	goTags="$(fStrNormalize_byecho "${goTags}")"  #...: Normalize string

	## Export
	export GOOS
	export GOARCH
	export CGO_ENABLED
	export CGO_CFLAGS
	export CGO_LDFLAGS

	fEcho_Clean
	fEcho_Clean_If "GOOS ..........: "  "${GOOS}"
	fEcho_Clean_If "GOARCH ........: "  "${GOARCH}"
	fEcho_Clean_If "CGO_ENABLED ...: "  "${CGO_ENABLED}"
	fEcho_Clean_If "\nCGO_CFLAGS:\n"                           "${CGO_CFLAGS}"
	fEcho_Clean_If "\nCGO_LDFLAGS:\n"                          "${CGO_LDFLAGS}"
	fEcho_Clean_If "\nldFlags:\n"                              "${ldFlags}"
	fEcho_Clean_If "\ngoTags:\n"                               "${goTags}"

	fEcho_Clean
	go build --tags "${goTags}" --ldflags "${ldFlags}" -o "bin/${exeName}" .
	fEcho_ResetBlankCounter

}


function fHook_PostBuild(){

	local -r sourceBinDir="bin"
	local -r targetDepsCopiesDir="dependencies"

	## Archive program dependencies
	if [[ -z "$(which x9copy-program-dependencies 2>/dev/null || true)" ]]; then
		fEcho_Clean "    fHook_PostBuild(): FYI: Program not found in path: 'x9copy-program-dependencies', skipping that post-build functionality."
	else

		## Validate
		[[ -z "$(which find   2>/dev/null || true)" ]] && fThrowError "fHook_PostBuild(): Not found in path: 'find'."
		[[ -z "$(which 7z     2>/dev/null || true)" ]] && fThrowError "fHook_PostBuild(): Not found in path: '7z'."
		[[ -z "$(which mktemp 2>/dev/null || true)" ]] && fThrowError "fHook_PostBuild(): Not found in path: 'mktemp'."

		if [[ ! -d "${sourceBinDir}" ]]; then
			fThrowError "fHook_PostBuild(): Source bin dir not found: '${sourceBinDir}'."
		else
			if [[ -z "$(find "${sourceBinDir}" -type f 2>/dev/null || true)" ]]; then
				fThrowError "fHook_PostBuild(): Nothing found in '${sourceBinDir}'."
			else

				## Get temp dir
				local -r tmpDir="$(mktemp -d)"

				## Make the dependencies directory
				[[ ! -d "${targetDepsCopiesDir}"             ]] &&  mkdir -p  "${targetDepsCopiesDir}"

				## Manage older archive version[s]
				fEcho_Clean "    Managing old system dependency archives ..."
				[[ -f "/tmp/system_old.7z"                   ]] && \rm  "/tmp/system_old.7z"
				[[ -f "${targetDepsCopiesDir}/system.7z"     ]] &&  mv  "${targetDepsCopiesDir}/system.7z"  "/tmp/system_old.7z"

				## For each file in bin, find and copy dependencies, preserving source structure.
				declare -r -i x9copy_program_dependencies_QUIET=1; export x9copy_program_dependencies_QUIET
				fEcho_Clean "    Copying system dependencies to temp dir '${tmpDir}' ..."
				for eachFile in $(find "${sourceBinDir}" -type f 2>/dev/null || true); do
					x9copy-program-dependencies "${eachFile}" "${tmpDir}"
				done

				if [[ -z "$(find "${targetDepsCopiesDir}" -type f 2>/dev/null || true)" ]]; then
					fEcho_Clean "    fHook_PostBuild(): No dependencies were copied to '${targetDepsCopiesDir}'."
				else

					## Arcvhive the dependencies
					fEcho_Clean "    Creating system dependencies archive at '${targetDepsCopiesDir}/system.7z' ..."
					7z a -t7z -mmt=on -mtc=on -mtm=on -mhc=on -mx=3 -ms=on -mqs=on "${targetDepsCopiesDir}/system.7z" "${tmpDir}/*" 1>/dev/null
						## -v2349858816b  ## Creates a '*.7z.001' file.

					## Valdiate
					if [[ ! -f "${targetDepsCopiesDir}/system.7z" ]]; then
						fThrowError "fHook_PostBuild(): Archive not found: '${targetDepsCopiesDir}/system.7z'."
					fi

					## Copy the program and dependencies to x9chroot
					local -r targetChroot="/var/x9chroot"
					local -r targetTest="${targetChroot}${HOME}/test"
					if [[ -n "$(which x9chroot 2>/dev/null || true)" ]]; then
						if [[ -n "$(ls -A "${targetChroot}${HOME}" 2>/dev/null || true)" ]]; then

							## Manage test dir versions
							fEcho_Clean "    Managing old x9chroot test folders ..."
							if [[ -d "${targetTest}_old" ]]; then \rm -rf "${targetTest}_old"                      ; fi
							if [[ -d "${targetTest}"     ]]; then  mv     "${targetTest}"      "${targetTest}_old" ; fi
							mkdir -p "${targetTest}"

							## Copy contents of bin to chroot target
							fEcho_Clean "    Copying '${sourceBinDir}/*' to '${targetTest}/' ..."
							cp --parents -a --update "${sourceBinDir}"/ "${targetTest}"/

							## Copy dependencies
							fEcho_Clean "    Copying system dependencies to '${targetTest}/' ..."
							pushd "${tmpDir}" 1>/dev/null
								sudo cp --parents -a --update ./  "${targetChroot}"/
							popd 1>/dev/null

						fi
					fi

				fi
			fi
		fi
	fi

	fEcho_ResetBlankCounter
	fEcho_Clean
	fEcho_Clean "Ready to test in isolation via these commands:"
	fEcho_Clean
	fEcho_Clean "x9chroot enter"
	fEcho_Clean "~/test/${sourceBinDir}/${exeName}"

}


function fMain(){

	## Args
	local -r version="$1"

	cd "$(dirname "${0}")"

	## Validate
	if [[   -z "$(which basename 2>/dev/null || true)" ]]; then fThrowError "Not found in path: 'basename'";          fi
	if [[   -z "$(which dirname  2>/dev/null || true)" ]]; then fThrowError "Not found in path: 'dirname'";           fi
	if [[   -z "$(which pwd      2>/dev/null || true)" ]]; then fThrowError "Not found in path: 'pwd'";               fi
	if [[   -z "$(which go       2>/dev/null || true)" ]]; then fThrowError "Not found in path: 'go'";                fi
	if [[   -z "$(which golint   2>/dev/null || true)" ]]; then fThrowError "Not found in path: 'golint'";            fi
	if [[   -z "$(which upx      2>/dev/null || true)" ]]; then fThrowError "Not found in path: 'upx'";               fi
	if [[ ! -f "main.go"                               ]]; then fThrowError "Not found: 'main.go'";                   fi
	if [[   -z "${version}"                            ]]; then fThrowError "No version specified (e.g. \"1.0.1\".)"; fi

	## Constants
	local -r exeName="$(basename "$(pwd)")"
	local -r gitCommitHash="$(git rev-list -1 HEAD)"
	local -r buildDateTime="$(date -u "+%Y%m%dT%H%M%SZ")"

	## Init
	[[ ! -d  bin                               ]] &&  mkdir  bin
	[[   -f "/tmp/${exeName}_old"              ]] && \rm  "/tmp/${exeName}_old"
	[[   -f "bin/${exeName}"                   ]] &&  mv  "bin/${exeName}"                     "/tmp/${exeName}_old"
#	[[   -f "bin/${exeName}"                   ]] &&  mv  "bin/${exeName}"                     "bin/${exeName}_old"
	[[   -f "/tmp/${exeName}_uncompressed_old" ]] && \rm  "/tmp/${exeName}_uncompressed_old"
	[[   -f "bin/${exeName}_uncompressed"      ]] &&  mv  "bin/${exeName}_uncompressed"        "/tmp/${exeName}_uncompressed_old"
#	[[   -f "bin/${exeName}_uncompressed"      ]] &&  mv  "bin/${exeName}_uncompressed"        "bin/${exeName}_uncompressed_old"

	## Clean up dependencies
	fEcho
	fEcho "Tidying ..."
	go mod tidy | ts "    "
	fEcho_ResetBlankCounter

	## Format
	fEcho "Formatting ..."
	gofmt -w -s . | ts "    "  ## Or -l instead of -d to only show what files changed.
	fEcho_ResetBlankCounter

	## Verify
	fEcho "Verifying ... $(go mod verify)"
	fEcho_ResetBlankCounter

	## Stastic analysis
	fEcho "Vetting ..."
	go vet . | ts "    "
	fEcho_ResetBlankCounter

	## Linting
	fEcho "Linting ..."
	golint . | ts "    "
	fEcho_ResetBlankCounter

	## Build
	fEcho "Building ..."
	fEcho
	fHook_Build
	fEcho_ResetBlankCounter

	## Validate
	if [[ ! -f "bin/${exeName}" ]]; then fThrowError "Not found: 'bin/${exeName}'."; fi

	## Compress
	fEcho "Shrinking ..."
	[[   -f "bin/${exeName}"      ]] && mv  "bin/${exeName}"  "bin/${exeName}_uncompressed"
#	upx  -qq --ultra-brute  -o"bin/${exeName}"  "bin/${exeName}_uncompressed" | ts "    "
	upx  -qq                -o"bin/${exeName}"  "bin/${exeName}_uncompressed" | ts "    "
	fEcho_ResetBlankCounter
	fEcho

	## Additional hook
	fEcho ""
	fEcho "Running post-build hook ..."
	fHook_PostBuild

	## Show
	fEcho ""
	LC_COLLATE="C" ls -lA --color=always --group-directories-first --human-readable --indicator-style=slash --time-style=+"%Y-%m-%d %H:%M:%S" "bin"
	fEcho_ResetBlankCounter

	## Test
	fEcho
	fEcho "Test run ..."
	fEcho_Clean "-------------------------------------------------------------------------------"
	"bin/${exeName}"
	fEcho_ResetBlankCounter
	fEcho_Clean "-------------------------------------------------------------------------------"
	fEcho_Clean

}


function fThrowError(){
	fEcho_Clean
	if [[ -n "$1" ]]; then
		fEcho_Clean "Error: $*"
	else
		fEcho_Clean "An error occurred."
	fi
	fEcho_Clean
	exit 1
}


function fStrNormalize_byecho(){
	local argStr="$*"
	argStr="$(echo -e "${argStr}")" #.................................................................. Convert \n and \t to real newlines, etc.
	argStr="${argStr//$'\n'/ }" #...................................................................... Convert newlines to spaces
	argStr="${argStr//$'\t'/ }" #...................................................................... Convert tabs to spaces
	argStr="$(echo "${argStr}" | awk '{$1=$1};1' 2>/dev/null || true)" #............................... Collapse multiple spaces to one and trim
	argStr="$(echo "${argStr}" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//' 2>/dev/null || true)" #..... Additional trim
	echo "${argStr}"
}


declare -i _wasLastEchoBlank=0
function fEcho_ResetBlankCounter(){ _wasLastEchoBlank=0; }
function fEcho_Clean(){
	if [[ -n "$1" ]]; then
		echo -e "$*" | echo -e "$*"
		_wasLastEchoBlank=0
	else
		[[ $_wasLastEchoBlank -eq 0 ]] && echo
		_wasLastEchoBlank=1
	fi
}
function fEcho_Clean_If(){
	local -r prefix="$1"
	local -r middleIf="$2"
	local -r postfix="$3"
	if [[ -n "${middleIf}" ]]; then fEcho_Clean "${prefix}${middleIf}${postfix}"; fi
}
function fEcho(){
	if [[ -n "$*" ]]; then fEcho_Clean "[ $* ]"
	else fEcho_Clean ""
	fi
}
# shellcheck disable=2120  ## References arguments, but none are ever passed; Just because this library function isn't called here, doesn't mean it never will in other scripts.
function fEcho_Force()       { fEcho_ResetBlankCounter; fEcho "$*";       }
function fEcho_Clean_Force() { fEcho_ResetBlankCounter; fEcho_Clean "$*"; }


set -e
set -E
fMain  "$1"  "$2"  "$3"  "$4"  "$5"  "$6"  "$7"  "$8"  "$9"