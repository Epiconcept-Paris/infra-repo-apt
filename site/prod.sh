#!/bin/sh
#
#	prod.sh - Add packages to prod repository from prep
#		  Delete packages from prod (but not prep)
#		  Show prod package versions
#
Prg=`basename $0`

# See tree.txt for wanted and required directory tree
DocDir=docroot
PreDir=$DocDir/prep/debs
RepDir=$DocDir/prod
DebDir=$RepDir/debs
TmpDir=tmp
Log=update.log

Usage()
{
    echo "Usage: $Prg [ add <package> | del <package> | ver [ <package> ] ]" >&2
    exit 1
}

test "$1" = 'add' -o "$1" = 'del' -o "$1" = 'ver' || Usage

#   We want our paths relative, so move to our top directory
if ! [ -d $PreDir -a -x update.sh ]; then
    cd `dirname $0`
    if ! [ -d $PreDir -a -x update.sh ]; then
	echo "$Prg: cannot find '$PreDir' directory and 'update.sh' script" >&2
	exit 2
    fi
fi
mkdir -p $TmpDir

#
#   add & del
#
if [ "$1" = 'add' -o "$1" = 'del' ]; then
    exec 2>>$Log
    test "$1" = 'add' && { Dir=$PreDir; Act='added'; } || { Dir=$DebDir; Act='deleted'; }
    shift
    date "+---- %Y-%m-%d %H:%M:%S - prod --------------------------------------------" >&2
    find $Dir -type f -name '*.deb' | sed "s;$Dir/;;" | sort >$TmpDir/deblist
    nbAdd=0
    nbDel=0
    while test "$1"
    do
	if expr "$1" : '[^_]*_[^_]*_' >/dev/null; then
	    expr "$1" : '.*/' >/dev/null && key="^$1" || key="/$1"
	    pkg=`grep "$key" $TmpDir/deblist`
	    test "$pkg" && nbp=`echo "$pkg" | wc -l` || nbp=0
	    #echo "pkg=\"$pkg\" nbp=\"$nbp\""
	    if [ $nbp -gt 1 ]; then	# Unlikely (should not happen)
		echo "Key '$1' selects more than 1 `basename $Dir` package - discarded:" >&2
		echo "$pkg" | sed 's/^/    /';
	    elif [ $nbp -lt 1 ]; then	# Not unlikely at all (not found)
		echo "Key '$1' does not match any `basename $Dir` package - discarded" >&2
	    else			# Hopefully likely (found)
		test -f $DebDir/$pkg && isF=y || isF=
		if [ "$Act" = 'added' ]; then
		    if [ "$isF" ]; then
			echo "Package $pkg is already in prod/debs - discarded" >&2
		    else
			mkdir -p `dirname $DebDir/$pkg`
			ln $PreDir/$pkg $DebDir/$pkg
			echo "Added $DebDir/$pkg"
			nbAdd=`expr $nbAdd + 1`
		    fi
		else
		    if [ "$isF" ]; then
			rm -v $DebDir/$pkg | sed 's/^r/R/'
			nbDel=`expr $nbDel + 1`
		    else
			echo "Package $pkg is not in prod/debs - discarded" >&2
		    fi
		fi
	    fi
	else
	    echo "Key '$1' does not look like <pkgname>_<pkgversion>_... - discarded" >&2
	fi
	shift
    done
    rm $TmpDir/deblist
    test $nbAdd -gt 0 -o $nbDel -gt 0 && exec ./update.sh $RepDir || echo "No package $Act."
#
#   ver
#
else
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
fi
