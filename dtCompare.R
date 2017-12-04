# Tommaso Leonardi (tl344@ebi.ac.uk), Giovanni Bussotti (giovanni@ebi.ac.uk)
# This script reads matrices produced by deeptools from bigWig files 
# and generates multiple heatmaps in a single plot.

#################################################
#		CONFIGURATION
#################################################
suppressPackageStartupMessages(library("argparse"))
# create parser object
parser <- ArgumentParser()
# specify our desired options # by default ArgumentParser will add an help option
parser$add_argument("--files"             , nargs="+", help="List of files to load. The files produced by deeptools computeMatrix must all be sorted in the same way. This can be done with the --sortRegions \"keep\" option in computeMatrix [default %(default)s]" )
parser$add_argument("--labels"            , nargs="+", help="Primary sample labels. The must be one label per sample. eg K562 H1ESC [default %(default)s]" )
parser$add_argument("--secondaryLabels"   , nargs="+", help="Secondary labels. If set, secondary labels will be used as an additional factor for faceting the plots (eg K562 H1ESC..). If not required set it to NA [default %(default)s]" , default="NA")
parser$add_argument("--sortByFirst"       , help="Sort by intensity the first subplot and use the same order for all subsequent plots? (if not set, each subplot is sorted independently). [default %(default)s]" , default=FALSE , action="store_true" )
parser$add_argument("--logNorm"           , help="Log normalise the intensities? [default %(default)s]"                                                       , default=FALSE , action="store_true")
parser$add_argument("--minimumValue"      , help="To avoid taking the log of 0 we add a small constant to each value before taking the log. The variable minimumValue defines this small constant. If set to NA it add to each value the minimum number !=0 [default %(default)s]" , default="NA")
parser$add_argument("--negativeToZero"    , help="Force negative numbers to 0. If logNorm is set to TRUE and you have negative values in your files, you need this option [default %(default)s]" , default=FALSE , action="store_true" )
parser$add_argument("--satQuantile"       , help="Saturate intensity above this quantile [default %(default)s]" , default="NA" )
parser$add_argument("--outFile"           , help="Basename for the outfile [default %(default)s]" , default="test" )
parser$add_argument("--outTable"          , help="Save to file the table that ggplot2 will plot as heatmap. The Label field identifies the individual matrices, and the rows of the table are in inverse orientation with respect to the heatmap plot" , default="NA" )
parser$add_argument("--profileStdErr"     , help="Plot the std error as a ribbon in the profile plots? [default %(default)s]" , default=FALSE , action="store_true" )
parser$add_argument("--profileSD"         , type="integer" ,  help="Plot one or more standard deviations (SD) as a ribbon in the profile plots? Even if the data (columns of the input matrices) is not normally distributed, the SD can be applied to arbitrary distributions. See the Chebyshev's inequality  [default %(default)s]" , default=0 )
parser$add_argument("--profileMAD"        , help="Plot the mean absolute deviation as a ribbon in the profile plots? [default %(default)s]" , default=FALSE , action="store_true" )
parser$add_argument("--profileCI"        , help="Plot the confidence interval at confidence level 95%% as a ribbon in the profile plots? The implemented formula works for quantitative continuous data (eg chip-seq support) but not for discrete qualitative data (eg categories, yes or no). It uses the t distribution for sample sizes < 30 [default %(default)s]" , default=FALSE , action="store_true" )
parser$add_argument("--profileFreeScales" , help="Should each profile plot have a free y-axis scale or all subplots should have the same limits? [default %(default)s]" , default=FALSE , action="store_true" )
parser$add_argument("--profileSplitLabels" , help="If you don't have secondary labels you can choose to have a subplot for each label rather the plotting them in different colours in the same plot." , default=FALSE , action="store_true" )
parser$add_argument("--heatW"             , type="integer" ,  help="Heatmap width [default %(default)s]" , default=4 )
parser$add_argument("--heatH"             , type="integer" ,  help="Heatmap height [default %(default)s]" , default=13 )
parser$add_argument("--profW"             , type="integer" ,  help="profile width [default %(default)s]" , default=7 )
parser$add_argument("--profH"             , type="integer" ,  help="profile height [default %(default)s]" , default=8 )
parser$add_argument("--title"             , help="Main title for the graph [default no title]" , default="NA")
parser$add_argument("--noHeat"            , help="Don't save the heatmap" , default=FALSE , action="store_true")
parser$add_argument("--noProf"            , help="Don't save the profile" , default=FALSE , action="store_true")
parser$add_argument("--verticalProfLabels", help="Print the labels of the x-axis of the Profile vertically." , default=TRUE , action="store_false")
parser$add_argument("--centerLabel"       , help="If you plot matrices centered on TES insted of TSS set this option to TES. Otherwise if your matrices correspond to scaled regions ingnore this option" , default="TSS")
parser$add_argument("--normFactors"       , nargs="+", help="Space separate list of normalisation factors. Each matrix will be divided by its corresponding factor. --files and --normFactors must contain the same number of elements and in the same order." , default="NA")
parser$add_argument("--debug"            , help="Save an object called '.dtCompare.debug' in the current folder that stores useful debugging data." , default=FALSE , action="store_true")

