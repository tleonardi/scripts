calcContext <- function(vienna){
        require(R4RNA)
        vienna <- as.character(vienna)
        helix <- viennaToHelix(vienna)[,c(1,2)]
        v <- unlist(strsplit(vienna, split=""))
        a <- rep(".", length(v))

        # Set paired regions
        a[c(helix$i, helix$j)] <- "p"

        # Set 5' external regions
        i=1;
        while(a[i] =="."){
                a[i] <- "e"
                i=i+1
        }
        # Set 3' external regions
        i=length(a);
        while(a[i] =="."){
                a[i] <- "e"
                i=i-1
        }
        # d and dd will store the distance between consecutive
        # nucleotides of helix for the 5' arm (d) and 3' arm (dd)
        d <- numeric()
        dd <- numeric()

        # Loop through helix and calculate the distance between
        # consecutive nucleotides to find the missing ones
        i=1
        for(i in 1:length(helix$i)){
                d[i] <- helix$i[i]-helix$i[i-1]
                dd[i] <- helix$j[i-1]-helix$j[i]
                i=i+1
        }

        # If there are missing nucleotides (d!=dd)
        # but only in one strand (d==1|dd==1), then
        # it is a bulge
        i=1
        for(i in which(d!=dd & (d==1|dd==1))){

                # If the bulge is in the 5' strand
                if(helix$i[i] - helix$i[i-1] >1){
                        a[seq(helix$i[i-1]+1, helix$i[i]-1)] <- "b"

                }

                # If the bulge is in the 3' strand
                if(helix$j[i-1] - helix$j[i] >1){
                        a[seq(helix$j[i]+1, helix$j[i-1]-1)] <- "b"
                }
        }

        # Everything else is a loop
        a[a=="."] <- "l"

        return(paste(a, sep="", collapse=''))
}
vcalcContext <- Vectorize(calcContext)
