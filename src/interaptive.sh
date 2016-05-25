#!/bin/bash

# Title				:interaptive.sh
# Description		:An interactive commandline interface for APT
#											(inspired by yaourt-gui)
# Author			:yafp
# URL				:https://github.com/yafp/interAPTive/
# Date				:20160525
# Version			:0.6
# Usage		 		:bash interaptive.sh 	(non-installed)
#					:interaptive			(installed via Makefile)
# Notes				:None
# Bash_version    	:4.3.14 				(tested with)


# ------------------------------------------------------
# Developer/Debug Notes
# ------------------------------------------------------
# Code stepping:
#	Enable code stepping by placing the following cmd at the place you want to start debugging
# 		trap '(read -p "[$BASH_SOURCE:$LINENO] $BASH_COMMAND?")' DEBUG



# ++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Functions
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++

# ------------------------------------------------------
# Function: 	sets some readonly variables
# ------------------------------------------------------
function initAppBasics() {
	readonly appAuthor="yafp"
	readonly appName="interAPTive"
	readonly appDescription="An interactive commandline interface for APT"
	readonly appVersion="0.6.20160525.01" # 0.x.YYMMDDDD
	readonly appTagline=" $appName - $appDescription"
	readonly appPathFull="/usr/bin/interaptive" # if 'installed' via makefile
	readonly appLicense="GPL3"
	readonly appURL="https://github.com/yafp/interAPTive/"
	readonly appDownloadURL="https://raw.githubusercontent.com/yafp/interAPTive/master/src/interaptive.sh"
	readonly appVersionURL="https://raw.githubusercontent.com/yafp/interAPTive/master/version"
	#set -o nounset # Handling for undefined variables
}


# ---------------------------------------------------------------------
# Function: 	Defines some text formating styles and colors
# ---------------------------------------------------------------------
function initTextAndColors() {
	# styles
	normal=$(tput sgr0)				# default
	bold=$(tput bold)				# bold
	underline=$(tput smul)			# underline
	background='\033[0;100m'		# background

	# colors
	red=$(tput setaf 1)
	green=$(tput setaf 2)
	yellow=$(tput setaf 3)
}


# ------------------------------------------------------
# Function:		Checks if Distribution is supported
#				Used on script start to check if it makes sense on that system or not
#				Even if unsupported script will continue, but display a warning
#				Using 'lsb_release' -i here
# 				Supported output:
#				- Debian
#				- Ubuntu
# ------------------------------------------------------
function checkForLinuxDistribution() {
	printf " Checking if distribution is supported\t"

	if hash lsb_release 2>/dev/null; then # check for lsb_release
		curDistri=$(lsb_release -i)

		if [[ $curDistri == *"Ubuntu"* ]] || [[ $curDistri == *"Debian"* ]] ; then
			printf "${bold}${green}PASSED${normal}\n"
		else
			printf "${bold}${yellow}WARN${normal}\n\n"
			printf " Feel free to continue while your distribution is not supported nor even tested.\n"
			pause
		fi
	fi

}


# ------------------------------------------------------
# Function: 	Checks if the executing user is root or not
#				Needed to decide if sudo is needed or not
# ------------------------------------------------------
function checkForRootUser() {
	printf " Checking user permissions\t\t"
	if [ "$EUID" -ne 0 ]; then # current user != root
		rootUser=false
  	else # current user = root
		rootUser=true
	fi
	printf "${bold}${green}PASSED${normal}\n\n"
}


