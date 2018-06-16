#!/bin/dash
#
# SYNOPSIS
#
#     la-container.sh apt-get-install PACKAGE...
#     la-container.sh backup [--force-full] [--no-live-check] [BACKUP_URL [--DUPLICITY-OPT]]
#     la-container.sh boot [DUMP.DIR]
#     la-container.sh build [--mirror=MIRROR] [--suite=SUITE]
#     la-container.sh build-options [--mirror=MIRROR] [--suite=SUITE]
#     la-container.sh dump [DUMP.DIR]
#     la-container.sh init
#     la-container.sh is-live HOSTNAME
#     la-container.sh lockfile lock|unlock|wait LOCKFILE [PID]
#     la-container.sh restore BACKUP_URL /DATA_DIR [--DUPLICITY-OPT...]
#     la-container.sh rotate /DATA_DIR [LOG_FILE ...]
#     la-container.sh run-timer TIMER-NAME
#     la-container.sh service restart|rotate|start|statusboard|stop [SERVICE_NAME]
#     la-container.sh snakeoil OUTPUT-DIR [*.]FQDN...
#     la-container.sh statusboard WHAT ok|fail|purge MESSAGE...
#     la-container.sh timer-when TIMER-NAME [AFTER]
#     /init.sh
#
#
# DESCRIPTION
#
#     la-container.sh is a Swiss army knife for building applications that
#     run on Linux Australia's infrastructure.  Read the "RUNNING AND USING
#     LA-CONTAINERS" section first, then if you are building an application
#     that will run in a la-container read the "DEVELOPMENT" section next.
#
#     la-container is used outside of the container to do these jobs:
#
#	  -   Building the docker base image for a la-container.
#         -   Restoring a containers backup.
#	  -   Creating dummy x509 certificates.
#
#     Inside of the container la-container.sh has these tasks, which happen
#     mostly automatically:
#
#	  -   It is init - ie does the job SysV init, systemd and systemctl do.
#	  -   It runs timers, like cron does.
#	  -   Backing up the container to multiple sites.
#	  -   Fetching security updates and installing them.
#	  -   Creating and publishing a health status board via HTTP.
#	  -   Rotating log files.
#
#
# INVOCATION
#
#     la-container.sh apt-get-install [--help] PACKAGE...
#
#	  When run in the container it install the Debian packages supplied
#	  not-interactively using apt-get and cleanups up all downloads
#	  after it is done.  This keeps the container small.
#
#	  PACKAGE...
#	      The Debian packages to download.
#
#     la-container.sh backup [--force-full] [--no-live-check] [BACKUP_URL]
#
#	  Do a backup.  Must be run from within the container.  The containers
#	  init process runs this command without arguments every 8 hours.
#	  A backup will not be sent to a location if nothing has changed since
#	  the last backup was sent there.  This command runs
#	  "application.sh dump" to prepare the backup.
#
#	  Backups run at a _very_ low priority.  They will take far longer
#	  than you expect.
#
#	  [--force-full]
#	      If not present the backup will be skipped entirely if it hasn't
#	      changed otherwise an incremental backup done if it isn't time
#	      for a full backup.  This option bypasses both checks, forcing
#	      a full backup to be done.
#
#	  [--no-live-check]
#	      Do the backup rather than aborting with an error message even if
#	      the server isn't running on the hostname contained in the file
#	      "/data/etc/la-container/production-fqdn".  This check is
#	      performed to verify it is the live container being backed up.  It
#	      is done to avoid having some poor developer being accused of
#	      wrecking havoc on the backup system by innocently spinning up a
#	      throwaway container and overwriting the real backup data with
#	      whatever crap he has on his system.
#
#	  [BACKUP_URL]
#	      Backup to this URL. If not supplied the result is sent to all
#	      location set in /DATA_DIR/etc/la-container/backup-sites.
#
#	  Configuration is read from these places:
#
#	      /DATA_DIR/etc/la-container/backup-sites
#		  This directory contains duplicity(1) URL's to send the
#		  backup to.  See the README.txt in the directory for more
#		  information.
#
#	      /DATA_DIR/etc/la-container/backup-keys
#		  This directory contains the public gpg keys used to encrypt
#		  the backups.  See the README.txt in the directory for more
#		  information.
#
#	      /DATA_DIR/etc/la-container/production-fqdn
#		  This file contains the fully qualified domain name of the
#		  the live container, ie the one running in production.  Look
#		  at the comments in the file for more information.
#
#     la-container.sh boot [--help] [DUMP.DIR]
#
#	  This is a working example of how to write the "application.sh boot"
#	  command, which is the first application command run within the
#	  container.  When boot exits all services with the container must be
#	  running.  The responsibilities of this command are:
#
#	  -   Check if [DUMP.DIR] was passed, and if so restore the dump.
#
#	  -   Populate /data with default versions of all tunable configuration
#	      files the application supports, if they don't already exist.
#	      Thus if the container is given empty /data it must start in its
#	      "factory default state", and after having populated /data with
#	      commented examples of everything the sysadmin can configure.
#
#	  -   Check if the files in /data are from an older version of the
#	      container, and upgrade them if so.
#
#	  -   Start all the containers services.
#
#	  [DUMP.DIR]
#	      If this directory is passed it will contain a copy of the data
#	      put their by an earlier run of "application.sh dump".
#	      "application.sh boot" must restore the container to the state
#	      it was in when that dump was done. This includes all of
#	      la-container.sh's state, but that is guaranteed to happen if
#	      you restore everything under /etc.
#
#     la-container.sh build [--mirror=MIRROR] [--suite=SUITE]
#
#	  Build the la-container docker container and add/replace it to the
#	  local docker repository.  Once it succeeds la-container-SUITE:latest
#	  should appear in "docker image ls".
#
#	  --mirror=MIRROR
#	      Download debian packages from MIRROR instead of
#	      http://deb.debian.org/debian.  This setting written to the
#	      containers /etc/apt/sources.list.
#
#	  --suite=SUITE
#	      The codename of Debian release to use instead of whatever stable
#	      is called.  This setting is written to the containers
#	      /etc/apt/sources.list.
#
#     la-container.sh build-options [--mirror=MIRROR] [--suite=SUITE]
#
#	  Echo the options given on the command line to stdout, but add the
#	  default values "la-container.sh build" would use for the omitted
#	  options.  In other words if "la-container.sh build" is run in the
#	  the future when new versions of software available it will build
#	  same the same container is will now if given the options passed
#	  instead of using the newer versions.  The definition of "same" is
#	  a little flexible.  It doesn't mean identical.  It means no software
#	  will notice the change, which implies the API is identical and the
#	  format of persisted data in /DATA_DIR is identical.
#
#     la-container.sh dump [--help] [DUMP.DIR]
#
#	  This is run in the container, only.  It is a working example of how
#	  to write the "application.sh boot" command, which must populate
#	  [DUMP.DIR] with a consistent (as in relational database definition
#	  of "consistent") copy of the data to be backed up.  Hard links work
#	  fine for files that don't change, such as stuff under /etc.
#	  [DUMP.DIR] will not exist when it is called.  If it does not exist
#	  when the command returns or the command has a non-zero exit status
#	  the backup will not proceed.
#
#	  Convert the backed up files to a format that plays well with
#	  duplicity(1)'s differential backup algorithm, is likely to be
#	  usable in 100 years, and is compatible with VCS's.  It turns out a
#	  SQL dump of a relational database meets all criteria with the
#	  minimum amount of pain: if done in one transaction it will be
#	  consistent, if dumped in primary key order it will be rdiff friendly,
#	  and the text will likely be usable by anyone in 100 years time.  For
#	  example, don't backup the raw.sqlite3 database, run "sqlite3
#	  raw.sqlite3 dump" and backup the result instead.
#
#	  Monitor duplicity's backups for a while for noise (ie nothing has
#	  changed, yet a new backup was created), and strip it out.  The
#	  example in la-container.sh tells mysql to omit dump dates when
#	  dumping the Wordpress database, then uses an ugly little sed script
#	  to remove the timestamp row Wordpress updates every time someone
#	  scratches their nose.  Wordpress doesn't mind, and such timestamps
#	  needlessly inflate differential backups.
#
#     la-container.sh init
#
#	  This is the containers docker entrypoint. It is invoked as /init.sh,
#	  which is a symlink to /usr/local/la-container/la-container.sh, which
#	  is where this script lives in the container.  On starting this
#	  script checks for the presence of a backup, runs "application.sh
#	  boot", checks for log rotates at least hourly and runs the
#	  timers configured in "/etc/la-container/timers" as it does so.
#	  application.sh is assumed to in the same directory as
#	  la-container.sh, after following symbolic links.
#
#     la-container.sh is-live HOSTNAME
#
#	  Exit with a status of 0 if the container is running on HOSTNAME,
#	  otherwise issue an error message and exit with a non-zero status.
#	  This can be used by "application.sh dump" to check if it is
#	  running on the live (aka production) container.  It can only be
#	  used within the container.
#
#     la-container.sh lockfile lock|unlock|wait LOCKFILE [PID]
#
#	  Ensure only one process is doing the activity associated with
#	  LOCKFILE.
#
#	  OPERATION
#
#	      lock	If another process owns LOCKFILE return its PID,
#			otherwise if this PID does not own LOCKFILE acquire
#			ownership.
#
#	      unlock	If PID owns LOCKFILE relinquish ownership.  This
#			should always follow a "wait" and a successful "lock".
#
#	      wait	Wait until no other PID owns LOCKFILE, then acquire
#			ownership if PID doesn't already own LOCKFILE.
#
#	  LOCKFILE	The name of a file under "/run" to use for the lock.
#
#	  PID		The currently running process id (see getpid(2)) that
#			is manipulating the lock.  If not pass the shells
#			process ID is used.  The lock is only held while this
#			process is running.
#
#     la-container.sh restore [--help] BACKUP_URL /DATA_DIR [--DUPLICITY-OPT...]
#
#	  Restore a container from a backup.  It fetches the backup so the
#	  container will restore it when it is next started.  If the backup is
#	  encrypted a matching private key must be in your gnupg(1) keyring.
#
#	  BACKUP_URL
#	      The duplicity(1) URL the backup was written to.  Duplicity(1)
#	      allows you to put the password in the environment variable
#	      FTP_PASSWORD instead of including it in the BACKUP_URL.
#
#	  /DATA_DIR
#	      The directory that will become /data in the container, ie
#	      the docker command to start the container will be passed
#	      "--volume /DATA_DIR:/data".  The directory can be empty.
#
#	  --DUPLICITY-OPT
#	      Without any DUPLICITY-OPT's duplicity(1) will restore the latest
#	      backup.  Look up duplicity's man page for the options to use to
#	      change that.
#
#     la-container.sh rotate /DATA_DIR [LOG_FILE ...]
#
#	  Rotate a containers log files.  This can be run both from within
#	  the container and on its host, but on the host runs for the same
#	  container must be separated by at least an hour.  On every run each
#	  log affected has its current log archived by renaming it, adding a
#	  suffix of .0, .1.gz, ... 9.gz; .gz meaning compressed with gzip.
#	  Any existing .9.gz is deleted.  If no log files are passed all the
#	  containers log files are rotated in this way.
#
#	  In its default configuration an la-container will rotate all its
#	  log files in this fashion weekly.  This period can be changed by
#	  altering /DATA_DIR/etc/la-container/log-rotate.conf, or if you need
#	  more flexibility the containers rotating of its logs can be disabled
#	  completely so you can do it using a tool like logrotate(8) on the
#	  host.  If using an external tool create the file
#	  /DATA_DIR/var/log/rotate-pending.flag when done, and don't touch
#	  files /DATA_DIR/var/log for at least an hour.
#
#
#	  /DATA_DIR	The containers data directory.  If run inside the
#			container this must be /data.
#
#	  LOG_FILE ...	The log files to rotate.  This must be absolute or
#			relative to /DATA_DIR/var/log.  It none are passed
#			all the containers log files are rotated.
#
#    la-container.sh run-timer TIMER-NAME
#
#	  Run the passed timer, writing the result to the status board.
#
#	  TIMER-NAME	The name of a timer in /etc/la-container/timers, or a
#			timer file.
#
#     la-container.sh service [--help] restart|rotate|start|statusboard|stop [SERVICE]
#
#	  This command start / stops / restarts / asks a service to reopen its
#	  log files.
#
#	  restart|rotate|start|statusboard|stop
#	      restart	    stop followed by a start
#	      rotate	    reopen log files, or restart that isn't supported.
#	      start	    starts the service if it isn't running.
#	      statusboard   updates the service's statusboard entry.
#	      stop	    stops the service if it is running.
#
#	  SERVICE
#	      The service being acted upon.  It not present all installed
#	      services are acted on.
#
#	  Services are described in the "/etc/la-container/services" directory.
#	  See that directory in the container for more information.
#
#     la-container.sh snakeoil [--help] OUTPUT-DIR [*.]FQDN...
#
#	  Write a x509 certificates for the domain names on the command line
#	  to OUTPUT-DIR.  The following files are written:
#
#	  cert.pem, chain.pem, fullchain.pem, privkey.pem
#	      The same naming convention certbot uses is employed here.  These
#	      files are the certificate, chain to the "CA" root, certificate +
#	      chain to the CA root, and the certificates private key
#	      respectively.  The private key doesn't have a password.
#
#	  ca-cert.pem, ca-privkey.pem
#	      The "CA" cert that was used to sign the above cert.  These are
#	      only created in OUTPUT-DIR if they don't already exist (ie, were
#	      created by a previous run).   If you ask your browser to trust
#	      ca-cert.pem it won't whine the cert.pem's it gets from the
#	      container are untrusted.  If you do this ensure ca-privkey.pem
#	      never leaves your machine.
#
#     la-container.sh statusboard WHAT ok|fail|purge MESSAGE...
#
#	  This can only be run in the container.  It adds this line to the
#         containers status board file:
#
#	      WHAT ok|fail YYYY-mm-dd:HH:MM:SS+0000 COUNT; MESSAGE..
#
#	  If there are more than a predefined number of lines with the same
#	  first two tokens the oldest are removed.  If "purge" is passed
#	  instead of "ok" or "fail" all lines from WHAT are removed.
#
#	  WHAT	    A token (no embedded white space or ';') describing what
#		    activity or service the line is for.  Tokens starting with
#		    la-container are reserved.
#
#	  ok|fail    'ok' if the activity or service is healthy, 'fail' if it
#		     needs some love.
#
#	  MESSAGE... An optional message describing the state of the service.
#		     It most not contain embedded newlines.
#
#	  YY-mm-dd:HH:MM:SSZ
#		     The time the line was added, ISO-8601 format, UTC.
#
#	  COUNT	     For 'ok' lines, the number of 'ok' lines written for this
#		     WHAT, including those that have been deleted.  'fail'
#		     lines contain a similar counter.
#
#	  The status board is a simple text file the container maintains so
#	  programs like Nagios and Cacti (and curious humans) can monitor its
#	  health.  It will remain small - probably less that 1K.  The container
#	  will make it available to everyone at the URL:
#
#	      http://..../_la-container_/statusboard.txt
#
#	  la-container.sh records on the status board the outcomes of backups,
#	  log rotates, security upgrades and timers.  The application is
#	  encouraged to add it's own, and in particular if it needs x509
#	  certificates it should report failures when they become close to
#	  expiring.
#
#
#     la-container.sh timer-when [--help] TIMER-NAME [AFTER]
#
#	  Write the unix time a timer should next run to stdout.
#
#	  TIMER-NAME	The name of a timer in /etc/la-container/timers, or a
#			timer file.
#
#	  AFTER		Return the next time a timer should run after this
#			unix time.  Defaults to now.
#
# RUNNING AND USING LA-CONTAINERS
#
#     An la-container is a docker container running the application on a
#     minimal Debian installation.  Being a docker image these containers
#     can be run on most cloud platforms and developers PC's.  The containers
#     have a standardised interface that lets a sysadmin backup and restore,
#     build, configure, monitor, run, security patch and upgrade all
#     la-container's in the same way.
#
#     Usage
#     -----
#
#	  Dependencies - Docker, amd64 and Debian.
#
#	      To run the container you need docker running on amd64, only.  The
#	      community edition will do.  To restore backups you need
#	      la-container.sh and duplicity(1) on the host, both which run
#	      fine in any POSIX'y environment.  Building containers requires
#	      la-container.sh running on Debian, plus the application.sh
#	      script for the container.  When building la-container.sh will
#	      tell you if any Debian packages it needs are missing.
#
#	  Building.
#
#	      To create the containers docker image with the latest versions
#	      of software run application.sh:
#
#		  ./application.sh build
#
#	      This makes the container available locally, ie run run
#	      successfully "docker image ls" will display it.  To see the
#	      supported build options run "./application.sh --help".
#
#	      If you have a copy of the container or it's backup the
#	      la-container.sh and application.sh used to build it can be found
#	      in /usr/local/la-container.  It can be rebuilt with the same
#	      versions of software using:
#
#		  /DATA_DIR/usr/local/la-container/application-build.sh
#
#	      This may fail if the software is no longer available at the
#	      same URL's. For example when Debian obsoletes a release will
#	      no longer be available from the mirrors so the above command
#	      will eventually start failing.  However for Debian at least you
#	      can get around that by editing the --mirror switch to use an
#	      appropriate URL from http://snapshot.debian.org.
#
#	  Starting and Stopping.
#
#	      Once you have build the container run it with:
#
#		  docker run --detach --rm --volume /DATA_DIR:/data \
#		      [netwok-options] IMAGE-NAME
#
#	      /DATA_DIR
#		  See the Background discussion.
#
#	      /data
#		  Do not change.
#
#	      [network-options]
#		  See the Background discussion on networking.  If omitted
#		  docker will typically give the container the IP Address
#		  172.17.0.2/24 with its internal ports visible on that IP.
#		  "docker inspect ID" displays the IP Address allocated to the
#		  container.  You will have to run "docker container ls" to
#		  obtain the container ID to feed to "docker inspect".
#
#	      IMAGE-NAME
#		  The name of the newly built container displayed by "docker
#		  image ls".
#
#	      To stop the container execute:
#
#		  docker stop $(docker container ls -qf ancestor=la-container)
#
#	  Initialising and Configuring the container.
#
#	      To create an instance of the container in its "factory reset"
#	      state pass it an empty /DATA_DIR.  It will then populate
#	      /DATA_DIR/etc with it's factory default configuration files.  If
#	      they aren't suitable stop the container, modify them and restart
#	      it.
#
#	      Every la-container has at least the configuration files listed
#	      below.  The application may add it's own.  The documentation for
#	      every la-container configuration file is embedded in it as
#	      comments, so for stuff under /etc/la-container look at the
#	      actual file or a directory's README.txt for more information.
#
#	      /DATA_DIR/etc/environment
#		  The environment variables inherited by all services.
#		  See pam_env(8).
#
#	      /DATA_DIR/etc/la-container/backup-sites
#		  The places backups will be sent to.  See the README.txt and
#		  also "la-container.sh backup".
#
#	      /DATA_DIR/etc/la-container/backup-gpgkeys
#		  The gpg keys that will be used for encrypted backups.  See
#		  the README.txt and also "la-container.backup".
#
#	      /DATA_DIR/etc/la-container/init-profile.sh
#		  This file is sourced by "la-container.sh init" when it
#		  starts.  The comments in the file document it.
#
#	      /DATA_DIR/etc/la-container/log-rotate.conf
#		  Configure log rotation.  The comments in the file document
#		  it.  Also see "la-container.sh rotate".
#
#	      /DATA_DIR/etc/la-container/production-fqdn
#		  Contains the fully qualified domain name of the
#		  production server.  The comments in the file document it.
#	          Also see "la-container.sh backup".
#
#	      /DATA_DIR/etc/ssmtp
#		  How email sent with /usr/lib/sendmail is to be
#		  dispatched. See ssmtp.conf(5).
#
#	      /DATA_DIR/etc/timezone
#		  A single line containing the timezone seen by the
#		  services.  A timezone is a pathname of a file under
#		  /usr/share/zoneinfo, eg Etc/UTC.  Useful for getting
#		  local time in the logs, but probably not much else.
#
#	  Security patches and upgrades.
#
#	      The container will automatically Debian's mirror for security
#             updates and install them as they arrive, stopping and starting
#             all services after it has done so. Beware this it will interrupt
#             services and cause a few seconds of down time.  If you configure
#	      /data/etc/timezone appropriately this will happen the small hours
#	      of the morning, local time.
#
#	      Any other changes, including upgrading the container are done
#	      rebuilding the container using "application.sh build".  A new
#	      version of the container will automatically upgrade the contents
#	      of /DATA_DIR (but a cautious person would ensure they have a
#	      backup of the container on hand in case it doesn't work).
#
#	  Log Maintenance.
#
#	      See "la-container.sh rotate".
#
#	  Monitoring.
#
#	      Monitoring software (eg, Cacti or Nagios) can gauge the health
#	      of the container by fetching the statusboard.  See
#	      "la-container.sh statusboard" for more information.
#
#     Background and Concepts
#     -----------------------
#
#	  /DATA_DIR
#
#	      The container stores it's data and configuration in a directory
#	      you provide on your host machine.  This directory is called
#	      /DATA_DIR here.  It must be writable by the container.  You pass
#	      its path to the container when you start it, via the docker
#	      command line:
#
#		  docker run --detach --rm --volume /DATA_DIR:/data IMAGE-NAME
#
#	      The container can assume it has exclusive access to /DATA_DIR
#	      while it's running.  This means if you want to change a
#	      containers configuration you must stop it, change the files in
#	      /DATA_DIR, then start it again.  It also means taking snapshot of
#	      a container by coping /DATA_DIR should be only done while the
#	      container isn't running, otherwise you risk getting a corrupt
#	      snapshot.
#
#	  Networking
#
#	      A container provides services via TCP and UDP ports it listens
#	      on.  It will list the ports in it's documentation.  However,
#	      those ports are inside of the container, effectively disconnected
#	      from the rest of the world.  To connect them, the administrator
#	      must tell docker what real world IP Address and Port combinations
#	      are to be mapped to those container ports.  Docker and Linux
#	      provides numerous ways of doing that so I won't go into it
#	      further here, except to say:
#
#	      -   If you are a developer you probably need do nothing as
#		  docker's defaults gives you (only) access to the containers
#		  running locally.
#
#	      -   On a production instance mapping an external IP Address
#	          directly into the container incurs the least overhead.  A
#		  firewall should not be needed as the tiny install also means
#		  the attack surface is correspondingly small.
#
#	      Just to re-iterate, the container will not care about, and indeed
#	      should be blissfully unaware of what IP Address it has been
#	      assigned or what ports the external world talks to, nor will it
#	      care if they change across restarts.
#
#	      Conversely, the container will need to access real outside world
#	      services (eg, for getting security patches and doing backups)
#	      via TCP/UDP.  It may not document what it needs, but it will
#	      need a connection to the internet, and DNS services.  Docker
#	      usually provides this automagically.
#
#	  Logging and Visibility
#
#	      The containers health can be monitored by looking at it's status
#	      board via http.  See "la-container.sh statusboard" for more
#	      information.
#
#	      The contain maps /var/log to /DATA_DIR/var/log.  In there
#	      la-container.sh writes it's own log:
#
#		  /DATA_DIR/var/log/init.log
#
#	      This is the stdout + stderr of init and the services it starts.
#	      This will be empty unless something goes wrong, or you alter
#	      "/DATA_DIR/etc/la-container/init-profile.sh" to output trace.
#	      Other services (eg, apache2) may write their own logs, but they
#	      will always be under /DATA_DIR/var/log.
#
#	      Those are the official means of seeing into the container.
#	      Unofficially, you can spawn a shell have wander around:
#
#		  docker exec -it IMAGE-NAME bash -il
#
#	      Being a minimal Debian install it's a very barren world, but
#	      you have root and apt-get.  Beware all memory of any changes you
#	      make outside of /data will be lost (including packages you
#	      installed) when the container is stopped.
#
# DEVELOPMENT
#
#     Development of an la-container application consists of one task: writing
#     a dash(1) script called "application.sh".  Although it can be just one
#     file it's usually more convenient to split it up into separate files,
#     store it all in a VCS project, and put application.sh itself in the root
#     directory of the project.
#
#     la-container.sh is itself a valid application.sh that follows all the
#     guidelines listed below, so you can use it as a working example.  In
#     fact installs a symlink to itself in the base container.  This produces
#     a fully operational container that does nothing, but you can run using
#     docker and have a look around.
#
#     "application.sh" first argument tells what action to perform - in
#     the same style as la-container.sh.  The actions application.sh must
#     provide are:
#
#     application.sh --help
#
#	  Print out a usage message.
#
#     application.sh boot [DUMP.DIR]
#
#	  This is called in the container at start up.  Its tasks are to
#	  restore a backup, upgrade persisted data to the current version,
#	  then start all services by running "la-container.sh service start".
#	  See "la-container.sh init" and "la-container.sh boot" for more
#	  information and a working example.
#
#     application.sh build [--help] [--application-specific-options...]
#
#	  Build and install the container into local docker instance, so
#	  "docker image ls" displays it.  application.sh can assume this is
#	  happening in a Debian amd64 environment will all Debian packages
#	  it requires are installed.  The end result must fulfill these
#	  conditions:
#
#	  -   It must run without asking for input.  Additional data can be
#	      be provided by options on the command line, but working defaults
#	      must be provided.
#
#	  -   It must have a usage message, and print if it the first command
#	      line argument is --help.
#
#	  -   It must provide / generate / download all files it needs to
#	      construct or put in the container.  This includes
#	      la-container.sh.  It must provide options allowing the user to
#	      select the versions of software to use, including the version
#	      of Debian la-container.sh will use to build the container.
#
#	  -   It must create the /usr/local/la-container/application-build.sh
#	      script in the container that takes no options and rebuilds the
#	      container with the same version of software in it.  The utility
#	      "la-container.sh build-options" helps you do this.
#
#	  -   If the local docker doesn't have the base la-container image
#	      needed, build it on the fly using la-container.sh.
#
#	  -   When done, the directory /usr/local/la-container in the container
#	      must contain everything needed to build the container.  At a
#	      minimum this will be application.sh and la-container.sh.  If
#	      application.sh needs other files in its directory (eg, files
#	      stored in a VCS project), then they must be copied as well.  Do
#	      not include the VCS's local data, eg the .git directory.
#
#	  -   Populate /etc/la-container with the information you know.  For
#	      example, if you know your production container will be available
#	      at http://linux.conf.au/, put linux.conf.au in production-fqdn.
#	      Add the backup stores and backup keys your project will be using
#	      to backup-sites and backup-keys.  If nothing else doing that
#	      means someone coming along later will know where to start their
#	      search for the backups.
#
#	  -   The built container must:
#
#	      (a) Populate /DATA_DIR with any all configuration files the
#		  application supports if they are there.
#
#	      (b) Run when given an empty /DATA_DIR and no internet connection.
#
#	      For (b) x509 certificates can be problematic as they must be
#	      provided if the container needs them to run.  See "la-container
#	      snakeoil" for a workaround.
#
#	  "la-container.sh build" can be used as a working example, but
#	  la-container.sh isn't split into multiple source files to avoid
#	  polluting application.sh's root directory.  That makes it's approach
#	  more complex than strictly necessary.  Running "docker build" on a
#	  conventional Dockerfile stored in a VCS is usually simpler.
#
#     application.sh dump DUMP.DIR
#
#	  Populate DUMP.DIR with all data to be backed up.  See
#	  "la-container.sh dump" for more information.
#
#     To allow la-container.sh to provide the standardised interface for
#     sysadmin's the application must do some things things using API's and
#     other facilities provided by the la-container.sh:
#
#     -   Programs that run continuously (aka services or daemons) must be
#	  started at boot up by adding a file to the container directory
#	  "/etc/la-container/services".  This is so la-container can restart
#	  them when security patches are installed, and ask them to reopen
#	  their log files after the log files have been rotated.  See the
#	  README.txt in that directory in the container for more information.
#
#     -   Log files must be written somewhere under the directory /var/log.
#
#     -   The file:
#	      /data/var/lib/la-container/www/_la-container_/statusboard.txt
#	  must be made available as the URL:
#	      http://...:80/_la-container_/statusboard.txt
#	  when the container is running.  If you don't run your own web server
#	  (or more precisely if, after "application boot" runs there is
#	  nothing listening to tcp 127.0.0.1:80) "la-container.sh init" will
#	  apt-get install a small web service to make it available.  In other
#	  words your application doesn't run a web server you need do nothing.
#         However if your application runs its own web server you will have to
#         arrange for it to serve the statusboard URL.
#
#     -   If you have cron jobs you can if you wish use la-container.sh's
#	  inbuilt timers instead of adding cron to your container.  The inbuilt
#	  timers automatically records timers activity on the statusboard.  If
#	  you use a different system system you should probably arrange for it
#	  record the outcome of important periodic tasks on the statusboard.
#	  See /etc/la-container/timers/README.txt in the container for more
#	  information.
#
#     -   If your container monitors its own health in some way ensure the
#	  statusboard is updated to show whether the container is healthy or
#	  not.  See "la-container.sh statusboard" for more information.
#
#     Debugging Techniques.
#
#     -   If the container is not starting look at /DATA_DIR/var/log/init.log.
#
#     -   If /DATA_DIR/var/log/init.log doesn't contain enough information
#	  put "set -x" (or even "set -xv") in
#	  /DATA_DIR/etc/la-container/init-profile.sh" and restart the
#	  container.
#
#     -   Once the container is starting, use:
#	      docker exec -it IMAGE-NAME bash -il
#	  to log into it.  From there you can manually invoke the same commands
#	  "la-container.sh init" does and watch what happens.  For example:
#
#	      la-container.sh backup file:////data/foo
#	      la-container.sh run-timer la-container-apt.timer
#	      la-container.sh service rotate mini-httpd
#
#	  Will do a backup to /data/foo, run the backups from the timer as
#	  "la-container.sh init" does, and ask the mini-http service to reopen
#	  its log files respectively.
#
#     -   If you need to examine the production container closely install
#	  openssh and add your public ssh keys to /root/.ssh/authorized_keys
#	  when you build the container.  You will then be able to ssh in as
#	  root.
#
#
# (c) 2018 Russell Stuart <russell-debian@stuart.id.au>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# The copyright holders grant you an additional permission under Section 7
# of the GNU Affero General Public License, version 3, exempting you from
# the requirement in Section 6 of the GNU General Public License, version 3,
# to accompany Corresponding Source with Installation Information for the
# Program or any work based on the Program. You are still required to
# comply with all other Section 6 requirements to provide Corresponding
# Source.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

