#!/bin/sh
#
#	genkey.sh - Generate a GPG key for APT signing
#
Prg=`basename $0`
Cnf=key.conf
#   Paths are relative, so move to our top directory
if ! [ -f $Cnf ]; then
    cd `dirname $0`
    if ! [ -f $Cnf ]; then
	echo "$Prg: cannot find '$Cnf' configuration file" >&2
	exit 2
    fi
fi
Name="`sed -n 's/^Name-Real: //p' $Cnf`"
Mail="`sed -n 's/^Name-Email: //p' $Cnf`"
if gpg -k | grep "^uid  *$Name <$Mail>$" >/dev/null; then
    echo "Deleting existing keys found for $Mail:"
    gpg -k $Mail | sed 's/^/    /'
    fp=`gpg --fingerprint $Mail | sed -n 's/^ *Key fingerprint = //p' | tr -d ' '`
    gpg --batch --delete-secret-and-public-key $fp
fi
echo "Please generate entropy with 'sudo grep -Lr SomeImpossibleString /'..."
gpg --gen-key --batch $Cnf
gpg -k
Sign=`gpg -k --with-colons $Mail | awk -F: '$1 == "sub" {print substr($5,9)}'`
gpg -a --export $Sign >key.gpg