args <- parser$parse_args()

#patch NA
for (n in names(args)){if(args[[n]][1] == "NA"  ){args[[n]] <- NA  } }
for (n in names(args)){assign(n,args[[n]]) }

if(sortByFirst) {
	        sortEach=F
} else {
	        sortEach=T
}

if(debug){
	save.image(file=".dtCompare.debug")
	quit(save="no")
}
#################################################
library("data.table")
library("reshape2")
library("RColorBrewer")
library("ggplot2")
library("dplyr")
library("scales")

if (length(labels) != length(files)){
	stop("There must be the same number of files and labels")
	quit(save = "no", status = 1, runLast = FALSE)	
}

if (any(!is.na(secondaryLabels)) && length(secondaryLabels) != length(labels)){
	stop("There must be the same number of primary and secondary labels")
	quit(save = "no", status = 1, runLast = FALSE)	
}

if (any(!is.na(secondaryLabels)) && length(secondaryLabels)==1){
	stop("It's unnecessary to use secondary labels if you only have one file")
	quit(save = "no", status = 1, runLast = FALSE)	
}

if(any(is.na(secondaryLabels)) && max(table(labels))>1){
	stop("Each sample must have a unique label")
        quit(save = "no", status = 1, runLast = FALSE)
}

if(any(!is.na(secondaryLabels)) && max(table(labels, secondaryLabels))>1){
	stop("Each sample must have a unique combination of label and secondary label")
        quit(save = "no", status = 1, runLast = FALSE)
}

if(profileSplitLabels && any(!is.na(secondaryLabels))){
	stop("You can't use profileSplitLabels when you have secondary labels")
        quit(save = "no", status = 1, runLast = FALSE)

}

if((profileStdErr && profileCI) || (profileStdErr && profileMAD) || (profileStdErr && (profileSD > 0)) || (profileMAD && profileCI) || (profileMAD && (profileSD > 0))) {
	stop("You should not visualize at the same time multiple different error areas in the profile plot")
        quit(save = "no", status = 1, runLast = FALSE)

}

if (any(!is.na(normFactors))){
    normFactors <- as.numeric(as.character(normFactors))
    if(length(normFactors) != length(files)){
	stop("There must be the same number of files and normalisation factors.")
        quit(save = "no", status = 1, runLast = FALSE)
    }
}


