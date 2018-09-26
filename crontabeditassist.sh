#!/bin/bash

# System-wide crontab file and cron job directory. Change these for your system.
BACKUP_COPY='/opt/crondeditwrkspace/original_allcrontabs_backup'
TEMP_WTH_OVERRWITE_FILES='/opt/crondeditwrkspace/tmp_allcrontabs_to_overwrite'
# SYSTEM_CRONTAB='/etc/crontab'
# SYSTEM_CROND='/etc/cron.d'
SYSTEM_CRONTAB='/opt/original_allcrontabs_backup/crontab'
SYSTEM_CROND='/opt/original_allcrontabs_backup/cron.d'

RED='\033[0;31m'    # Red
NOCL='\033[0m'      # Text Reset
GREEN='\033[0;32m'  # Green
YELLOW='\033[0;33m' # Yellow
RED='\033[0;31m'    # Red
BLUE='\033[0;34m'   # Blue

#
# Take a backup of all Original system files
take_system_backup() {
	sudo mkdir -p ${BACKUP_COPY}
	sudo cp ${SYSTEM_CRONTAB} ${BACKUP_COPY}/
	sudo cp -r ${SYSTEM_CROND} ${BACKUP_COPY}/
}

#
# create a Tmp folder containing  *.overwrite file
create_overwrite_editable() {
	sudo mkdir -p ${TEMP_WTH_OVERRWITE_FILES}
	sudo cp ${SYSTEM_CRONTAB} ${TEMP_WTH_OVERRWITE_FILES}/
	sudo cp -r ${SYSTEM_CROND} ${TEMP_WTH_OVERRWITE_FILES}/

	cd ${TEMP_WTH_OVERRWITE_FILES}/
	sudo find -type f -exec mv {} {}".overwrite" \;
	sudo find -type f -name "*.overwrite" -exec chmod 777 {} \;
}

# Method: copied as-is from reference
# Reference:
# https://gist.github.com/hanchang/1167330/a0b07afaf71a8a5dc1b55ca9d04349c1f8ca4437
#
# Given a stream of crontab lines, exclude non-cron job lines, replace
# whitespace characters with a single space, and remove any spaces from the
# beginning of each line.
function clean_cron_lines() {
	while read line; do
		echo "${line}" |
			egrep --invert-match '^($|\s*#|\s*[[:alnum:]_]+=)' |
			sed --regexp-extended "s/\s+/ /g" |
			sed --regexp-extended "s/^ //"
	done
}

#
# Method: copied as-is from reference
# Reference Method:
# https://gist.github.com/hanchang/1167330/a0b07afaf71a8a5dc1b55ca9d04349c1f8ca4437
#
# Given a stream of cleaned crontab lines, echo any that don't include the
# run-parts command, and for those that do, show each job file in the run-parts
# directory as if it were scheduled explicitly.
function lookup_run_parts() {
	while read line; do
		match=$(echo "${line}" | egrep -o 'run-parts (-{1,2}\S+ )*\S+')

		if [[ -z ${match} ]]; then
			echo "${line}"
		else
			cron_fields=$(echo "${line}" | cut -f1-6 -d' ')
			cron_job_dir=$(echo "${match}" | awk '{print $NF}')

			if [[ -d ${cron_job_dir} ]]; then
				for cron_job_file in "${cron_job_dir}"/*; do # */ <not a comment>
					[[ -f ${cron_job_file} ]] && echo "${cron_fields} ${cron_job_file}"
				done
			fi
		fi
	done
}

