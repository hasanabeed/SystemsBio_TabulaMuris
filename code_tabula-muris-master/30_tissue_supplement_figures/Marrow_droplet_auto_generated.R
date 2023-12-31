## ----setup---------------------------------------------------------------
library(knitr)
knit_hooks$set(optipng = hook_optipng)

## ------------------------------------------------------------------------
library(here)
source(here('30_tissue_supplement_figures', 'supplemental_figures.R'))
save_folder = here('30_tissue_supplement_figures', 'Marrow', 'droplet')
dir.create(save_folder, recursive=TRUE)
method = "droplet"

tissue_of_interest = 'Marrow'
filename = paste0('droplet_',tissue_of_interest, '_seurat_tiss.Robj')
load(here('00_data_ingest', '04_tissue_robj_generated', filename))

# Make sure cluster ids are numeric
tiss@meta.data[, 'cluster.ids'] = as.numeric(tiss@meta.data[, 'cluster.ids'])

# Concatenate original cell ontology class to free annotation
cell_ontology_class = tiss@meta.data$cell_ontology_class
cell_ontology_class[is.na(cell_ontology_class)] = "NA"

free_annotation = sapply(tiss@meta.data$free_annotation,
    function(x) { if (is.na(x)) {return('')} else return(paste(":", x))},
    USE.NAMES = FALSE)
tiss@meta.data[, "free_annotation"] = paste(cell_ontology_class,
    free_annotation, sep='')

additional.group.bys = sort(c())

group.bys = c(standard.group.bys, additional.group.bys)

genes_to_check = c("Ahnak", "Atxn1", "Beta-s", "Bpgm", "Camp", "Ccl3", "Ccr6", "Cd14", "Cd19", "Cd2", "Cd22", "Cd27", "Cd34", "Cd3e", "Cd4", "Cd40", "Cd44", "Cd48", "Cd68", "Cd7", "Cd74", "Cd79a", "Cd79b", "Cd8a", "Chchd10", "Cnp", "Cox6a2", "Cpa3", "Cr2", "Cxcr4", "Cxcr5", "Dntt", "Emr1", "Eng", "Fcer1a", "Fcer1g", "Fcer2a", "Fcgr3", "Fcgr4", "Flt3", "Gpr56", "Hbb-b2", "Hp", "Il3ra", "Il7r", "Irf8", "Itga2", "Itgal", "Itgam", "Itgax", "Itgb2", "Kit", "Klrb1a", "Lcn2", "Ltf", "Ly6d", "Mcpt8", "Mki67", "Mpeg1", "Mpl", "Ms4a1", "Ngp", "Pax5", "Pglyrp1", "Pld4", "Ptprc", "Rag1", "Rag2", "S100a11", "Slamf1", "Spn", "Stmn1", "Tfrc", "Thy1", "Tmem176b", "Vpreb1", "Vpreb3")

## ----use-optipng, optipng='-o7'------------------------------------------
dot_tsne_ridge(tiss, genes_to_check, save_folder, prefix = prefix,
    group.bys = group.bys, method = method)

## ------------------------------------------------------------------------
#tiss.markers <- FindAllMarkers(object = tiss, only.pos = TRUE, min.pct = 0.25, thresh.use = 0.25)
#filename = file.path(save_folder, paste(prefix, 'findallmarkers.csv', sep='_'))
#write.csv(tiss.markers, filename)

## ----optipng='-o7'-------------------------------------------------------
in_SubsetA = tiss@meta.data$cluster.ids == 2
in_SubsetA[is.na(in_SubsetA)] = FALSE


