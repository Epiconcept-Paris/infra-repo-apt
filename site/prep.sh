#!/bin/sh
#
#	prep.sh - Update prep repository after adding packages
#		  List prep packages
#
Prg=`basename $0`

# See tree.txt for required and wanted directory tree
SrcDir=sources
RepDir=docroot/prep
DebDir=$RepDir/debs
TmpDir=tmp

#
#   list
#
if [ "$1" = 'list' ]; then
    if ! [ -d $DebDir/any/all ]; then
	echo "$Prg: no prep files yet (run $Prg update)" >&2
	exit 2
    fi
    find $DebDir -type f -name '*.deb' -links 2 | sed "s;$DebDir/;;"
    NewDeb=`find $SrcDir -type f -name '*.deb' -links 1 | wc -l`
    test $NewDeb -gt 0 && echo "$Prg: $NewDeb new source(s) package(s) also exist (run $Prg update)" >&2
    exit 0
elif [ "$1" != 'update' ]; then
    echo "Usage: $Prg [ update | list ]" >&2
    exit 1
fi

#   Paths are relative, so move to our top directory
if ! [ -d $SrcDir -a -x update.sh ]; then
    cd `dirname $0`
    if ! [ -d $SrcDir ]; then
	echo "$Prg: cannot find '$SrcDir' directory and 'update.sh' script" >&2
	exit 2
    fi
fi

#
#   update
#
exec 2>>log
Cmd="find $SrcDir -type f -name '*.deb'"
if [ `eval $Cmd -links 1 | wc -l` -eq 0 ]; then	# Just exit if nothing to add
    echo "No new packages found."
    exit 0
fi

# Link new packages to prep/
mkdir -p $TmpDir
date "+---- %Y-%m-%d %H:%M:%S ---------------------------------------------------" >&2
eval $Cmd >$TmpDir/deblist
echo "Adding files to $RepDir ..."
while read deb
do
    File=`basename $deb`
    eval `stat -c 'Links=%h Size=%s' $deb`
    eval `dpkg-deb -W --showformat 'Name=${Package} Vers=${Version} Arch=${Architecture}' $deb`
    #echo "File=$File Size=$Size Links=$Links Name=$Name Vers=$Vers Arch=$Arch"
    if [ $Links -eq 1 -a "$Arch" = 'amd64' ]; then
	skip=
	case $Name in
	    epi-php5-6-oauth)	skip=y ;;
	    epi-php53-zmq)	skip=y ;;
	    epi-php-*-7-[12])	skip=y ;;
	esac
	if [ "$skip" ]; then
	    echo "Skipping obsolete package '$Name'." >&2
	    continue
	fi
    fi
    DebVer=`expr "$Vers" : '.*+\(deb[1-9][0-9]*\)$'` || DebVer='any'
    ArchDir=$DebDir/$DebVer/$Arch
    mkdir -p $ArchDir
    if [ $Links -eq 1 ]; then
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
	test $File = $Pkg || echo "Warning: `expr $deb : "$SrcDir/\(.*\)"` -> $DebVer/$Arch/$Pkg" >&2
	ln $deb $ArchDir/$Pkg
    fi
done <$TmpDir/deblist
rm $TmpDir/deblist

exec ./update.sh $RepDir
