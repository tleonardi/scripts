# Script respository
This is my collection of various scripts (mostly bash and R) to automate simple repetive tasks.

## Table of contents
- [p2fdr](#p2fdr)
- [calcContext.R](#calcContext.R)
- [collapseCSV](#collapseCSV)
- [ht](#ht)
- [lsfTophat](#lsfTophat)
- [seqimp2html](#seqimp2html)
- [seqimpSummarise](#seqimpSummarise)
- [dropbox](#dropbox)
- [csv2html](#csv2html)

## p2fdr
Reads a tab separated file and uses the Benjamini and Hochberg method
to calculate the FDR for the p-values in the specified column

Usage:

    PtoFDR.sh [-h] [-H] [-m SIZE] -c column filename
       -h displays this help message
       -H ignores the first (header) row of the file
       -m use SIZE as main memory buffer for sort (default 100M).
       -c the number of the column with p-values
       Notice: this script doesn't support pipes or named pipes

# calcContext.R
calcContext.R is an R function that reads an RNA secondary structure in vienna format and returns the structural context of each nucleotide.
The output is a string of the same length of the input sequence where each character can take three values:
- p: paired nucleotide
- e: external nucleotide
- l: nucleotide is in a loop
- b: nucleotide is in a bulge

# collapseCSV
This program reads a 2 fields tab separated files and using the first field as index it collapses the file putting the second field values all on the same line separated by commas.
If the -s option is provided it sums up all the second field values having the same index.
The input file must be sorted by the index.	

# ht
ht is a handy replacement for head that aligns columns in an orderly fashion.
This script was written by Dennis Gascoigne at some point in 2010

# lsfTophat
This script allows to run Tophat on an LSF system with a shared filesystem. It runs Tophat on a node using a temporary local folder to store output. Upon completion, it copies the output back to a user-specified path.

Usage:

    usage: lsfTophat [-dnh] -p <params list> -o <out folder> -i <genome index> -f <fastq> -t <tophat binary>
    
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

# seqimp2html
Seqimp2html makes a folder with all QC plots from seqimp and an index.html file with links.

Usage:

    seqimp2html <analysis_folder> <description.txt> <output_dir>
	<analysis folder>: path to the analysis folder created by SequenceImp
	<description.txt>: description file submitted to SequenceImp
	<output_dir>: path to the directory where to save output

# seqimpSummarise
SeqimpSummarise reads a SeqIMP description files and produces a properly formatted summary table of counts.
Usage:
 
    seqimpSummarise <analysis_folder> <description.txt>
	<analysis folder>: path to the analysis folder created by SequenceImp
	<description.txt>: description file submitted to SequenceImp

# dropbox

This script copies a file to an http-accessible folder, provides the URL pointing to it (and optionally a shortened URL) and optionally sends the the link via email.
If the filename is not specified, the input is read from stdin and saved in the html folder
Usage:

    dropbox [-s] [-e <email>] [-h] [-u <url>] [-f <folder>] [-n] filename
    Options:
      -s            Shorten the URL using Google APIs
      -e <email>    Email address to send the link to.
                    Default: tleonardi@gmail.com
      -h            Print this help screen
      -u <URL>      Base URL of the http folder
                    Default: http://www.ebi.ac.uk/~tl344/dropbox
      -f <folder>   Save the file in the specified http-accessible folder.
                    Default: /homes/tl344/public_html/dropbox
      -n            Do not send an email
      -o <name>     Target file name
                    Default: source filename or date-time.html if reading from stdin

# csv2htm
This script creates an HTML table from a tab delimited file. Optionally, the table will use the DataTables JS library. The delimited input file can be provided as a filename argument or through stdin.
Usage:

    csv2htm [OPTIONS] input.csv
    Options:
      -d       Specify delimiter to look for, instead of tab.
      --head   Treat first line as header, required for proper function of datatables
      --dt     Use Datables
      --help   Print this help message
