#!/bin/bash
set -e

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
# For some unknown reason this script failed to copy back the results folders
# To get them back I've used:
# for i in *.log; do HOST=$(grep "Job was executed on host" $i | perl -pe 's/Job was executed on host\(s\) \<(.+)\>, in queue .*/$1/'); FOLDER=$(grep "A summary of the alignment counts can be found in" $i | perl -pe 's/.+A summary of the alignment counts can be found in (\/.+)align.summary.txt$/$1/'); JOB=$(grep "was submitted from host" $i | perl -pe 's/Job \<(.+)\> was submitted from host .+/$1/'); echo $HOST : $FOLDER : $JOB;mkdir -p $BASEDIR/transcriptomes/tophat/$JOB; scp $HOST:$FOLDER/* $BASEDIR/transcriptomes/tophat/$JOB;done

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

TMP=/tmp/$RANDOM$RANDOM
mkdir $TMP

if [ -z "$DRY" ]; then
	$TOPHAT $PARAMS -o $TMP $INDEX $FASTQ;
else
	echo $TOPHAT $PARAMS -o $TMP $INDEX $FASTQ > $TMP/test_tophat.output;
fi
mkdir -p $OUT
mv $TMP/* $OUT
rm -rf $TMP

