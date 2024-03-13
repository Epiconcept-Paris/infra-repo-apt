#!/bin/sh
#
#	prod.sh - Add packages to prod repository from prep
#		  Delete packages from prod (but not prep)
#		  Show prod package versions
#
Prg=`basename $0`

# See tree.txt for wanted and required directory tree
DocDir='docroot'
PreDir="$DocDir/prep/debs"
ProDir='prod'
TmpDir='tmp'
Log=/var/log/epiconcept/aptv2.prod.log		# Aka 'update.log' in README.md

Usage()
{
    echo "Usage: $Prg [-t <prod-tag> ] add <package> | del <package> | ver [ <package> ] | ls [ <filter> ]" >&2
    exit ${1:-1}
}

#   We want our paths relative, so move to our top directory
if ! [ -d $PreDir -a -x update.sh ]; then
    cd `dirname $0`
    if ! [ -d $PreDir -a -x update.sh ]; then
	echo "$Prg: cannot find '$PreDir' directory and 'update.sh' script" >&2
	exit 2
    fi
fi
mkdir -p $TmpDir

ProTag=		# Not strictly needed, but for clarity
test "$APT_PROD_TAG" && Protag="$APT_PROD_TAG"
#   Parse options
while getopts 'ht:' opt
do
    case $opt in
	t)  ProTag="$OPTARG"	;;
	h)  Usage 0;;	# help
	\?) Usage 1;;	# error
    esac
done
shift `expr $OPTIND - 1`
if [ "$ProTag" ]; then
    ProDir="$ProDir-$ProTag"
    Log=$(echo "$Log" | sed "s/\.prod\./.$ProDir./")
    #echo "ProDir=\"$ProDir\" Log=\"$Log\""; exit 0
fi
RepDir="$DocDir/$ProDir"
DebDir="$RepDir/debs"

test "$1" = 'add' -o "$1" = 'del' -o "$1" = 'ver' -o "$1" = 'ls' || Usage

#
#   ls (with optional egrep filter $2)
#
if [ "$1" = 'ls' ]; then
    List="config/$ProDir.list"
    test -s "$List" || exit 0
    if [ "$2" ]; then
	egrep "$2" "$List"
    else
	cat "$List"
    fi
    exit 0
fi

#
#   add & del
#
if [ "$1" = 'add' -o "$1" = 'del' ]; then
    exec 2>>$Log
    test "$1" = 'add' && { Dir=$PreDir; Act='added'; } || { Dir=$DebDir; Act='deleted'; }
    shift
    date "+---- %Y-%m-%d %H:%M:%S - $ProDir --------------------------------------------" >&2
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
			echo "Package $pkg is already in $ProDir/debs - discarded" >&2
		    else
			mkdir -p `dirname $DebDir/$pkg`
			ln $PreDir/$pkg $DebDir/$pkg	# hard link
			echo "Added $DebDir/$pkg"
			nbAdd=`expr $nbAdd + 1`
		    fi
		else
		    if [ "$isF" ]; then
			rm -v $DebDir/$pkg | sed 's/^r/R/'
			nbDel=`expr $nbDel + 1`
		    else
			echo "Package $pkg is not in $ProDir/debs - discarded" >&2
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