for(fileName in files){
	if(as.numeric(system(paste("grep ^# ", fileName, " | wc -l"), intern=T)) != 2){
		stop(paste(fileName, " has wrong format.", sep=""))
		quit(save = "no", status = 1, runLast = FALSE)
	}

	
	categories <- read.delim(pipe(paste("head -1", fileName, "| sed 's/#//' | perl -pe 's/([a-zA-Z-]+):([0-9]+)\t*/\\1\t\\2\n/g'")), header=F, col.names=c("Name", "number"))
	dimensions <- read.delim(pipe(paste("head -2", fileName, "| tail -1 | sed 's/#//' | perl -pe 's/([a-zA-Z-]+):([0-9]+)\t*/\\1\t\\2\n/g'")), header=F, col.names=c("Name", "dim"))
	
	if(which(files==fileName) == 1){
		firstFileCatNames <- categories$Name
		firstFileCatNumbers <- categories$number
		firsFileDimensions <- dimensions$dim
	}
	
	if(!all(categories$Name == firstFileCatNames) || !all(categories$number == firstFileCatNumbers) || !all(dimensions$dim == firsFileDimensions)){
		stop(paste(fileName, " has a header different from", files[1], sep=""))
		quit(save = "no", status = 1, runLast = FALSE)
	}

}


mat2 <- list()
for(fileName in files){

	fileIndex <- which(files==fileName)
	# Get the label for the current file
	fileLabel <- labels[fileIndex]
	# Read the matrix
	mat <- as.data.frame(fread(fileName))
	setnames(mat, colnames(mat), as.character(1:ncol(mat)))

	if (any(!is.na(normFactors))){
		NFact <- normFactors[fileIndex]	
		mat <- mat/NFact
	}
	
	if(any(is.na(mat))){
		# Set negative number to 0 and print warning message
		warning(paste("Some fields of '", fileName, "' do not contain any value.\nWe are forcing them to 0.\nDid you use '--missingDataAsZero' in computeMatrix?", sep=""))
		mat[is.na(mat)] <- 0 
	}
	if(any(mat<0)){
		if(negativeToZero){
			mat[mat<0] <- 0
		} else {
			if(logNorm){
				stop(paste("Some fields of '",fileName, "' contain negative values.\nThis is not going to work well with log normalisation.", sep=""))
				#quit(save = "no", status = 1, runLast = FALSE)
			} else{
				warning(paste("Some fields of '", fileName, "' contain negative values.\nSet 'negativeToZero' to TRUE to force them to 0.", sep=""))
			}
		}
	}

	# Keep track of how many columns contain data
	nfields <- ncol(mat)
	mat$Row <- 1:nrow(mat)

	# If this is not the first file, reorder based on the first file
	if(fileIndex!=1 && sortEach==FALSE){
		mat <- mat[origRowOrder,]
	}
	# Assign the categories and sort the entries of each category
	from=1
	for(i in 1:nrow(categories)){
		to <- from + categories[i,"number"] - 1
		if((fileIndex==1 && sortByFirst == TRUE) || sortEach==TRUE){
			mat[from:to,] <- mat[from:to,][order(rowMeans(mat[from:to,1:nfields]), decreasing=F),]
		}
		mat[from:to,"Category"] <- categories[i,"Name"]
		from <- to + 1
	}
	
	# Save the reordered original row numbers to reorder 
	# the files after the first	
	if(fileIndex==1){
		origRowOrder <- mat$Row
	}
	
	# Reinitiate the Row ids as a factor for plotting
	mat$Row <- factor(1:nrow(mat))

	# Make a column with the file label
	mat$Label <- fileLabel

	# If there are secondary labels also make a column
	if(any(!is.na(secondaryLabels))){
		mat$secLabel <- secondaryLabels[fileIndex]
	}
	mat2[[fileIndex]] <- mat
}

mat2 <- rbindlist(mat2)

if(!is.na(outTable)){
	write.table(mat2, file = outTable, append = FALSE, quote = FALSE, sep = "\t")
}

if(any(!is.na(secondaryLabels))){
	mm <- reshape2::melt(mat2, id.vars=c("Row", "Category", "Label", "secLabel" ))
} else {
	mm <- reshape2::melt(mat2, id.vars=c("Row", "Category", "Label"))
}