# ------------------------------------------------------
# Function: 	Searches the dpkg log for some specific keywords & Shows the result
# Source:		http://linuxcommando.blogspot.de/2008/08/how-to-show-apt-log-history.html
# Check: 		https://github.com/blyork/apt-history for better approach
# ------------------------------------------------------
function aptLog() {
	printHead
	printf " You are going to load the dpkg log (/var/log/dpkg).\n Select one of the following options:\n\n"
	printf " [${green}I${normal}]nstall\n [${green}U${normal}]pgrade\n [${green}R${normal}]emove\n [${green}A${normal}]ll\t\t[default]\n\n"
	read -p " ${green}Please choose: ${normal}" answer
	case $answer in
		[iI]) # install
			cat /var/log/dpkg.log | grep 'install '
			;;
		[uU]) #upgrade
			cat /var/log/dpkg.log | grep 'upgrade '
			;;
		[rR]) #remove
			cat /var/log/dpkg.log | grep 'remove '
			;;
		[aA]) # all
			cat /var/log/dpkg.log | less
			;;
		"") # all
			cat /var/log/dpkg.log | less
			;;
		*) # catch all other input as invalid
			printf "\n Invalid input, aborting\n"
			;;
	esac
	pause
}


# ------------------------------------------------------
# Function:		Executes the command in $1 (after user selected an existing  command number)
#				$1 = command to execute
#				$2 = if $2 is set, it means the commands needs sudo permissions for normal users
# ------------------------------------------------------
function executeAPTCommand() {
	printHead
	if [[ $rootUser == false ]]; then # not a root user - check if command needs sudo permissions or not
		# executing as non-root user - lets check if the commands needs sudo permissions or not
		if [[ -z $2  ]]; then # sudo is NOT needed
			printf " Executing command: ${bold}$1${normal}\n\n"
			$1
		else # sudo is needed
			printf " Executing command: ${bold}$2 $1${normal}\n\n"
			sudo $1
		fi
	else # root user
		printf " Executing command: ${bold}$1${normal}\n\n"
		$1
	fi
	pause
	unset "$1"
	unset "$2"
}


# ------------------------------------------------------
# Function:		Pauses the script logic and waits for user interaction
# ------------------------------------------------------
function pause() {
	printf "\n ${green}Press ANY key to continue${normal}"
	read -n 1
	#printCoreUI # reload main UI
}


# ------------------------------------------------------
# Function:		Outputs a human readable error & writes to syslog if supported
# 				$1 = errorcode
# 				$2 = error-string
#
# Errors:
#	1 = Unable to find apt
#	2 = Unable to fetch version informations online
#	3 = Unable to find curl
#	4 = Invalid command entered
# ------------------------------------------------------
function printError() {
	printf "\n ${bold}${red}ERROR${normal}\t$1\n"
	printf "\t$2\n\n"
	printf "\tVisit ${background}$appURL${normal} to report issues.\n"

	# Log error to syslog (#25)
	if hash logger 2>/dev/null; then # check for logger
		logger "$appName ($appVersion) Error $1 - $2" #25
	else
		printf "${bold}${red}FAILED${normal}\tUnable to write log entry as logger is not installed."
	fi
}


