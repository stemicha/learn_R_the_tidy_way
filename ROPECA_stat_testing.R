#########################################
## Run ROPECA
#########################################
# load the library
library(PECA)
library(foreach)
library(doParallel)
library(tidyverse)

setwd("~/Desktop/courses/R_course/R_course___learn_R_the_tidy_way__Michalik")

peptide_data <- read_delim(file = "peptide_data.txt",delim = "\t",col_names = T)
peptide_data_ROPECA_in <- peptide_data %>% 
  select(PG.ProteinGroups,PEP.StrippedSequence,peptide_Intensity,R.FileName.short) %>% 
  spread(key = R.FileName.short,value=peptide_Intensity)
#write_delim(x = peptide_data,path = "peptide_data.txt",delim = "\t",col_names = T)

file_conditions_ROPECA_in <- peptide_data %>% distinct(R.FileName.short,R.Condition,strain,media_growth_phase)
# ROPECA
#setup comparison pairs by using combn() function
pairs <- combn(unique(file_conditions_ROPECA_in$R.Condition), 2)
 
#Start a cluster
cl <- parallel::makeCluster(4, outfile = "") # number of cores.
registerDoParallel(cl) #register cores

#setup the progressbar 
pb <- txtProgressBar(0, ncol(pairs), style = 3)
#do calculation in parallel
results.ropeca <- foreach(i=1:ncol(pairs), .combine=rbind.data.frame) %dopar% { #use the foreach function in parallel processing mode (dopar)
  setTxtProgressBar(pb, i) #update progressbar
  #lookup group1
  group1 <- as.character(file_conditions_ROPECA_in$R.FileName.short[file_conditions_ROPECA_in$R.Condition %in% pairs[1,i]])
  #lookup group2
  group2 <- as.character(file_conditions_ROPECA_in$R.FileName.short[file_conditions_ROPECA_in$R.Condition %in% pairs[2,i]])
  #calculate ROPECA
  peca.out <- suppressMessages(PECA::PECA_df(df = as.data.frame(peptide_data_ROPECA_in),#input data.frame
                      id =  "PG.ProteinGroups",#set the protein ID column
                      samplenames1 =  group1,#string input for the group1
                      samplenames2 =  group2,#string input for the group2
                      test="rots",#use the ROTS test
                      type="median",#do the median test
                      normalize=FALSE,#no normalization since normalization should be done upfront (e.g. median norm.)
                      paired=FALSE,
                      progress = F))
  peca.out$PG.ProteinGroups <- rownames(peca.out) #add the rownames as column
  peca.out$group1 <- pairs[1,i]#add group1 from the pairwise comparison
  peca.out$group2 <- pairs[2,i]#add group2 from the pairwise comparison
  peca.out# output for the for loop
}
close(pb)#closing progressbar
stopCluster(cl)#closing cluster for parallel computing

#convert the output to a tibble and therefore replace rownames with numbers
results.ropeca <- as.tibble(results.ropeca)

write_delim(x = results.ropeca,path = "ROPECA_test_results_pairwise_comparisons__rho_project.txt",delim = "\t",col_names = T)


#results.ropeca <- read_delim("ROPECA_test_results_pairwise_comparisons__rho_project.txt",delim = "\t",col_names = T)
#
#
#results.ropeca <- results.ropeca %>% 
#       separate(col = group1,into = c("group1_strain","group1_media","group1_phase"),sep = "_",remove = F) %>% 
#       separate(col = group2,into = c("group2_strain","group2_media","group2_phase"),sep = "_",remove = F)
#
#
#results.ropeca_filter <- results.ropeca %>% 
#                          filter(group1_strain=="HG"&group2_strain=="ST") %>% 
#                          filter((group1_media=="RPMI" & group2_media=="RPMI") | (group1_media=="TSB" & group2_media=="TSB") ) %>% 
#                          filter((group1_phase=="exp" & group2_phase=="exp") | (group1_phase=="stat" & group2_phase=="stat") )
#
#results.ropeca_filter %>% distinct(group1,group2)
#
#write_delim(x = results.ropeca_filter,path = "ROPECA_test_results_pairwise_comparisons__rho_project_filtered.txt",delim = "\t",col_names = T)


