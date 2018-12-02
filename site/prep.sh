#!/bin/sh
#
#	prep.sh - Update prep repository after adding packages
#		  List prep packages
#
Prg=`basename $0`

# See tree.txt for wanted and required directory tree
SrcDir=sources
DocDir=docroot
RepDir=$DocDir/prep
DebDir=$RepDir/debs
TmpDir=tmp
Log=update.log

Usage()
{
    echo "Usage: $Prg [ update | list ]" >&2
    exit 1
}

test "$1" = 'update' -o "$1" = 'list' || Usage

#   Paths are relative, so move to our top directory
if ! [ -d $SrcDir -a -x update.sh ]; then
    cd `dirname $0`
    if ! [ -d $SrcDir ]; then
	echo "$Prg: cannot find '$SrcDir' directory and 'update.sh' script" >&2
	exit 2
    fi
fi
DebCmd="find $SrcDir -type f -name '*.deb' -links 1"
NewDeb=`eval $DebCmd | wc -l`

#
#   list
#
if [ "$1" = 'list' ]; then
    if ! [ -d $DebDir/any/all ]; then
	echo "$Prg: no prep files yet (run $Prg update)" >&2
	exit 2
    fi
    find $DebDir -type f -name '*.deb' -links 2 | sed "s;.*/;;" | sort
    test $NewDeb -gt 0 && echo "$Prg: also found $NewDeb unprocessed source package(s) (new or obsolete)" >&2
    exit 0
fi

#
#   update
#
exec 2>>$Log
if [ $NewDeb -gt 0 ]; then
    # Link new packages to prep/
    mkdir -p $TmpDir
    date "+---- %Y-%m-%d %H:%M:%S ---------------------------------------------------" >&2
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
	    case $Name in
		epi-php5-6-oauth)	skip=y ;;
		epi-php53-zmq)	skip=y ;;
		epi-php-*-7-[12])	skip=y ;;
	    esac
	    if [ "$skip" ]; then
		echo "Skipping obsolete package '$File'" >&2
		continue
	    fi
	fi
	DebVer=`expr "$Vers" : '.*+\(deb[1-9][0-9]*\)$'` || DebVer='any'
	ArchDir=$DebDir/$DebVer/$Arch
	if [ -f $ArchDir/$File ]; then
	    eval `stat -c 'iNum=%i PrSz=%s' $ArchDir/$File`
	    prev=`find $SrcDir -inum $iNum`
	    if cmp $deb $prev >/dev/null; then
		echo "Skipping package $deb already added from `dirname $prev`" >&2
	    else
		echo "Package $deb (sz=$Size) already added from `dirname $prev` (sz=$PrSz)" >&2
	    fi
	    continue
	fi
	Pkg=${Name}_${Vers}_$Arch.deb
	test $File = $Pkg || echo "Linked `expr $deb : "$SrcDir/\(.*\)"` as $DebVer/$Arch/$Pkg" >&2
	mkdir -p $ArchDir
	test "$Mod" || echo "Adding files to $RepDir ..."
	ln $deb $ArchDir/$Pkg
	Mod=y
    done <$TmpDir/deblist
    rm $TmpDir/deblist
fi
test "$Mod" || echo "No new packages found." | tee -a $Log

#   Remove .debs whose source was deleted
if [ -d $DocDir/prod/debs ]; then
    find $DocDir/prod/debs -type f -name '*.deb' -links -3 >$TmpDir/prodprep
    if [ -s $TmpDir/prodprep ]; then
	echo "Removing stale production packages whose source has been deleted"
	xargs rm -v <$TmpDir/prodprep | sed 's/^r/R/' >&2
	./update.sh $DocDir/prod
    fi
    rm $TmpDir/prodprep
fi
find $DebDir -type f -name '*.deb' -links -2 >$TmpDir/preponly
if [ -s $TmpDir/preponly ]; then
    echo "Removing stale pre-prod packages whose source has been deleted"
    xargs rm -v <$TmpDir/preponly | sed 's/^r/R/' >&2
    Mod=y
fi
rm $TmpDir/preponly

test "$Mod" && exec ./update.sh $RepDir