# ------------------------------------------------------
# Function:	 	Check for updates and install them if user ask to
# ------------------------------------------------------
function selfUpdate() {
	printHead
	printf " Starting selfupdate...\n"
	printf " Searching curl\t\t\t"
	if hash curl 2>/dev/null; then # curl is installed - continue with selfupdate
		printf "${bold}${green}PASSED${normal}\n"

		curl -o /tmp/interaptive_version $appVersionURL # download version file to compare local vs online version
		appVersionLatest=`cat /tmp/interaptive_version`

		if [[ "$appVersionLatest" == "Not Found" ]]; then
			printf " Fetching update information\t${bold}${red}FAILED${normal}\n"
			printError "2" "Unable to fetch version informations (${background}$appVersionURL${normal}) ... aborting"
			pause
			return
		else # was able to fetch the version file online via curl
			printf " Fetching update information\t${bold}${green}PASSED${normal}\n"
			printf "\n Installed:\t\t\t$appVersion\n"
			printf " Online:\t\t\t$appVersionLatest\n\n"
			if [[ $appVersionLatest > $appVersion ]]; then # found updates
				printf " Found newer version\n"
				# check if script was installed on expected location
				if hash "$appPathFull" 2>/dev/null; then # check for installed version of this script
			        printf " Detected installed version of ${bold}$appName${normal} at ${bold}$appPathFull${normal}\n\n"

					# Ask if user wants to upgrade
					read -p " ${green}Do you really want to update ${bold}$appName${normal}${green} to the latest version? [${normal}Y${green}]es or ANY other key to cancel: ${normal}" answer
				  	case $answer in
						[yY])
							# get latest version
							curl -o /tmp/interaptive.sh $appDownloadURL
							printf " Finished downloading latest version of ${bold}$appName${normal}\n"
							# replace installed copy with new version
							if [[ $rootUser==false ]]; then
								sudo cp /tmp/interaptive.sh $appPathFull
							else
								cp /tmp/interaptive.sh $appPathFull
							fi
							printf " Finished replacing ${bold}$appName${normal} at ${bold}$appPathFull${normal}\n"
							printf " You need to restart ${bold}$appName${normal} now to finish the update\n"
							printf "\n ${green}Press ANY key to quit ${bold}$appName${normal}"
							read -n 1
							clear
							printf " Bye\n\n"
							exit
							;;
					esac
			    else
					printf " ${bold}${red}ERROR${normal} Unable to find installed version of ${bold}$appName${normal} at ${bold}$appPathFull${normal} (errno 1).\n\n"
					printf " Visit ${bold}$appURL${normal} to report issues.\n"
			        exit 1
			    fi
			else # there are no updates available because:
				if [[ $appVersionLatest < $appVersion ]]; then # user has dev build
					printf " You are using a development version, nothing to do here.\n"
				else # user is using latest official version
					printf " You are already using the latest official version\n"
				fi
			fi
		fi
    else # Curl is not installed -> can't check for updates
		printf "${bold}${red}FAILED${normal}\n"
		printError "3" "Unable to find curl ... aborting"
    fi
	pause
}


# ------------------------------------------------------
# Function:		Print a random developer quote on exiting the app
# ------------------------------------------------------
function showRandomDeveloperQuote {
	devQuote[0]="Prolific developers don't always write a lot of code, instead they solve a lot of problems. The two things are not the same."
	devQuote[1]="Prolific programmers contribute to certain disaster."
	devQuote[2]="Without requirements or design, programming is the art of adding bugs to an empty text file."
	devQuote[3]="Deleted code is debugged code."
	devQuote[4]="There is no programming language–no matter how structured–that will prevent programmers from making bad programs."
	devQuote[5]="The gap between theory and practice is not as wide in theory as it is in practice"
	devQuote[6]="Good design adds value faster than it adds cost."
	devQuote[7]="Errors should never pass silently. Unless explicitly silenced."

	rand=$[$RANDOM % 8]
	printf "\n ${green}${devQuote[$rand]}${normal}\n"
}


# ------------------------------------------------------
# Function:		Shows app informations
# ------------------------------------------------------
function printAppInfo {
	printHead
	printf " ${bold}Software${normal}\n"
	printf " Name:\t\t$appName\n"
	printf " About:\t\t$appDescription\n"
	printf " Version:\t$appVersion\n"
	printf " URL:\t\t$appURL\n\n"
	printf " Developer:\t$appAuthor\n"
	printf " License:\t$appLicense\n\n\n"

	if hash lsb_release 2>/dev/null; then # check for lsb_release
		printf " ${bold}System${normal}\n "
		lsb_release -d
		printf " "
		lsb_release -c
		printf "\n\n"
	fi
	printf " ${bold}Man pages${normal}\n"
	printf " ${background}apt${normal} ${background}apt-get${normal} ${background}apt-cache${normal}\n\n"
	pause
}


