## ----setup---------------------------------------------------------------
library(knitr)
knit_hooks$set(optipng = hook_optipng)

## ------------------------------------------------------------------------
library(here)
source(here('30_tissue_supplement_figures', 'supplemental_figures.R'))
save_folder = here('30_tissue_supplement_figures', 'Brain_Non-Myeloid', 'facs')
dir.create(save_folder, recursive=TRUE)
method = "facs"

tissue_of_interest = 'Brain_Non-Myeloid'
filename = paste0('facs_',tissue_of_interest, '_seurat_tiss.Robj')
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

additional.group.bys = sort(c("subtissue"))

group.bys = c(standard.group.bys, additional.group.bys)

genes_to_check = c("Aldh1l1", "Aqp4", "Ascl1", "Calb1", "Cldn5", "Cspg4", "Dcx", "Des", "Dlx2", "Eno2", "Gad1", "Gjc2", "Ly6c1", "Mab21l1", "Mag", "Mcam", "Mobp", "Mog", "Mpo", "Neurod6", "Ocln", "Pdgfra", "Pdgfrb", "Pecam1", "Rbfox3", "Reln", "Slc17a7", "Slc1a3", "Slco1c1", "Snap25", "Susd5")

## ----use-optipng, optipng='-o7'------------------------------------------
dot_tsne_ridge(tiss, genes_to_check, save_folder, prefix = prefix,
    group.bys = group.bys, method = method)

## ------------------------------------------------------------------------
#tiss.markers <- FindAllMarkers(object = tiss, only.pos = TRUE, min.pct = 0.25, thresh.use = 0.25)
#filename = file.path(save_folder, paste(prefix, 'findallmarkers.csv', sep='_'))
#write.csv(tiss.markers, filename)

## ------------------------------------------------------------------------
endo.sub<-tiss@raw.data[, grep("endothelial",tiss@meta.data$cell_ontology_class)]
endo<-grep("endothelial",tiss@meta.data$cell_ontology_class)
endo.sub.names<-colnames(tiss@scale.data)[endo]
endo.sub<-tiss@raw.data[,endo.sub.names]


## ------------------------------------------------------------------------
library(dplyr)
library(Matrix)
library(cowplot)
library(matrixStats)  # for colMins
require(RColorBrewer)
library(rrcov)        # For PcaHubert
library(data.table)   # for data.table
library(parallel)     # For mclapply

## ------------------------------------------------------------------------

# return minimum (most negative) correlation value for each gene
get.gene.cor <- function(data, min.cells.expr = 1) {
  mat = t(data[, colSums(data > 0) > min.cells.expr]) # filter genes
  mat = mat - rowMeans(mat)
  cr = tcrossprod( mat/sqrt(rowSums(mat^2)) )
  return(cr)
}
get.min.cor <- function(data, min.cells.expr = 1) {
  require(matrixStats)
  cr = get.gene.cor(data, min.cells.expr)
  min.cor = colMins(cr, na.rm =T)
  names(min.cor) = colnames(cr)
  return(min.cor)
}


## robust PCA function
do.robpca <- function(data.counts,min_cells=0,min_sd=0,ncp=10,expression.values="log10.cpm",from.mat = T,...){
  require(rrcov)
  if(!from.mat){
    if(min_cells>0){
      data<-filter.genes(data.counts,expression.values,min_sd,min_cells)
    } else{ cast.counts <- cast.to.df(data.counts,expression.values) }
  } else {
    cast.counts = data.counts[, colSums(data.counts > 0) > min_cells]
  }
  print('starting rPCA')
  pca <- PcaHubert(cast.counts, k = ncp,kmax=ncp,...)
  rm(cast.counts);gc()
  scores <- as.data.frame(getScores(pca));scores$cell.name <- rownames(scores); scores <- data.table(scores);setkey(scores)
  var   <- as.data.frame(getLoadings(pca)); var$gene <- rownames(var);var <- as.data.table(var);setkey(var)
  gc()
  list(pca, scores, var)
}

filter.genes <- function(data.counts,expression.value="log10.cpm",min_sd=0,min_cells=0){
  data=copy(data.counts);
  data[,numcells_exp:=sum(get(expression.value)>0),by=gene]; data<-data[numcells_exp>min_cells]
  data[,gene_sd:=sd(get(expression.value)),by=gene]; data<-data[gene_sd>min_sd]
  data
}


