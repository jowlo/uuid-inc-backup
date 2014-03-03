#!/bin/bash
#
#
# incremental backups with backup-count rotation
#
#
############################ SETTINGS #################

#uuid of device that is used as backup drive
BACKUPUUID="4ba7df79-6764-4fe8-a4d4-eead5fb4c6cc" 

# mountpoint where device should be mounted, should not be present, will be created.
# But containing directory should be existing. Specify as full path.
# If device with UUID is already mounted, existing mountpoint is used
BACKUPMNTPOINT="/mnt/backupDrive"

# directory to which we will backup under mountpoint, can be present, if not, will be created
BACKUPDIR="backup"

# filename prefix for backup tar-files
# will be appended by -dDATE-iINCREMENTALNUMBER.tgz
# better use alphabeticCharacters only
# (alphabetic only probably better)
BACKUPFILENAME="backup"     

# directory to which files should be copied when incremental threshold is reached
ROTATEDIR="rotate"

# threshold of incremental backups.
# after how many incremental backups should we rotate and make a new full backup
# set reeaaly high to not rotate and do only incrementals and manual full updates via --full flag
INCTHRESHOLD=30

# always force full backup. no incrementals. will still rotate everytime
# uncomment if needed
#FORCE_FULL_BACKUP="true"

# timestamp filename
# (alphabetic or (^\.[:alpha:]) only probably better)
TIMESTAMP="${BACKUPFILENAME}.stamp"

# date and time format used for filenames
# (better use formats that result in numerical strings only)A
# see man date for format strings
DATE="$(date +%d%m%Y)"
TIME="$(date +%H%M)"

# should ipfire defaults be backed up too?
# commment out to disable
INCLUDE_IPFIRE="true"

# directories to back up
SOURCEDIRS="
/home/
"

# directories to be excluded during backup
EXCLUDEDIRS="
/home/*
/home/user/Musik
/home/user/Spiele
/home/user/.VirtualBox
/home/*/.local/share/Trash
/var/ipfire/modem*
"



################################# SCRIPT #####################

### error handling
# function takes 2 arguments: "Error string" #ExitCode
function error_exit
{
      echo "BACKUP failed: ${1:-"Unknown Error"}" 1>&2
      exit $[2]
}


USAGE="Usage: `basename $0` [-fiIvh] [-d <dirname>] [-m <dirname>] [-U <UUID>] [-r <dirname>] [-p <filenameprefix>] [-g <filename>]\n
\t\t -f  rotate and force full backup\n
\t\t -i  include IPFire backup folders defined (default) \n
\t\t\t in /var/ipfire/backup/include\n
\t\t\t and /var/ipfire/backup/include.user\n
\t\t -n  do not include IPFire backup folders \n 
\t\t -I  ONLY backup IPFire Settings. Includes -i flag, disables all other sources\n
\t\t -U [UUID of backup device]\n
\t\t -d [dirname] backup directory name\n
\t\t -p [filenameprefix] prefix for backup filename\n
\t\t -g [filename] filename for timestamp parsed to tar via -g\n
\t\t\t defaults to: <filename>.stamp, where filename is taken\n
\t\t\t from default settings or overriden via -p flag if set)\n
\t\t -m [dirname] mountpoint that will be created by the script\n
\t\t -r [dirname] name of the rotate directory under backup directory\n
\t\t -v verbose output in addition to logging via /bin/logger\n
\t\t -h  print this help message and exit\n
\n
\tIf no arguments are given, standards defined in the script itself will be used.\n
\tNOTE: This will not work, unless you change the default values \n
\t\tin the script or provide command line arguments!\n"

