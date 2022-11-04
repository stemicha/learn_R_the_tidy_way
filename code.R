barplot(res$eig[,2], names.arg = 1:nrow(res$eig))
drawn <-
c("ST1258_RPMI_BR1_t4h", "HG001_RPMI_BR2_t4h", "HG001_TSB_BR1_exp", 
"HG001_TSB_BR2_exp", "ST1258_TSB_BR2_exp", "ST1258_TSB_BR3_exp", 
"HG001_RPMI_BR3_t4h", "HG001_TSB_BR3_t4h", "HG001_TSB_BR1_t4h", 
"HG001_TSB_BR2_t4h", "ST1258_TSB_BR3_t4h", "ST1258_TSB_BR1_t4h", 
"ST1258_TSB_BR2_t4h", "ST1258_TSB_BR1_exp")
plot.PCA(res, select = drawn, axes = 1:2, choix = 'ind', invisible = 'quali', title = '', cex = cex)
drawn <-
integer(0)
plot.PCA(res, select = drawn, axes = 1:2, choix = 'var', title = '', cex = cex)
drawn <-
c("ST1258_RPMI_BR1_t4h", "HG001_TSB_BR1_exp", "HG001_RPMI_BR2_t4h", 
"ST1258_TSB_BR2_t4h", "ST1258_RPMI_BR1_exp", "ST1258_TSB_BR1_t4h", 
"ST1258_RPMI_BR3_t4h", "ST1258_RPMI_BR3_exp", "HG001_RPMI_BR1_t4h", 
"HG001_RPMI_BR1_exp", "HG001_TSB_BR2_exp", "ST1258_RPMI_BR2_exp"
)
plot.PCA(res, select = drawn, axes = 3:4, choix = 'ind', invisible = 'quali', title = '', cex = cex)
drawn <-
integer(0)
plot.PCA(res, select = drawn, axes = 3:4, choix = 'var', title = '', cex = cex)
drawn <-
c("HG001_RPMI_BR2_t4h", "HG001_RPMI_BR3_t4h", "ST1258_RPMI_BR1_t4h", 
"HG001_RPMI_BR3_exp", "ST1258_RPMI_BR3_t4h", "ST1258_TSB_BR3_exp", 
"ST1258_RPMI_BR1_exp", "HG001_TSB_BR1_exp", "ST1258_TSB_BR2_t4h", 
"ST1258_RPMI_BR2_t4h", "ST1258_RPMI_BR2_exp", "HG001_RPMI_BR1_t4h", 
"ST1258_TSB_BR2_exp", "ST1258_TSB_BR1_exp")
plot.PCA(res, select = drawn, axes = 5:6, choix = 'ind', invisible = 'quali', title = '', cex = cex)
drawn <-
integer(0)
plot.PCA(res, select = drawn, axes = 5:6, choix = 'var', title = '', cex = cex)
res.hcpc = HCPC(res, nb.clust = -1, graph = FALSE)
drawn <-
c("ST1258_RPMI_BR1_t4h", "HG001_RPMI_BR2_t4h", "HG001_TSB_BR1_exp", 
"HG001_TSB_BR2_exp", "ST1258_TSB_BR2_exp", "ST1258_TSB_BR3_exp", 
"HG001_RPMI_BR3_t4h", "HG001_TSB_BR3_t4h", "HG001_TSB_BR1_t4h", 
"HG001_TSB_BR2_t4h", "ST1258_TSB_BR3_t4h", "ST1258_TSB_BR1_t4h", 
"ST1258_TSB_BR2_t4h", "ST1258_TSB_BR1_exp")
plot.HCPC(res.hcpc, choice = 'map', draw.tree = FALSE, select = drawn, title = '')
res.hcpc$desc.var
