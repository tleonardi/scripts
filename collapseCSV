#!/bin/bash
#
# Tommaso Leonardi, 2011
# This program reads a 2 fields tab separated files and using 
# the first field as index it collapses the file putting the 
# second field values all on the same line separated by commas.
# If the -s option is provided it sums up all the second field 
# values having the same index. The input file must be sorted by the index.	
#	
#
#
#
INPUT="NONE"
while getopts "sh" opt
do
    case $opt in
        (s) SUM=1;;
        (h) HELP=1;;
    	esac
done

if [ $HELP ] ; then
		echo -e "This program reads a 2 fields tab separated files and using the first field as index it collapses the file putting the second field values all on the same line separated by commas.\n\n If the -s option is provided it sums up all the second field values having the same index. The input file must be sorted by the index."
exit
fi

shift $(($OPTIND - 1))
INPUT=$1

if [ "$INPUT" = "" ] ; then 
	TMP1=`mktemp`
	while read line
	do
    		echo "$line" >> ${TMP1}
	done
	INPUT="$TMP1"
fi



if [ $SUM ] ; then
	cat $INPUT|awk 'BEGIN{OFS="\t"}{if($1==ID){VAL+=$2} else{if(ID!=""){print ID,VAL;}ID=$1;VAL=$2;} }END{print ID,VAL}'
else
	cat $INPUT|awk 'BEGIN{OFS="\t"}{if($1==ID){VAL=VAL","$2} else{if(ID!=""){print ID,VAL;}ID=$1;VAL=$2;} }END{print ID,VAL}'
fi
rm -f ${TMP1}

