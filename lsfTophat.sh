#!/bin/bash
set -e -o pipefail
# Tommaso Leonardi, tl344@ebi.ac.uk
# This script allows to run Tophat on an LSF system with a shared filesystem
# It runs Tophat on a node using a temporary local folder to store output.
# Upon completion, it copies the output back to a user-specified path

usage()
{
cat << EOF
usage: $0 [-dh] -p <params list> -o <out folder> -i <genome index> -f <fastq> -t <tophat binary>

This script makes your life easier when you have to run Tophat over LSF 

OPTIONS:
   -h      Show this message
   -p      List of parameters to be passed to Tophat
   -o      Path where to save Tophat output (it's created if it doesn't exist)
   -i      Path to genome index
   -f      Path to Fastq file
   -t      Path to Tophat binary
   -d	   Dry run


EOF
}

while getopts “hp:o:i:f:t:d” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         p)
             PARAMS=$OPTARG
             ;;
         o)
             OUT=$OPTARG
             ;;
         i)
             INDEX=$OPTARG
             ;;
         f)
             FASTQ=$OPTARG
             ;;
	 t)
	     TOPHAT=$OPTARG
	     ;;
	 d)
	     DRY=1
	     ;;
     esac
done

if [ -z "$PARAMS" ] || [ -z "$OUT" ] || [ -z "$INDEX" ] || [ -z "$FASTQ" ] || [ -z "$TOPHAT" ]; then
	usage;
	exit 1;
fi

if [ -d "$OUT" ]; then
	echo "Error: Output directory $OUT already exists";
	exit 1;
fi
mkdir -p $OUT

TMP=$(mktemp -d --tmpdir=/tmp)

if [ -z "$DRY" ]; then
	$TOPHAT $PARAMS -o $TMP $INDEX $FASTQ;
else
	echo "$TOPHAT $PARAMS -o $TMP $INDEX $FASTQ" | tee $TMP/test_tophat.output;
fi

cp -R $TMP/* $OUT
rm -rf $TMP

