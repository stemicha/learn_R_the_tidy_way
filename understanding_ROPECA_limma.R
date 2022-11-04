ROPECA_stats_RPMI_exp %>% filter(new_symbol=="rho")

# signal log2 ratio : slr = 6.64 for rho

tmp<- peptide_data_ROPECA_in %>% filter(PG.ProteinGroups=="SAOUHSC_02362")

pairs <- combn(unique(file_conditions_ROPECA_in$R.Condition), 2)

i=4
samplenames1 <- as.character(file_conditions_ROPECA_in$R.FileName.short[file_conditions_ROPECA_in$R.Condition %in% pairs[1,i]])
#lookup group2
samplenames2 <- as.character(file_conditions_ROPECA_in$R.FileName.short[file_conditions_ROPECA_in$R.Condition %in% pairs[2,i]])


df <- tmp
id <- "PG.ProteinGroups"

probeintensities <- df
probenamesGene <- subset(probeintensities,select=id)
probeintensities <- subset(probeintensities,select=c(samplenames1,samplenames2))
probeintensities <- as.matrix(probeintensities)


# Log transformation
message("Performing log-transformation")
flush.console()
probeintensities <- probeintensities + 1
probeintensities <- log2(probeintensities)
colnames(probeintensities) <- c(samplenames1,samplenames2)



design <- cbind(G1=1,G1vsG2=c(rep(1,length(samplenames1)), rep(0,length(samplenames2))))
probeSLR <- as.matrix(cbind(probeintensities[,samplenames1], probeintensities[,samplenames2]))
fit <- lmFit(probeSLR, design) #defaul: "ls"
fit <- eBayes(fit)
probeSLR <- fit$coefficients[,2]
t <- fit$t[,2]


fit.ls<- lsfit(x = c(0,0,0,1,1,1),y = probeintensities[1,])


plot(x = c(0,0,0,1,1,1),y = probeintensities[1,])
abline(b= fit.ls$coefficients[2],a = fit.ls$coefficients[1])
points(x = 0,y=fit.ls$coefficients[1],col="red")
points(x = 1,y=1*fit.ls$coefficients[2]+fit.ls$coefficients[1],col="red")

tmp.val.group1=fit.ls$coefficients[1]
tmp.val.group2=1*fit.ls$coefficients[2]+fit.ls$coefficients[1]
tmp.val.group1-tmp.val.group2