#
# Tunable stuff.
#
VERSION="0.0.0"
DEBIAN_LOCALES="en_AU.UTF-8"		# Separate locales with ','
DEBIAN_MIRROR="http://deb.debian.org/debian"
DEBIAN_SUITE="stable"
#
# Debian base packages.  All bar the first two are for doing backups.  We
# are prepared to pay a considerable price to make backups "just work".
#
DEBIAN_PACKAGES="
    locales
    ssmtp

    duplicity
    eatmydata
    gnupg
    nocache
    python-atomicwrites
    python-azure
    python-cloudfiles
    python-boto
    python-gdata
    python-oauthlib
    python-paramiko
    python-requests-oauthlib
    python-swiftclient
    python-urllib3
    openssh-client
    rsync"

#
# Who am I?
#
case "${0}" in
    */*)	ME="${0}" ;;
    *)	  ME="$(which "${0}")" || ME="./${0}" ;;
esac

#
# Run a sub-shell, preserving trace options.
#
sub_shell()
{
    local options="$(set -o | sed 's/[[:space:]]\+/=/')"
    echo dash
    case "${options}" in
	*verbose=on*)	echo ' -o verbose';;
    esac
    case "${options}" in
	*xtrace=on*)		echo ' -o xtrace';;
    esac
}

#
# application.sh boot [DUMP.DIR]
# ==============================
#
# If DUMP.DIR was give restore the backup in there.  Then do first time boot
# initialisation, which includes upgrading the data to the current version
# of /data was from a older version.
#
application_boot()
{
    [ $# -le 2 -a x"${2:-}" != x"--help" ] || {
	echo 1>&2 "usage: ${0##*/} ${1} [/DATA_DIR]"
	return 1
    }
    [ -z "${2:-}" -o -d "${2:-}" ] || {
	echo 1>&2 "${0##*/} ${1}: ${2} is not a directory."
	return 1
    }
    #
    # Move mysql DB's to /data.  If they haven't supplied one create the
    # database.
    #
