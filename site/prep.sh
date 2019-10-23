#!/bin/sh
#
#	prep.sh - Update prep repository after adding packages
#		  List prep packages
#		  Show prep package versions
#
Prg=`basename $0`

# See tree.txt for wanted and required directory tree
CfgDir=config
GpgDir=gpg
SrcDir=sources
DocDir=docroot
RepDir=$DocDir/prep
DebDir=$RepDir/debs
TmpDir=tmp
Log=update.log

Usage()
{
    echo "Usage: $Prg [ update | list | ver [ <package> ] ]" >&2
    exit 1
}

test "$1" = 'update' -o "$1" = 'list' -o "$1" = 'ver' || Usage

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

if [ "$1" = 'list' -o "$1" = 'ver' ]; then
    if ! [ -d $DebDir/any/all ]; then
	echo "$Prg: no prep files yet (run $Prg update)" >&2
	exit 4
    fi
fi
# Count single-hardlink sources for list and update
DebCmd="find -L $SrcDir -type f -name '*.deb' -links 1"
NewDeb=`eval $DebCmd | wc -l`

#
#   list
#
if [ "$1" = 'list' ]; then
    find $DebDir -type f -name '*.deb' -links 2 | sed 's;.*/;;' | sort
    test $NewDeb -gt 0 && echo "$Prg: also found $NewDeb unprocessed source package(s) (new or obsolete)" >&2
    exit 0
fi
#
#   ver
#	TmpDir files: deblist, deblook
#
mkdir -p $TmpDir
if [ "$1" = 'ver' ]; then
    find $DebDir -type f -name '*.deb' | sed "s;$DebDir/;;" | sort >$TmpDir/deblist
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
#   update
#	TmpDir files: deblist
#
# Before any work, make sure we have a signing key (same code as in update.sh)
Mail="`sed -n 's/^Name-Email: //p' $GpgDir/key.conf`"
Sign=`gpg -k --with-colons $Mail | awk -F: '$1 == "sub" {print substr($5,9)}'`
if [ -z "$Sign" ]; then
    echo "$Prg: no signing key available" >&2
    echo "\t did you run a 'sudo -u `id -nu` gpg --import $GpgDir/signing.gpg' ?" >&2
    exit 2
fi

# First, add single-hardlink packages from $SrcDir
exec 2>>$Log
nbAdd=0
if [ $NewDeb -gt 0 ]; then
    date "+---- %Y-%m-%d %H:%M:%S - prep --------------------------------------------" >&2
    eval $DebCmd >$TmpDir/deblist
    while read deb
    do
	# Check if our $deb is still there (Travis handling as of oct 2019)
	if ! [ -s "$deb" ]; then
	    echo "\aCannot find previously existing $deb - Aborting" | tee -a $Log
	    echo "\t File may have been suppressed during run, please try again"
	    exit 5
	fi
	# We want to create the link from the actual package info, not from the deb filename
	# Only dpkg-deb -f without tag returns package names unchanged (e.g.: in uppercase)
	# The sed command below assumes (reasonably so) that the tag values do not contain spaces
	eval `dpkg-deb -f $deb | sed -n -e 's/Package: /Name=/p' -e 's/Version: /Vers=/p' -e 's/Architecture: /Arch=/p' | tr '\n' ' '`
	eval `stat -c 'Size=%s sDev=%D' $deb`
	#echo "File=`basename $deb` sDev=$sDev Size=$Size Name=$Name Vers=$Vers Arch=$Arch"

	# Skip amd64 packages declared as obsolete
	if [ $Arch = 'amd64' ]; then	# For performance
	    skip=
	    while read RegExp rest
	    do
		expr "$RegExp" : '#' >/dev/null && continue	# allow comments
		echo "$Name" | grep "^$RegExp" >/dev/null && { skip=y; break; }
	    done <$CfgDir/obsolete
	    if [ "$skip" ]; then
		echo "Skipping obsolete package '$deb'" >&2
		continue
	    fi
	fi

	# Make $ArchDir if needed and check its filesystem
	DebVer=`expr "$Vers" : '.*+\(deb[1-9][0-9]*\)$'` || DebVer='any'
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
	    eval `stat -c 'pkSz=%s nbLk=%h iNum=%i' $ArchDir/$Pkg`
	    # Does it already exist as other inode in $SrcDir ?
	    prev=; test "$nbLk" -gt 1 && prev=`find $SrcDir -inum $iNum`
	    # Are files identical ? For performance, only cmp if sizes are =
	    same=; test "$Size" -eq "$pkSz" && cmp $deb $ArchDir/$Pkg >/dev/null && same=y
	    if [ "$same" ]; then
		test "$nbLk" -gt 1 && what="link (iNum=$iNum)" || what='file'
		echo "Removing stale $what $ArchDir/$Pkg identical to $deb" >&2
		rm $ArchDir/$Pkg
	    elif [ "$prev" ]; then
	    	# No: other source with same internal name ??
		echo "\aPackage $deb has same name $Pkg as $prev - Aborting" | tee -a $Log
		exit 6
	    else
		echo "Skipping $deb (sz=$Size) as $ArchDir/$Pkg already exists (sz=$pkSz)" | tee -a $Log
		continue
	    fi
	fi

	# Link new package to prep/
	test $nbAdd -eq 0 && echo "Adding files to $RepDir ..."
	ln $deb $ArchDir/$Pkg
	test "`basename $deb`" = "$Pkg" || echo "Linked `expr $deb : "$SrcDir/\(.*\)"` as $DebVer/$Arch/$Pkg" >&2
	nbAdd=`expr $nbAdd + 1`
    done <$TmpDir/deblist
    rm $TmpDir/deblist
fi
(test $nbAdd -eq 0 && echo "No new packages found." || echo "$nbAdd packages added.") | tee -a $Log

# Then, remove any prod .debs whose source was deleted
#	TmpDir files: prodprep
if [ -d $DocDir/prod/debs ]; then
    find $DocDir/prod/debs -type f -name '*.deb' -links -3 >$TmpDir/prodprep
    if [ -s $TmpDir/prodprep ]; then
	nbDel=`wc -l <$TmpDir/prodprep`
	echo "Removing $nbDel stale production packages whose source has been deleted"
	xargs rm -v <$TmpDir/prodprep | sed 's/^r/R/' >&2
	echo "Updating $DocDir/prod ..."
	./update.sh $DocDir/prod
    fi
    rm $TmpDir/prodprep
fi

# Last, remove now prep .debs whose source was deleted
#	TmpDir files: preponly
#   We don't keep the previoud possible nbDel as it was of prod packages, not prep
nbDel=0
find $DebDir -type f -name '*.deb' -links -2 >$TmpDir/preponly
if [ -s $TmpDir/preponly ]; then
    nbDel=`wc -l <$TmpDir/preponly`
    echo "Removing $nbDel stale pre-prod packages whose source has been deleted"
    xargs rm -v <$TmpDir/preponly | sed 's/^r/R/' >&2
fi
rm $TmpDir/preponly

test $nbAdd -gt 0 -o $nbDel -gt 0 && exec ./update.sh $RepDir
