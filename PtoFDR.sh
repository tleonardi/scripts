#!/bin/bash
# Tommaso Leonardi, 2013-04-12
# Performs Benjamini and Hochberg p-value adjustment
# on a tab separated file
# Original awk implementation of BH algorithm by McBryan's blog:
# http://blog.mcbryan.co.uk/2013/01/false-discovery-rates-and-large-files.html

MEM="100M"
HEADER=
while getopts "hHc:m:" opt
do
    case $opt in
        (H) HEADER=1;;
        (h) HELP=1;;
	(c) COLUMN=$OPTARG;;
	(m) MEM=$OPTARG;;
	(*) HELP=1;;
	esac
done

if [ -z "$COLUMN" ]; then
	HELP=1
fi

if [ $HELP ] ; then
	echo "Reads a tab separated file and uses the Benjamini and Hochberg method" 
	echo "to calculate the FDR for the p-values in the specified column"
	echo  
	echo "Usage:"
	echo "  PtoFDR.sh [-h] [-H] [-m SIZE] -c column filename"
	echo "    -h displays this help message"
	echo "    -H ignores the first (header) row of the file"
	echo "    -m use SIZE as main memory buffer for sort (default 100M)."
	echo "    -c the number of the column with p-values"
	echo "  Notice: this script doesn't support pipes or named pipes" 
exit
fi

shift $(($OPTIND - 1))
FILENAME=$1

if [ ! -f $FILENAME -a ! -p $FILENAME ]; then
	echo "$FILENAME: No such file or directory"
	exit
fi

export LC_ALL=C

# Count how many lines in file
NUMROWS=`wc -l $FILENAME | awk '{print $1}'`
# Check is the file has a header row (-H option)
if [ $HEADER ] ; then
	# Subtract one from NUMROWS
	NUMROWS=`expr $NUMROWS - 1`
	# Print a new header that includes the q-value column
	head -n1 $FILENAME | awk -v col=$COLUMN 'BEGIN{OFS=FS="\t"}{for (i = 1; i <= col ; i++){printf $i"\t"} printf "q-value\t";for (i = col+1; i <= NF-1; i++){printf $i"\t"}printf $NF"\n"}'
fi

# If header is set: sort ... <(tail -n +2 $FILENAME)
# If it's not set : sort ... $FILENAME
(if [[ ! -z $HEADER ]]; then sort -S $MEM -k"$COLUMN","$COLUMN"gr <(tail -n +2 $FILENAME); else sort -S $MEM -k"$COLUMN","$COLUMN"gr "$FILENAME"; fi) | awk -v col=$COLUMN -v numrows=$NUMROWS '\
function min(a,b)
{
	if (a <= b)
	return a
	else
	return b
}

BEGIN { cummin = 1.0; OFS=FS="\t"; }
{
cummin = min(cummin,$col*(numrows/(numrows - NR + 1)));
for (i = 1; i <= col ; i++){
	printf $i"\t"
}
printf cummin"\t";
for (i = col+1; i <= NF-1; i++){
	printf $i"\t"
}
printf $NF"\n"
}'