#
# Method: copied as-is from reference
# Reference Method:
# https://gist.github.com/hanchang/1167330/a0b07afaf71a8a5dc1b55ca9d04349c1f8ca4437
#
uncommented_crontab_entries_before() {
	local CRONTAB="${TEMP_WTH_OVERRWITE_FILES}/crontab.overwrite"
	local CRONDIR="${TEMP_WTH_OVERRWITE_FILES}/cron.d"

	# Single tab character. Annoyingly necessary.
	tab=$(echo -en "\t")

	# Temporary file for crontab lines.
	temp=$(mktemp) || exit 1

	# Add all of the jobs from the system-wide crontab file.
	cat "${CRONTAB}" | clean_cron_lines | lookup_run_parts >"${temp}"

	# Add all of the jobs from the system-wide cron directory.
	cat "${CRONDIR}"/* | clean_cron_lines >>"${temp}" # */ <not a comment>

	# Add each user's crontab (if it exists). Insert the user's name between the
	# five time fields and the command.
	while read user; do
		crontab -l -u "${user}" 2>/dev/null |
			clean_cron_lines |
			sed --regexp-extended "s/^((\S+ +){5})(.+)$/\1${user} \3/" >>"${temp}"
	done < <(cut --fields=1 --delimiter=: /etc/passwd)

	# Output the collected crontab lines. Replace the single spaces between the
	# fields with tab characters, sort the lines by hour and minute, insert the
	# header line, and format the results as a table.
	cat "${temp}" |
		sed --regexp-extended "s/^(\S+) +(\S+) +(\S+) +(\S+) +(\S+) +(\S+) +(.*)$/\1\t\2\t\3\t\4\t\5\t\6\t\7/" |
		sort --numeric-sort --field-separator="${tab}" --key=2,1 |
		sed "1i\mi\th\td\tm\tw\tuser\tcommand" |
		column -s"${tab}" -t

	sudo rm --force "${temp}"
}

before_mainedit() {

	if [ "$(id -u)" != "0" ]; then
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		echo -e "Only ${BLUE}root (i.e. sudo)${NOCL} can run this operation"
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		exit 1
	fi

	if [ -e ${TEMP_WTH_OVERRWITE_FILES} ] && [ -e ${BACKUP_COPY} ]; then
		sudo mv ${TEMP_WTH_OVERRWITE_FILES} "${TEMP_WTH_OVERRWITE_FILES}_OLD"
		sudo mv ${BACKUP_COPY} "${BACKUP_COPY}_OLD"
	fi

	take_system_backup
	echo -e "successfully! completed the original backup"
	echo -e "FullPath: ${BLUE}${BACKUP_COPY}${NOCL}"
	echo

	create_overwrite_editable
	echo -e "successfully! created editable files: ${BLUE}*.overwrite${NOCL}"
	echo -e "in folder: ${BLUE}${TEMP_WTH_OVERRWITE_FILES}${NOCL}"
	echo
	echo
	echo "~ Start Manual Edit ~"
	echo -e "Add comment using hash(#) to the following entries found in file"
	echo -e "Edit files with extension ${BLUE}.overwrite${NOCL} ONLY using command line"
	echo -e "${BLUE}gedit *.overwrite${NOCL}"
	echo -e "for all the files in PATH:${BLUE}${TEMP_WTH_OVERRWITE_FILES}${NOCL}"
	echo
	echo -e "Depending on your comfort level, you may choose terminal edit tools like"
	echo -e "${BLUE}'vi'${NOCL} or ${BLUE}'vim'${NOCL} *.overwrite"
	echo

	echo -e -n "${GREEN}"
	echo " - - - - - - - - - - - - - - - - - - - - "
	uncommented_crontab_entries_before
	echo " - - - - - - - - - - - - - - - - - - - - "
	echo -e "${NOCL}"
	echo -e "NOTE: for ${BLUE}user(local account)${NOCL} specific crontab entry (IF and ONLY IF) listed above"
	echo -e "(then) use the command: ${RED}sudo crontab -u (user) -e${NOCL}"
	echo

	echo

}

uncommented_crontab_entries_after() {
	local CRONTAB=${TEMP_WTH_OVERRWITE_FILES}"/crontab.overwrite"
	local CRONDIR=${TEMP_WTH_OVERRWITE_FILES}"/cron.d"

	# Single tab character. Annoyingly necessary.
	tab=$(echo -en "\t")

	# Temporary file for crontab lines.
	temp=$(mktemp) || exit 1

	# Add all of the jobs from the system-wide crontab file.
	cat "${CRONTAB}" | clean_cron_lines | lookup_run_parts >"${temp}"

	# Add all of the jobs from the system-wide cron directory.
	cat "${CRONDIR}"/*.overwrite | clean_cron_lines >>"${temp}" # */ <not a comment>

	# Add each user's crontab (if it exists). Insert the user's name between the
	# five time fields and the command.
	while read user; do
		crontab -l -u "${user}" 2>/dev/null |
			clean_cron_lines |
			sed --regexp-extended "s/^((\S+ +){5})(.+)$/\1${user} \3/" >>"${temp}"
	done < <(cut --fields=1 --delimiter=: /etc/passwd)

	# Output the collected crontab lines. Replace the single spaces between the
	# fields with tab characters, sort the lines by hour and minute, insert the
	# header line, and format the results as a table.
	cat "${temp}" |
		sed --regexp-extended "s/^(\S+) +(\S+) +(\S+) +(\S+) +(\S+) +(\S+) +(.*)$/\1\t\2\t\3\t\4\t\5\t\6\t\7/" |
		sort --numeric-sort --field-separator="${tab}" --key=2,1 |
		sed "1i\mi\th\td\tm\tw\tuser\tcommand" |
		column -s"${tab}" -t

	local cnt=$(cat "${temp}" | wc -l)

	if [ ${cnt} -ne 0 ]; then
		echo -e "${NOCL}"
		echo -e "found active (un-comment) entries ${RED}${cnt}${NOCL}"
		echo -e "use cmd: ${RED}sudo crontab -u user -e ${NOCL} "
		echo "Only If crontab entries listed(above) could NOT be found in *.overwrite files"
	fi

	sudo rm --force "${temp}"
}