## cast to dataframe function
cast.to.df <- function(data.counts,expression.values="log10.cpm",annot="none", to.matrix = F, genes.use = NULL){
  if(!is.null(genes.use)) data.counts = data.counts[gene %in% genes.use]
  if(annot != "none"){
    cast.counts <- dcast.data.table(data.counts, cell.name ~ gene, value.var=expression.values, fill = 0)
    setkey(data.counts)
    cast.counts <- merge(cast.counts,unique(data.counts[,.(cell.name,get(annot))]),by="cell.name")
    setnames(cast.counts,c(colnames(cast.counts)[1:(ncol(cast.counts)-1)],annot))
    cast.counts <- as.data.frame(cast.counts)
  }
  else{
    cast.counts <- as.data.frame(dcast.data.table(data.counts, cell.name ~ gene, value.var=expression.values,fill=0))
    gc()
  }
  rownames(cast.counts)<-cast.counts$cell.name; cast.counts <- cast.counts[,c(ncol(cast.counts),2:(ncol(cast.counts)-1))]
  if(to.matrix) cast.counts = as.matrix(cast.counts)
  cast.counts
}



## ------------------------------------------------------------------------
ECs<-CreateSeuratObject(raw.data=endo.sub, min.cells=5, min.genes=5) # already filter zero count genes
colnames(ECs@meta.data)[colnames(ECs@meta.data)=='nUMI']<-'nReads' ##change name

#Add ribo data
ribo.genes<-grep(pattern="^Rp[s1][[:digit:]]", x=rownames(x=ECs@data), value=TRUE) ##60
percent.ribo<-Matrix::colSums(ECs@raw.data[ribo.genes, ])/Matrix::colSums(ECs@raw.data)
ECs <- AddMetaData(object = ECs, metadata = percent.ribo, col.name = "percent.ribo")

#Add mito data
mito.genes <- grep(pattern = "^mt-", x = rownames(x = ECs@data), value = TRUE)
percent.mito <- Matrix::colSums(ECs@raw.data[mito.genes, ])/Matrix::colSums(ECs@raw.data)
ECs <- AddMetaData(object = ECs, metadata = percent.mito, col.name = "percent.mito")

GenePlot(object = ECs, gene1 = "nReads", gene2 = "nGene")

ECs <- FilterCells(object = ECs, subset.names = c("nGene", "nReads"), low.thresholds = c(200, 20000), high.thresholds = c(25000, Inf))
ECs <- NormalizeData(object = ECs)
ECs <- ScaleData(object = ECs)


## ------------------------------------------------------------------------

DF<-as.data.frame(cbind(tiss@cell.names, as.character(tiss@meta.data$subtissue)))
rownames(DF)<-DF$V1
ECs@meta.data$subtissue<-as.character(DF[ECs@cell.names, 2])


## ------------------------------------------------------------------------

data.pca <- t(log2(1+1e6*(t(t(ECs@raw.data)/colSums(ECs@raw.data))))) ##log 2 normalize data
gene.min.cors <- get.min.cor(data.pca, min.cells.expr = 2)
genes.use <- names(sort(gene.min.cors)[1:2500])

# Remove some housekeeping genes
genes.use <- genes.use[grep('^Rp[ls].*', genes.use, invert = T)]
genes.use <- genes.use[grep('Rn45s', genes.use, invert = T)]
genes.use <- genes.use[grep('Lars2', genes.use, invert = T)]
genes.use <- genes.use[grep('Malat1', genes.use, invert = T)]

ncp=20
num.sig.genes <- 30

pcalist <- do.robpca(data.pca[, genes.use],ncp = ncp, from.mat = T)
loadings <- pcalist[[3]]
sdev<-pcalist[[1]]
sdev<-sdev@sd
data.scaled<-t(t(data.pca[,genes.use]) / colMaxs(data.pca[,genes.use]))

library(pbapply)
dims <- paste0('PC', 1:ncp) ## 1:20
pc.sigs <- as.data.frame(do.call(cbind, lapply(dims, function(dim) {
  setorderv(loadings,dim,-1)
  genes.pos <- loadings[,gene][1:num.sig.genes]
  setorderv(loadings,dim,1)
  genes.neg <- loadings[,gene][num.sig.genes:1]
  cast.sig <- as.data.frame(cbind(rowSums(data.scaled[, genes.pos]), rowSums(data.scaled[, genes.neg])))
  print(head(cast.sig))
  cast.sig$pc.score <- cast.sig[, 1] - cast.sig[, 2]
  colnames(cast.sig) <- c(paste0(dim,'.pos'), paste0(dim,'.neg'), dim)
  return(as.matrix(cast.sig))
  }
)))

