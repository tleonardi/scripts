#!/bin/bash
#	Tommaso Leonardi, 2013
#	Reads a SeqIMP description files and produces 
#	a properly formatted summary table of counts.
#
# 	15/02/13 - v0.1
#	05/08/13 - v0.2
# 		the FILES array now contain the Names of the samples
#		(columns 1 of description file) rather than their
#		filenames (column 2). The reason for this change is
#		that all result files of seqimp are named based on 
#		the sample name rather than the original filename
#

# Check proper number of arguments 
if [ ! $# == 2 ]
  then
    echo "
Usage: merge_count_files.sh analysis_folder description.txt
	analysis folder: path to the analysis folder created by SequenceImp
	description.txt: description file submitted to SequenceImp
    "
    exit
fi

# Check if the analysis directory exists
if [ ! -d $1 ]
then
    	echo "$1: doesn't exist or is not a directory"
	echo "Please provide a valid path to the analysis directory"
	exit 1
fi
ANALYSIS_DIR=$1

# Check if the description file exists
if [ ! -f $2 ]
then
    	echo "$2: No such file"
	echo "Please provide a valid description file"
	exit 1
fi
DESCRIPTION_FILE=$2

#Load file names in array
FILES=($(awk 'NR>1{printf("%s ",$1)}' $DESCRIPTION_FILE ))

# Check that all count files exist
for i in "${FILES[@]}"; do
	if [ ! -f $ANALYSIS_DIR/$i/miRNA_ANALYSIS/$i.mature.counts.txt ]
	then
    		echo "$ANALYSIS_DIR/$i/miRNA_ANALYSIS/$i.mature.counts.txt: No such file"
		echo "Please make sure that all files described in $2 have a corresponding count files"
	exit 1
	fi
done;


TMP="$(mktemp)"
TMP2="$(mktemp)"

# Join the first two files to TMP
join -1 1 -2 1 -a 1 -t $'\t' <(sort -k1,1 $ANALYSIS_DIR/${FILES[0]}/miRNA_ANALYSIS/${FILES[0]}.mature.counts.txt ) <(sort -k1,1 $ANALYSIS_DIR/${FILES[1]}/miRNA_ANALYSIS/${FILES[1]}.mature.counts.txt ) > $TMP

# For each subsequent file, join it with TMP
for i in $(seq 2 $(expr ${#FILES[@]} - 1)); do
	join -1 1 -2 1 -a 1 -t $'\t' $TMP <(sort -k1,1 $ANALYSIS_DIR/${FILES[$i]}/miRNA_ANALYSIS/${FILES[$i]}.mature.counts.txt ) > $TMP2
	mv $TMP2 $TMP
done;

# Do some basic error checking making sure that all the 'precursor' columns contain the same value
awk -v FILES="$(echo ${FILES[@]})" 'BEGIN{OFS=FS="\t";NFILES=split(FILES,F," ")} {for(i=2;i < NFILES*4+1;i+=4){PRE=i;PRECURSORS=PRECURSORS","$(PRE)}for(a=2; a <= split(PRECURSORS,P,","); a++){if(P[a]!=P[2]){printf("There was an error with matching lines: %s\n",P[a]) | "cat >&2" ;exit 1}}PRECURSORS=""}' $TMP
if [ $? -ne 0 ]; then
	echo "Exiting" 
	exit 1;
fi

# Print only the interesting columns with an appropriate header
awk -v FILES="$(echo ${FILES[@]})" 'BEGIN{OFS=FS="\t";NFILES=split(FILES,F," ")} $1=="Mature"{printf("Mature\tPrecursor");for(i=1;i<=NFILES;i++){printf("\t%s_Mapped_Reads\t%s_Unique_Reads",F[i],F[i])}printf("\n")};$1!="Mature"{printf("%s\t%s",$1,$2); for(i=2;i < NFILES*4+1;i+=4){MAPPED=i+2;UNIQUE=i+3;printf("\t%s\t%s",$(MAPPED),$(UNIQUE))}printf("\n")}' $TMP

rm $TMP