overwrite_revision() {
	if [ -e ${TEMP_WTH_OVERRWITE_FILES} ] && [ -e ${BACKUP_COPY} ]; then
		echo
		echo -e "Scanning the tmp overwrite Files: ${BLUE}${TEMP_WTH_OVERRWITE_FILES}${NOCL}"
		echo
		echo "After user edit found Uncommented list of crontabs"
		echo -e -n "${BLUE}"
		echo " - - - - - - - - - - - - - - - - - - - - "
		uncommented_crontab_entries_after
		echo -e "${BLUE} - - - - - - - - - - - - - - - - - - - - ${NOCL}"
		echo
		echo
		echo -e "Would you like to ${BLUE}Replace (Overwrite)${NOCL} the following files"
		echo -e -n "${BLUE}"
		sudo ls -l ${SYSTEM_CRONTAB}
		echo -e "${NOCL}"
		echo "files in folder ${SYSTEM_CROND}"
		echo -e -n "${BLUE}"
		sudo ls -l ${SYSTEM_CROND}
		echo -e "${NOCL}"
		echo -e "with their equivalent ${BLUE}*.overwrite${NOCL} files in  ${BLUE}${TEMP_WTH_OVERRWITE_FILES}${NOCL}"
		echo
	else
		echo
		if [ ! -e ${TEMP_WTH_OVERRWITE_FILES} ]; then
			echo -e "${RED}Missing:${NOCL} Temporary Edit Folder: ${BLUE}${TEMP_WTH_OVERRWITE_FILES}${NOCL} containing ${BLUE}*.overwrite${NOCL} files "
			echo
		fi
		if [ ! -e ${BACKUP_COPY} ]; then
			echo -e "${RED}Missing:${NOCL} Original backup: ${BLUE}${BACKUP_COPY}${NOCL} containing files "
			echo
		fi
		echo -e "you may want to run ${BLUE}sudo ./beforeedit.sh${NOCL} to get started"
		exit 1
	fi

}

crontab_file_replace() {
	local new_file_crontab=${TEMP_WTH_OVERRWITE_FILES}"/crontab.overwrite"
	#local SYSTEM_CRONTAB='/etc/crontab'

	echo "Start~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	if [ $(sudo diff ${SYSTEM_CRONTAB} ${new_file_crontab} | wc -l) -ne 0 ]; then
		echo -e "${BLUE} *Found *${NOCL} Diff between"
		echo -e "${RED}Original${NOCL} file= ${RED}${SYSTEM_CRONTAB}${NOCL}"
		echo -e "${BLUE}New${NOCL} file= ${BLUE}${new_file_crontab}${NOCL}"
		echo
		sudo chown --reference=${SYSTEM_CRONTAB} ${new_file_crontab}
		sudo chmod --reference=${SYSTEM_CRONTAB} ${new_file_crontab}
		sudo rm ${SYSTEM_CRONTAB}
		sudo mv ${new_file_crontab} ${SYSTEM_CRONTAB}
		echo -e "replaced ${BLUE} ${SYSTEM_CRONTAB} ${NOCL}"
		echo
	else
		echo -e "${BLUE} *NO* ${NOCL} Diff between crontab and crontab.overwrite"
		sudo rm ${new_file_crontab}
	fi
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Stop"
}