pc.sigs <- pc.sigs[match(ECs@cell.names, rownames(pc.sigs)), ]
pc.sigs <- as.matrix(pc.sigs[, grepl("PC[0-9]+$", colnames(pc.sigs))])
ECs <- SetDimReduction(ECs, 'pca', 'cell.embeddings', new.data = pc.sigs)
pc.loadings<-loadings[,1:20]
pc.loadings<-as.matrix(pc.loadings)
rownames(pc.loadings)<-loadings$gene
ECs <- SetDimReduction(ECs, 'pca', 'gene.loadings', new.data = pc.loadings)
ECs@dr$pca@key<-"PC"


## ------------------------------------------------------------------------

ECs <- FindClusters(object = ECs, reduction.type = "pca", dims.use = 1:15,
    resolution = 1, print.output = 0, save.SNN = TRUE, force.recalc = T)

ECs <- RunTSNE(object = ECs, dims.use = 1:8, seed.use = 10, check_duplicates = F, perplexity=40)
  
# unsupervised clustering
prefix = 'EndothelialCells'
filename = make_filename(save_folder, prefix, 'cluster.ids', 'tsneplot')
TSNEPlot(object = ECs, do.label = T, label.size = 6, pt.size = 3.1, colors.use = brewer.pal(11,'Paired'), do.return=TRUE) + labs(x = "tSNE 1", y="tSNE 2")+ theme(axis.title.x = element_text(colour = "black", size=16), axis.title.y = element_text(colour = "black", size=16), legend.text=element_text(size=13))
ggsave(filename, dpi=300)
dev.off()
write_caption("Subclustering of endothelial cells grouped by cluster ID.", filename)

#annotated by brain subregion
filename = make_filename(save_folder, prefix, 'subtissue', 'tsneplot')
TSNEPlot(object = ECs, do.label = T, label.size = 6, pt.size = 3.1, colors.use = brewer.pal(9,'Set1'), do.return=TRUE, group.by="subtissue") + labs(x = "tSNE 1", y="tSNE 2")+ theme(axis.title.x = element_text(colour = "black", size=16), axis.title.y = element_text(colour = "black", size=16), legend.text=element_text(size=13))
ggsave(filename, dpi=300)
dev.off()
write_caption("Subclustering of endothelial cells colored by brain region.", filename)

PCHeatmap(object = ECs, pc.use = 1:12, cells.use = 300, do.balanced = TRUE, label.columns = FALSE, num.genes = 20)
PCAPlot(object = ECs, dim.1 = 1, dim.2 = 2, pt.size = 2)


#plots of key defining genes for the Inflamed (Venous) and Notch (Arterial) populations
genes_check<-c('Vcam1','Icam1','Lcn2','Hif1a','Vwf','Csf1','Notch1','Hey1','Vegfc','Edn1','Tmem100')

filename = make_filename(save_folder, prefix, 'venous-arterial', 'featureplot')
FeaturePlot(ECs, features.plot=genes_check, pt.size = 2, no.axes = T,
    cols.use = c("lightgray", "red"), dark.theme = F, no.legend = FALSE)
ggsave(filename, dpi=300)
dev.off()
write_caption("Key defining genes for the Inflamed (Venous) and Notch (Arterial) populations.", filename)

filename = make_filename(save_folder, prefix, 'subtissue', 'ridgeplot')
filename = violinplot_and_save(tiss, save_folder, prefix=prefix,
    group.by='subtissue',
    genes=genes_check, colors.use=brewer.pal(11,'Paired'), method=method)
write_caption("Key defining genes for the Inflamed (Venous) and Notch (Arterial) populations.", filename)

## ------------------------------------------------------------------------


DE_markers <- mclapply(levels(ECs@ident),  function(x) {
  df <- FindMarkers(object = ECs, ident.1 = x, only.pos = TRUE, min.pct = 0.20, thresh.use = 0.20)
  df$gene <- rownames(df)
  df$cluster <- x
  return(df)
  }, mc.cores = 2)
DE_markers <- bind_rows(DE_markers)

