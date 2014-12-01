#!/bin/bash

# Small script to manage uploads
#
# Usage:
# Add a new file :
#    bash reupload.sh http://link.to.file
# Test links (and reup if needed) :
#    bash reupload.sh

if [ ! [ -f etc/reuploader.conf ]  && ! [ source etc/reuploader.conf ]] then
	echo "Configuration not found, exiting"
	exit 0
fi

#######################################
#                                     #
#         System variables            #
#                                     #
#######################################
# Path to executables
SQLITE="/usr/bin/sqlite3"
PLOW="/usr/local/bin"

#
# Download procedure
# $1 : url
# $2 : if equal to no, it's a new download try

function download {
	link=$1
	file=`${PLOW}/plowdown -v0 --printf="%F" -o ${FPATH} ${link}`
	if [ "$2" == "no" ]; then
		if [ "${file}" != "" ]; then
			${SQLITE} ${DBNAME} "UPDATE upfile SET file='${file}', seen=DATETIME('NOW'), link='${link}', tries=0 WHERE source='${link}'"
		else
			${SQLITE} ${DBNAME} "UPDATE upfile SET tries=(tries+1) WHERE source='${link}'"
		fi
	else
		if [ "${file}" != "" ]; then
			${SQLITE} ${DBNAME} "INSERT INTO upfile (source, file, seen, link, tries) VALUES('${link}', '${file}', DATETIME('NOW'), '${link}', 0)"
		else
			${SQLITE} ${DBNAME} "INSERT INTO upfile (source, file, seen, link, tries) VALUES('${link}', '', '1970-01-01 00:00:00', '', ${TRIES})"
		fi
	fi
}

#
# Upload procedure
# $1 : source file
# $2 : initial source

function upload {
	RANDOM=$$$(date +%s)
	file=$1
	source=$2
	provider=${plugins[$RANDOM % ${#plugins[@]}]}
	uploaded=`${PLOW}/plowup -v0 --printf="%u" ${provider} ${file}`
	if [ "${uploaded}" != "" ]; then
		${SQLITE} ${DBNAME} "UPDATE upfile SET seen=DATETIME('NOW'), link='${uploaded}', tries=0 WHERE source='${source}'"
	else
		echo "Cannot upload ${file}"
	fi
}

#
# function check
#
function check {
	for row in `${SQLITE} ${DBNAME} "SELECT source, link, file FROM upfile WHERE tries<3 ORDER BY seen ASC LIMIT ${nbf}"`
	do
		IFS='|' read -a fields <<< "$row"
		if [ "${fields[2]}" == "" ]; then
			download ${fields[1]} "no"
		else
			file=${fields[2]}
			test=`${PLOW}/plowprobe -v0 --printf="%c" ${fields[1]}`
			if [ "${test}" == "0" ]; then
				${SQLITE} ${DBNAME} "UPDATE upfile SET seen=DATETIME('NOW'), tries=0 WHERE source='${fields[0]}'"
			else
				upload ${file} ${fields[1]}
			fi
		fi
	done
}

#
# The core
#
# Checks requirement, create if needed
if [ ! -f ${DBNAME} ]; then
	`${SQLITE} ${DBNAME} < resources/inidb.sql`
fi
if [ -f ${FPATH} ]; then
	echo "${FPATH} exists and is not a directory. Aborted"
	exit 0
else
	if [ ! -d ${FPATH} ]; then
		mkdir ${FPATH}
	fi
fi

#
# The new link procedure
#
if [ $1 ]; then
	count=`${SQLITE} ${DBNAME} "SELECT COUNT(*) FROM upfile WHERE source='$1'"`
	if [ "$count" == "0" ]; then
		download $1 0
	else
		echo "$1 is already here"
	fi
else
	check
fi

