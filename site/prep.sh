#!/usr/bin/env bash
#
#	update.sh - Update prep repository after adding packages
#		    List prep packages
#
Prg=`basename $0`
PrgDir=`dirname $0`
CfgDir=config
SrcDir=sources
DocDir=docroot
DebDir=$DocDir/prep/debs

#   Paths are relative, so move to our top directory
if ! [ -f $CfgDir/dists -a -f $CfgDir/alias ]; then
    cd $PrgDir
    if ! [ -f $CfgDir/dists -a -f $CfgDir/alias ]; then
	echo "$Prg: cannot find $CfgDir/dist and $CfgDir/alias files" >&2
	exit 2
    fi
fi

#
#   list
#
if [ "$1" = 'list' ]; then
    if ! [ -d $DebDir/any/all ]; then
	echo "$Prg: no prep files yet (run $Prg update)" >&2
	exit 2
    fi
    find $DebDir -name '*.deb' -links 2 | sed "s;$DebDir/;;"
    NewDeb=`find $SrcDir -name '*.deb' -links 1 | wc -l`
    test $NewDeb -gt 0 && echo "$Prg: $NewDeb new source(s) packages also exist (run $Prg update)" >&2
    exit 0
elif [ "$1" != 'update' ]; then
    echo "Usage: $Prg [ update | list ]" >&2
    exit 1
fi

#
#   update
#
declare -A PkgDir
rm -fv $DebDir/*/*/over | sed 's/^r/R/'	# sed for cosmetics
Cmd="find $SrcDir -type f -name '*.deb'"
if [ `eval $Cmd -links 1 | wc -l` -eq 0 ]; then	# Just exit if nothing to add
    echo "No new packages found."
    exit 0
fi
eval $Cmd >tmp/debs
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
	ln $deb $ArchDir    
    fi
    PkgDir[$DebVer/$Arch]=y
    echo "$Name optional base" >>$ArchDir/over
    #echo "`expr $File : '\([^_]*\)_'` optional base" >>$ArchDir/over
done <tmp/debs
cd $DocDir/prep
for DebArch in ${!PkgDir[@]}
do
    ArchDir=debs/$DebArch
    echo "Processing $ArchDir"
    dpkg-scanpackages -m $ArchDir/ $ArchDir/over >$ArchDir/Packages
done


exit 0
#---------------------------------------------
DocRoot=/var/www/files.epiconcept.fr/data/files
Top=$DocRoot/repositories_apt/epiconcept/
DebDir=$Top/deb
ZipDir=$DocRoot/Episoft
Dists="wheezy jessie stretch sid precise trusty xenial bionic"
Archs="amd64 armhf"
Log=/home/epiconcept_build/journal.log
date '+%Y-%m-%d H%:M:%S' >>$Log
rsync -rav /home/travis/depot/ $Top/deb/ >>$Log
cd $Top
for i in deb/*.deb
do
    echo "$i optionnal base" | sed -e "s#deb/##" -e "s#.deb##" -e "s#_all##" -e "s#_[0-9]* # #"
done | sort -u >override
ls deb/*.deb | sed 's;^deb/\(.*\)\.deb$;\1 optionnal base;' | sed -e 's/_all//' -e 's/_[0-9]* / /' | sort -u >over
dpkg-scanpackages deb/ override >Packages 2>>$Log
gzip -c Packages >Packages.gz
bzip2 -c Packages >Packages.bz2
for dist in $Dists
do
    Dir=dists/$dist
    sed -e "s/ARCH/$Archs/g" -e "s/DATE/$(date --date='TZ="UTC"' +"%a, %d %b %G %R:%S UTC%z")/g" -e "s/DIST/$dist/g" apt_deploy_Release >$Dir/Release
    for arch in $Archs
    do
	chemin="$Dir/main/binary-$arch/"
	mkdir -p $chemin
	chmod 775 $chemin
	rsync -raq --dirs $Top/Packages* $chemin
	chmod 664 $chemin/*
	cp $Dir/Release* $chemin
    done
done
chmod 664 deb/* $ZipDir/*
chmod 664 deb/* $ZipDir
