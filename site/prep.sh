#!/bin/sh
#
#	prep.sh - Update prep repository after adding packages
#		  List prep packages
#		  Show prep package versions
#
Prg=`basename $0`

# See tree.txt for wanted and required directory tree
CfgDir='config'
GpgDir='gpg'
SrcDir='sources'
DocDir='docroot'
ProDir='prod'
PrpDir="$DocDir/prep"
DebDir="$PrpDir/debs"
TmpDir='tmp'
Log=/var/log/epiconcept/aptv2.preprod.log	# Aka 'update.log' in README.md

Usage()
{
    echo "Usage: $Prg update | ver [ <package> ] | list [ <filter> ] | ls [ <filter> ]" >&2
    exit 1
}

now()
{
    # Timestamps: just comment-out next line to remove them
    date '+[%Y-%m-%d %H:%M:%S] '
}

#
#   initial checks -----------------------------------------------------
#
test "$1" = 'update' -o "$1" = 'ver' -o "$1" = 'list' -o "$1" = 'ls' || Usage

#   We want our paths relative, so move to our top directory
if ! [ -f $CfgDir/obsolete -a -x update.sh ]; then
    cd `dirname $0`
    if ! [ -f $CfgDir/obsolete -a -x update.sh ]; then
	echo "$Prg: cannot find '$CfgDir/obsolete' file and 'update.sh' script" >&2
	exit 2
    fi
fi
if ! [ -d $SrcDir ]; then
    echo "$Prg: you must first create and populate a '$SrcDir' directory" >&2
    exit 3
fi

if [ "$1" = 'list' -o "$1" = 'ls' -o "$1" = 'ver' ]; then
    if ! [ -d $DebDir/any/all ]; then
	echo "$Prg: no prep files yet (run $Prg update)" >&2
	exit 4
    fi
fi
# Count single-hardlink sources for list and update
DebCmd="find -L $SrcDir -type f -name '*.deb' -links 1"
NewDeb=`eval $DebCmd | wc -l`

#
#   list or ls ---------------------------------------------------------
#
if [ "$1" = 'list' -o "$1" = 'ls' ]; then
    test "$1" = 'list' && OptLnk='-links 2'
    if [ "$2" ]; then
	find -L $DebDir -type f -name '*.deb' $OptLnk | sed 's;.*/;;' | sort | egrep "$2"
    else
	find -L $DebDir -type f -name '*.deb' $OptLnk | sed 's;.*/;;' | sort
    fi
    test "$1" = 'list' -a $NewDeb -gt 0 && echo "$Prg: also found $NewDeb unprocessed source package(s) (new or obsolete)" >&2
    exit 0
fi
#
#   ver ----------------------------------------------------------------
#	TmpDir files: deblist, deblook
#
mkdir -p $TmpDir
if [ "$1" = 'ver' ]; then
    find -L $DebDir -type f -name '*.deb' | sed "s;$DebDir/;;" | sort >$TmpDir/deblist
    if [ "$2" ]; then	# package name given: display all versions
	expr "$2" : '.*/' >/dev/null && key="^$2" || key="/$2"
	expr "$2" : '.*_' >/dev/null || key="${key}_"
	grep "$key" $TmpDir/deblist | sed 's;.*/;;'
    else		# display all packages names that have multiple versions
	awk -F_ '{print $1}' $TmpDir/deblist | sort >$TmpDir/deblook
	sort -u $TmpDir/deblook | diff $TmpDir/deblook - | sed -n 's/^< //p' | sed 's;.*/;;'
	rm $TmpDir/deblook
    fi
    rm $TmpDir/deblist
    exit 0
fi

#
#   update -------------------------------------------------------------
#	TmpDir files: newdebs, prodprep, preponly
#
#   Before any work, make sure we have a signing key (same code as in update.sh)
Mail="`sed -n 's/^Name-Email: //p' $GpgDir/key.conf`"
Sign=`gpg -k --with-colons $Mail | awk -F: '$1 == "sub" {print substr($5,9)}'`
if [ -z "$Sign" ]; then
    echo "$Prg: no signing key available" >&2
    echo "\t did you run a 'sudo -u `id -nu` gpg --import $GpgDir/signing.gpg' ?" >&2
    exit 2
fi