if(logNorm) {
	if(is.na(minimumValue)) minimumValue <- min(mm$value[mm$value>0])
        mm$value <- log10(mm$value + as.numeric(minimumValue))
}

mm$Label <- factor(mm$Label, levels=unique(labels))

hmcol = colorRampPalette(brewer.pal(9, "GnBu"))(100)

# X Scale
binsize <- dimensions[4, "dim"]
downstream <- dimensions[dimensions$Name == "downstream", "dim"]/binsize
upstream <- dimensions[dimensions$Name == "upstream", "dim"]/binsize
body <- dimensions[dimensions$Name == "body", "dim"]/binsize

if(body==0){
	xscale <- scale_x_discrete(breaks=c(1, downstream, downstream+upstream), labels=c(paste("-", downstream*binsize/1000, "Kb", sep=""), centerLabel, paste("+", upstream*binsize/1000, "Kb", sep="")))
} else {
	xscale <- scale_x_discrete(breaks=c(1, downstream, downstream+body, downstream+body+upstream), labels=c(paste("-", downstream*binsize/1000, "Kb", sep=""), "TSS", "TES", paste("+", upstream*binsize/1000, "Kb", sep="")))
	
}


heatmapPlot <- ggplot(mm, aes(x=variable, y=Row, fill=value)) + geom_tile() + scale_y_discrete(breaks=NULL) + xscale + theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust=0.5))

# Add title
if(!is.na(title)){
	heatmapPlot <- heatmapPlot + ggtitle(title)
}

# Faceting
if(nrow(categories)==1) {
   if (length(labels)>=2 && any(is.na(secondaryLabels))) heatmapPlot <- heatmapPlot + facet_grid(Label ~ ., scales = "free", space = "free")
   else if (length(labels)>=2 && any(!is.na(secondaryLabels))) heatmapPlot <- heatmapPlot + facet_grid(Label ~ secLabel, scales = "free", space = "free")
}

if(nrow(categories)>1) {
   if (length(labels)<2){
           heatmapPlot <- heatmapPlot + facet_grid(Category ~ ., scales = "free", space = "free")
   }
   else if (length(labels)>=2 && any(is.na(secondaryLabels))) {
           heatmapPlot <- heatmapPlot + facet_grid(Category ~ Label, scales = "free", space = "free")
   }
   else if (length(labels)>=2 && any(!is.na(secondaryLabels))) {
           heatmapPlot <- heatmapPlot + facet_grid(secLabel+Category ~ Label, scales = "free", space = "free")
   }
}


# Scale fill
if(!is.na(satQuantile)){
        heatmapPlot <- heatmapPlot + scale_fill_gradientn(colours=hmcol, limits=c(min(mm$value),quantile(mm$value, as.numeric(satQuantile))), oob=squish)
} else {
        heatmapPlot <- heatmapPlot + scale_fill_gradientn(colours=hmcol)
}

# Define names for outfiles
outFileHeatMap <- paste(outFile, "_heatmap.pdf", sep="")
outFileProfile <- paste(outFile, "_profile.pdf", sep="")


if(noHeat==FALSE){
	pdf(outFileHeatMap, width=heatW, height=heatH)
        	print(heatmapPlot)
	dev.off()
}