# Parse command line options.
while getopts fiInhvU:d:p:g:m:r: OPT; do
    case "$OPT" in
        f)
            FORCE_FULL_BACKUP="true"
            ;;       
        i)
            INCLUDE_IPFIRE="true"
            ;;
        I)
            INCLUDE_IPFIRE="true"
            SOURCEDIRS=""
            EXCLUDEDIRS=""
            ;;
        n)
            INCLUDE_IPFIRE="false"
            ;;
        U)
            BACKUPUUID="${OPTARG}"
            ;;
        d)
            BACKUPDIR="${OPTARG}"
            ;;
        p)
            BACKUPFILENAME="${OPTARG}"
            TIMESTAMP="${BACKUPFILENAME}.stamp"
            ;;
        g)
            TIMESTAMP="${OPTARG}"
            ;;
        v)
            VERBOSE="true"
            ;;
        m)  
            BACKUPMNTPOINT="${OPTARG}"
            ;;
        r)
            ROTATEDIR="${OPTARG}"
            ;;
        h)
            echo -e $USAGE >&2
            exit 0
            ;;
        \?)
            # getopts issues an error message
            echo -e $USAGE >&2
            exit 1
            ;;
    esac
done

### assemble source and excludes

# gather IPFire backup list inclusions and append to SOURCEDIRS
if [ "$INCLUDE_IPFIRE" == "true" ]
then
  INCIPFIRESOURCES="$(for WORD in `cat /var/ipfire/backup/include; cat /var/ipfire/backup/include.user`; do /bin/ls -d $WORD 2>/dev/null; done;)"
  SOURCEDIRS="${SOURCEDIRS}
    ${INCIPFIRESOURCES}"
fi


# expand all wildcards in SOURCEDIRS
SOURCE=""
for source in ${SOURCEDIRS[@]}
do
  for src in "$(/bin/ls -d ${source} 2>/dev/null)"
  do
    if [ -n "${src##+([[:space:]])}" ]
    then
      SOURCE="${SOURCE} ${src}"
    fi
  done
done

# gather IPFire backup list exclusions and append to EXCLUDEDIRS
if [ "$INCLUDE_IPFIRE" == "true" ]
then
  EXCIPFIRESOURCES=$(for WORD in `cat /var/ipfire/backup/exclude; cat /var/ipfire/backup/exclude.user`; do /bin/ls -d $WORD 2>/dev/null; done;)
  EXCLUDEDIRS="${EXCLUDEDIRS}
    ${EXCIPFIRESOURCES}"
fi

# expand all wildcards in EXCLUDEDIRS
EXCLUDE=""
for exclusion in ${EXCLUDEDIRS[@]}
do
  for exc in "$(/bin/ls -d ${exclusion} 2>/dev/null)"
  do
    if [ -n "${exc##+([[:space:]])}" ]
    then
      EXCLUDE="${EXCLUDE} --exclude=${exc}"
    fi
  done
done




### check for USB-UUID
DEV="$(blkid -t UUID=${BACKUPUUID} | awk 'BEGIN{FS=":"} {print $1}')"

### check if UUID is mounted
CURRENTMNTPOINT="$(cat /etc/fstab | grep ${BACKUPUUID} | awk '{FS="=|\\ "} {print $2}'
)"
if [ -n "${CURRENTMNTPOINT##+([[:space:]])}" ]
then
  WAS_MOUNTED="true"
  BACKUPMNTPOINT="${CURRENTMNTPOINT##+([[:space:]])}" 
fi

if [ ! "${WAS_MOUNTED}" == "true" ]
then
  ### check if we have found a /dev symlink for our UUID
  if [ -z $DEV ]
  then
    error_exit "Not able to locate device by UUID." 1
  fi
  
  ### check if mountpoint exists and if not create
  if [ ! -d $BACKUPMNTPOINT ]
  then
    if ! /bin/mkdir $BACKUPMNTPOINT 
    then 
      error_exit " Not able to create mountpoint ${BACKUPMNTPOINT}." 2
    fi
  fi
  
  ### check if we can mount to mountpoint and mount
  if ! /bin/mount $DEV $BACKUPMNTPOINT 
  then
    error_exit "Not able mount device ${DEV} at ${BACKUPMNTPOINT}." 3
  fi
fi

### assemble full backup directory path
BACKUPDIR="${BACKUPMNTPOINT}/${BACKUPDIR}"