#   local la_wordpress_db='var/lib/mysql/la@0002wordpress'
#   ln --force --relative --symbolic "/data/${la_wordpress_db}" "/${la_wordpress_db}"
#   if [ ! -d "/data/${la_wordpress_db}" ]
#   then
#	mkdir --parents "/data/${la_wordpress_db}"
#	printf 'create database `la-wordpress`;' | mysql
#   fi
    #
    # Do a restore if asked.
    #
    [ -z "${2:-}" ] || {
	local dump_dir="${2}"
#	la_container service start mysqld
	cp --archive --link "${dump_dir}/copied/." "/data/."
#	mysql 'la-wordpress' <"${dump_dir}/generated/${la_wordpress_db}.dump"
    }
    #
    # Use the SSL certs in /data/srv/www.  If they aren't there install
    # self signed ones.
    #
#   [ -s /data/srv/www/certs/fullchain.pem ] || {
#	mkdir --parents /data/srv/www/certs
#	cp --archive /srv/www/testing-certs/. /data/srv/www/certs/.
#   }
#   ln --force --relative --symbolic /data/srv/www/certs /srv/www/certs
    #
    # Start up all services
    #
    la_container service start
}


#
# application.sh dump DUMP.DIR
# ============================
#
# We have been called inside of the container to create a directory, DUMP.DIR,
# containing everything that needs to be backed up.  The directory doesn't
# exist when we are called.  If it doesn't exist when we return the backup
# silently doesn't happen.
#
application_dump()
{
    local -
    set -o errexit -o noclobber -o nounset
    local action="${1:-}"
    shift
    [ $# -ge 1 -a x"${1:-}" != x"--help" ] || {
	echo 1>&2 "usage: ${0##*/} DUMP_DIR"
	return 1
    }
    [ ! -e "${1:-}" ] || {
	echo 1>&2 "${0##*/} ${1}: ${1} must not exist."
	return 1
    }
    dump_dir="${1}"
    temp_dir="${dump_dir}.tmp"
    rm --force --recursive "${temp_dir}"
    #
    # Copy everything bar /data/tmp, /data/var/log, /data/var/spool and
    # the databases.  The databases must be dumped as text and stripped
    # of "noise" to prevent the differential backups from growing too
    # quickly.
    #
    mkdir --parents "${temp_dir}/copied"
    (
	find /data \
	    -path /data -o \
	    -path /data/tmp -prune -o \
	    -path /data/var -o \
	    -path /data/var/lib -o \
	    -path /data/var/lib/mysql -prune -o \
	    -path /data/var/lib/postgresql -prune -o \
	    -path /data/var/lib/la-container -prune -o \
	    -path /data/var/log -prune -o \
	    -prune -print |
	while read -r path
	do
	    local target="${temp_dir}/copied/${path#/data/}"
	    mkdir --parents "${target%/*}"
	    cp --archive --link "${path}" "${target}"
	done
    )
    #
    # Dump the wordpress mysql database.
    #
#   local la_wordpress_db='var/lib/mysql/la@0002wordpress'
#   mkdir --parents "${temp_dir}/generated/${la_wordpress_db%/*}"
#   config_value() {
#	sed --quiet "s/.*\<define(\'$1\', *\'\([^\']*\)\');.*/\1/p" \
#	    /etc/wordpress/config-www.*.php
#   }
#   cat >|/tmp/backup-mysqldump.cnf <<-===
#	[mysqldump]
#	user=$(config_value DB_USER)
#	password=$(config_value DB_PASSWORD)
#	compatible=ansi
#	order-by-primary
#	single-transaction
#	skip-dump-date
#	result-file=${temp_dir}/generated/${la_wordpress_db}.dump
#	===
#   mysqldump --defaults-file=/tmp/backup-mysqldump.cnf --databases 'la-wordpress'
#   rm --force /tmp/backup-mysqldump.cnf
#   #
#   # Wordpress updates a few rows in it's database whenever the site is
#   # rendered.  Delete those rows as they make the backup different in ways
#   # that aren't worth backing up.
#   #
#   sed --in-place \
#	--expression "/^INSERT INTO \"wp_options\" VALUES (/s/,(\([0-9]*,'\(wp_scheduled_missed\|akismet_spam_count\)'\),'[^']*',\('[^']*'\))/,(\1,\'0\',\3)/g'" \
#	--expression "/^INSERT INTO "wp_options" VALUES (/s/,(\([0-9]*,'\(_transient_timeout_wp_scheduled_missed\|_transient_wp_scheduled_missed\)'\),'[^']*',\('[^']*'\))//g'" \
#	"${temp_dir}/generated/var/lib/mysql/la@0002dwordpress.mysql-dump"
    #
    # Now that's all worked without an error so it can be safely sent to
    # the backups in the knowledge it is complete, rename "${temp_dir}" to
    # "${dump_dir}".
    #
    mv "${temp_dir}" "${dump_dir}"
}


#
# la-container.sh apt-get-install DEBIAN-PACKAGE ...
# ==================================================
#
# A utility function for apt-get install.  It cleans up after itself.
#
la_container_apt_get_install()
{
    local action="${1:-}"
    shift
    [ -n "${2:-}" -a x"${2:-}" != x"--help" ] || {
	echo 1>&2 "usage: ${ME##*/} ${action} debian-package..."
	return 1
    }
    export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
    apt-get update
    apt-get install --quiet --no-install-recommends --yes "$@"
    apt-get --yes dist-upgrade
    #
    # Clean up the apt cache and logs.
    #
    find \
	    "${temp_dir}/var/log" \
	    "${temp_dir}/var/cache/apt" \
	    "${temp_dir}/var/lib/apt" \
	    ! -name extended_states -type f -print0 |
	xargs -0 --no-run-if-empty rm
}


#
# container.sh backup [--no-live-check] [BACKUP_URL]
# ==================================================
#
# Do a backup of the container to the BACKUP_URL.  If no URL is supplied
# backup to all places configured in /data/etc/la-container/backup-sites.
#
la_container_backup()
{
    local -
    set -o errexit -o noclobber -o nounset
    #
    # Get the args.
    #
    local action="${1}"
    shift
    local opt_force_full=
    local opt_no_live_check=
    while :
    do
	case "${1:-}" in
	    --force-full)	local opt_force_full=True; shift;;
	    --no-live-check)	local opt_no_live_check=True; shift;;
	    --help)
		echo 1>&2 "usage: ${ME##*/} ${action} [--force-full] [--no-live-check] [BACKUP-URL [--DUPLICITY-OPTS ...]]]"
		exit 1;;
	    *://*/*|'')		break;;
	    *)
		echo 1>&2 "${ME##*/} ${action}: unknown option ${1}."
		exit 1;;
	esac
    done
    local opt_url=
    local opt_duplicity_opts=
    [ $# = 0 ] || {
	local opt_url="${1:-}"
	shift
	opt_duplicity_opts="$*"
    }
    local duplicity_opt
    for duplicity_opt
    do
	case "${duplicity_opt}" in
	    --la-container:backup-full=*)
		la_container backup-period "${duplicity_opt}" "${ME##*/} ${action}";;
	    --la-container:backup-incr=*)
		la_container backup-period "${duplicity_opt}" "${ME##*/} ${action}";;
	    --la-container:keep-full=*)
		la_container backup-period "${duplicity_opt}" "${ME##*/} ${action}";;
	    --la-container:keep-incr=*)
		la_container backup-period "${duplicity_opt}" "${ME##*/} ${action}";;
	    --la-container:*)
		echo 1>&2 "${ME##*/} ${action}: unrecognised option ${duplicity_opt}."
		return 1;;
	esac
    done
    #
    # Get a list of sites to backup to.
    #
    local exit_status=0
    local temp_dir="$(mktemp --directory "/data/tmp/${ME##*/}-${action}-XXXXXXXX")"
    (
	local backup_sites_dir="/data/etc/la-container/backup-sites"
	local unknown_backup_site="${temp_dir}/backup-sites/manual"
	if [ -z "${opt_url}" ]
	then
	    local backup_sites="$(
		grep --files-with-match --recursive \
		    '^[^# /]*://'  "${backup_sites_dir}")" || :
	else
	    local url_re="$(printf "%s" "${opt_url}" | sed 's/[][*\\^$]/\\&/')"
	    local backup_sites="$(
		grep --files-with-match --recursive \
		    "^${url_re}"  "${backup_sites_dir}")" || :
	    if [ -z "${backup_sites:-}" -o -n "${opt_duplicity_opts}" ]
	    then
		backup_sites="${unknown_backup_site}"
		mkdir --parents "${backup_sites%/*}"
		printf "%s\n%s\n" "${opt_url}" "${opt_duplicity_opts}">|"${backup_sites}"
	    fi
	fi
	[ -n "${backup_sites:-}" ] || {
	    echo 1>&2 "${ME##*/}: There are no backup sites in ${backup_sites_dir}."
	    return 1
	}
	#
	# Verify all gpg keys requested exist.
	#
	local gpg_keys_dir="/data/etc/la-container/backup-gpgkeys"
	local opt='--encrypt-key\(=\|[[:space:]]\+\)\([^[:space:]]\+\)'
	local backup_site
	for backup_site in ${backup_sites}
	do
	    local gpgkey
	    for gpgkey in $(
                sed --quiet \
                    --expression '/^[[:space:]]*#/d;/^[^ \/]\+:\/\//d' \
                    --expression ":loop;/${opt}/!d" \
                    --expression "h;s/.*${opt}.*/\2/p" \
                    --expression "x;s/\\(.*\\)${opt}/\\1/;b loop" \
                    "${backup_site}")
	    do
		[ -f "${gpg_keys_dir}/${gpgkey}" ] &&
		    grep --silient --line-regexp \
			--regexp='-----BEGIN PGP PUBLIC KEY BLOCK-----' \
			"${gpg_keys_dir}/${gpgkey}" ||
		    {
			local message="gpg key ${gpgkey}"
			[ x"${backup_site}" = x"${unknown_backup_site}" ] || {
			    mssage="${message} used in backup site ${backup_site##*/}"
			}
			message="${message} is not a gpg key in ${gpg_keys_dir}"
			echo 1>&2 "${ME##*/} ${action}: ${message}."
			return 1
		    }
	    done
	done
	#
	# If we have to encrypt things verify we have keys.
	#
	local gpg_keys="$(
	    grep --files-with-match --line-regexp --recursive \
		--regexp='-----BEGIN PGP PUBLIC KEY BLOCK-----' \
		"${gpg_keys_dir}" |
	    sort)" || :
	local encrypted_sites="$(
	    egrep --files-without-match \
		--regexp='--no-encryption\>' ${backup_sites})" || :
	[ -z "${encrypted_sites:-}" -o -n "${gpg_keys:-}" ] || {
	    echo 1>&2 "${ME##*/}: There are no gpg keys in ${gpg_keys_dir}."
	    return 1
	}
	#
	# Are we the production instance?
	#
	[ -z "${opt_no_live_check}" ] || {
	    local production_fqdn="$(
		sed '/^[[:space:]]*\(#\|$\)/d;q' \
		    /data/etc/la-container/production-fqdn)"
	    [ -z "${production_fqdn}" -o x"${production_fqdn}" = x"localhost" ] ||
		la_container is-live ${production_fqdn} || return 1
	}
	#
	# Run the backup for each site.  The lock and dump are done lazily.
	#
	local backup_site
	for backup_site in ${backup_sites}
	do
	    local backup_status_dir=$(
		[ x"${backup_site}" = x"${unknown_backup_site}" ] &&
		    echo "${temp_dir}/backup-status" ||
		    echo "/data/var/lib/la-container/backup/status/${backup_site##*/}")
	    la_container backup-site "${temp_dir}" "${backup_site}" \
		"${backup_status_dir}" "${opt_force_full}"
	done
    ) || exit_status=$?
    rm --force --recursive "${temp_dir}"
    la_container lockfile unlock la-container-backup
    return "${exit_status}"
}

#
# Create the backup dump directory.  Purely internal.
#
la_container_backup_dump()
{
    local -
    set -o errexit -o noclobber -o nounset
    local action="${1}"
    local dump_tar="${2}"
    local dump_dir="${dump_tar}.dir"
    #
    # application.sh must live in the same directory as us.
    #
    local application_sh="${0}"
    [ x"${0}" != x"${0#*/}" ] ||
	local application_sh="$(which "${application_sh}")"
    local application_sh="$(readlink --canonicalize-existing "${application_sh}")"
    local application_sh="${application_sh%/*}/application.sh"
    #
    # Create a dump of all important data - this is what we backup.
    #
    rm --force --recursive "${dump_dir}"
    $(sub_shell) ${application_sh:-./application.sh} dump "${dump_dir}"
    #
    # If the file contents haven't changed force timestamp to be restored
    # to what was in the last backup so duplicity's rdiff doesn't backup
    # useless timestamp changes.
    #
    local timestamp_file="/data/var/lib/la-container/backup/timestamps.txt"
    mkdir --parents "${timestamp_file%/*}"
    [ ! -s "${timestamp_file}" ] || (
	cd "${dump_dir}"
	local timestamp hash filename
	while read -r timestamp hash filename
	do
	    [ -e "${filename}" -a ! -d "${filename}" ] || continue
	    #
	    # If a files sha256 sum hasn't changed set it's mtime to the
	    # value we recorded.
	    #
	    local new_hash="$(
		(   stat --format "%a.%t.%T.%u.%g.%N" "${filename}"
		    [ -L "${filename}" -o ! -f "${filename}" ] ||
			cat "${filename}"
		) | sha256sum)"
	    local new_hash="${new_hash%% *}"
	    [ x"${hash}" != x"${new_hash}" ] ||
		touch --date="${timestamp}" "${filename}"
	done <"${timestamp_file}"
    )
    (
	local filename
	cd "${dump_dir}"
	find . -type f | LANG=C sort |
	    while read -r filename
	    do
		#
		# Record this times mtime and sha256sum for next time around.
		#
		local new_hash="$(
		    (   stat --format "%a.%t.%T.%u.%g.%N" "${filename}"
			[ -L "${filename}" -o ! -f "${filename}" ] ||
			    cat "${filename}"
		    ) | sha256sum)"
		local new_hash="${new_hash%% *}"
		local timestamp="$(date +@%s.%N --reference="${filename}")"
		printf '%s %s %s\n' "${timestamp}" "${new_hash}" "${filename}"
	    done
    ) >|"${timestamp_file}.tmp"
    mv "${timestamp_file}.tmp" "${timestamp_file}"
    #
    # Create the tar file.  We use tar files owned by "nobody" so anybody
    # can restore them without getting permission failures.
    #
    tar --create --file "${dump_tar}" --sparse --acls --selinux --xattrs  \
	--atime-preserve --sort=name --directory "${dump_dir}" .
    rm --force --recursive "${dump_dir}"
    chown nobody. "${dump_tar}"
}