# ------------------------------------------------------
# Function:		Detects size of terminal window & displays warnings if to small
# 				Prints a header including appname & description
# ------------------------------------------------------
function printHead {
	errorCount=0			# Init errorCounter to 0
	showASCIIArt=false		# Set a default value for boolean (assuming window is to small)

	# Height
	minLines=33 			# Define min height (+5 for full ASCII-art)
	curLines=$(tput lines)	# get lines of current terminal window
	errorLinesHeight=""

	# Width
	minColumns=74 			# Define mid width
	curColumns=$(tput cols)	# get columns of current terminal window
	errorColumnsWidth=""

	clear

	if (( $curLines < $minLines )); then # not enough height
		errorLinesHeight=" ${bold}${red}ERROR${normal}\tWindow height ($curLines) is to small (min $minLines)\n"
		errorCount=$((errorCount+1)) # Errorcount +1
	else # enough height available
		if (( $curLines > $minLines+4 )); then # check if its enough height for ASCII-art as well
			showASCIIArt=true # enable ASCII art
		fi
	fi

	# check columns (width)
	if (( $curColumns < $minColumns )); then
		errorColumnsWidth=" ${bold}${red}ERROR${normal}\tWindow width ($curColumns) is to small (min $minColumns)\n"
		errorCount=$((errorCount+1)) # Errorcount +1
	fi

	# Show ASCII art only if we have enough space - otherwise skip
	if [ "$showASCIIArt" = true ] ; then
		printf "\n  _)        |               \    _ \ __ __| _)\n"
		printf "   |    \    _|   -_)   _| _ \   __/    |    | \ \ /  -_)\n"
		printf "  _| _| _| \__| \___| _| _/  _\ _|     _|   _|  \_/ \___|\n\n"
	fi

	printf "${bold}$appTagline\n"

	# print a green line under the header
	printf " ${green}"
	for (( c=1; c<=$curColumns-2; c++ )); do
		printf "-"
	done
	printf "${normal}\n\n"

	# check if errors happened - if so pause the script
	if (( $errorCount > 0 )); then
		printf "$errorLinesHeight"
		printf "$errorColumnsWidth"
		printf "\n Please resize your terminal window\n\n"
		pause
	fi
}


# ------------------------------------------------------
# Function:		Prints a command listing (all functions)
# ------------------------------------------------------
function printCommandList {
	# 1x = Update'ing
	printf " ${bold}Update & Upgrade${normal}\n"
	printf " [11] Update local package information\t\t(apt update)\n"
	printf " [12] Download and install updates\t\t(apt upgrade)\n\n"

	# 2x = search & info
	printf " ${bold}Information${normal}\n"
	printf " [21] Search packages by name\t\t\t(apt search)\n"
	printf " [22] Show package information\t\t\t(apt show)\n"
	printf " [23] Show package version information\t\t(apt-cache policy)\n"
	printf " [24] Changelog for single package\t\t(apt-get changelog)\n" # Issue 13
	printf " [25] Dependencies for single package\t\t(apt-cache depends)\n" # Issue 12
	printf " [26] List packages\t\t\t\t(apt list)\n\n" # Issue 3

	# 3x = install
	printf " ${bold}Install${normal}\n"
	printf " [31] Install new packages by name\t\t(apt install)\n"
	printf " [32] Reinstall a packages by name\t\t(apt install --reinstall)\n\n" # Issue 14

	# 4x = remove
	printf " ${bold}Removal${normal}\n"
	printf " [41] Remove packages by name\t\t\t(apt remove)\n"
	printf " [42] Purge packages by name\t\t\t(apt purge)\n" # Issue 8
	printf " [43] Remove unneeded packages\t\t\t(apt-get autoremove)\n"
	printf " [44] Remove all stored archives from cache\t(apt-get clean)\n\n"

	# misc
	printf " ${bold}Misc${normal}\n"
	printf "  [E] Edit sources\t\t\t\t(apt edit-sources)\n" # Issue 4
	printf "  [L] Show log\t\t\t\t\t(/var/log/dpkg)\n" # Issue 10
	printf "  [I] Info\n" # Issue 17
	printf "  [S] Selfupdate\n" # Issue 18
	printf "  [Q] Quit\n\n"
}