## ----optipng='-o7'-------------------------------------------------------
SubsetA.cells.use = tiss@cell.names[in_SubsetA]
write(paste("Number of cells in SubsetA subset:", length(SubsetA.cells.use)), stderr())
SubsetA.n.pcs = 6
SubsetA.res.use = 0.5
SubsetA.perplexity = 30
SubsetA.genes_to_check = c("A430084P05Rik", "Adamts14", "Car5b", "Ccl4", "Ccna2", "Ccr6", "Ccr7", "Cd160", "Cd19", "Cd1d1", "Cd22", "Cd34", "Cd3e", "Cd4", "Cd6", "Cd68", "Cd69", "Cd74", "Cd79a", "Cd79b", "Cd8a", "Cd8b1", "Chchd10", "Cma1", "Cnp", "Cr2", "Ctla2a", "Ctla4", "Cxcr5", "Cxcr6", "Dntt", "Egr2", "Emr1", "Foxp3", "Gzma", "H2-Aa", "H2-Ab1", "H2-Eb1", "Hp", "Il2ra", "Il2rb", "Il7r", "Itga4", "Itgax", "Itgb7", "Khdc1a", "Klra1", "Klrb1a", "Klrb1c", "Klrc1", "Lcn2", "Lef1", "Ly6c2", "Lyz2", "Mki67", "Mmp9", "Mpeg1", "Ms4a1", "Ncam1", "Ncr1", "Ngp", "Nkg7", "Pax5", "Pld4", "Prf1", "Rag1", "Rag2", "Rrm2", "Serpinb9", "Sh2d1b1", "Stmn1", "Styk1", "Tcf7", "Tnfrsf4", "Top2a", "Tyrobp", "Ugt1a7c", "Vpreb3")
SubsetA.group.bys = c(group.bys, "subsetA_cluster.ids")
SubsetA.tiss = SubsetData(tiss, cells.use=SubsetA.cells.use, )
SubsetA.tiss <- SubsetA.tiss %>% ScaleData() %>% 
  FindVariableGenes(do.plot = TRUE, x.high.cutoff = Inf, y.cutoff = 0.5) %>%
  RunPCA(do.print = FALSE)
SubsetA.tiss <- SubsetA.tiss %>% FindClusters(reduction.type = "pca", dims.use = 1:SubsetA.n.pcs, 
    resolution = SubsetA.res.use, print.output = 0, save.SNN = TRUE) %>%
    RunTSNE(dims.use = 1:SubsetA.n.pcs, seed.use = 10, perplexity=SubsetA.perplexity)


## ----optipng='-o7'-------------------------------------------------------
colors.use = c('LightGray', 'Coral')
tiss@meta.data[, "SubsetA"] = "(Not in subset)"
tiss@meta.data[SubsetA.tiss@cell.names, "SubsetA"] = "SubsetA" 
filename = make_filename(save_folder, prefix="SubsetA", 'highlighted', 
    'tsneplot_allcells')
p = TSNEPlot(
  object = tiss,
  do.return = TRUE,
  group.by = "SubsetA",
  no.axes = TRUE,
  pt.size = 1,
  no.legend = TRUE,
  colors.use = colors.use
) + coord_fixed(ratio = 1) +
    xlab("tSNE 1") + ylab("tSNE 2")
ggsave(filename, width = 4, height = 4)

filename = make_filename(save_folder, prefix="SubsetA", 'highlighted', 
    'tsneplot_allcells_legend')
# Plot TSNE again just to steal the legend
p = TSNEPlot(
    object = tiss,
    do.return = TRUE,
    group.by = "SubsetA",
    no.axes = TRUE,
    pt.size = 1,
    no.legend = FALSE,
    label.size = 8,
    colors.use = colors.use
    ) + coord_fixed(ratio = 1) +
    xlab("tSNE 1") + ylab("tSNE 2")

# Initialize an empty canvas!
ggdraw()
# Draw only the legend
ggdraw(g_legend(p))
ggsave(filename, width = 8, height = 4)
dev.off()


## ----optipng='-o7'-------------------------------------------------------
dot_tsne_ridge(SubsetA.tiss, SubsetA.genes_to_check,
    save_folder, prefix = "SubsetA", group.bys = SubsetA.group.bys, 
    "droplet")


## ----optipng='-o7'-------------------------------------------------------
in_SubsetB = tiss@meta.data$cluster.ids == 11
in_SubsetB[is.na(in_SubsetB)] = FALSE