#
# Parse the period passed.  Purely internal.
#
la_container_backup_period()
{
    local -
    set -o errexit -o noclobber -o nounset
    local action="${1}"
    local opt="${2}"
    local backup_site="${3}"
    local period="${opt#--*=}"
    local qty="${period%.*}"
    local period seconds
    case "$(echo "${qty}" | tr -d '[0-9]'):${period}" in
	:[1-9]*.minute*)
	    period=$(($(date +1%Y%j%H%M) / ${qty}))
	    seconds=$((60 * ${qty}));;
	:[1-9]*.hour*)
	    period=$(($(date +1%Y%j%H) / ${qty}))
	    seconds=$((3600 * ${qty}));;
	:[1-9]*.day*)
	    period="${opt#--*=}"
	    period=$(($(date +1%Y%j) / ${qty}))
	    seconds=$((24 * 3600 * ${qty}));;
	:[1-9]*.week*)
	    period="${opt#--*=}"
	    period=$(( $(date +%G%V) / ${qty}))
	    seconds=$((7 * 24 * 3600 * ${qty}));;
	:[1-9]*.month*)
	    period="${opt#--*=}"
	    period=$(($(date +%Y%m) / ${qty}))
	    seconds=$((30 * 24 * 3600 * ${qty}));;
	:[1-9]*.year*)
	    period="${opt#--*=}"
	    period=$(($(date +%Y) / ${qty}))
	    seconds=$((365 * 24 * 3600 * ${qty}));;
	*)
	    echo 1>&2 "${backup_site}: invalid period in ${opt}."
	    return 1;;
    esac
    printf "%s:%s" "${period}" "${seconds}"
}