calculateCIs <- function(value){
# Calculate the upper and lower 95% confidence interval.
# If there's less then 30 data points use a t.distribution
	res<-list()
	if(length(value)<30 ){
		# Before running the t-test we need to check whether
		# all values are equal. If they are, t.test() would 
		# quit with an error.
		# The code to test for equality of elements of a vector was
		# modified from Hadley's answer: http://stackoverflow.com/a/4752580/3173905
		tolerance = .Machine$double.eps ^ 0.5
		x <- range(value) / mean(value)
		if(isTRUE(all.equal(x[1], x[2], tolerance = tolerance))){
			if(profileCI){
				stop("In one ore more category there is less then 30 elements and they are all equal: can't compute the CI from a t.distribution")
		        	quit(save = "no", status = 1, runLast = FALSE)
			} else{
				res$low=NA_real_
				res$hig=NA_real_
			}
		}else{
			res$low=t.test(value)$conf.int[1]
			res$high=t.test(value)$conf.int[2]
		}
	} else {
		res$low=mean(value) - (1.96 * sd(value)/sqrt(length(value)))
		res$high=mean(value) + (1.96 * sd(value)/sqrt(length(value)))
	}
return(res)
}
# PLOT PROFILES
if(any(!is.na(secondaryLabels))){
	profiles <- group_by(mm, Category, Label, secLabel, variable) %>% summarise(mean=mean(value), stderr=sd(value)/sqrt(length(value)) , sd=sd(value),  MAD=sum(abs(value - mean(value)))/length(value), CIlow=calculateCIs(value)$low, CIhigh=calculateCIs(value)$high)
} else {
	profiles <- group_by(mm, Category, Label, variable) %>% summarise(mean=mean(value), stderr=sd(value)/sqrt(length(value))           , sd=sd(value), MAD=sum(abs(value - mean(value)))/length(value), CIlow=calculateCIs(value)$low, CIhigh=calculateCIs(value)$high)

}


profScales="fixed"
if(profileFreeScales){
	profScales="free"
}

profilePlot <- ggplot(profiles, aes(x=variable, y=mean, group=Label)) + geom_line(aes(colour=Label)) + xscale + theme_bw()

# Add title
if(!is.na(title)){
	profilePlot <- profilePlot + ggtitle(title)
}

# Faceting
if(nrow(categories)==1 && length(labels)>=2){
	if(any(is.na(secondaryLabels)) && profileSplitLabels) {
		profilePlot <- profilePlot + facet_wrap(~Label, ncol=1, scales=profScales)
	}
	if(any(!is.na(secondaryLabels))){
		if(profileSplitLabels){
			profilePlot <- profilePlot + facet_grid(Label~secLabel, scales=profScales)
		}else{
			profilePlot <- profilePlot + facet_wrap(~secLabel, ncol=1, scales=profScales)
		}
	}
}

if(nrow(categories)>1) {
	if (length(labels)<2){
		profilePlot <- profilePlot + facet_wrap(~Category, ncol=1, scales=profScales)
	}
	else if (length(labels)>=2 && any(is.na(secondaryLabels))) {
		if(profileSplitLabels){
			profilePlot <- profilePlot + facet_grid(Category~Label, scales=profScales)
		}else{
			profilePlot <- profilePlot + facet_wrap(~Category, ncol=1, scales=profScales)
		}
	}
	else if (length(labels)>=2 && any(!is.na(secondaryLabels))) {
		profilePlot <- profilePlot +facet_grid(Category~secLabel, scales=profScales)
	}
}

if(profileStdErr){
	profilePlot <- profilePlot + geom_ribbon(aes(ymin=mean-stderr, ymax=mean+stderr, fill=Label), alpha=0.3)
}

if(profileMAD){
	profilePlot <- profilePlot + geom_ribbon(aes(ymin=mean-MAD, ymax=mean+MAD, fill=Label), alpha=0.3)
}

if(profileCI){
	profilePlot <- profilePlot + geom_ribbon(aes(ymin=CIlow, ymax=CIhigh, fill=Label), alpha=0.3)
}

if(profileSD > 0){
	profilePlot <- profilePlot + geom_ribbon(aes(ymin=mean - (profileSD * sd), ymax=mean + (profileSD * sd), fill=Label), alpha=0.3)
}

if(verticalProfLabels){
	profilePlot <- profilePlot + theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust=0.5))
}
if(noProf==FALSE){
	pdf(outFileProfile, width=profW, height=profH)
		print(profilePlot)
	dev.off()
}
