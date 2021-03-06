Automated Incremental Backup with Rotation based on UUID
==============

Short
--------------
The uuid-inc-backup.sh.sh shell script will perform incremental backups of hardcoded source directories via tar to a device with a specific UUID. If the device is not present, no backup will be performed. If the device is not mounted but present, it will be mounted, backed up to and unmounted afterwards.

By default, only 30 incremental backups are made. If this threshold is reached, all backups will be moved to a rotate directory and a new full backup is created. The threshold can be changed (to something around 99999999 to disable auto-rotation)

All Variables can be either set within the script itself as defaults or via command line options.

This automates what is described in depth here: http://www.gnu.org/software/tar/manual/html_chapter/Backups.html#SEC95

Restoring
--------------
See the guide on incremental backups via tar at http://www.gnu.org/software/tar/manual/html_chapter/Backups.html#SEC95 for ways to restore from the backup files.

NOTE: Tar will **delete** everything newer than the snapshot taken in the backup if you don't pay attention. See above guide.

Encryption
--------------
As of now, encrypting the backup is not coded in. But it could be easily added to the tar command line below by piping tar to 

		| openssl aes-256-cbc -kfile /path/to/key.pem > ${BACKUPFILENAME}.tgz.enc

where key.pem is a keyfile created by

		openssl genpkey -algorithm RSA -out /path/to/key.pem -aes-256-cbc 

The keyfile needs to be saved in a safe place (offsite), as it will not be copied to the backupdir (even if so, it will be in the encrypted backup).

*Decryption* could then be done by issuing

		cat backupfilename.tgz.enc | openssl aes-256-cbc -d -kfile ./key.pem | tar [x]
		
after opening the keyfile.


Splitting
--------------
As with encryption, splitting the backups into files with a maximus size could be achieved by piping the output of the tar command (or the output of above openssl encryption command) to something like

		| split -d -b 4000m - ${BACKUPFILENAME}.tgz.

To restore files afterwards, prepend any restoring with the following and pipe the output to your restore command

		cat backup-????.tgz.* |

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