#
# Run a backup to a site.  Purely internal.
#
la_container_backup_site()
{
    local -
    set -o errexit -o noclobber -o nounset
    local action="${1}"
    local temp_dir="${2}"
    local backup_site="${3}"
    local backup_status_dir="${4}"
    local force_full="${5}"
    #
    # Get the backup URL, split off any query string
    # (which duplicity doesn't use) and see if it's
    # meant to be unencrypted.
    #
    local backup_url="$(sed --quiet '/^[^# \/]*:\/\//p;T;q'  "${backup_site}")"
    local all_opts=" $(
	sed --quiet \
	    --expression '/^[^# \/]*:\/\//d;/^[[:space:]]*#/d;H' \
	    --expression '${x;s/\n/ /gp};d' \
	    "${backup_site}")"
    #
    # Extract options we (rather than duplicity) processes.
    #
    local duplicity_opts=
    local opt_backup_full="$(la_container backup-period 1.month '')"
    local opt_backup_incr="$(la_container backup-period 8.hours '')"
    local opt_keep_full="$(la_container backup-period 3.months '')"
    local opt_keep_incr="$(la_container backup-period 1.year '')"
    local opt_unencrypted=
    #
    # Extract our pseudo options and the encryption keys.
    #
    local encrypt_keys=
    local key_next=
    local opt
    for opt in ${all_opts}
    do
	[ -z "${key_next}" ] || {
	    local encrypt_keys="${encrypt_keys} --encrypt-key ${opt}"
	    local key_next=
	    continue
	}
	case "${opt}" in
	    --la-container:backup-full=*)
		opt_full="$(la_container backup-period "${opt}" "${backup_site}" '')" ;;
	    --la-container:backup-incr=*)
		opt_full="$(la_container backup-period "${opt}" "${backup_site}" '')" ;;
	    --la-container:keep-full=*)
		opt_full="$(la_container backup-period "${opt}" "${backup_site}" '')" ;;
	    --la-container:keep-incr=*)
		opt_full="$(la_container backup-period "${opt}" "${backup_site}" '')" ;;
	    --encrypt_key=*)
		local encrypt_keys="${encrypt_keys} --encrypt-key ${opt#--*=}" ;;
	    --encrypt_key)
		key_next=true;;
	    --no-encryption)
		opt_unencrypted=true
		duplicity_opts="${duplicity_opts} ${opt}" ;;
	    *)
		duplicity_opts="${duplicity_opts} ${opt}" ;;
	esac
    done
    #
    # No encryption keys means use all of the keys in the backup-gpgkeys
    # directory.
    #
    [ -n "${opt_unencrypted}" -o -n "${encrypt_keys}" ] || {
	local encrypt_keys="$(
	    for key in ${gpg_keys}
	    do printf " --encrypt-key '%s' " ${key##*/}
	    done)"
    }
    #
    # Do we need to do a backup now?
    #
    local current_backup_full=$(
	[ ! -s "${backup_status_dir}/backup-full-no.txt" ] ||
	cat "${backup_status_dir}/backup-full-no.txt")
    local current_backup_incr=$(
	[ ! -s "${backup_status_dir}/backup-incr-no.txt" ] ||
        cat "${backup_status_dir}/backup-incr-no.txt")
    [ x"${current_backup_full}" != x"${opt_backup_full%:*}" ] ||
        [ x"${current_backup_incr}" != x"${opt_backup_incr%:*}" ] ||
	return 0
    #
    # If the gpg keys have changed or the full_backup-no.txt has changed,
    # then we must do a full backup, otherwise we can try for an
    # incremental.
    #
    if  [ -n "${opt_unencrypted}" ]
    then
	local encrypt_keys=
	local gpg_options=
	local keys=
    else
	local gpg_homedir="${temp_dir}/gnupg-home"
	local gpg_options="--gpg-options '--trust-model always --no-auto-check-trust --homedir ${gpg_homedir}'"
	local keys="$(cat "${gpg_keys}")"
	#
	# Create a GPG keyring if we don't have one.
	#
	[ -d "${gpg_homedir}" ] || {
	    (umask 0077; mkdir --parents "${gpg_homedir}")
	    gpg --quiet --batch --trust-model always --homedir "${gpg_homedir}" \
		--no-auto-check-trust --import ${gpg_keys}
	}
    fi
    #
    # Determine the type of backup.
    #
    if  [ -s "${backup_status_dir}/backup-gpgkeys.txt" ] &&
	[ x"$(cat ${backup_status_dir}/backup-gpgkeys.txt)" = x"${keys}" ] &&
	[ -s "${backup_status_dir}/full-backup-interval.txt" ] &&
	[ x"$(cat ${backup_status_dir}/full-backup-no.txt)" = x"${opt_full%:*}" ]
    then local backup_type=
    else local backup_type=full
    fi
    #
    # We are ready to do the backup.  Acquire the lock.
    #
    local lockpid="$(la_container lockfile lock la-container-backup)"
    [ -z "${lockpid}" ] || {
	echo "${ME##*} backup: process ${locklpid} is currently doing a backup."
	return 1
    }
    #
    # If we don't back a dump yet create it.
    #
    local dump_tar="${temp_dir}/dump.tar"
    [ -d "${dump_tar}" ] || {
	la_container backup-dump "${dump_tar}"
	[ -s "${dump_tar}" ] || return 1
    }
    #
    # If a password ie embedded in the URL strip it out.
    # We don't want it to be visible to a ps.
    #
    local path="${backup_url}"
    local scheme="${path%://*}"
    local path="${path#*://}"
    local host="${path%%/*}"
    local path="${path#*/}"
    case "${host}" in
	*:*@*.*)
	    local user="${host%@*}"
	    local password="${user#*:}"
	    local backup_url="${scheme}://${user%:*}@${host##*@}/${path}" ;;
	*)  local password= ;;
    esac
    local status_token="la-container:backup-${backup_site##*/}"
    local status_url="${scheme}://${host%%*@}/${path}"
    #
    # Has anything changed since the last backup?
    #
    local timestamp_sha256="$(sha256sum "/data/var/lib/la-container/backup/timestamps.txt")"
    local timestamp_sha256="${timestamp_sha256%% *}"
    [ -n "${force_full}" -o ! -s "${backup_status_dir}/timestamps.sha265" ] ||
	[ x"$(cat "${backup_status_dir}/timestamps.sha265")" = x"${timestamp_sha256}" ] || {
	    la_container statusboard "${status_token}" ok \
		skipped-unchanged ${status_url}
	    return 0
	}
    #
    # Ask duplicity to do the backup.  Don't stop because if one fails -
    # the whole point of having multiple backups is to deal with one
    # failing.
    #
    mkdir --parents "${backup_status_dir}/duplicity-archive"
    (
	local elapsed="$(date +%s)"
	local output="$(
	    statusboard_eval 256 \
		FTP_PASSWORD="'${password}'" duplicity ${backup_type} \
		--archive-dir "'${backup_status_dir}/duplicity-archive'" \
		${encrypt_keys} ${gpg_options} ${duplicity_opts} \
		--no-print-statistics --verbosity warning \
		"${dump_tar}" "'${backup_url}'")"
	#
	# If it worked clean up.
	#
	local status="${output##* }"
	if [ x"${status}" = x"ok" ]
	then
	    echo "${opt_backup_full%:*}" >|"${backup_status_dir}/backup-full-no.txt"
	    echo "${opt_backup_incr%:*}" >|"${backup_status_dir}/backup-incr-no.txt"
	    echo "${timestamp_sha256}" >|"${backup_status_dir}/timestamp.sha256"
	    [ -z "${opt_keep_incr}" ] || {
		local keep_count=$(( (${opt_keep_incr#*:} + ${opt_backup_full#*:} - 1) / ${opt_backup_full#*:}))
		FTP_PASSWORD="${password}" duplicity \
		    remove-all-inc-of-but-n-full ${keep_count} \
		    --archive-dir "${backup_status_dir}/duplicity-archive" \
		    --verbosity warning --force "${backup_url}"
	    }
	    [ -z "${opt_keep_full}" ] || {
		local keep_count=$(( (${opt_keep_full#*:} + ${opt_backup_full#*:} - 1) / ${opt_backup_full#*:}))
		FTP_PASSWORD="${password}" duplicity \
		    remove-all-but-n-full ${keep_count} \
		    --archive-dir "${backup_status_dir}/duplicity-archive" \
		    --verbosity warning --force "${backup_url}"
	    }
	fi || :
	#
	# Write what happened to the status board.  This must happen last so
	# we get the true elapsed time for the backup site.
	local elapsed=$(( $(date +%s) - ${elapsed} ))
	local message=$(
	    [ x"${status}" = x"ok" ] || printf "%s" "${output% *}")
	la_container statusboard "${status_token}" "${status}" \
	    $(printf "%dsec %s" ${elapsed} "${status_url}") ${message}
    ) 8>&1 9>&2 || :
}


#
# Build the rootfs.  Purely for internal use by la_container_build(), which
# calls while in a fakechroot.
#
la_container_build_fakechroot()
{
    local -
    set -o errexit -o noclobber -o nounset
    local action="${1}"
    local debian_mirror="${2}"
    local debian_suite="${3}"
    local locales="${4}"
    #
    # Start with a minbase install.
    #
    export LC_ALL=C
    local temp_dir="$(mktemp --tmpdir --directory "${ME##*/}-${action}-XXXXXXXX")"
    local rootfs="${temp_dir}/rootfs"
    trap ": rm --force --recursive '${temp_dir}'" 0 1 2 15
    if [ -z "${FAKECHROOT:-}" ]
    then local variant=minbase
    else local variant=fakechroot
    fi
    debootstrap --variant="${variant}"  \
	"${debian_suite}" "${rootfs}" "${debian_mirror}"
    [ ! -e "${rootfs}/sbin/ldconfig.REAL" ] || {
	echo 1>&2 "${ME##*/} ${action}: You've been bitten by http://bugs.debian.org/731859.  The workaround is to run '${ME##*/} build' as root."
	return 1
    }
    #
    # Ensure we download security patches and updates.
    #
    dd status=none of="${rootfs}/etc/apt/sources.list" <<-===
	deb ${debian_mirror} stretch main
	deb ${debian_mirror} stretch-updates main
	deb ${debian_mirror}-security stretch/updates main
	===
    #
    # Put the required files in /usr/local/la-container.
    #
    mkdir --parents "${rootfs}/usr/local/la-container"
    cp "${ME}" "${rootfs}/usr/local/la-container"
    chmod a+x "${rootfs}/usr/local/la-container/${ME##*/}"
    ln --relative --symbolic \
	"${rootfs}/usr/local/la-container/${ME##*/}" "${rootfs}/init.sh"
    ln --relative --symbolic \
	"${rootfs}/usr/local/la-container/${ME##*/}" "${rootfs}/usr/bin/."
    ln --symbolic "${ME##*/}" "${rootfs}/usr/local/la-container/application.sh"
    ln --relative --symbolic \
	"${rootfs}/usr/local/la-container/application.sh" "${rootfs}/usr/bin/."
    dd status=none of="${rootfs}/usr/local/la-container/application-build.sh" <<-===
	#!/bin/sh
	#
	# This script must build a new copy of container it appears in with the
	# same versions of software.  But if you are seeing this particular
	# version in a live container it means its developer hasn't done his
	# job.
	#
	# The last line of this must run the copy of application.sh that lives
	# in the same directory this script lives, passing it the options
	# needed to build the container with the right versions of software.
	#
	"\${0%/*}/application.sh" build --mirror=${debian_mirror} --suite=${debian_suite}
	===
    chmod a+x "${rootfs}/usr/local/la-container/application-build.sh"
    #
    # Install the dummy application-build.sh
    #
    # The chroot may be fake (ie, implemented via a LD_PRELOAD shim), and if
    # so ldconfig won't be fooled.  So move it out of the way and use
    # ldconfig's -r switch instead.
    #
    [ -z "${FAKECHROOT:-}" ] || {
	mv "${rootfs}/sbin/ldconfig" "${rootfs}/sbin/ldconfig.${ME##*/}"
	dd status=none of="${rootfs}/sbin/ldconfig" <<-===
		#!/bin/sh
		exec '/sbin/ldconfig.${ME##*/}' -r '${rootfs}' "\$@"
		===
	chmod a+x "${rootfs}/sbin/ldconfig"
    }
    #
    # Build a sed regexp that matches the locales
    # in /etc/locale.gen that must be generated.
    #
    local locales_re="$(
	echo "${locales}" |
	sed 's/\([^.,]*\)[.]\([^,]*\)/\1\\([.][^ ]*\\)\\?  *\2\\>/g;s/,*$//;s/,/\\|/g')"
    lang_language="$(
	echo "${locales}" |
	sed --quiet 's/^\([^_]*\)\(_[^,.]*\)\([.][^,]*\).*/\1\2\3 \1\2:\1/p')"
    #
    # Add extra packages and do locale config in a chroot.
    #
    chroot "${rootfs}" $(sub_shell) <<-==1==
	#
	# Mark everything auto installed, because debootstrap doesn't.
	#
	apt-mark auto \$(dpkg-query --showformat='\${Package} ' --show)
	#
	# Install the extra packages.
	#
	dpkg --add-architecture i386
	/usr/local/la-container/la-container.sh apt-get-install $(echo ${DEBIAN_PACKAGES})
	#
	# Set the locale.
	#
	sed --in-place 's/^[[:space:]]*#[[:space:]]*\(${locales_re}\)/\1/' /etc/locale.gen
	#
	# The settings of the LANG= and LANGUAGE= variables
	# in /etc/default/locale.
	#
	dd status=none of=/etc/default/locale <<-==2==
		LANG="${lang_language% *}"
		LANGUAGE="${lang_language#* }"
		==2==
	locale-gen
	==1==
    #
    # Check the locales they asked for exist.
    #
    for loc in $(echo "${locales}" | tr ',' ' ')
    do
	local loc_lang="${loc%.*}"
	local encoding="${loc##*.}"
	echo "${loc}" |
	    egrep --silent "^${loc_lang}([.].*)? ${encoding}\>" "${rootfs}/etc/locale.gen" || {
		echo 1>&1 "${ME##*/} ${action}: '${loc}' is not a valid locale."
		return 1
	    }
    done
    #
    # Restore ldconfig.
    #
    [ ! -e "${rootfs}/sbin/ldconfig.${ME##*/}" ] || {
	mv "${rootfs}/sbin/ldconfig.${ME##*/}" "${rootfs}/sbin/ldconfig"
    }
    #
    # Provide root logins with the same environment init creates.
    #
    dd status=none of="${rootfs}/etc/profile.d/la-container-profile.sh" <<-===
	[ ! -s /etc/timezone ] || export TZ=\$(cat /etc/timezone)
	[ ! -s /etc/default/locale ] || {
	    eval export \$(grep  '^[A-Z].*.' /etc/default/locale)
	}
	if [ -e "/data/etc/environment" ]
	then
	    [ ! -s /data/etc/environment ] ||
		eval export \$(grep '^[[:space:]]*[^#]' /data/etc/environment)
	elif [ -e "/etc/environment" ]
	then
	    [ ! -s /etc/environment ] ||
		eval export \$(grep '^[[:space:]]*[^#]' /etc/environment)
	fi
	===
    #
    # Install backup config.
    #
    mkdir -p "${rootfs}/etc/la-container/backup-sites"
    mkdir -p "${rootfs}/etc/la-container/backup-gpgkeys"
    dd status=none of="${rootfs}/etc/la-container/backup-sites/README.txt" <<-===
	#
	# To configure backup sites add files to this directory.
	#
	# Each file must have a duplicity(1) backup URL in it's first
	# noncomment line, optionally followed by lines containing duplicity
	# options to use for this backup.  Comment lines start with a '#'.
	# The base container does not support all backends (aka URL schemes) -
	# see below.
	#
	# Include the duplicity option "--no-encryption" if you don't want
	# the backup to be encrypted.  Otherwise if you don't include
	# --encrypt-key options the backup will be encrypted with all keys
	# in /data/etc/la-container/backup-gpgkeys.  The key passed to
	# --encrypt-key must be a filename in that directory.
	#
	# How often backups are done, and how long they are kept is controlled
	# using these options (default values are shown):
	#     --la-container:backup-full=1.month
	#     --la-container:backup-incr=8.hours
	#     --la-container:keep-full=1.year
	#     --la-container:keep-incr=3.months
	# The default values mean:
	#     .   Do a full back at least once a month.
	#     .   Do a backup (incremental or full) every 8 hours.
	#     .   Keep 1 year of full backups (ie, the last 12 full backups).
	#     .   Keep incremental backups for 3 months of full backups (ie,
	#         keep the incremental backups for the last 3 full backups).
	# The period can be one of the following (N is a integer 1 or above):
	#     N.hours
	#     N.days
	#     N.weeks
	#     N.months
	#     N.years
	#
	# Example 1:
	#
	#    #
	#    # Write an unencrypted backup to the directory
	#    # /data/var/lib/container-backup (this directory must exist).
	#    #
	#    file:////data/var/lib/container-backup
	#    --no-encryption
	#
	# Example 2:
	#
	#    #
	#    # Write an backup encrypted with all keys in
	#    # /data/etc/la-container/backup-gpgkeys to Amazon s3.
	#    # Note: if there are no keys in backup-gpgkeys this will fail.
	#    #
	#    s3+http://aws-key:aws-secret@www.myconf.org.au-backups/production
	#    --s3-use-new-style --s3-use-ia
	#
	#
	# DUPLICITY BACKEND SUPPORT
	#
	# "Supported" below means supported by the base la-container image.
	#
	# azure://		Supported.
	# cf+http://		Supported.
	# cf+hubci://		Not supported by Debian.
	# copy://		Supported.
	# dpbx://		Application must install python-dropbox.
	# file://		Supported (careful!  use file:///data/tmp/...)
	# fish://		Application must install lftp.
	# ftp://		Application must install lftp.
	# ftps://		Application must install lftp.
	# gdocs://		Supported.
	# gs://			Supported.
	# hsi://		Supported.
	# imap://		Supported.
	# lftp+???://		Application must install lftp.
	# mega://		Not supported by Debian.
	# mf://			Not supported by Debian.
	# multi://		Supported.
	# ncftp+???://		Application must install ncftp.
	# onedrive://		Supported.
	# par2+???://		Application must install python-pexpect.
	# pydrive://		Not supported by Debian.
	# rsync://		Supported.
	# s3://			Supported.
	# scp://		Supported.
	# sftp://		Supported.
	# swift://		Supported.
	# swift://		Supported.
	# tahoe://		Application must install tahoe-lfs.
	# webdav://		Supported.
	#
	===
    dd status=none of="${rootfs}/etc/la-container/backup-gpgkeys/README.txt" <<-===
	#
	# This directory contains the public gpg keys used to encrypt the
	# backups.  Any of the keys can be used to decrypt it.  Each key
	# must be contained in a file whose name, when passed to gpg's
	# --recipient option, will select the public gpg key it contains.
	#
	# Here is an example of one way to prepare such a file:
	#
	#     gpg --armor \\
	#	  --export-options export-minimal,no-export-attributes \\
	#	  --output russell-gpg@stuart.id.au \\
	#	  --export russell-gpg@stuart.id.au
	#
	===
    dd status=none of="${rootfs}/etc/la-container/production-fqdn" <<-===
	#
	# This file contains the fully qualified domain name of production
	# host server.  "la-container.sh backup" will not perform a backup
	# if it is not running on this host.  It verifies it is running on
	# the host by doing a http fetch of a special URL.
	#
	# Setting this fqdn to "localhost" is bypasss the check entirely,
	# causing backup to behave as if "--no-live-check" is passed.
	#
	localhost
	===
    #
    # Install "la-container.sh init" config.
    #
    dd status=none of="${rootfs}/etc/la-container/init-profile.sh" <<-===
	#
	# The file is sourced by "la-container.sh init" when it starts.
	# Debugging shell options (eg set -o xtrace) are preserved when
	# init.sh calls other .sh scripts, so there is is a good chance doing
	# will that will get you line by line trace of everything the
	# la-container doesn't.  The trace appears in
	# /DATA_DIR/var/log/init.log.
	#
	===
    #
    # Log rotate config.
    #
    dd status=none of="${rootfs}/etc/la-container/log-rotate.conf" <<-===
	#
	# Set to "true" to stop the container from rotating it's own logs.
	# Otherwise the container will rotate it's logs when *all* conditions
	# below are met.
	#
	# Format: shell snippet.
	#
	LOGROTATE_DISABLED=false

	#
	# Time of day (localtime) the container will rotate it's logs.
	#
	LOGROTATE_TIMES=02:35

	#
	# The two letter day names, separated by commas, on which the container
	# will rotate its logs.
	#
	LOGROTATE_DAYS=su

	#
	# 2 digit day of month numbers (ie the XX in the IS0 8601 date
	# 2018-02-XX), separated by commas on which the logs will be rotated.
	#
	LOGROTATE_MONTHDAYS=
	===
    #
    # mini-httpd config, used if no web server is installed.
    #
    dd status=none of="${rootfs}/etc/la-container/mini-httpd.conf" <<-===
	#
	# If the application doesn't start a service that listens to
	# tcp port 80 the la-container will install mini-httpd, symlink
	# it's configuration file to this one in /DATA_DIR/etc, and start it.
	# This is to ensure the URL http://.../_la-container_/statusboard.txt
	# can be fecthed from the container.  If the application does install
	# something that listens on port 80 it must ensure it responds to the
	# statusboard URL.
	#
	charset=UTF-8
	dir=/data/var/lib/la-container/www
	host=0::0
	logfile=/var/log/mini-httpd.log
	nochroot
	pidfile=/var/run/mini-httpd.pid
	port=80
	user=www-data
	===
    #
    # Write the service definitions.
    #
    local services_dir="${rootfs}/etc/la-container/services"
    mkdir --parents "${services_dir}"
    dd status=none of="${services_dir}/README.txt" <<-===
	#
	# The services are provided because the usual tools for controlling
	# services (SysV-init and systemd) aren't part of in Debian minbase.
	# "la-container.sh service" is their replacement.  It will start /
	# stop / rotate all services in this directory that are installed
	# (ie the file defined by Executable below is present and executable).
	# If they aren't installed they are silently ignored, allowing us to
	# ship a useful defaults.
	#
	# Each service is described by a file whose name has the format:
	#
	#     PRIORITY-SERVICENAME.service
	#
	# where:
	#
	#     PRIORITY	    Services are started in ascending PRORITY order,
	#		    and are stopped in the reversed order.  PRIORITY
	#		    may not contain a '-'.
	#
	#     SERVICENAME   The service name as passed to "la-container.sh
	#		    service".  The debian package name that installed
	#		    the service should contain the service name.
	#
	# The file must start with "Keyword: value" lines:
	#
	#     Cmdline:      A "grep --line-regexp" matching /proc/PID/cmdline
	#		   of the running service (only).  The nulls in that
	#		    file are translated to a space before giving it to
	#		    grep.  If this line doesn't start with a '/' is
	#		    taken to be a shell command which is executed
	#		    directly.  If this is a problem because your
	#		    service name rewrites it's command line so it
	#		    doesn't start with a / (I'm looking at you nginx),
	#		    prefixing the pattern with "/*" is a usable
	#		    workaround.
	#
	#     Executable:   Path to an executable that will be present if
	#		    service installed.  If this line is absent the
	#		    first token in Cmdline is used.
	#
	#     Rotate:       Command that makes the service reopen all its log
	#		    files.  See below for options.  It will only be
	#		    called if Cmdline finds the service.  If this line
	#		    is absent the service is stopped and started.
	#
	#     Statusboard:  Command that writes on the status of the service
	#		    to the status board.  The result is recorded as
	#		    "ok" if the command had an exit status, "fail"
	#		    otherwise.  The output of the command use as the
	#		    status board message.  If this is absent "fail"
	#		    is recorded if Cmdline doesn't find the process,
	#		    "ok" is recorded if it does with the message being
	#		    the up time, run time and command line.
	#
	#     Start:	    Command that starts the service.  See below for
	#		    options.  It will only be called if Cmdline
	#		    doesn't find the process.  If this line is absent
	#		    Cmdline is used.
	#
	#     Stop:	    Command that stops the service.  See below for
	#		    options. It will only be called if Cmdline finds
	#		    the service.  If this line is absent or if
	#		    Cmdline still finds PID's after it returns those
	#		    PID's are sent a SIGTERM, followed by a SIGKILL if
	#		    they don't respond.
	#
	# The commands to Rotate, Start and Stop are executed by the dash(1)
	# eval command, which waits to for them complete.  If they start with
	# a '/' they run as "eval setsid COMMAND", otherwise you must call
	# setsid if required (it never hurts and puts the command in the
	# backgroud which must happen otherwise the "la-container.sh service"
	# will hang).  If setsid isn't used you can call shell functions
	# defined here, which can follow after a blank line.
	#
	===
    dd status=none of="${services_dir}/2200-bind9.service" <<-===
	Cmdline: /usr/sbin/named -f -u bind
	Start: /usr/sbin/rndc start
	Stop: /usr/sbin/rndc stop && skip_terminate=true
	===
    dd status=none of="${services_dir}/2400-cron.service" <<-===
	Cmdline: /usr/sbin/cron
	===
    dd status=none of="${services_dir}/2600-openssh-server.service" <<-===
	Cmdline: /usr/sbin/sshd -D
	Start: mkdir --parents /run/sshd; setsid /usr/sbin/sshd -D &
	===
    dd status=none of="${services_dir}/5200-mariadb-server.service" <<-===
	Cmdline: /usr/sbin/mysqld
	Rotate: mysqladmin refresh
	Start: su --shell /bin/sh --command /usr/sbin/mysqld mysql
	Stop: mysqladmin shutdown
	===
    dd status=none of="${services_dir}/5400-postgresql.service" <<-===
	Cmdline: /usr/lib/postgresql/[^/ ]*/bin/postgres -D .*
	Executable: /usr/bin/pg_ctlcluster
	Rotate: postgresql_start_stop reload
	Start: postgresql_start_stop start
	Stop: postgresql_start_stop --force stop

	postgresql_start_stop()
	{
	    local action="\${1}"
	    shift
	    local instance
	    for instance in /etc/postgresql/*/*/postgresql.conf
	    do
 		local name="\${instance%/*}"
 		local version="\${name%/*}"
 		setsid /usr/bin/pg_ctlcluster \$@ "\${version##*/}" "\${name##*/}" \${action} || :
	    done
	}
	===
    dd status=none of="${services_dir}/6200-exim4.service" <<-===
	Cmdline: /usr/sbin/exim4 -bd -q1m
	===
    dd status=none of="${services_dir}/6400-postfix.service" <<-===
	Cmdline: /usr/lib/postfix/sbin/master -w
	Start: postfix start
	Stop: postfix stop
	===
    dd status=none of="${services_dir}/8200-apache2.service" <<-===
	Cmdline: /usr/sbin/apache2 -k start
	Rotate: apache2ctl graceful
	Start: apache2ctl start
	Stop: apache2ctl stop
	===
    dd status=none of="${services_dir}/8400-mini-httpd.service" <<-===
	Cmdline: /usr/sbin/mini_httpd -C /etc/mini-httpd.conf
	===
    dd status=none of="${services_dir}/8600-nginx.service" <<-===
	Cmdline: /*nginx: master process .*
	Executable: /usr/sbin/nginx
	Rotate: kill -USR1 \${service_pids}
	Start: /usr/sbin/nginx -g "daemon on; master_process on;"
	===
    #
    # Write the timer definitions.
    #
    local timers_dir="${rootfs}/etc/la-container/timers"
    mkdir --parents "${timers_dir}"
    dd status=none of="${timers_dir}/README.txt" <<-===
	#
	# Timers are provided because cron isn't in Debian minbase.  The init
	# script dedicates its life to running these timers after it has done
	# its boot up duties.  Timers are run synchronously.
	#
	# Each file in this directory with the file extension ".timer" defines
	# a timer.  Time file names can consist of letters, digits and "-"
	# only and should not start with "la-container-".
	#
	# Timer files are dash(1) scripts that are run when the timer fires,
	# but the first non blank lines have special significance.  They must
	# set the shell variables below which control when the timer fires.
	# If a variable is set a timer only files when it says, ie the
	# conditions with one variable are OR'ed, and then the variables are
	# AND'ed.
	#
	#   TIMER_TIMES
	#	Set this to a list times the timer can fire, format 24 hour
	#	HH:MM. Multiple times are separated by commas.  If not set
	#	the timer is disabled.  Example: "TIMER_TIMES=01:09,16:22"
	#	If this is set as "TIMER_TIMES=*" the timer runs every poll,
	#	and polls are guarrenteed to happen at least once per hour.
	#
	#   TIMER_DAYS
	#	Set this to the two letter day names (English) the timer is
	#	eligble to run, separated by commas. If not set the timer is
	#       eligble to run on all days.  For example: "TIMER_DAYS=mo,we".
	#
	#   TIMER_MONTHDAYS
	#	Set this to the two digit days of the month this timer eligble
	#	to run, separated by commans.  If not set the timer is eligble
	#       to every day of the month.  For example, to only run the timer
	#       in the 1st and 3rd weeks of the month:
	#	"TIMER_MONTHDAYS=01,02,03,04,06,07,15,16,17,18,19,20,21"
	#
	===
    dd status=none of="${timers_dir}/la-container-apt.timer" <<-===
	TIMER_TIMES=03:30

	export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
	if  apt-get update &&
	    apt-get upgrade --fix-broken --quiet --with-new-pkgs --yes --simulate | egrep --silent '^(Conf|Inst) '
	then
	    apt-get upgrade --fix-broken --quiet --with-new-pkgs --yes &&
		apt-get clean
	    case "\$(set -o | tr -d ' ')" in
		*[!a-z]xtraceon[!a-z]*)		sub_shell='dash -o xtrace';;
		*)				sub_shell=dash;;
	    esac
	    \${sub_shell} "\${ME}" service
	fi
	===
    dd status=none of="${timers_dir}/la-container-log-rotate.timer" <<-===
	. /data/etc/la-container/log-rotate.conf
	TIMER_TIMES=\$([ x"\${LOGROTATE_DISABLED#[1TtYy]}" != x"\${LOGROTATE_DISABLED}" ] || printf "%s" "\${LOGROTATE_TIMES}")
	TIMER_DAYS=\${LOGROTATE_DAYS}
	TIMER_MONTHDAYS=\${LOGROTATE_MONTHDAYS}

	case "\$(set -o | tr -d ' ')" in
	    *[!a-z]xtraceon[!a-z]*)	sub_shell='dash -o xtrace';;
	    *)				sub_shell=dash;;
	esac
	\${sub_shell} "\${ME}" rotate /data
	===
    dd status=none of="${timers_dir}/la-container-backup.timer" <<-===
	TIMER_TIMES=*

	case "\$(set -o | tr -d ' ')" in
	    *[!a-z]xtraceon[!a-z]*)	sub_shell='dash -o xtrace';;
	    *)				sub_shell=dash;;
	esac
	nice ionice --class 3 --ignore nocache -n 10 chrt --idle 0 eatmydata \
	    \${sub_shell} "\${ME}" backup
	===
    #
    # Construct our Dockerfile, and package it all up in a tar ball that
    # that the docker build is waiting for on file description 9.
    #
    (
	. "${rootfs}/etc/os-release"
	dd status=none of="${temp_dir}/Dockerfile" <<-===
		FROM scratch
		COPY rootfs /
		ENTRYPOINT /init.sh
		LABEL os_release="${PRETTY_NAME}"
		VOLUME ["/data"]
		===
    )
    tar --create --directory="${temp_dir}" Dockerfile rootfs 1>&9
    #
    # Clean up.
    #
    : rm --force --recursive "${temp_dir}" 0 1 2 15
    trap - 0 1 2 15
}


#
# la-container.sh build-options [--mirror=M] [--suite=M]
# ======================================================
#
# Echo the options given on the command line to stdout, but add the
# default values "la-container.sh build" would use for the omitted
# options.
#
la_container_build_options()
{
    local -
    set -o errexit -o noclobber -o nounset
    #
    # Parse the command line.
    #
    local locales=
    local debian_mirror=
    local debian_suite=
    local action="${1:-}"
    shift			# get rid of "build"
    local arg
    local locales=
    for arg do
	case "${arg}" in
#	    --locales=*)
#		local loc="${arg#--*=}"
#		[ x"${loc%.*}" != x"${loc}" ] || loc="${loc}.UTF-8"
#		locales="${locales}${loc}," ;;
	    --mirror=*)		debian_mirror="${arg#--*=}" ;;
	    --suite=*)		debian_suite="${arg#--*=}" ;;
	    *)
		echo 1>&2 "usage: ${ME##*/} ${action} [--help] [options]"
		echo 1>&2 "options:"
#		echo 1>&2 "  --locales=L Include these locales (default: ${DEBIAN_LOCALES})."
		echo 1>&2 "  --mirror=M  Debian mirror to use (default: deb.debian.org)."
		echo 1>&2 "  --suite=S   Debian suite to use (default: stable's codename)."
		echo 1>&2
		echo 1>&2 "Build the la-container and install it into docker.  The la-container is the"
		echo 1>&2 "base of your container, ie your Dockerfile will contain 'FROM la-container'".
		return 1 ;;
	esac
    done
    [ -n "${locales}" ] || locales="${DEBIAN_LOCALES}"
    [ -n "${debian_mirror}" ] || debian_mirror="${DEBIAN_MIRROR}"
    [ -n "${debian_suite}" ] || debian_suite="${DEBIAN_SUITE}"
    local debian_suite="$(
	wget --output-document - --quiet "${debian_mirror}/dists/${debian_suite:-stable}/Release" |
	sed --quiet 's/^Codename: *\(.*\)/\1/p;T;q')" || :
    [ -n "${debian_suite}" ] || {
	echo "${0##*/} build: Fetch of '${debian_mirror}/dists/${debian_suite:-stable}/Release' failed."
	return 1
    }
    [ x"$(uname -m)" = x"x86_64" ] || {
	echo 1>&2 "${ME##*/} ${action}: this must be run on a X86_64 (amd64) kernel."
    }
    [ -n "${locales}" ] || locales="${DEBIAN_LOCALES}"
    printf " --locales=%s --mirror=%s --suite=%s\n" \
	"${locales}" "${debian_mirror}" "${debian_suite} "
}


#
# la-container.sh build [--mirror=M] [--suite=M]
# ==============================================
#
# Build the la-container and add to docker.
#
la_container_build()
{
    local -
    set -o errexit -o noclobber -o nounset
    local action="${1}"
    shift
    local options="$(la_container_build_options "${action}" "$@")"
    local locales="${options##* --locales=}"
    local locales="${locales%% *}"
    local debian_mirror="${options##* --mirror=}"
    local debian_mirror="${debian_mirror%% *}"
    local debian_suite="${options##* --suite=}"
    local debian_suite="${debian_suite%% *}"
    #
    # Construct the tarball in a fakechroot to avoid needing root. Do it by
    # recursively calling ourselves so blackslash mania doesn't drive me
    # insane, preserve the trace settings as we do it and sprinkle with
    # redirections so the we can see what happened when it all goes tits up.
    #
    getroot="fakechroot fakeroot"
    [ $(id -u) != 0 ] || getroot=
    (
	${getroot} $(sub_shell) 9>&1 1>&8 \
	    "${ME}" build-fakechroot "${debian_mirror}" "${debian_suite}" "${locales}" |
	docker build --tag="la-container-${debian_suite}" -
    ) 8>&1
    trap - 0 1 2 15
}


#
# la-container.sh init
# ====================
#
# We have been called inside the container to do the job of the Unix init
# process (ie, pid 1).
#
la_container_init()
{
    #
    # application.sh lives with us.
    #
    local -
    set -o errexit -o noclobber -o nounset
    local application_sh="${0}"
    [ x"${0}" != x"${0#*/}" ] || application_sh="$(which "${application_sh}")"
    local application_sh="$(readlink --canonicalize-existing "${application_sh}")"
    local application_sh="${application_sh%/*}/application.sh"
    #
    # If the container is mounted read-only there is not much we can do.
    #
    if [ ! -w /data ]
    then
	if [ -e /data/etc/la-container/init-profile.sh ]
	then . /data/etc/la-container/init-profile.sh
	else . /etc/la-container/init-profile.sh
	fi
	. /etc/profile
	$(sub_shell) "${application_sh}" boot
	#
	# Put us to sleep forever.
	#
	while :; do sleep 1000000000 || :; done
    fi
    #
    # Setup logging.
    #
    mkdir --parents /data/var
    [ -d /data/var/log ] || cp --archive /var/log /data/var/log
    mv /var/log /var/log.orig
    ln --force --relative --symbolic /data/var/log /var
    exec >>/var/log/init.log 2>&1
    if [ -e /data/etc/la-container/init-profile.sh ]
    then . /data/etc/la-container/init-profile.sh
    else . /etc/la-container/init-profile.sh
    fi
    . /etc/profile
    #
    # If we are restoring a backup erase everything, bar the backup.
    # But, our log is an exception.  They still get to see all of this
    # happen.
    #
    local dump_tar="/data/tmp/_la-container_/restored-dump.tar"
    if [ -s "${dump_tar}" ]
    then
	#
	# Clean up.
	#
	find /data \
	    -path /data -o \
	    -path /data/tmp -o \
	    -path ${dump_tar%/*} -o \
	    -path ${dump_tar} -prune -o \
	    -path /data/var -o \
	    -path /data/var/log -o \
	    -path /data/var/log/init.log -prune -o \
	    -print0 -prune |
	xargs -0 --no-run-if-empty rm --force --recursive
	#
	# Set the default environment for the restore.
	#
	ln  --force --symbolic "/usr/share/zoneinfo/${TZ}" /etc/localtime
	#
	# Restore.
	#
	local dump_tar="/data/tmp/_la-container_/restored-dump.tar"
	rm --force --recursive "${dump_tar}.dir"
	mkdir --parents "${dump_tar}.dir"
	tar --extract --file "${dump_tar}" --directory "${dump_tar}.dir"
	$(sub_shell) "${application_sh}" boot "${dump_tar}.dir"
	rm --force --recursive "${dump_tar}.dir"
	#
	# If we have a new init-profile.sh read it again.
	#
	[ ! -e /data/etc/la-container/init-profile.sh ] ||
	    . /data/etc/la-container/init-profile.sh
    fi
    #
    # Set the default environment.
    #
    mkdir --parents /data/tmp
    chown 0.0 /data/tmp
    chmod 1777 /data/tmp
    #
    # Ensure the permissions on root's authorized_keys are acceptable to
    # openssh.
    #
    mkdir --parents /root/.ssh
    chmod 0755 /root /root/.ssh
    touch /root/.ssh/authorized_keys
    chmod 0644 /root/.ssh/authorized_keys
    #
    # Copy our config into /data if it doesn't exist.
    #
    (
	mkdir --parents /data/etc
	mv /etc/environment /etc/environment.orig
	ln --relative --symbolic /data/etc/environment /etc/
	mkdir --parents /data/etc/la-container
	for config in /etc/la-container/*
	do
	    #
	    # The sysadmin doesn't get to mangle these.
	    #
	    case "${config}" in
		/etc/la-container/services)	continue;;
		/etc/la-container/timers)	continue;;
	    esac
	    [ -e "/data/${config}" ] ||
		cp --archive  "${config}" "/data/${config}"
	done
	[ -e /data/etc/environment ] ||
	    cp --archive /etc/environment /data/etc/environment
	#
	# Redirect ssmtp(8) config to /data/etc/ssmtp,
	# creating it if it doesn't exist.
	#
	[ -d /data/etc/ssmtp ] || cp --archive /etc/ssmtp /data/etc
	mv /etc/ssmtp /etc/ssmtp.orig
	ln --force --relative --symbolic /data/etc/ssmtp /etc/
    )
    #
    # If there is a backup awaiting, restore it.
    #
    if [ ! -s "${dump_tar}" ]
    then
	la_container statusboard la-container:init.sh ok "Starting"
	$(sub_shell) "${application_sh}" boot
    else
	la_container statusboard la-container:init.sh ok "Restore complete"
	rm --force "${dump_tar}"
    fi
    #
    # Put current copies of la-container.sh and application.sh in /data,
    # so they will be backed up.
    #
    mkdir --parents /data/usr/local
    cp --archive /usr/local/la-container /data/usr/local/.
    #
    # Install security updates.
    #
    la_container run-timer la-container-apt.timer
    local http_server_running=true
    bash -c '</dev/tcp/127.0.0.1/80' 2>/dev/null || http_server_running=
    #
    # Our main loop.  Run the timers.
    #
    local now="$(date +%s)"
    local timer_list=''
    while :
    do
	#
	# If there is no web server listening on port 80 and mini-httpd isn't
	# installed install it, and configure it to serve the status board.
	#
	# This is retried because there may be no internet connection when
	# the container is first started.
	#
	[ -n "${http_server_running}" -o -x /usr/sbin/mini_httpd ] || (
	    export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
	    apt-get install --quiet --no-install-recommends --yes mini-httpd || :
	    [ ! -x /usr/sbin/mini_httpd ] || {
		ln --force --symbolic \
		    /data/etc/la-container/mini-httpd.conf /etc/.
		la_container service restart mini-httpd || :
	    }
	)
	#
	# Do a statusboard update for all services.
	#
	la_container service statusboard
	#
	# Wait a maximum of 1 hour so we can reopen logs if a rotate is
	# pending.
	#
	local next_event="$((${now} + 3600))"
	#
	#
	local timer_file
	for timer_file in /etc/la-container/timers/*.timer
	do
	    local timer_name="${timer_file##*/}"
	    local timer_next="${timer_list##* ${timer_name}=}"
	    local timer_next="${timer_next%% *}"
	    [ -n "${timer_next}" ] ||
		timer_next="$(la_container timer-when "${timer_name}" "${now}")"
	    [ -z "${timer_next}" ] || {
		local timer_list="${timer_list} ${timer_name}=${timer_next}"
		if [ x"${timer_next}" != x"*" ]
		then
		    [ "${next_event}" -le "${timer_next}" ] ||
			local next_event="${timer_next}"
		fi
	    }
	done
	#
	# Wait for the next event to become due.
	#
	[ "${next_event}" -le "${now}" ] ||
	    sleep $((${next_event} - ${now}))
	local now="$(date +%s)"
	#
	# Do everything scheduled to be done now.
	#
	local new_list=''
	for timer_when in ${timer_list}
	do
	    if [ x"${timer_when#*=}" != x"*" ] && [ "${timer_when#*=}" -gt "${now}" ]
	    then new_list="${new_list} ${timer_when}"
	    else la_container run-timer "${timer_when%=*}" || :
	    fi
	done
	local timer_list="${new_list}"
	#
	# Do the log rotate.  This must be last.
	#
	if [ -f /data/var/log/rotate-pending.flag ]
	then
	    exec >>/var/log/init.log 2>&1
	    la_container service rotate || :
	    rm --force /data/var/log/rotate-pending.flag
	    la_container statusboard la-container:logging ok rotate 'done'
	fi
    done
}


#
# la-container.sh is-live HOSTNAME
# ================================
#
# If run on HOSTNAME this succeeds, otherwise emits an error message with a
# non-zero exit status.
#
la_container_is_live()
{
    local action="${1}"
    [ $# = 2 -a x"${2:-}" != x"--help" ] || {
	echo 1>&2 "usage: ${ME##*/} ${action} [--help] HOSTNAME"
	return 1
    }
    local hostname="${2}"
    local random_data="$(dd status=none bs=16 count=1 if=/dev/urandom | xxd -p)"
    la_container statusboard "la-container:is-live:${random_data}" ok performing is-live test
    local response="$(
	bash -c "(
	    printf 'GET /_la-container_/statusboard.txt HTTP/1.0\r\nHost: ${hostname}\r\n\r\n'
	    cat 1>&9
	) 2>&1 9>&1 <>/dev/tcp/${hostname}/80 1>&0")" || :
    la_container statusboard la-container:is-live:${random_data} purge
    printf "${response}" |
	fgrep ":${random_data} " --silent || {
	echo "${ME##*/} ${action}: this isn't the live ${hostname} server."
	return 1
    }
}

#
# la-container.sh lockfile OPERATION LOCKFILE [PID]
# =================================================
#
# Lock file creation / deletion
#
# OPERATION
#
#     lock	return of PID of process holding LOCKFILE, or acquire
#		lock and return nothing.
#
#     unlock	release the lock on LOCKFILE if this process PID owns it.
#
#     wait	wait until this process PID can acquire the lock on LOCKFILE,
#	        acquire it and return.
#
# LOCKFILE	The filename of LOCKFILE.  It will be modified to be /run, and
#		to end with '.lock'.
#
# PID		The PID of the currently process being manipulating the lock.
#		If not passed this process is used.
#
la_container_lockfile()
{
    local action="${1}"
    [ $# -ge 3 -a x"${2}" != x"--help" ] || {
	echo 1>&2 "usage: ${ME##*/} ${action} lock|unlock|wait LOCKFILE [PID]"
	return 1
    }
    local operation="${2}"
    local lockfile="/run/${3#/run/}"
    local lockfile="${lockfile%.lock}.lock"
    local my_pid="${4:-$$}"
    local my_contents="$(
	echo "${my_pid}" "$(tr '\0' ' ' </proc/${my_pid}/cmdline)")"
    local lock_contents="$(
	[ ! -f "${lockfile}" ] || cat "${lockfile}" 2>/dev/null || :)"
    #
    # Unlock is the simple case.
    #
    if [ x"${operation}" = x"unlock" ]
    then
	[ x"${my_contents}" != x"${lock_contents}" ] || rm "${lockfile}"
	return 0
    fi
    #
    # Do we have the lock?
    #
    [ x"${my_contents}" != x"${lock_contents}" ] || return 0
    #
    # Poll the lock.
    #
    echo "${my_pid}" "$(tr '\0' ' ' </proc/${my_pid}/cmdline)" >|"${lockfile}.${my_pid}"
    while :
    do
	ln "${lockfile}.${my_pid}" "${lockfile}" 2>/dev/null && break || :
	local lock_contents="$(cat "${lockfile}" 2>/dev/null)" || continue
	[ -n "${lock_contents}" ] || continue
	local lock_pid="${lock_contents%% *}"
	local his_contents="$(
	    (echo "${lock_pid}" "$(tr '\0' ' ' </proc/${lock_pid}/cmdline)") 2>/dev/null)"
	[ x"${lock_contents}" = x"${his_contents}" ] || {
	    rm --force "${lockfile}"
	    continue
	}
	[ x"${operation}" = x"wait" ] || { echo "${lock_pid}"; return 0; }
	sleep 0.1
    done
    rm --force "${lockfile}.${my_pid}"
}


