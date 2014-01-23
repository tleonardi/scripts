#!/bin/bash
set -e -o pipefail
# Tommaso Leonardi, tl344@ebi.ac.uk
# This script allows to run Tophat on an LSF system with a shared filesystem
# It runs Tophat on a node using a temporary local folder to store output.
# Upon completion, it copies the output back to a user-specified path

usage()
{
cat << EOF
usage: $0 [-dnh] -p <params list> -o <out folder> -i <genome index> -f <fastq> -t <tophat binary>

This script makes your life easier when you have to run Tophat over LSF.
Tophat's output is stored in a temporary directory on the node (under /tmp) 
and upon colpletion the results are copied back to an output folder 
specified with the -o option.
If the -n option is specified the results are directly stored in the output
directory rather than in /tmp. This is useful if the tophat tmp data exceeds
the size available on /tmp.
OPTIONS:
   -h      Show this message
   -p      List of parameters to be passed to Tophat
   -o      Path where to save Tophat output (it's created if it doesn't exist)
   -i      Path to genome index
   -f      Path to Fastq file
   -t      Path to Tophat binary
   -d	   Dry run
   -n	   Write directly to the folder specified by -o

EOF
}

while getopts “hnp:o:i:f:t:d” OPTION
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
	 n)
	     NOTMP=1
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

if [ -z "$NOTMP" ]; then
	TMP=$(mktemp -d --tmpdir=/tmp)
else
	TMP=$OUT
	mkdir -p $TMP
fi

echo -e "$0: Running Tophat with :\n$TOPHAT $PARAMS -o $TMP $INDEX $FASTQ" | tee $TMP/tophat_command.txt;
if [ -z "$DRY" ]; then
	$TOPHAT $PARAMS -o $TMP $INDEX $FASTQ;
fi

if [ -z "$NOTMP" ]; then
	echo "$0: Creating output directory $OUT"
	mkdir -p $OUT

	echo "$0: Copying Tophat results to $OUT"
	cp -R $TMP/* $OUT

	echo "$0: Cleaning up $TMP"
	rm -rf $TMP
fi
echo "$0: Done"

