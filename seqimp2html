#!/bin/bash
#	Tommaso Leonardi, 2013
#
#	05/08/13 - v0.1
#	Make a folder with all QC plots from seqimp and an index.html file with links


# Check proper number of arguments 
if [ ! $# == 3 ]
  then
    echo "
Usage: make_html_dir.sh analysis_folder description.txt output_dir
	analysis folder: path to the analysis folder created by SequenceImp
	description.txt: description file submitted to SequenceImp
	output_dir: path to the directory where to save output
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

# Check that result dirs exist
for i in "${FILES[@]}"; do
	if [ ! -d $ANALYSIS_DIR/$i ]
	then
    		echo "$ANALYSIS_DIR: No such directory"
		echo "Please make sure that all files described in $2 have a corresponding results directory"
	exit 1
	fi
done;

# Check that OUTDIR doesn't exist
if [ -d $3 ]
then
	echo "$3: directory already exists"
	exit 1
fi
OUTDIR=$3
mkdir $OUTDIR

# Initialise HTML file
echo -e "<html>
<head>
<link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\">
</head>
<p style=\"text-align: center;font-size: 22px;\">Seqimp QC</p>
<br>
<table id=\"tab\">
        <thead>
        	<th>Sample name</th>
        	<th>Reaper</th>
        	<th>Processed</th>
        	<th>Bowtie</th>
        </thead>
	<tbody>
" > $OUTDIR/index.html

for a in $(seq 0 $(expr ${#FILES[@]} - 1)); do
	i=${FILES[a]}
	mkdir $OUTDIR/$i
	cp $ANALYSIS_DIR/$i/QC/${i}_Reaper_qc.pdf $OUTDIR/$i
	cp $ANALYSIS_DIR/$i/QC/${i}_Processed_reads_qc.pdf $OUTDIR/$i
	cp $ANALYSIS_DIR/$i/QC/${i}_Bowtie_qc.pdf $OUTDIR/$i
	echo -e "<tr>" >> $OUTDIR/index.html
	echo -e "<td>$i</td>" >> $OUTDIR/index.html
	echo -e "<td><a href=\"$i/${i}_Reaper_qc.pdf\" target=\"_blank\">Reaper</a></td>" >> $OUTDIR/index.html
	echo -e "<td><a href=\"$i/${i}_Processed_reads_qc.pdf\" target=\"_blank\">Processed</a></td>" >> $OUTDIR/index.html
	echo -e "<td><a href=\"$i/${i}_Bowtie_qc.pdf\" target=\"_blank\">Bowtie</a></td>" >> $OUTDIR/index.html
	echo -e "</tr>" >> $OUTDIR/index.html
done;
echo -e "</tbody></table></html>" >> $OUTDIR/index.html


# Make style file
echo -e "<style type=\"text/css\">
#tab {
	background-color: whiteSmoke;
	border-radius: 6px;
	-webkit-border-radius: 6px;
	-moz-border-radius: 6px;
	margin-left: auto;
	margin-right: auto;
}
#tab th {
	color: #333;
	font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
	font-size: 16px;
	font-style: normal;
	font-weight: normal;
	text-align: left;
	padding: 0 20px;
}
#tab td {
	padding: 0 20px;
	line-height: 20px;
	color: #0084B4;
	font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
	font-size: 14px;
	border-bottom: 1px solid #fff;
	border-top: 1px solid #fff;
}
#tab td:hover {
	background-color: #fff;
}
p {
	color: #333;
	font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
	font-size: 16px;
	font-style: normal;
	font-weight: normal;
	text-align: left;
}
</style>
" > $OUTDIR/style.css