#
# la-container.sh restore BACKUP_URL /DATA_DIR [--DUPLICITY-OPT ...]
# ==================================================================
#
# Read a backup from BACKUP_URL and write it to /DATA_DIR.  To select
# something other than the latest backup append the requisite duplicity(1)
# to select it.
#
la_container_restore()
{
    local -
    set -o errexit -o noclobber -o nounset
    #
    # Parse the command line.
    #
    [ $# -ge 3 -a x"${2:-}" != x"--help" -a x"${3:-}" != x"--help" ] || {
	echo 1>&2 "usage: ${ME##*/} ${1} BACKUP_URL /DATA [--DUPLICITY-OPTS...]"
	return 1
    }
    local action="${1}"
    local backup_url="${2}"
    local data_dir="${3}"
    case "${backup_url}" in
	*://*/*) ;;
	*)
	    echo 1>&2 "${ME##*/} ${action}: '${backup_url}' is not duplicity URL."
	    return 1 ;;
    esac
    [ ! -e "${data_dir}" -o -d "${data_dir}" ] || {
	echo 1>&2 "${ME##*/} ${action}: '${data_dir}' is not a directory."
	return 1
    }
    shift 3
    #
    # Get the backup, and if it works arrange for the container to restore it.
    # Get rid of duplicity's spurious error message as we do it.  It's
    # whining because it can't restore ownership, but we use a single tar file
    # so we don't have to worry about ownership.
    #
    local dump_tar="${data_dir}/tmp/_la-container_/restored-dump.tar"
    rm --force --recursive "${dump_tar%/*}"
    mkdir --parents "${dump_tar%/*}"
    (   (duplicity --use-agent "$@" "${backup_url}" "${dump_tar}.tmp" &&
	    mv "${dump_tar}.tmp" "${dump_tar}" 1>&9
	) |
	grep --invert-match "^Error '\[Errno 1\] Operation not permitted: '${dump_tar}.tmp'' processing [.]\$"
    ) 9>&1
}


