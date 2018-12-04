#!/bin/sh
#
#	prep.sh - Update prep repository after adding packages
#		  List prep packages
#		  Show prep package versions
#
Prg=`basename $0`

# See tree.txt for wanted and required directory tree
CfgDir=config
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

#   Paths are relative, so move to our top directory
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
# For list and update
DebCmd="find $SrcDir -type f -name '*.deb' -links 1"
NewDeb=`eval $DebCmd | wc -l`

#
#   list
#
if [ "$1" = 'list' ]; then
    find $DebDir -type f -name '*.deb' -links 2 | sed 's;.*/;;' | sort
    test $NewDeb -gt 0 && echo "$Prg: also found $NewDeb unprocessed source package(s) (new or obsolete)" >&2
    exit 0
#
#   ver
#
elif [ "$1" = 'ver' ]; then
    find $DebDir -type f -name '*.deb' | sed "s;$DebDir/;;" | sort >$TmpDir/deblist
    if [ "$2" ]; then
	expr "$2" : '.*/' >/dev/null && key="^$2" || key="/$2"
	expr "$2" : '.*_' >/dev/null || key="${key}_"
	grep "$key" $TmpDir/deblist | sed 's;.*/;;'
    else	# display all packages names that have multiple versions
	awk -F_ '{print $1}' $TmpDir/deblist | sort >$TmpDir/deblook
	sort -u $TmpDir/deblook | diff $TmpDir/deblook - | sed -n 's/^< //p' | sed 's;.*/;;'
	rm $TmpDir/deblook
    fi
    rm $TmpDir/deblist
    exit 0
fi

#
#   update
#
exec 2>>$Log
nbAdd=0
if [ $NewDeb -gt 0 ]; then
    # Link new packages to prep/
    mkdir -p $TmpDir
    date "+---- %Y-%m-%d %H:%M:%S - prep --------------------------------------------" >&2
    eval $DebCmd >$TmpDir/deblist
    while read deb
    do
	File=`basename $deb`
	eval `stat -c 'Size=%s' $deb`
	# Only dpkg-deb -f without tag returns package names unchanged (e.g.: in uppercase)
	# The sed command below assumes (reasonably so) that the tag values do not contain spaces
	eval `dpkg-deb -f $deb | sed -n -e 's/Package: /Name=/p' -e 's/Version: /Vers=/p' -e 's/Architecture: /Arch=/p' | tr '\n' ' '`
	#echo "File=$File Size=$Size Name=$Name Vers=$Vers Arch=$Arch"
	if [ $Arch = 'amd64' ]; then
	    skip=
	    while read RegExp rest
	    do
		expr "$RegExp" : '#' >/dev/null && continue	# allow comments
		echo "$Name" | grep "^$RegExp" >/dev/null && { skip=y; break; }
	    done <$CfgDir/obsolete
	    if [ "$skip" ]; then
		echo "Skipping obsolete package '$File'" >&2
		continue
	    fi
	fi
	DebVer=`expr "$Vers" : '.*+\(deb[1-9][0-9]*\)$'` || DebVer='any'
	ArchDir=$DebDir/$DebVer/$Arch
	Pkg=${Name}_${Vers}_$Arch.deb
	if [ -f $ArchDir/$Pkg ]; then
	    eval `stat -c 'iNum=%i PrSz=%s' $ArchDir/$Pkg`
	    prev=`find $SrcDir -inum $iNum`
	    if cmp $deb $prev >/dev/null; then
		echo "Skipping package $deb already added from `dirname $prev`" >&2
	    else
		echo "Package $deb (sz=$Size) already added from `dirname $prev` (sz=$PrSz)" >&2
	    fi
	    continue
	fi
	test $File = $Pkg || echo "Linked `expr $deb : "$SrcDir/\(.*\)"` as $DebVer/$Arch/$Pkg" >&2
	mkdir -p $ArchDir
	test $nbAdd -eq 0 && echo "Adding files to $RepDir ..."
	ln $deb $ArchDir/$Pkg
	nbAdd=`expr $nbAdd + 1`
    done <$TmpDir/deblist
    rm $TmpDir/deblist
fi
(test $nbAdd -eq 0 && echo "No new packages found." || echo "$nbAdd packages added.") | tee -a $Log

#   Remove .debs whose source was deleted
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
#   We don't keep our possible nbDel as it was production packages, not ours
nbDel=0
find $DebDir -type f -name '*.deb' -links -2 >$TmpDir/preponly
if [ -s $TmpDir/preponly ]; then
    nbDel=`wc -l <$TmpDir/preponly`
    echo "Removing $nbDel stale pre-prod packages whose source has been deleted"
    xargs rm -v <$TmpDir/preponly | sed 's/^r/R/' >&2
fi
rm $TmpDir/preponly

test $nbAdd -gt 0 -o $nbDel -gt 0 && exec ./update.sh $RepDir
