# Tommaso Leonardi, tl344@ebi.ac.uk
# This script reads matrices produced by deeptools from bigWig files 
# and generates multiple heatmaps in a single plot.

#################################################
#		CONFIGURATION
#################################################

# List of files to load
# the files produced by deeptools computeMatrix must all be
# sorted in the same way.
# This can be done with the --sortRegions "no" option in computeMatrix.
files <- c("K562H3k4me3StdSig.txt", "H1hescH3k4me3StdSig.txt", "wgEncodeSydhTfbsGm12878Pol2StdSig.txt", "wgEncodeSydhTfbsK562Pol2StdSig.txt")

# Primary sample labels
# The must be one label per sample
labels <- c("K562", "H1ESC","K562", "H1ESC")

# Secondary labels
# If set, secondary labels will be used as
# an additional factor for faceting the plots
# If not required set it to NA
secondaryLabels<-NA
#secondaryLabels <- c("H3K4me3", "H3K4me3", "Pol2", "Pol2")

# Sort by intensity the first subplot and use the same
# order for all subsequent plots?
sortByFirst <- F

# Sort each subplot by intensity?
# (incompatible with sortByFirst)
sortEach <- T

# Log normalise the intensities?
logNorm=FALSE

# Saturate intensity above this quantile
satQuantile=0.95

# Basename for the outfile
outFile="test"

# Plot the std error as a ribbon in the profile plots?
profileStdErr=T

# Should each profile plot have a free y-axis scale
# or all subplots should have the same limits?
profileFreeScales=F

# Output dimensions for the graphical devices
# for heatmap and profiles.
heatW=7
heatH=14
profW=7
profH=8


#################################################
library("data.table")
library("reshape")
library("RColorBrewer")
library("ggplot2")

if ( sortByFirst & sortEach){
	stop("Incompatible options: sortEach and sortByFirst.")
	quit(save = "no", status = 1, runLast = FALSE)	
}

if (length(labels) != length(files)){
	stop("There must be the same number of files and labels")
	quit(save = "no", status = 1, runLast = FALSE)	
}

if (!is.na(secondaryLabels) & length(secondaryLabels) != length(labels)){
	stop("There must be the same number of primary and secondary labels")
	quit(save = "no", status = 1, runLast = FALSE)	
}


if (!is.na(secondaryLabels) & length(secondaryLabels)==1){
	stop("It's unnecessary to use secondary labels if you only have one file")
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
	
	if(!all(categories$Name == firstFileCatNames) | !all(categories$number == firstFileCatNumbers) | !all(dimensions$dim == firsFileDimensions)){
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

	# Keep track of how many columns contain data
	nfields <- ncol(mat)
	mat$Row <- 1:nrow(mat)

	# If this is not the first file, reorder based on the first file
	if(fileIndex!=1 & sortEach==FALSE){
		mat <- mat[origRowOrder,]
	}
	# Assign the categories and sort the entries of each category
	from=1
	for(i in 1:nrow(categories)){
		to <- from + categories[i,"number"] - 1
		if((fileIndex==1 & sortByFirst == TRUE) | sortEach==TRUE){
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

mm <- melt(mat2)





hmcol = colorRampPalette(brewer.pal(9, "GnBu"))(100)

# X Scale
binsize <- dimensions[4, "dim"]
downstream <- dimensions[dimensions$Name == "downstream", "dim"]/binsize
upstream <- dimensions[dimensions$Name == "upstream", "dim"]/binsize
body <- dimensions[dimensions$Name == "body", "dim"]/binsize

if(body==0){
	xscale <- scale_x_discrete(breaks=c(1, downstream, downstream+upstream), labels=c(paste("-", downstream*binsize/1000, "Kb", sep=""), "TSS", paste("+", upstream*binsize/1000, "Kb", sep="")))
} else {
	xscale <- scale_x_discrete(breaks=c(1, downstream, downstream+body, downstream+downstream+upstream), labels=c(paste("-", downstream*binsize/1000, "Kb", sep=""), "TSS", "TES", paste("+", upstream*binsize/1000, "Kb", sep="")))
	
}

# Faceting
if(nrow(categories)==1) {
   if (length(labels<2)) facets <- NA
   else if (length(labels)>=2 & is.na(secondaryLabels)) facets <- facet_grid(Label ~ ., scales = "free", space = "free")
   else if (length(labels)>=2 & !is.na(secondaryLabels)) facets <- facet_grid(Label ~ secLabel, scales = "free", space = "free")
}

if(nrow(categories)>1) {
   if (length(labels)<2){
	   facets <- facet_grid(Category ~ ., scales = "free", space = "free")
   }
   else if (length(labels)>=2 & is.na(secondaryLabels)) {
	   facets <- facet_grid(Category ~ Label, scales = "free", space = "free")
   }
   else if (length(labels)>=2 & !is.na(secondaryLabels)) {
	   facets <- facet_grid(secLabel+Category ~ Label, scales = "free", space = "free")
   }
}


# Scale fill
if(logNorm) {
	mm$value <- log10(mm$value + 1)
	fill <- scale_fill_gradientn(colours=hmcol)
}

if(!is.na(satQuantile)){
	fill <- scale_fill_gradientn(colours=hmcol, limits=c(0,quantile(mm$value, satQuantile)), oob=squish)
}

# Define names for outfiles
outFileHeatMap <- paste(outFile, "_heatmap.pdf", sep="")
outFileProfile <- paste(outFile, "_profile.pdf", sep="")



pdf(outFileHeatMap, width=heatW, height=heatH)
	print(ggplot(mm, aes(x=variable, y=Row, fill=value)) + geom_tile() + facets +  scale_y_discrete(breaks=NULL) + xscale + fill + theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust=0.5)))
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

# Faceting
if(nrow(categories)==1) {
   if (length(labels<2)) facets <- NA
   else if (length(labels)>=2 & is.na(secondaryLabels)) facets <- NA
   else if (length(labels)>=2 & !is.na(secondaryLabels)) facets <- facet_grid(~secLabel, scales=profScales)
}

if(nrow(categories)>1) {
   if (length(labels)<2){
           facets <- facet_grid(Category~., scales=profScales)
   }
   else if (length(labels)>=2 & is.na(secondaryLabels)) {
           facets <- facet_grid(Category~., scales=profScales)
   }
   else if (length(labels)>=2 & !is.na(secondaryLabels)) {
           facets <- facet_grid(Category~secLabel, scales=profScales)
   }
}

ribbon <- NA
if(profileStdErr){
	ribbon <- geom_ribbon(aes(ymin=mean-stderr, ymax=mean+stderr, fill=Label), alpha=0.3)
}


pdf(outFileProfile, width=profW, height=profH)
	print(ggplot(profiles, aes(x=variable, y=mean, group=Label)) + geom_line(aes(colour=Label)) + facets + ribbon + xscale)
dev.off()