#
# la-container.sh rotate /DATA_DIR [LOG_FILE ...]
# ===============================================
#
# Rotate the containers log files.  If LOG_FILE is supplied it must be
# absolute or relative to /DATA_DIR/var/log.  If LOG_FILE is not supplied
# all the containers logs are rotated.  Once a rotate of any log file is
# done another one can not be done until container responds, which may
# take up to an hour.  If a log file is not rotated it will grow without
# bound.
#
la_container_rotate()
{
    local action="${1}"
    [ $# -ge 2 -a x"${2:-}" != x"--help" ] || {
	echo 1>&2 "usage: ${ME##*/} ${action} /DATA_DIR [log_file ...]"
	return 1
    }
    local data_dir="${2}"
    [ -d "${data_dir}/var/log" ] || {
	echo 1>&2 "${ME##*/} ${action}: ${data_dir}/var/log is not a directory."
	return 1
    }
    [ ! -e "${data_dir}/var/log/rotate-pending.flag" ] || {
	echo 1>&2 "${ME##*/} ${action}: A previous rotate is pending."
	return 1
    }
    shift 2
    #
    # Rotate the files given, or if none given rotate everything.
    #
    local log_file
    (
	if [ $# = 0]
	then find "${data_dir}/var/log" -type f ! -name "*.0" ! -name "*.[1-9].gz"
	else for arg; do printf "%s\n" "${arg}"; done
	fi
    ) | (
	while read -r log_file
	do
	    log_file="${data_dir}/var/log/${log_file#${data_dir}/var/log/}"
	    [ ! -L "${log_file}" -a -f "${log_file}" -a -s "${log_file}" ] ||
		continue
	    for no in 8 9 6 5 4 3 2 1
	    do
		[ ! -f "${log_file}.${no}.gz" ] ||
		    mv "${log_file}.${no}.gz" "${log_file}.$((${no} + 1)).gz"
	    done
	    [ ! -s "${log_file}.0" ] || {
		mv "${log_file}.0" "${log_file}.1"
		gzip -9 "${log_file}.1"
	    }
	    mv "${log_file}" "${log_file}.0"
	done
	touch "${data_dir}/var/log/rotate-pending.flag"
    )
}


#
# la-container.sh run-timer [--help] TIMER-NAME
# =============================================
#
# Run the passed timer, logging the result to the status board.
#
#   TIMER-NAME	The name of a timer in /etc/la-container/timers, or a timer
#		file.
#
la_container_run_timer()
{
    local -
    set -o errexit -o noclobber -o nounset
    local action="${1}"
    [ $# = 2 -a x"${2:-}" != x"--help" ] || {
	echo 1>&2 "usage: ${ME##*/} ${action} TIMER-NAME"
	return 1
    }
    local timer_name="${2}"
    local timer_file="${timer_name%.timer}.timer"
    [ x"${timer_file##*/}" != x"${timer_file}" ] ||
	local timer_file="/etc/la-container/timers/${timer_file}"
    [ -f "${timer_file}" ] || {
	echo 1>&2 "${ME##*/} ${action}: Can't find timer ${timer_name}."
	exit 1
    }
    local elapsed="$(date +%s%N)"
    (
	local output="$(statusboard_eval 256 . "'${timer_file}'")"
	local elapsed=$(($(date +%s%N) - ${elapsed}))
	local status="${output##* }"
	if [ x"${status}" = x"ok" ]
	then local message=
	else local message="${output% *}"
	fi
	la_container statusboard \
	    "la-container:timer:${timer_name%.timer}" "${status}" \
	    $(printf "runtime=%d.%03dms" $(($elapsed / 1000000)) $(($elapsed / 1000 % 1000))) \
	    "${message}"
    ) 8>&2 9>&1
}


#
# la-container.sh service restart|rotate|start|stop [service]
# ===========================================================
#
# We have been called inside of the container to (re)start the containers
# services.
#
la_container_service()
{
    local -
    set -o errexit -o noclobber -o nounset
    local action="${1}"
    local request="${2:-}"
    case "${request}" in
	restart|rotate|start|statusboard|stop)	;;
	*)
	    echo 1>&2 "usage: ${ME##*/} ${action} restart|rotate|start|statusboard|stop [service-name]"
	    return 1;;
    esac
    service_name="${3:-}"
    service_seen="not found"
    #
    # service restart|rotate|start|stop "${service-from-SERVICES}"
    #
    #   restart:    Stop the service if running.
    #   rotate:     Run rotate command if running.
    #   start:      Start the service if not running.
    #   statusboard: Update the status board for the service.
    #   stop:       Stop the service if running.
    #
    service()
    {
	local new_state="${1}"
	local service_file="${2}"
	local name="${service_file##*/}"
	local name="${name%.service}"
	local name="${name#*-}"		# Strip off the priority
	[ -z "${service_name:-}" -o x"${service_name:-}" = x"${name##*/}" ] ||
	    return 0
	[ -z "${service_seen}" ] || service_seen="not installed"
	local service="$(
	    sed --quiet \
		'1,/^[[:space:]]*$/{/^[[:space:]]*#/!H};${x;s/\n/|/g;s/^/|/p}' \
		"${service_file}")"
	local cmdline="${service##*|Cmdline: }"
	local cmdline="${cmdline%%|*}"
	local executable="${service##*|Executable: }"
	local executable="${executable%%|*}"
	[ -n "${executable}" ] || executable="${cmdline%% *}"
	[ -x "${executable}" ] || return 0
	service_seen=
	local start_cmd="${service##*|Start: }"
	local start_cmd="${start_cmd%%|*}"
	[ -n "${start_cmd}" ] || start_cmd="${cmdline}"
	local status_cmd="${service##*|Statusboard: }"
	local status_cmd="${status_cmd%%|*}"
	[ -n "${status_cmd}" ] ||
	    status_cmd='service_statusboard "${name}" "${service_pids}"'
	local stop_cmd="${service##*|Stop: }"
	local stop_cmd="${stop_cmd%%|*}"
	local rotate_cmd="${service##*|Rotate: }"
	local rotate_cmd="${rotate_cmd%%|*}"
	local service_pids="$(service_pids "${cmdline}")"
	local skip_terminate=
	[ -n "${rotate_cmd}" -o x"${new_state}" != x"rotate" ] ||
	    new_state=stop
	sed '1,/^[[:space:]]*$/d' "${service_file}" |
	(
	    . /dev/fd/0
	    case "${new_state}" in
		rotate)
		    [ -z "${service_pids}" ] || eval ${rotate_cmd};;
		start)
		    local setsid=setsid
		    [ x"${start_cmd#/}" != x"${start_cmd}" ] || setsid=
		    [ -n "${service_pids}" ] || eval ${setsid} ${start_cmd};;
		statusboard)
		    (eval ${status_cmd}) || :;;
		stop|restart)
		    [ -z "${service_pids}" -o -z "${stop_cmd}" ] ||
			eval ${stop_cmd}
		    terminate_kill "${cmdline}" "${skip_terminate}";;
	    esac
	)
    }
    #
    # Return the PID's of processes whose /proc/PID/cmdline matches the grep
    # regexp passed.
    #
    service_pids()
    {
	local cmdline="${1}"
	if [ x"${cmdline#/}" = x"${cmdline}" ]
	then (eval "${cmdline}")
	else
	    local procfile
	    for procfile in /proc/[1-9]*
	    do
		: tr '\0' ' ' "${procfile}/cmdline"
		! (tr '\0' ' ' <"${procfile}/cmdline") 2>/dev/null |
		    grep --line-regexp --silent --regexp="${cmdline} *" ||
		echo "${procfile##*/}"
	    done
	fi
    }
    #
    # Record the processes status.
    #
    service_statusboard()
    {
	local name="${1}"
	local service_pids="${2}"
	local stat=
	[ -z "${service_pids}" ] ||
	    stat="$(
		cat /proc/${service_pids%% *}/stat 2>/dev/null |
		tr ' ' '\n' |
		sed -n '16{s/^/cutime=/;H};17{s/^/cstime=/;H};22{s/^/starttime=/;H};${x;s/\n/ /g;p}')"
	if [ -z "${stat}" ]
	then local status="fail"
	else
	    local clock_ticks="$(getconf CLK_TCK)"
	    local cutime="${stat#* cutime=}"
	    local cutime="${cutime%% *}"
	    local cstime="${stat#* cstime=}"
	    local cstime="${cstime%% *}"
	    local starttime="${stat#* starttime=}"
	    local starttime="${starttime#* starttime=}"
	    local uptime="$(cat /proc/uptime)"
	    local uptime="${uptime%% *}"
	    local uptime="${uptime%.*}${uptime#*.}"
	    local uptime=$((${uptime} - ${starttime}))
	    local runtime=$((${cutime} + ${cstime}))
	    local status="$(
		printf \
		    "ok uptime=%d-%02d:%02d:%02d.%02d runtime=%d-%02d:%02d:%02d.%02d" \
		    $((uptime / 86400000)) \
		    $((uptime / 3600000 % 24)) $((uptime / 60000 % 60)) \
		    $((uptime / 100 % 60)) $((uptime % 100)) \
		    $((runtime / 86400000)) \
		    $((runtime / 3600000 % 24)) $((runtime / 60000 % 60)) \
		    $((runtime / 100 % 60)) $((runtime % 100)) )"
	fi
	la_container statusboard "la-container:service:${name}" ${status}
    }
    #
    # Send a SIGTERM to the processes found by the regexp passed.  If they
    # don't exit send a SIGKILL to them.
    #
    terminate_kill()
    {
	local cmdline="${1}"
	local skip_terminate="${2}"
	[ -n "${skip_terminate}" ] || {
	    local service_pids="$(service_pids "${cmdline}")"
	    [ -z "${service_pids}" ] || kill "${service_pids}" || return 0
	}
	local retry
	for retry in $(seq 100)
	do
	    local service_pids="$(service_pids "${cmdline}")"
	    [ -n "${service_pids}" ] || return 0
	    sleep 0.1
	done
	local service_pids="$(service_pids "${cmdline}")"
	[ -z "${service_pids}" ] || kill -9 "${service_pids}" || :
    }
    #
    # Stop / restart the services
    #
    if [ x"${request}" != x"start" ]
    then
	local service
	for service in /etc/la-container/services/*.service
	do service "${request:-stop}" "${service}"
	done
    fi
    #
    # Start the services.
    #
    : ====================================================================
    if [ x"${request}" != x"stop" -a  x"${request}" != x"statusboard" ]
    then
	local service
	for service in /etc/la-container/services/*.service
	do service start "${service}"
	done
    fi
    #
    # Did we do something?
    #
    [ -z "${service_name}" -o -z "${service_seen}" ] || {
	echo 1>&2 "${ME##*/} ${action}: service ${service_name} ${service_seen}."
	return 1
    }
}