## ----optipng='-o7'-------------------------------------------------------
SubsetB.cells.use = tiss@cell.names[in_SubsetB]
write(paste("Number of cells in SubsetB subset:", length(SubsetB.cells.use)), stderr())
SubsetB.n.pcs = 3
SubsetB.res.use = 1
SubsetB.perplexity = 30
SubsetB.genes_to_check = c("A430084P05Rik", "Car5b", "Ccl4", "Ccna2", "Ccr6", "Ccr7", "Cd160", "Cd19", "Cd1d1", "Cd22", "Cd34", "Cd3e", "Cd4", "Cd6", "Cd68", "Cd69", "Cd74", "Cd79a", "Cd79b", "Cd8a", "Cd8b1", "Chchd10", "Cnp", "Cr2", "Ctla2a", "Ctla4", "Cxcr5", "Cxcr6", "Dntt", "Egr2", "Foxp3", "Gzma", "H2-Aa", "H2-Ab1", "H2-Eb1", "Hp", "Il10", "Il2ra", "Il2rb", "Il7r", "Itga4", "Itgb7", "Klra1", "Klrb1a", "Klrb1c", "Klrc1", "Lcn2", "Lef1", "Ly6c2", "Lyz2", "Mki67", "Mmp9", "Mpeg1", "Ms4a1", "Ncam1", "Ngp", "Nkg7", "Pld4", "Prf1", "Rag2", "Rrm2", "Serpinb9", "Stmn1", "Tcf7", "Tgfb1", "Tnfrsf4", "Top2a", "Tyrobp", "Ugt1a7c", "Vpreb3")
SubsetB.group.bys = c(group.bys, "subsetB_cluster.ids")
SubsetB.tiss = SubsetData(tiss, cells.use=SubsetB.cells.use, )
SubsetB.tiss <- SubsetB.tiss %>% ScaleData() %>% 
  FindVariableGenes(do.plot = TRUE, x.high.cutoff = Inf, y.cutoff = 0.5) %>%
  RunPCA(do.print = FALSE)
SubsetB.tiss <- SubsetB.tiss %>% FindClusters(reduction.type = "pca", dims.use = 1:SubsetB.n.pcs, 
    resolution = SubsetB.res.use, print.output = 0, save.SNN = TRUE) %>%
    RunTSNE(dims.use = 1:SubsetB.n.pcs, seed.use = 10, perplexity=SubsetB.perplexity)


## ----optipng='-o7'-------------------------------------------------------
colors.use = c('LightGray', 'Coral')
tiss@meta.data[, "SubsetB"] = "(Not in subset)"
tiss@meta.data[SubsetB.tiss@cell.names, "SubsetB"] = "SubsetB" 
filename = make_filename(save_folder, prefix="SubsetB", 'highlighted', 
    'tsneplot_allcells')
p = TSNEPlot(
  object = tiss,
  do.return = TRUE,
  group.by = "SubsetB",
  no.axes = TRUE,
  pt.size = 1,
  no.legend = TRUE,
  colors.use = colors.use
) + coord_fixed(ratio = 1) +
    xlab("tSNE 1") + ylab("tSNE 2")
ggsave(filename, width = 4, height = 4)

filename = make_filename(save_folder, prefix="SubsetB", 'highlighted', 
    'tsneplot_allcells_legend')
# Plot TSNE again just to steal the legend
p = TSNEPlot(
    object = tiss,
    do.return = TRUE,
    group.by = "SubsetB",
    no.axes = TRUE,
    pt.size = 1,
    no.legend = FALSE,
    label.size = 8,
    colors.use = colors.use
    ) + coord_fixed(ratio = 1) +
    xlab("tSNE 1") + ylab("tSNE 2")

# Initialize an empty canvas!
ggdraw()
# Draw only the legend
ggdraw(g_legend(p))
ggsave(filename, width = 8, height = 4)
dev.off()


## ----optipng='-o7'-------------------------------------------------------
dot_tsne_ridge(SubsetB.tiss, SubsetB.genes_to_check,
    save_folder, prefix = "SubsetB", group.bys = SubsetB.group.bys, 
    "droplet")