exec 2>>$Log	# All stderr from now on goes to log
nbAdd=0
# First, add single-hardlink packages from $SrcDir
if [ $NewDeb -gt 0 ]; then
    echo "$(now)Link new packages to prep/" >&2
    date "+---- %Y-%m-%d %H:%M:%S - prep --------------------------------------------" >&2
    eval $DebCmd >$TmpDir/newdebs
    while read deb
    do
	# Check if our $deb is still there (Travis handling as of oct 2019)
	test -s "$deb" || {
	    echo "\aCannot find previously existing $deb - Aborting" | tee -a $Log
	    echo "\t File may have been suppressed during run, please try again"
	    exit 5
	}
	# We want to create the link from the actual package info, not from the deb filename
	# Only dpkg-deb -f without tag returns package names unchanged (e.g.: in uppercase)
	# The sed command below assumes (reasonably so) that the tag values do not contain spaces
	eval `dpkg-deb -f $deb | sed -n -e 's/Package: /Name=/p' -e 's/Version: /Vers=/p' -e 's/Architecture: /Arch=/p' | tr '\n' ' '`
	eval `stat -c 'Size=%s sDev=%D' $deb`
	File=`basename $deb`
	echo "$(now)File=$File Size=$Size Name=$Name Vers=$Vers Arch=$Arch" >&2

	# Skip amd64 packages declared as obsolete
	if [ $Arch = 'amd64' ]; then	# For performance
	    skip=
	    while read RegExp rest
	    do
		expr "$RegExp" : '#' >/dev/null && continue	# allow comments
		echo "$Name" | grep "^$RegExp" >/dev/null && { skip=y; break; }
	    done <$CfgDir/obsolete
	    if [ "$skip" ]; then
                echo "$(now)Skipping obsolete package '$File'" >&2
		continue
	    fi
	fi

	# Make $ArchDir if needed and check its filesystem
	DebVer=`expr "$Vers" : '.*[+~]\(deb[1-9][0-9]*\)$'` || DebVer='any'
	ArchDir=$DebDir/$DebVer/$Arch
	mkdir -p $ArchDir
	if [ "$sDev" != "`stat -c '%D' $ArchDir`" ]; then
	    echo "\aSource $deb and prep $ArchDir/ are on != filesystems - Aborting" | tee -a $Log
	    exit 6
	fi

	# Check if our link target already exists (it should not)
	Pkg=${Name}_${Vers}_$Arch.deb
	if [ -f $ArchDir/$Pkg ]; then
	    # Yes, find more about it
	    eval `stat -c 'prSz=%s nbLk=%h iNum=%i' $ArchDir/$Pkg`

	    # Does it already exist as other inode(s) in $SrcDir ?
	    prev=
	    test "$nbLk" -gt 1 && prev=`find -L $SrcDir -xdev -inum $iNum`

	    # Are files identical ? For performance, only cmp if sizes are =
	    same=
	    test "$Size" -eq "$prSz" && cmp $deb $ArchDir/$Pkg >/dev/null && same=y

	    if [ "$same" ]; then
		# Yes: remove $ArchDir/$Pkg
		test "$nbLk" -gt 1 && what="link (iNum=$iNum)" || what='file'
		echo "Removing stale $what $ArchDir/$Pkg identical to $deb" >&2
		rm $ArchDir/$Pkg
	    elif [ "$prev" ]; then
	    	# No: other source with same internal name ??
		echo "\aPackage $deb has same name $Pkg as inum $(echo "$prev" | tr '\n' ',') - Aborting" | tee -a $Log
		exit 6
	    else
		echo "$(now)Package $deb (sz=$Size) already added from `dirname $prev` (sz=$prSz)" >&2
	    fi
	    continue
	fi

	# Link the new package to prep/
	test $nbAdd -eq 0 && echo "$(now)Adding files to $PrpDir ..." >&2
	ln "$deb" "$ArchDir/$Pkg"
	test $File = $Pkg || echo "$(now)Linked `expr $deb : "$SrcDir/\(.*\)"` as $DebVer/$Arch/$Pkg" >&2
	nbAdd=`expr $nbAdd + 1`
    done <$TmpDir/newdebs
    rm $TmpDir/newdebs
fi
if [ $nbAdd -eq 0 ]; then
    echo "$(now)No new packages found." | tee -a $Log
else
    echo "$(now)$nbAdd packages added." | tee -a $Log
fi

# Then, remove any prod .debs whose source was deleted
#	TmpDir files: prodprep
for Dir in $DocDir/$ProDir*
do
    test -d "$Dir/debs" || break	# Allow no $ProDir at all
    # TODO: check -3 next line
    find -L "$Dir/debs" -type f -name '*.deb' -links -3 >$TmpDir/prodprep
    if [ -s $TmpDir/prodprep ]; then
	nbDel=`wc -l <$TmpDir/prodprep`
	echo "$(now)Removing $nbDel stale production packages whose source has been deleted" >&2
	xargs rm -v <$TmpDir/prodprep | sed 's/^r/R/' >&2
	echo "$(now)Updating $(dirname $Dir) ..." >&2
	./update.sh $Dir
    fi
    rm $TmpDir/prodprep
done

#   Then remove any stale prep packages whose source has been deleted
#   We can re-use the previous possible nbDel as it was for prod packages, not prep
nbDel=0
find -L $DebDir -type f -name '*.deb' -links -2 >$TmpDir/preponly
if [ -s $TmpDir/preponly ]; then
    nbDel=`wc -l <$TmpDir/preponly`
    echo "$(now)Removing $nbDel stale pre-prod packages whose source has been deleted" >&2
    xargs rm -v <$TmpDir/preponly | sed 's/^r/R/' >&2
fi
rm $TmpDir/preponly

#   And finally, run update.sh on our prep dir
echo "$(now)update.sh $PrpDir" >&2
test $nbAdd -gt 0 -o $nbDel -gt 0 && exec ./update.sh $PrpDir
echo "$(now)update.sh $PrpDir ended" >&2
