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
parser$add_argument("--files"             , nargs="+", help="List of files to load. The files produced by deeptools computeMatrix must all be sorted in the same way. This can be done with the --sortRegions \"no\" option in computeMatrix [default %(default)s]" )
parser$add_argument("--labels"            , nargs="+", help="Primary sample labels. The must be one label per sample. eg K562 H1ESC [default %(default)s]" )
parser$add_argument("--secondaryLabels"   , nargs="+", help="Secondary labels. If set, secondary labels will be used as an additional factor for faceting the plots (eg K562 H1ESC..). If not required set it to NA [default %(default)s]" , default="NA")
parser$add_argument("--sortByFirst"       , help="Sort by intensity the first subplot and use the same order for all subsequent plots? (if not set, each subplot is sorted independently). [default %(default)s]" , default=FALSE , action="store_true" )
parser$add_argument("--logNorm"           , help="Log normalise the intensities? [default %(default)s]"                                                       , default=FALSE , action="store_true")
parser$add_argument("--minimumValue"      , help="To avoid taking the log of 0 we add a small constant to each value before taking the log. The variable minimumValue defines this small constant. If set to NA it add to each value the minimum number !=0 [default %(default)s]" , default="NA")
parser$add_argument("--negativeToZero"    , help="Force negative numbers to 0. If logNorm is set to TRUE and you have negative values in your files, you need this option [default %(default)s]" , default=FALSE , action="store_true" )
parser$add_argument("--satQuantile"       , help="Saturate intensity above this quantile [default %(default)s]" , default="NA" )
parser$add_argument("--outFile"           , help="Basename for the outfile [default %(default)s]" , default="test" )
parser$add_argument("--profileStdErr"     , help="Plot the std error as a ribbon in the profile plots? [default %(default)s]" , default=FALSE , action="store_true" )
parser$add_argument("--profileFreeScales" , help="Should each profile plot have a free y-axis scale or all subplots should have the same limits? [default %(default)s]" , default=FALSE , action="store_true" )
parser$add_argument("--profileSplitLabels" , help="If you don't have secondary labels you can choose to have a subplot for each label rather the plotting them in different colours in the same plot." , default=FALSE , action="store_true" )
parser$add_argument("--heatW"             , type="integer" ,  help="Heatmap width [default %(default)s]" , default=4 )
parser$add_argument("--heatH"             , type="integer" ,  help="Heatmap height [default %(default)s]" , default=13 )
parser$add_argument("--profW"             , type="integer" ,  help="profile width [default %(default)s]" , default=7 )
parser$add_argument("--profH"             , type="integer" ,  help="profile height [default %(default)s]" , default=8 )
parser$add_argument("--title"             , help="Main title for the graph [default no title]" , default="NA")
args <- parser$parse_args()

#patch NA
for (n in names(args)){if(args[[n]][1] == "NA"  ){args[[n]] <- NA  } }
for (n in names(args)){assign(n,args[[n]]) }

if(sortByFirst) {
	        sortEach=F
} else {
	        sortEach=T
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

if (!is.na(secondaryLabels) && length(secondaryLabels) != length(labels)){
	stop("There must be the same number of primary and secondary labels")
	quit(save = "no", status = 1, runLast = FALSE)	
}

if (!is.na(secondaryLabels) && length(secondaryLabels)==1){
	stop("It's unnecessary to use secondary labels if you only have one file")
	quit(save = "no", status = 1, runLast = FALSE)	
}

if(is.na(secondaryLabels) && max(table(labels))>1){
	stop("Each sample must have a unique label")
        quit(save = "no", status = 1, runLast = FALSE)
}

if(!is.na(secondaryLabels) && max(table(labels, secondaryLabels))>1){
	stop("Each sample must have a unique combination of label and secondary label")
        quit(save = "no", status = 1, runLast = FALSE)
}

if(profileSplitLabels && !is.na(secondaryLabels)){
	stop("You can't use profileSplitLabels when you have secondary labels")
        quit(save = "no", status = 1, runLast = FALSE)

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
	mat <- read.delim(fileName, comment.char = "#", header=F, sep=" ")
	colnames(mat) <- 1:ncol(mat)
	
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
	if(!is.na(secondaryLabels)){
		mat$secLabel <- secondaryLabels[fileIndex]
	}
	mat2[[fileIndex]] <- mat
}

mat2 <- rbindlist(mat2)

mm <- reshape2::melt(mat2, id.vars=c("Row", "Category", "Label"))

if(logNorm) {
	if(is.na(minimumValue)) minimumValue <- min(mm$value[mm$value>0])
        mm$value <- log10(mm$value + minimumValue)
}

mm$Label <- factor(mm$Label, levels=unique(labels))

hmcol = colorRampPalette(brewer.pal(9, "GnBu"))(100)

# X Scale
binsize <- dimensions[4, "dim"]
downstream <- dimensions[dimensions$Name == "downstream", "dim"]/binsize
upstream <- dimensions[dimensions$Name == "upstream", "dim"]/binsize
body <- dimensions[dimensions$Name == "body", "dim"]/binsize

if(body==0){
	xscale <- scale_x_discrete(breaks=c(1, downstream, downstream+upstream), labels=c(paste("-", downstream*binsize/1000, "Kb", sep=""), "TSS", paste("+", upstream*binsize/1000, "Kb", sep="")))
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
   if (length(labels)>=2 && is.na(secondaryLabels)) heatmapPlot <- heatmapPlot + facet_grid(Label ~ ., scales = "free", space = "free")
   else if (length(labels)>=2 && !is.na(secondaryLabels)) heatmapPlot <- heatmapPlot + facet_grid(Label ~ secLabel, scales = "free", space = "free")
}

if(nrow(categories)>1) {
   if (length(labels)<2){
           heatmapPlot <- heatmapPlot + facet_grid(Category ~ ., scales = "free", space = "free")
   }
   else if (length(labels)>=2 && is.na(secondaryLabels)) {
           heatmapPlot <- heatmapPlot + facet_grid(Category ~ Label, scales = "free", space = "free")
   }
   else if (length(labels)>=2 && !is.na(secondaryLabels)) {
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



pdf(outFileHeatMap, width=heatW, height=heatH)
        print(heatmapPlot)
dev.off()


# PLOT PROFILES
if(!is.na(secondaryLabels)){
	profiles <- group_by(mm, Category, Label, secLabel, variable) %>% summarise(mean=mean(value), stderr=sd(value)/sqrt(length(value)))
} else {
	profiles <- group_by(mm, Category, Label, variable) %>% summarise(mean=mean(value), stderr=sd(value)/sqrt(length(value)))
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
	if(is.na(secondaryLabels) && profileSplitLabels) {
		profilePlot <- profilePlot + facet_wrap(~Label, ncol=1, scales=profScales)
	}
	if(!is.na(secondaryLabels)){
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
	else if (length(labels)>=2 && is.na(secondaryLabels)) {
		if(profileSplitLabels){
			profilePlot <- profilePlot + facet_grid(Category~Label, scales=profScales)
		}else{
			profilePlot <- profilePlot + facet_wrap(~Category, ncol=1, scales=profScales)
		}
	}
	else if (length(labels)>=2 && !is.na(secondaryLabels)) {
		profilePlot <- profilePlot +facet_grid(Category~secLabel, scales=profScales)
	}
}

if(profileStdErr){
	profilePlot <- profilePlot + geom_ribbon(aes(ymin=mean-stderr, ymax=mean+stderr, fill=Label), alpha=0.3)
}

pdf(outFileProfile, width=profW, height=profH)
	print(profilePlot)
dev.off()