### assemble full rotate direcotry path
ROTATEDIR="${BACKUPDIR}/${ROTATEDIR}"

### change to root dir to preserve directory structure
cd /

### check if backupdirectory exists/can be created
if ! mkdir -p $BACKUPDIR 
then
  error_exit "backup directory '${BACKUPDIR}' not existing and/or could not be created." 4
fi


### shellfu to get last backupfilenamenumber
#lastBackupStamp=$(ls -vl ${BACKUPDIR}/${BACKUPFILENAME}-*.tgz | grep -v ^l | tail -n 1 | grep -P -o 'backup-[0-9]+')


### number of backups in backup directory
noOfBackups=$[10#$(ls -l ${BACKUPDIR}/${BACKUPFILENAME}-*.tgz 2>/dev/null | grep -v ^l | wc -l)]

### check, if the max amount of incremental backups has been reached or --full flag is set and create rotatedir
if [ $[noOfBackups]  -ge $[INCTHRESHOLD] ] || [ "${FORCE_FULL_BACKUP}" == "true" ]
then
  curRotateDir=${ROTATEDIR}/${DATE}-${TIME}
  ### check if rotatedir exists or if it can be created
  if ! mkdir -p ${curRotateDir}
  then 
    error_exit "Not able to create rotatedir ${curRotateDir}." 5
  else
    ### shell fu! move everything
    find ${BACKUPDIR} -maxdepth 1 -type f \( -name "${BACKUPFILENAME}*" -o -name "${TIMESTAMP}" \) -exec sh -c 'mv "$@" "$0"' ${curRotateDir}/ {} +
    if [ $? -ne 0 ]
    then
      error_exit "Old incremental backups could not be moved to rotatedir ${curRotateDir}." 6
    else
      LOG="Threshold for incremental backups reached. Moved all backups to ${curRotateDir}."
      noOfBackups=0
    fi
  fi
fi


### start backup

### check if file is not existing already. should be impossible, but never be sure - filesystems ! :)
if [ -f "${BACKUPDIR}/${BACKUPFILENAME}-d${DATE}t${TIME}-i$[noOfBackups].tgz" ]
then
  error_exit "BAD ERROR: The target backup file already exists: ${BACKUPDIR}/${BACKUPFILENAME}-d${DATE}t${TIME}-i$[noOfBackups].tgz." 7
fi

tar -cpzf ${BACKUPDIR}/${BACKUPFILENAME}-d${DATE}t${TIME}-i$[noOfBackups].tgz -g ${BACKUPDIR}/${TIMESTAMP} ${SOURCE} ${EXCLUDE} &> /dev/null

### check if successful
if [ $? -ne 0 ]
then
  error_exit "SERIOUSLY BAD: Backup failed for tar though circumstances seemed fine!" 8
else
  LOG="Incremental backup of ${SOURCE} to ${BACKUPDIR} successful."
fi


### umount and remove mountpoint

if [ ! "${WAS_MOUNTED}" == "true" ]
then
  if ! /bin/umount ${BACKUPMNTPOINT}
  then
    error_exit "Unmounting of backup drive with UUID ${BACKUPUUID} failed." 9
  fi
  
  if ! /bin/rmdir $BACKUPMNTPOINT
  then
    error_exit "Removal of mountpoint ${BACKUPMNTPOINT} failed." 10
  fi
fi



### write to log
/usr/bin/logger ${LOG}
if [ "${VERBOSE}" == "true" ]
  echo -e "Backed up the following directories:\n\n${SOURCE}\n\n\nWith the exclusion of:\n\n${EXCLUDE}\n\n tar command used:\n\n" 
  echo -e "tar -cpzf ${BACKUPDIR}/${BACKUPFILENAME}-d${DATE}t${TIME}-i$[noOfBackups].tgz -g ${BACKUPDIR}/${TIMESTAMP} ${SOURCE} ${EXCLUDE} &> /dev/null"
then
  echo -e $LOG
fi

exit 0
# EOF