crond_dir_replace() {
	local tmp_overwrite_crond=${TEMP_WTH_OVERRWITE_FILES}"/cron.d/"

	cd "${tmp_overwrite_crond}"
	# remove any gedit file
	# sudo find -type f -name "*.overwrite~" -exec rm {} \;


	for f in *.overwrite; do
		local sys_original_file="${f%.overwrite}"
		local new_changed_file="${f%}"

		# echo "Syste_File is "
		# echo "${sys_original_file}"
		# echo "tmp overwrkte is "
		# echo "${new_changed_file}"

		local sys_original_filepath="${SYSTEM_CROND}/${sys_original_file}"
		local new_changed_filepath="${tmp_overwrite_crond}${new_changed_file}"

		# echo "Syste_File is "
		# echo "${sys_original_filepath}"
		# echo "tmp overwrkte is "
		# echo "${new_changed_filepath}"

		echo
		if [ $(sudo diff ${sys_original_filepath} ${new_changed_filepath} | wc -l) -ne 0 ]; then
			echo "Start~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
			echo -e "${BLUE} *Found* ${NOCL} Diff between"
			echo -e "Replacing ${RED}Original${NOCL} file= ${RED}${sys_original_file}${NOCL}"
			echo -e "with ${BLUE}New${NOCL} file= ${BLUE}${new_changed_file}${NOCL}"

			sudo chown --reference=${sys_original_filepath} ${new_changed_filepath}
			sudo chmod --reference=${sys_original_filepath} ${new_changed_filepath}
			sudo rm ${sys_original_filepath}
			sudo mv ${new_changed_filepath} ${sys_original_filepath}
			echo -e "replaced ${BLUE} ${sys_original_filepath} ${NOCL}"
			echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Stop"
		fi
	done

}

main_cron_replace() {
	echo
	echo
	crontab_file_replace
	crond_dir_replace
}

review_replace_crontab_list() {
	local
	local BLUE='\033[0;34m' # BLUE
	local NOCL='\033[0m'    # Text Reset

	if [ "$(id -u)" != "0" ]; then
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		echo -e "Only ${BLUE}root (i.e. sudo)${NOCL} can run this operation"
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		exit 1
	fi

	overwrite_revision
	echo
	while true; do
		read -p "Are you happy with the Un-commented crontab lines? " yn
		case $yn in
		[YES]*)
			echo -e "...start ${BLUE}replaceing${NOCL} origial files under "
			main_cron_replace
			return 0
			break
			;;
		[NO]*)
			echo -e "...${BLUE}Exiting Now${NOCL}"
			echo
			return 7
			;;
		*)
			echo
			echo -e "Please answer ${GREEN}YES${NOCL} or ${GREEN}NO${NOCL} (i.e. all Capital letter only)"
			echo
			;;
		esac
	done
}

check_overwrite_folder_uncommented() {
	if [ -e ${TEMP_WTH_OVERRWITE_FILES} ] && [ -e ${BACKUP_COPY} ]; then
		echo
		echo -e "for all the files in PATH:${BLUE}${TEMP_WTH_OVERRWITE_FILES}${NOCL}"
		echo
		echo -e -n "${GREEN}"
		echo " - - - - - - - - - - - - - - - - - - - - "
		uncommented_crontab_entries_after
		echo " - - - - - - - - - - - - - - - - - - - - "
		echo -e "${NOCL}"
	else
		echo
		if [ ! -e ${TEMP_WTH_OVERRWITE_FILES} ]; then
			echo -e "${RED}Missing:${NOCL} Temporary Edit Folder: ${BLUE}${TEMP_WTH_OVERRWITE_FILES}${NOCL} containing ${BLUE}*.overwrite${NOCL} files "
			echo
		fi
		if [ ! -e ${BACKUP_COPY} ]; then
			echo -e "${RED}Missing:${NOCL} Original backup: ${BLUE}${BACKUP_COPY}${NOCL} containing files "
			echo
		fi
		echo -e "you may want to run ${BLUE}sudo ./beforeedit.sh${NOCL} to get started"
		exit 1
	fi
}