#
# la-container.sh snakeoil OUTPUT-DIR HOST-A [HOST-B ...]
# =======================================================
#
# Write a self signed X509 certificate and key for the supplied hosts
# to the OUTPUT_DIR.  Wild cards and IP addresses are accepted.
#
la_container_snakeoil()
{
    local -
    set -o errexit -o noclobber -o nounset
    local action="${1}"
    [ -n "$(which "faketime")" ] || {
	echo 1>&2 "${ME##*/} ${1}: please install the debian package faketime."
	return 1
    }
    action="${1:-}"
    [ $# -ge 3 -a -x"${1:-}" != x'--help' ] || {
	echo 1>&2 "usage: ${ME##*/} ${action} OUTPUT-DIRECTORY fqdn ..."
	return 1
    }
    shift
    output_dir="${1}"
    [ -d "${output_dir}" ] || {
	echo 1>&2 "${ME##*/} ${action} '${output_dir}' is not a directory."
	return 1
    }
    shift
    local temp_dir="$(
	mktemp --directory --tmpdir "${ME##*/}-${action}-XXXXXXX.conf")"
    trap "rm --force --recursive '${temp_dir}'" 0 1 2 15
    #
    # The openssl config file we use.
    #
    dd status=none of="${temp_dir}/openssl.conf" <<-===
	[ req ]
	attributes		= my_attributes
	default_bits		= 2048
	default_md		= sha256
	distinguished_name	= my_distinguished_name
	prompt			= no

	[ my_distinguished_name ]
	countryName		= AU
	stateOrProvinceName	= ${ME##*/}
	localityName		= ${ME##*/}
	organizationName	= ${ME##*/}
	organizationalUnitName	= "Do not trust this ceritificate. Do NOT install it. Run away"
	commonName		= ${1}
	emailAddress		= no-one-is-listening@not-to-be.trusted.com

	[ my_attributes ]
	unstructuredName	= "A potentially very evil person"

	[ my_ca_extensions ]
	basicConstraints	= CA:true,pathlen:0
	certificatePolicies	= ia5org,2.5.29.32.0,@my_ca_policies
	extendedKeyUsage	= clientAuth,codeSigning,emailProtection,ipsecIKE,msCodeCom,msCodeInd,msCTLSign,msEFS,OCSPSigning,serverAuth,timeStamping
	keyUsage		= cRLSign,dataEncipherment,digitalSignature,keyAgreement,keyCertSign,keyEncipherment,nonRepudiation
	nsCertType		= objsign
	subjectKeyIdentifier	= hash

	[my_sign_extensions]
	authorityKeyIdentifier	= keyid:always,issuer:always
	basicConstraints	= CA:true,pathlen:0
	certificatePolicies	= ia5org,2.5.29.32.0,@my_cert_policies
	extendedKeyUsage	= clientAuth,codeSigning,emailProtection,ipsecIKE,msCodeCom,msCodeInd,msCTLSign,msEFS,OCSPSigning,serverAuth,timeStamping
	keyUsage		= cRLSign,dataEncipherment,digitalSignature,keyAgreement,keyCertSign,keyEncipherment,nonRepudiation
	nsCertType		= objsign
	subjectAltName		= @my_subjectAltName
	subjectKeyIdentifier	= hash

	[my_req_extensions]
	basicConstraints	= CA:true,pathlen:0
	certificatePolicies	= ia5org,2.5.29.32.0,@my_cert_policies
	extendedKeyUsage	= clientAuth,codeSigning,emailProtection,ipsecIKE,msCodeCom,msCodeInd,msCTLSign,msEFS,OCSPSigning,serverAuth,timeStamping
	keyUsage		= cRLSign,dataEncipherment,digitalSignature,keyAgreement,keyCertSign,keyEncipherment,nonRepudiation
	nsCertType		= objsign
	subjectAltName		= @my_subjectAltName
	subjectKeyIdentifier	= hash

	[my_ca_policies]
	policyIdentifier	= 2.5.29.32.0
	CPS.1			= "http://${1}/"
	userNotice.1		= @my_ca_user_notice

	[my_ca_user_notice]
	explicitText		= "Installing this certificate will stop your browser from issuing annoying warnings.  It should also be safe provided you ensure the private key never leaves your laptop.  Or, if it does leave your laptop, you never use the internet again."

	[my_cert_policies]
	policyIdentifier	= 2.5.29.32.0
	CPS.1			= "http://${1}/"
	userNotice.1		= @my_cert_user_notice

	[my_cert_user_notice]
	explicitText		= "This certificate is not secure.  If you see this certificate on a live site its owners need a good spanking, and you have been chosen to deliver it.  If the noise attracts the constabulary's attention show them this notice.  They will understand."

	[my_subjectAltName]
	DNS.1			= localhost
	DNS.2			= localhost.localdomain
	IP.1			= 127.0.0.1
	IP.2			= 172.17.0.2
	IP.3			= 172.17.0.3
	IP.4			= 172.17.0.4
	IP.5			= 172.17.0.5
	IP.6			= ::1
	$(
	    d=3; i=7
	    for fqdn do
		case "${fqdn}" in
		    [0-9]*.[0-9]*.[0-9]*.[0-9]*|*::*)
			printf 'IP.%s			= %s\n' "${i}" "${fqdn}"
			i="$((${i} + 1))" ;;
		    *)
			printf 'DNS.%s			= %s\n' "${d}" "${fqdn}"
			d="$((${d} + 1))" ;;
		esac
	    done
	)
	===
    #
    # Do we need to generate a CA Cert?
    #
    [ -s "${output_dir}/ca-cert.pem" -a -s "${output_dir}/ca-privkey.pem" ] || {
	LD_PRELOAD=/usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1 \
	    FAKETIME="@1970-01-01 00:00:00" TZ=UTC \
	    openssl req -newkey rsa -nodes -config "${temp_dir}/openssl.conf" \
		-x509 -days 24855 -rand "${output_dir}/.rnd" \
		-extensions my_ca_extensions -out "${temp_dir}/ca-cert.pem" \
		-keyout "${temp_dir}/ca-privkey.pem"
	mv "${temp_dir}/ca-cert.pem" "${output_dir}/."
	mv "${temp_dir}/ca-privkey.pem" "${output_dir}/."
    }
    #
    # Generate the real cert.
    #
    openssl req -newkey rsa -nodes -config "${temp_dir}/openssl.conf" \
	-rand "${output_dir}/.rnd" -reqexts my_req_extensions \
	-keyout "${temp_dir}/privkey.pem" -out "${temp_dir}/req.pem"
    LD_PRELOAD=/usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1 \
	FAKETIME="@1970-01-01 00:00:00" TZ=UTC \
	openssl </dev/null x509 -req -days 24855 \
	-in "${temp_dir}/req.pem" -out "${temp_dir}/cert.pem" \
	-extfile "${temp_dir}/openssl.conf" -days 24855 \
	-extensions my_sign_extensions -CAcreateserial \
	-CA "${output_dir}/ca-cert.pem" -CAkey "${output_dir}/ca-privkey.pem"
    #
    # The hairy phase is over, move the results to the output directory
    # emulating letsencrypt's filenames.
    #
    serial="$(
	openssl x509 -in "${temp_dir}/cert.pem" -noout -text |
	sed -n '/^ *Serial Number:$/{x;d};x;/^ *Serial Number:$/!d;x;s/[: ]//gp;q')"
    rm --force \
	"${output_dir}/cert.pem" "${output_dir}/privkey.pem" \
	"${output_dir}/fullchain.pem" "${output_dir}/chain.pem"
    mv "${temp_dir}/cert.pem" "${output_dir}/cert-${serial}.pem"
    mv "${temp_dir}/privkey.pem" "${output_dir}/privkey-${serial}.pem"
    cat >"${output_dir}/fullchain-${serial}.pem" \
	"${output_dir}/cert-${serial}.pem" "${output_dir}/ca-cert.pem"
    ln --symbolic "cert-${serial}.pem" "${output_dir}/cert.pem"
    ln --symbolic "fullchain-${serial}.pem" "${output_dir}/fullchain.pem"
    ln --symbolic "privkey-${serial}.pem" "${output_dir}/privkey.pem"
    ln --symbolic "ca-cert.pem" "${output_dir}/chain.pem"
    #
    # Simples!  Why everyone has so much trouble with something soooo
    # straight forward is beyond me. :D
    #
    rm --force --recursive "${temp_dir}"
    trap - 0 1 2 15
}


#
# la-container.sh status [--help] WHAT ok|fail|purge MESSAGE...
# =============================================================
#
# Add a line to the status board file.
#
la_container_statusboard()
{
    local -
    set -o errexit -o noclobber -o nounset
    local action="${1}"
    shift
    [ $# -ge 2 -a x"${2:-}" != x"--help" ] || {
	echo 1>&2 "usage: ${ME##*/} ${action} [--help] WHAT ok|fail|purge MESSAGE..."
	return 1
    }
    local what="${1}"
    local status="${2}"
    shift 2
    case "${status}" in
	fail|ok|purge) ;;
	*)
	    echo 1>&2 "usage: ${ME##*/} ${action} [--help] WHAT ok|fail|purge MESSAGE..."
	    return 1;;
    esac
    local statusboard="/data/var/lib/la-container/www/_la-container_/statusboard.txt"
    local temp="${statusboard%/_la-container_/*}/statusboard.txt.tmp"
    local lock=la-container-statusboard
    la_container lockfile wait "${lock}" "$$"
    mkdir --parents "${statusboard%/*}"
    >>"${statusboard}"
    #
    # Do this in a temporary file so if it all goes wrong we don't care.
    #
    local what_regexp="$(printf "%s" "${what}" | sed 's/[][\\\/*.^$]/\\&/g')"
    if [ x"${status}" = x"purge" ]
    then sed "/^${what_regexp} /d" "${statusboard}" >|"${temp}"
    else
	local count=$(
	    sed --quiet \
		"s;^${what_regexp} ${status} [^ ]\+ \([0-9]\+\)\; .*;\1;p;T;q" \
		"${statusboard}")
	if [ -z "${count}" ]
	then count=1
	else count=$((${count} + 1))
	fi
	(
	    printf "%s %s %s %s; %s\n" "${what}" "${status}" \
		$(date --utc '+%Y-%m-%d:%H:%M:%SZ') ${count} "$*"
	    sed "/^${what_regexp} ${status} /d" "${statusboard}"
	)>|"${temp}"
    fi
    mv "${temp}" "${statusboard}"
    la_container lockfile unlock "${lock}" "$$"
}

#
# Shell eval the passed command, returning the last characters of its output
# (ie stdout + stderr) with newlines translated to space and with 'ok' or
# 'fail' appended depending on its exit status, passing through an unmodified
# copy of stdout to fd 8 and an unmodified copy of stderr to fd 9.
#
statusboard_eval()
{
    local capture_len="${1}"
    shift
    ((((eval $*) && echo ok 1>&7 || echo fail 1>&7) 2>&1 1>&6 |
	tee --append /dev/fd/8 1>&7) 6>&1 | tee --append /dev/fd/9) 7>&1 |
	sed 'H;x;s/\n/ /g;$q;s/.\{'"${capture_len}"'\}$/&/;s/.*//;x;d'
}

#
# la-container.sh timer-when [--help] TIMER-NAME [AFTER]
# ======================================================
#
# Write the unix time a timer should next run to stdout.
#
#   TIMER-NAME	The name of a timer in /etc/la-container/timers, or a timer
#		file.
#
#   AFTER	Return the next time a timer should run after this unix time.
#		Defaults to now.
#
la_container_timer_when()
{
    local -
    set -o errexit -o noclobber -o nounset
    local action="${1}"
    [ $# -ge 2 -a x"${2:-}" != x"--help" ] || {
	echo 1>&2 "usage: ${ME##*/} ${action} TIMER-NAME [AFTER]"
	return 1
    }
    local timer_name="${2}"
    local timer_file="${timer_name%.timer}.timer"
    [ x"${timer_file##*/}" != x"${timer_file}" ] ||
	local timer_file="/etc/la-container/timers/${timer_file}"
    [ -f "${timer_file}" ] || {
	echo 1>&2 "${ME##*/} ${action}: Can't find timer ${timer_name}."
	exit 1
    }
    local after="${3:-}"
    [ -n "${after}" ] || after="$(date +%s)"
    #
    # Parse the settings in the timer file.
    #
    local settings="$(
	(
	    sed '/^[[:space:]]*$/q' "${timer_file}"
	    echo echo
	    echo 'echo :: TIMES=${TIMER_TIMES:-} DAYS=${TIMER_DAYS:-} MONTHDAYS=${TIMER_MONTHDAYS:-}'
	) | $(sub_shell) |
	sed --quiet '/^:: TIMES=[^ ]* DAYS=[^ ]* MONTHDAYS=[^ ]*$/p')"
    local settings="${settings#:: TIMES=}"
    local timer_times="$(
	printf "%s" "${settings%% *}" | tr ',' '\n' |
	grep -v '^[[:space:]]*$' | sort | tr '\n' ' ')"
    [ -n "${timer_times}" ] || return 0
    [ x"${timer_times% }" != x"*" ] || {
	printf "*"
	return 0
    }
    local settings="${settings##* DAYS=}"
    local timer_days="${settings%% *}"
    [ -n "${timer_days}" ] || timer_days="mo,tu,we,th,fr,sa,su"
    local timer_days="$(
	printf "%s" "${timer_days}" |
	sed --expression 's/[Mm][Oo][^,]*,*/1/' \
	    --expression 's/[Tt][Uu][^,]*,*/2/' \
	    --expression 's/[Ww][Ee][^,]*,*/3/' \
	    --expression 's/[Tt][Hh][^,]*,*/4/' \
	    --expression 's/[Ff][Rr][^,]*,*/5/' \
	    --expression 's/[Ss][Aa][^,]*,*/6/' \
	    --expression 's/[Ss][Uu][^,]*,*/7/')"
    settings="${settings##* MONTHDAYS=}"
    local timer_monthdays="${settings%% *}"
    [ -n "${timer_monthdays}" ] ||
	timer_monthdays="01,02,03,04,05,05,06,07,08,09,10,11,12,13,14,15,15,16,17,18,19,20,21,22,23,24,25,25,26,27,28,29,30,31"
    #
    # Advance the time by a day until we find a time that matches
    # TIMER_DAYS and TIMER_MONTHDAYS.
    #
    time="${after}"
    while :
    do
	local monthday_weekday="$(date --date=@${time} +"%u:%d")"
	local timer_weekday="${timer_days}:,${timer_monthdays},"
	case "${timer_weekday}" in
	    *${monthday_weekday%:*}*:*,${monthday_weekday#*:},*)
		for timer_time in ${timer_times}
		do
		    local when="%Y-%m-%dT${timer_time}:00"
		    local next_time="$(date --date=@${time} +"${when}")"
		    local next_time="$(date --date="${next_time}" +%s)"
		    [ "${next_time}" -le "${now}" ] || {
			printf "%s" "${next_time}"
			return 0
		    }
		done
	esac
	time="$((24 * 3600 + ${time}))"
    done
}

#
# Our entry point.
#
la_container()
{
    case "${1:-}" in
	--help|--manual)
	    expand < "${ME}" |
		sed --quiet '1,2d;s/^# \?//p;/^ *(c) 20.. Russell Stuart /q' |
		less
	    return 0;;
	boot|dump)
	    egrep --silent '^[0-9]+:[^:]*:/docker/' /proc/self/cgroup || {
		echo 1>&2 "${ME##*/} ${1}: I must be run in the docker container."
		return 1
	    }
	    eval $(printf "'%s' " "application_${1}" "$@")
	    return 0 ;;
	backup|backup-dump|backup-period|backup-site|init|is-live|lockfile|run-timer|service|statusboard|timer-when)
	    egrep --silent '^[0-9]+:[^:]*:/docker/' /proc/self/cgroup || {
		echo 1>&2 "${ME##*/} ${1}: I must be run in the docker container."
		return 1
	    }
	    eval $(printf "'%s' " "la_container_$(echo ${1} | tr '-' '_')" "$@")
	    return 0 ;;
	apt-get-install)
	    #
	    # This is should be run in the container's root file system,
	    # but it's typically very early so it's in a chroot,
	    # not in the docker container.
	    #
	    eval $(printf "'%s' " "la_container_$(echo ${1} | tr '-' '_')" "$@")
	    return 0 ;;
	build|build-fakechroot|built-options|restore|snakeoil)
	    #
	    # They are probably missing dependencies.
	    #
	    for dependency in \
		docker:docker.io duplicity debootstrap fakechroot fakeroot openssl
	    do
		[ -n "$(which "${dependency%:*}")" ] || {
		    echo 1>&2 "${ME##*/} ${1}: please install the debian package ${dependency#*:}."
		    return 1
		}
	    done
	    eval $(printf "'%s' " "la_container_$(echo ${1} | tr '-' '_')" "$@")
	    return 0 ;;
    esac
    #
    # Subtly tell 'im there's a PEBKAC problem.
    #
    echo 1>&2 "usage: ${ME##*/} --help|--manual"
    echo 1>&2 "       ${ME##*/} apt-get-install PACKAGE..."
    echo 1>&2 "       ${ME##*/} backup [--no-live-check] [BACKUP_URL [--DUPLICITY-OPT]]"
    echo 1>&2 "       ${ME##*/} boot [DUMP.DIR]"
    echo 1>&2 "       ${ME##*/} build [--mirror=MIRROR] [--suite=SUITE]"
    echo 1>&2 "       ${ME##*/} build-options [--mirror=MIRROR] [--suite=SUITE]"
    echo 1>&2 "       ${ME##*/} dump [DUMP.DIR]"
    echo 1>&2 "       ${ME##*/} init"
    echo 1>&2 "       ${ME##*/} is-live HOSTNAME"
    echo 1>&2 "       ${ME##*/} lockfile lock|unlock|wait LOCKFILE [PID]"
    echo 1>&2 "       ${ME##*/} restore BACKUP_URL /DATA_DIR [--DUPLICITY-OPT...]"
    echo 1>&2 "       ${ME##*/} rotate /DATA_DIR [LOG_FILE ...]"
    echo 1>&2 "       ${ME##*/} run-timer TIMER-NAME"
    echo 1>&2 "       ${ME##*/} service restart|rotate|start|statusboard|stop [SERVICE_NAME]"
    echo 1>&2 "       ${ME##*/} snakeoil OUTPUT-DIR [*.]FQDN..."
    echo 1>&2 "       ${ME##*/} statusboard WHAT ok|fail|purge MESSAGE..."
    echo 1>&2 "       ${ME##*/} timer-when TIMER-NAME [AFTER]"
    return 1
}


#
# Entry point.
#
if [ x"${ME##*/}" = x"init.sh" -a $# = 0 ]
then la_container init
else la_container "$@"
fi

# vim: set autoindent shiftwidth=4 tabstop=8 noexpandtab spell:
