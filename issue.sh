#!/bin/sh

function issue {
	
	local hookFile="$(git rev-parse --show-toplevel)/.git/hooks/prepare-commit-msg"
	local BOLD_WHITE="\e[1;37m"
	local RESET_COLOR="\033[0m"
	
	function __help {
		if [[ $1 == "--invalid-option" ]]; then
			printf "The option $BOLD_WHITE$2$RESET_COLOR is not valid. Please look at the following help-page.\r\n\r\n"
		fi
		
		printf "usage: issue [<option> | <command>] [--global] [<args>]

The available options are:
  ${BOLD_WHITE}install${RESET_COLOR}\tinstalls the hook inside your current repository and prepares the .gitconfig
  ${BOLD_WHITE}uninstall${RESET_COLOR}\tuninstalls the hook inside your current repository and cleans up the .gitconfig
  ${BOLD_WHITE}reinstall${RESET_COLOR}\tuninstall + install
  ${BOLD_WHITE}enable-check${RESET_COLOR}\t\tenables checks on prompt start to verify, if the set issue is still up to date
  ${BOLD_WHITE}disable-check${RESET_COLOR}\tdisables checks on prompt start
	
The available commands are:
  ${BOLD_WHITE}open${RESET_COLOR}\tsets up a new issue for new prefixes on commits
  ${BOLD_WHITE}close${RESET_COLOR}\tcloses the current issue
  ${BOLD_WHITE}status${RESET_COLOR}\tshows the current issue and if check is enabled\r\n"
	}
	
	function __install {
		local hook='#!/bin/sh

# setting up colors for console output
CYAN='\''\033[0;36m'\''
BOLD_CYAN='\''\033[1;36m'\''
RESET_COLOR='\''\033[0m'\''

COMMIT_PREFIX=$(git config --local prefix.commitMessage)
COMMIT_MESSAGE=$(cat "$1")

# If an issue number exits it should be set
# before the commit message
if [[ -n "$COMMIT_PREFIX" && "$COMMIT_PREFIX" != none ]]; then
	printf "\r\n${CYAN}Prefixing commit message with ${BOLD_CYAN}$COMMIT_PREFIX${RESET_COLOR}\r\n"
	echo "$COMMIT_PREFIX $COMMIT_MESSAGE" > "$1";
fi'
		
		if [[ "$1" == "--global" ]]; then
			printf "  Setting up .gitconfig...\r\n"
			$(git config --global prefix.check disabled)
		else
			printf "\r\n  Creating hook-file...\r\n"
			echo "$hook" > "$hookFile"
			
			printf "  Setting up .gitconfig...\r\n"
			$(git config --local prefix.commitMessage none)
			$(git config --local prefix.check disabled)
		fi
	}
	
	function __uninstall {
		if [[ "$1" == "--global" ]]; then
			printf "  Cleaning up .gitconfig...\r\n"
			$(git config --global --remove-section prefix)
		else
			printf "\r\n  Deleting hook-file...\r\n"
			rm "$hookFile"
			
			printf "  Cleaning up .gitconfig...\r\n"
			$(git config --local --remove-section prefix)
		fi
	}
	
	function __reinstall {
		__uninstall $1
		__install $1
	}
	
	function __enableCheck {
		if [[ "$1" == "--global" ]]; then
			$(git config --global prefix.check "enabled")
			
			function cd {
				local fromNormalDir=0
				local toRepo=0
				local oldRepo="none"
				local newRepo="none"
				
				function __isNormalDir {
					if [[ $( git rev-parse --git-dir 2>&1 ) == 'fatal: Not a git repository'* ]]; then
						echo 1
					else
						echo 0
					fi
				}
				
				if [ $(__isNormalDir) == 1 ]; then
					fromNormalDir=1
				else
					oldRepo=$(git rev-parse --show-toplevel)
				fi
				
				builtin cd "$@"
				
				if [[ "$(git config --local prefix.check)" == "enabled" ]]; then
					if [[ $(__isNormalDir) == 0 ]]; then
						toRepo=1
						newRepo=$(git rev-parse --show-toplevel)
					fi
					
					if [[ $fromNormalDir == 1 && $toRepo == 1 || $oldRepo != "none" && $newRepo != "none" && $oldRepo != $newRepo ]]; then
						issue --check
					fi
				fi
				
				unset -f __isNormalDir
			}
		else
			if [[ ! -e $hookFile ]]; then
				printf "The command ${BOLD_WHITE}issue${RESET_COLOR} isn"\'"t installed for your repository yet.\r\n"
				return
			fi
			
			$(git config --local prefix.check enabled)
		fi
	}
	
	function __disableCheck {
		if [[ "$1" == "--global" ]]; then
			$(git config --global prefix.check disabled)
			unset -f cd
		else
			if [[ ! -e $hookFile ]]; then
				printf "The command ${BOLD_WHITE}issue${RESET_COLOR} isn"\'"t installed for your repository yet.\r\n"
				return
			fi
			
			$(git config --local prefix.check disabled)
		fi
	}
	
	function __check {
		if [[ ! -e $hookFile ]]; then
			printf "The command ${BOLD_WHITE}issue${RESET_COLOR} isn"\'"t installed for your repository yet.\r\n"
			return
		fi
		
		local issue=$(git config --local prefix.commitMessage)
		
		if [[ -n "$issue" && "$issue" != "none" ]]; then
			read -r -p "You"\'"re currently working on issue $(echo -e ${BOLD_WHITE}$issue${RESET_COLOR}). 
Do you wish to drop it? Then please answer yes.
" response
			if [[ ${response,,} =~ ^(yes|y)$ ]]; then
				$(git config --local prefix.commitMessage none)
				printf "You"\'"ve droped the issue.\r\n"
			fi
		else
			printf "You"\'"re currently working on no issue.\r\n"
		fi
	}
	
	function __open_issue {
		if [[ ! -e $hookFile ]]; then
			printf "The command ${BOLD_WHITE}issue${RESET_COLOR} isn"\'"t installed for your repository yet.\r\n"
			return
		fi
		
		local PREFIX=$1;
		# Saving a commit message prefix
		# in the global .gitconfig.
		# It will be read by the hook to set the prefix
		# in front of the commit message.
		$(git config --local prefix.commitMessage "$PREFIX")
		printf "\r\n${BOLD_WHITE}Prefixing enabled${RESET_COLOR}\r\n"
		printf "Make sure enabling the prepare-commit-msg hook\r\n"
		printf "in your repsitory: http://git.io/vITez\r\n\r\n"
	}
	
	function __close_issue {
		if [[ ! -e $hookFile ]]; then
			printf "The command ${BOLD_WHITE}issue${RESET_COLOR} isn"\'"t installed for your repository yet.\r\n"
			return
		fi
	
		# If no prefix is passed, the prefix will be
		# replaced with the string none in the global .gitconfig.
		$(git config --local prefix.commitMessage none)
		printf "\r\n${BOLD_WHITE}Prefixing disabled${RESET_COLOR}\r\n\r\n";
	}
	
	function __status {
		if [[ "$1" == "--global" ]]; then
			printf "Your global settings for <issue>

  Check: ${BOLD_WHITE}$(git config --global prefix.check)${RESET_COLOR}\r\n"
		else
			if [[ ! -e $hookFile ]]; then
				printf "The command ${BOLD_WHITE}issue${RESET_COLOR} isn"\'"t installed for your repository yet.\r\n"
				return
			fi
			
			printf "Your local settings for <issue>

  Issue: ${BOLD_WHITE}$(git config --local prefix.commitMessage)${RESET_COLOR}
  Check: ${BOLD_WHITE}$(git config --local prefix.check)${RESET_COLOR}\r\n"
		fi
	}
	
	if [[ $1 =~ ^-- ]]; then
		if [[ $1 == "--install" ]]; then
			__install $2

		elif [[ $1 == "--uninstall" ]]; then
			__uninstall $2
		
		elif [[ $1 == "--reinstall" ]]; then
			__reinstall $2
		
		elif [[ $1 == "--enable-check" ]]; then
			__enableCheck $2
		
		elif [[ $1 == "--disable-check" ]]; then
			__disableCheck $2
		
		elif [[ $1 == "--check" ]]; then
			__check
		
		elif [[ $1 == "--help" ]]; then
			__help
		
		else
			__help --invalid-option $1
		
		fi
		
	elif [[ $1 == open && -n $2 ]]; then
		__open_issue "$2"
	
	elif [[ $1 == close ]]; then
		__close_issue
	
	elif [[ $1 == "status" ]]; then
			__status $2
	
	fi
	
	unset -f __help
	unset -f __install
	unset -f __uninstall
	unset -f __reinstall
	unset -f __enableCheck
	unset -f __disableCheck
	unset -f __check
	unset -f __open_issue
	unset -f __close_issue
	unset -f __status
}

if [[ "$(git config --global prefix.check)" == "enabled" ]]; then
	issue --enable-check --global
fi