uncommented_crontab_system() {
	local CRONTAB=${SYSTEM_CRONTAB}
	local CRONDIR=${SYSTEM_CROND}

	# Single tab character. Annoyingly necessary.
	tab=$(echo -en "\t")

	# Temporary file for crontab lines.
	temp=$(mktemp) || exit 1

	# Add all of the jobs from the system-wide crontab file.
	cat "${CRONTAB}" | clean_cron_lines | lookup_run_parts >"${temp}"

	# Add all of the jobs from the system-wide cron directory.
	cat "${CRONDIR}"/* | clean_cron_lines >>"${temp}" # */ <not a comment>

	# Add each user's crontab (if it exists). Insert the user's name between the
	# five time fields and the command.
	while read user; do
		crontab -l -u "${user}" 2>/dev/null |
			clean_cron_lines |
			sed --regexp-extended "s/^((\S+ +){5})(.+)$/\1${user} \3/" >>"${temp}"
	done < <(cut --fields=1 --delimiter=: /etc/passwd)

	# Output the collected crontab lines. Replace the single spaces between the
	# fields with tab characters, sort the lines by hour and minute, insert the
	# header line, and format the results as a table.
	cat "${temp}" |
		sed --regexp-extended "s/^(\S+) +(\S+) +(\S+) +(\S+) +(\S+) +(\S+) +(.*)$/\1\t\2\t\3\t\4\t\5\t\6\t\7/" |
		sort --numeric-sort --field-separator="${tab}" --key=2,1 |
		sed "1i\mi\th\td\tm\tw\tuser\tcommand" |
		column -s"${tab}" -t

	sudo rm --force "${temp}"
}

check_SYSTEM_files() {
	echo
	echo -e "systrm file :${BLUE}${SYSTEM_CRONTAB}${NOCL}"
	echo -e "AND all the files in PATH:${BLUE}${SYSTEM_CROND}${NOCL}"
	echo -e -n "${GREEN}"
	echo " - - - - - - - - - - - - - - - - - - - - "
	uncommented_crontab_system
	echo " - - - - - - - - - - - - - - - - - - - - "
	echo -e "${NOCL}"
}

case "$1" in
check_overwrite)
	check_overwrite_folder_uncommented
	;;
check_system)
	check_SYSTEM_files
	;;
before)
	before_mainedit
	;;
after)
	review_replace_crontab_list
	;;
*)
	echo
	echo -e "${RED}NOTE:${NOCL} This can cause some Serious Issues in your OS image "
	echo -e "If you are ${RED}NOT${NOCL} sure or confident, what you are doing ${RED}Please, Just Stop${NOCL} using this Script"
	echo
	echo -e "${BLUE}~##~ ~##~ ~##~ ~##~ ~##~ ~##~ ~##~ ~##~ ~##~ ~##~ ~##~ ~##~${NOCL}"
	echo -e "${BLUE}~##~${NOCL} Script to assist with crontab edit and replace ~##~ ${BLUE}~##~${NOCL}"
	echo -e "${BLUE}#${NOCL} sudo ./crontabeditassist.sh ${BLUE}before${NOCL}"
	echo -e "${BLUE}#${NOCL}"
	echo -e "${BLUE}#${NOCL} sudo ./crontabeditassist.sh ${RED}after${NOCL}"
	echo -e "${BLUE}#${NOCL}       ${RED}after${NOCL} => will find and replace Modified *.overwrite of your system files"
	echo -e "${BLUE}#${NOCL}"
	echo -e "${BLUE}#${NOCL} sudo ./crontabeditassist.sh ${BLUE}check_overwrite${NOCL}"
	echo -e "${BLUE}#       check_overwrite${NOCL} => will cross-check uncommented crontab entires in *.overwrite files"
	echo -e "${BLUE}#${NOCL} if exist ( in Path: ${BLUE}${TEMP_WTH_OVERRWITE_FILES}${NOCL} ) "
	echo -e "${BLUE}#${NOCL}"
	echo -e "${BLUE}#${NOCL} sudo ./crontabeditassist.sh ${BLUE}check_system${NOCL}"
	echo -e "${BLUE}#       check_system${NOCL} => will cross-check uncommented crontab entires in System"
	echo -e "${BLUE}#${NOCL} 1) file: ${SYSTEM_CRONTAB}"
	echo -e "${BLUE}#${NOCL} 2) folder: ${SYSTEM_CROND}"
	echo -e "${BLUE}~##~ ~##~ ~##~ ~##~ ~##~ ~##~ ~##~ ~##~ ~##~ ~##~ ~##~ ~##~${NOCL}"
	echo
	;;
esac