# ------------------------------------------------------
# Function: 	Print head
#				Print Command list
#				Wait for user input
#				Defines the inidividual commands for each command-entry
# ------------------------------------------------------
function printCoreUI {
	while true
	do
		printHead			# print head
		printCommandList	# print command list

		read -p " ${green}Please enter a command number: ${normal}" answer
	  	case $answer in
			11) # update
				executeAPTCommand "apt update" "sudo"
				;;

			12) # upgrade
				printHead
				printf " You are going to update your system using the apt-upgrade command.\n\n"
				printf " [${green}N${normal}]ormal\t(apt upgrade)\t[default]\n [${green}F${normal}]ull\t\t(apt full-upgrade)\n [${green}D${normal}]ist\t\t(apt dist-upgrade)\n\n"
				read -p " ${green}Please choose: ${normal}" upgradeType
				case $upgradeType in
					[nN]) # apt upgrade
						executeAPTCommand "apt upgrade" "sudo"
						;;
					"") # default - same as above
						executeAPTCommand "apt upgrade" "sudo"
						;;
					[fF]) # full-upgrade
						executeAPTCommand "apt full-upgrade" "sudo"
						;;
					[dD]) # dist-upgrade
						executeAPTCommand "apt dist-upgrade" "sudo"
						;;
				esac
				;;

			21) # search
				read -p " ${green}Searching for: ${normal}" search
				executeAPTCommand "apt search $search"
				;;
			22) # show
				read -p " ${green}Show info for pkg: ${normal}" search
				executeAPTCommand "apt show $search"
				;;
			23) # policy
				read -p " ${green}Show policy for pkg: ${normal}" search
				executeAPTCommand "apt-cache policy $search"
				;;
			24) # changelog
				read -p " ${green}Please enter a package name for changelog: ${normal}" search
				executeAPTCommand "apt-get changelog $search"
				;;
			25) # depends
				read -p " ${green}Please enter a package name for dependencies: ${normal}" search
				executeAPTCommand "apt-cache depends $search"
				;;
			26) # list
				read -p " ${green}List all [${normal}I${green}]nstalled, [${normal}U${green}]pgradable or [${normal}A${green}]ll versions: ${normal}" listOption
				case $listOption in
					[iI]) # list --installed
						executeAPTCommand "apt list --installed"
						;;
					[uU]) # list --upgradable
						executeAPTCommand "apt list --upgradable"
						;;
					[aA]) # list --all-versions
						executeAPTCommand "apt list --all-versions"
						;;
				esac
				;;

			31) # install
				read -p " ${green}Please enter a package name for installation: ${normal}" search
				executeAPTCommand "apt install $search" "sudo"
				;;
			32) # reinstall
				read -p " ${green}Please enter a package name for re-installation: ${normal}" search
				executeAPTCommand "apt install --reinstall $search" "sudo"
				;;
			41) # remove
				read -p " ${green}Please enter a package name for removal: ${normal}" search
				executeAPTCommand "apt remove $search" "sudo"
				;;
			42) # purge
				read -p " ${green}Please enter a package name for purge: ${normal}" search
				executeAPTCommand "apt purge $search" "sudo"
				;;
			43) # autoremove
				executeAPTCommand "apt-get autoremove" "sudo"
				;;
			44) # clean
				executeAPTCommand "apt-get clean" "sudo"
				;;
			[eE]) # edit sources
				executeAPTCommand "apt edit-sources" "sudo"
				;;
			[lL]) # apt log
				aptLog
				;;
			[iI]) # help / info
				printAppInfo
				;;
			[sS]) # selfupdate
				selfUpdate
				;;
	   		[qQ]) # quit
				clear
				showRandomDeveloperQuote
				exit
				;;
			"") # Just pressing enter/return without command number
				;;
			*)	# any other input = invalid input
				printError "4" "Invalid command ... aborting"
				pause
				;;
		esac
	done
}


# ++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Main Script
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++
initTextAndColors			# Loads the text & color definitions
initAppBasics				# Loads the app-specific readonly variables

printHead 					# print script head in case of errors in checkForApt
checkForLinuxDistribution	# Check if distribution is supported or not
checkForRootUser			# check if user is root or not
printCoreUI 				# run the main loop and wait for user input
