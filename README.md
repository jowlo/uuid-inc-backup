Automated Incremental Backup with Rotation based on UUID
==============

Short
--------------
The uuid-inc-backup.sh.sh shell script will perform incremental backups of hardcoded source directories via tar to a device with a specific UUID. If the device is not present, no backup will be performed. If the device is not mounted but present, it will be mounted, backed up to and unmounted afterwards.

By default, only 30 incremental backups are made. If this threshold is reached, all backups will be moved to a rotate directory and a new full backup is created. The threshold can be changed (to something around 99999999 to disable auto-rotation(

All Variables can be either set within the script itself as defaults or via command line options.

This automates what is described in depth here: http://www.gnu.org/software/tar/manual/html_chapter/Backups.html#SEC95

Restoring
--------------
See the guide on incremental backups via tar at http://www.gnu.org/software/tar/manual/html_chapter/Backups.html#SEC95 for ways to restore from the backup files.

NOTE: Tar will **delete** everything newer than the snapshot taken in the backup if you don't pay attention. See above guide.


Usage for uuid-inc-backup.sh
--------------

	Usage: uuid-inc-backup.sh [-fiInvh] [-d <dirname>] [-m <dirname>] [-U <UUID>] [-r <dirname>] [-d <dirname>] [-p <filenameprefix>] [-g <filename>] [-m <dirname>]	 
    	 -f rotate and force full backup
    	 -i include IPFire backup folders defined (default)
    	   in /var/ipfire/backup/include
    	   and /var/ipfire/backup/include.user
    	 -n do not include IPFire backup folders 
    	 -I ONLY backup IPFire Settings. Includes -i flag, disables all other sources
    	 -U [UUID of backup device]
    	 -d [dirname] backup directory name
    	 -p [filenameprefix] prefix for backup filename
    	 -g [filename] filename for timestamp parsed to tar via -g
    	   defaults to: <filename>.stamp, where filename is taken
    	   from default settings or overriden via -p flag if set)
    	 -m [dirname] mountpoint that will be created by the script
    	 -r [dirname] name of the rotate directory under backup directory
    	 -v verbose output in addition to logging via /bin/logger
    	 -h print this help message and exit
	
	If no arguments are given, standards defined in the script itself will be used.
	NOTE: This will not work, unless you change the default values
	      in the script or provide command line arguments!