DE_markers <- DE_markers[DE_markers$p_val<0.05, ]
DE_markers_sorted <- DE_markers %>% group_by(cluster) %>% top_n(10, avg_logFC)


DoHeatmap(object = ECs, genes.use = DE_markers_sorted$gene, slim.col.label = TRUE, remove.key = FALSE, cex.row = 7)



## ------------------------------------------------------------------------

current.cluster.ids <- c(0, 1, 2, 3, 4)
new.cluster.ids <- c("Capillary/BBB-maintenance", "Capillary/BBB-maintenance","Arterial/Notch-signaling", "Capillary/BBB-maintenance", "Venous/inflammatory")
ECs@ident <- plyr::mapvalues(x = ECs@ident, from = current.cluster.ids, to = new.cluster.ids)
ECs<-StashIdent(object=ECs, save.name="Annotation") ## for more clusters


filename = here('00_data_ingest', paste(tissue_of_interest, 'EndothelialCells',
    "seurat_tiss.Robj", sep='_'))
print(filename)
save(ECs, file=filename)

filename = make_filename(save_folder, prefix, group.by='function_and_vessel_type', plottype='tsneplot')
TSNEPlot(object = ECs, do.label = FALSE, pt.size = 3, colors.use = brewer.pal(8,'Set2'),
    do.return=TRUE) + labs(x = "tSNE 1", y="tSNE 2")+ theme(axis.title.x = element_text(colour = "black", size=16), axis.title.y = element_text(colour = "black", size=16), legend.text=element_text(size=13))
ggsave(filename, dpi=300)
#dev.off()
write_caption("Subclustering of endothelial cells colored by function and vessel type.", filename)

## ------------------------------------------------------------------------
filename = make_filename(save_folder, prefix, group.by='function_and_vessel_type', plottype='featureplot')
features.plot <- c("Vwf","Flt4","Nr2f2","Ephb4","Car4","Slc16a1","Tfrc","Efnb2","Jag1","Bmx")
FeaturePlot(ECs, features.plot=features.plot, pt.size = 2, no.axes = T,
    cols.use = c("lightgray", "red"), dark.theme = F, no.legend = FALSE)
ggsave(filename, dpi=300)
#dev.off()
write_caption("Key defining genes for function and vessel type.", filename)

filename = make_filename(save_folder, prefix, group.by='function_and_vessel_type', plottype='dotplot')
DotPlot(object = ECs, genes.plot = features.plot, plot.legend = TRUE,group.by = "Annotation", x.lab.rot = F)
ggsave(filename, dpi=300)
#dev.off()
write_caption("Key defining genes for function and vessel type.", filename)

## ----optipng='-o7'-------------------------------------------------------
in_SubsetA = tiss@meta.data$cluster.ids == 2
in_SubsetA[is.na(in_SubsetA)] = FALSE


## ----optipng='-o7'-------------------------------------------------------
SubsetA.cells.use = tiss@cell.names[in_SubsetA]
write(paste("Number of cells in SubsetA subset:", length(SubsetA.cells.use)), stderr())
SubsetA.n.pcs = 10
SubsetA.res.use = 1
SubsetA.perplexity = 30
SubsetA.genes_to_check = c("A2m", "Aldh1l1", "Aqp4", "Gdf10", "Gfap", "Naga", "Nbl1", "Nsdhl", "Slc1a3", "St6galnac5", "Tnfaip2", "Vim")
SubsetA.group.bys = c(group.bys, "subsetA_cluster.ids")
SubsetA.tiss = SubsetData(tiss, cells.use=SubsetA.cells.use, )
SubsetA.tiss <- SubsetA.tiss %>% ScaleData() %>% 
  FindVariableGenes(do.plot = TRUE, x.high.cutoff = Inf, y.cutoff = 0.5) %>%
  RunPCA(do.print = FALSE)
SubsetA.tiss <- SubsetA.tiss %>% FindClusters(reduction.type = "pca", dims.use = 1:SubsetA.n.pcs, 
    resolution = SubsetA.res.use, print.output = 0, save.SNN = TRUE) %>%
    RunTSNE(dims.use = 1:SubsetA.n.pcs, seed.use = 10, perplexity=SubsetA.perplexity)


## ----optipng='-o7'-------------------------------------------------------
group.bys = c(group.bys, "subtissue")

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
    save_folder, prefix = "SubsetA-Astrocytes", group.bys = SubsetA.group.bys, 
    "facs")


