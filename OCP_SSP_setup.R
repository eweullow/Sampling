# OCP-Nigeria soil sampling plan setup
# M. Walsh, December 2015

# Required packages
# install.packages(c("downloader","raster","rgdal","sampling")), dependencies=TRUE)
require(downloader)
require(rgdal)
require(raster)
require(sampling)

# Data download ------------------------------------------------------------
# Create a "Data" folder in your current working directory
dir.create("OCP_SSP", showWarnings=F)
setwd("./OCP_SSP")

# download current 1 km GeoSurvey cropland mask
download("https://www.dropbox.com/s/ed9m9opaenc7tyv/CRP_mask.csv.zip?dl=0", "CRP_mask.csv.zip", mode="wb")
unzip("CRP_mask.csv.zip", overwrite=T)
crpmk <- read.table("CRP_mask.csv", header=T, sep=",")

# download grids
download("https://www.dropbox.com/s/vewvi0l1o949yh2/OCP_grids.zip?dl=0", "OCP_grids.zip", mode="wb")
unzip("OCP_grids.zip", overwrite=T)
glist <- list.files(pattern="tif", full.names=T)
grids <- stack(glist)

# download admin unit names by LGA ID's
download("https://www.dropbox.com/s/20tkxozgxu1jbgl/Admin_units.csv?dl=0", "Admin_units.csv", mode="wb")
admin <- read.table("Admin_units.csv", header=T, sep=",")

# Data setup ---------------------------------------------------------------
# generate AfSIS 10k GIDs
res.pixel <- 10000
xgid <- ceiling(abs(crpmk$x)/res.pixel)
ygid <- ceiling(abs(crpmk$y)/res.pixel)
gidx <- ifelse(crpmk$x<0, paste("W", xgid, sep=""), paste("E", xgid, sep=""))
gidy <- ifelse(crpmk$y<0, paste("S", ygid, sep=""), paste("N", ygid, sep=""))
GID10k <- paste(gidx, gidy, sep="-")
crpmk <- cbind(crpmk, GID10k)

# extract gridded variables at survey locations
coordinates(crpmk) <- ~x+y
projection(crpmk) <- projection(grids)
crpgrid <- extract(grids, crpmk)
crpmk <- as.data.frame(crpmk)
crpmk <- cbind.data.frame(crpmk, crpgrid)
crpmk <- merge(admin, crpmk, by="LGA_ID") ## add State & LGA names

# Tabulate locations by LGAs & GID10k -------------------------------------
# identify suitable 10k GIDs
psites <- as.data.frame(with(crpmk, table(LGA_name, GID10k)))
psites <- psites[ which(psites$Freq > 80), ] ## select site if frequency of suitable locations is >80%
psites <- psites[ order(psites$LGA_name, psites$GID10k), ]
write.csv(psites, "Potential Sites.csv", row.names=F)

# identify suitable LGAs
plga <- as.data.frame(with(psites, table(LGA_name)))
plga <- plga[ which(plga$Freq > 3), ] ## select LGA if suitable GIDs >3 per LGA
write.csv(plga, "Potential LGAs.csv", row.names=F)

# Sample suitable GIDs ----------------------------------------------------
# sample 1 suitable 10k GID (Site) per LGA
set.seed(1385321)
slga <- as.vector(sample(plga$LGA_name, 60)) ## sample 60 LGAs
psites <- psites[psites$LGA_name%in%slga, ] ## identify potential GIDs within sampled LGAs
sample <- strata(psites, "LGA_name", size = rep(1, length(slga)), method="srswor") ## sample suitable GIDs
ssites <- getdata(psites, sample)
write.csv(ssites, "Sampled Sites.csv", row.names=F)

# Sample 10 suitable 1k GIDs (Clusters) per Site
set.seed(5321)
pGID10 <- as.vector(ssites$GID10k) 
pclust <- crpmk[crpmk$GID10k%in%pGID10, ] ## identify potentially suitable 1k clusters
sample <- strata(pclust, "GID10k", size = rep(10, length(slga)), method="srswor") ## sample suitable 1k clusters
sclust <- getdata(pclust, sample)
sclust <- sclust[ order(sclust$LGA_name, sclust$GID10k), ]
write.csv(sclust, "Sampled Clusters.csv", row.names=F)


