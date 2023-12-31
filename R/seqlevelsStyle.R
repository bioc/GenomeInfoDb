### =========================================================================
### seqlevelsStyle() and related low-level utilities
### -------------------------------------------------------------------------


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### .set_seqlevelsStyle_from_seqlevels_and_genome()
###
### This is the workhorse behing the seqlevelsStyle() setter for Seqinfo
### objects.
###

### 'genome' must be a single string.
### Return "NCBI", "UCSC", or a character NA.
.is_NCBI_assembly_or_UCSC_genome <- function(genome)
{
    NCBI_assemblies <- registered_NCBI_assemblies()
    if (genome %in% NCBI_assemblies[ , "assembly"])
        return("NCBI")
    UCSC_genomes <- registered_UCSC_genomes()
    if (genome %in% UCSC_genomes[ , "genome"])
        return("UCSC")
    ## We try getChromInfoFromUCSC(). It will succeed if genome is a valid
    ## (unregistered) UCSC genome, and will fail otherwise.
    ## Note that getChromInfoFromUCSC() uses an in-memory caching mechanism
    ## so will be fast and won't need internet access if the chromosome
    ## information for 'genome' is already in the cache. If 'genome' is not
    ## in getChromInfoFromUCSC's cache, getChromInfoFromUCSC() will try to
    ## fetch the chromosome sizes from UCSC with fetch_chrom_sizes_from_UCSC()
    ## and will fail if 'genome' is an unknown UCSC genome. This is the only
    ## situation where internet is accessed.
    chrominfo <- try(getChromInfoFromUCSC(genome), silent=TRUE)
    if (!inherits(chrominfo, "try-error"))
        return("UCSC")
    NA_character_
}

### A RefSeq accession begins with 2 or 3 upper case letters. Note that
### the 3-letter prefix is rare e.g. chromosome 2 in NCBI33 (hg15) has
### accession GPC_000001061.1.
.is_RefSeq_accession <- function(seqnames)
    grepl("^[A-Z][A-Z][A-Z]?_[0-9]+\\.[0-9]+$", seqnames)

.get_seqlevelsStyle_for_NCBI_seqlevels <- function(seqlevels)
{
    is_refseq <- .is_RefSeq_accession(seqlevels)
    if (all(is_refseq))
        return("RefSeq")
    if (any(is_refseq))
        return(c("RefSeq", "NCBI"))
    "NCBI"
}

### Will map GRCh38 and any GRCh38 patch level to hg38. This will allow
### us to switch the style of stuff like SNPlocs.Hsapiens.dbSNP144.GRCh38
### (based on GRCh38.p2) to UCSC.
.map_NCBI_assembly_to_UCSC_genome <- function(assembly)
{
    stopifnot(isSingleString(assembly))
    UCSC_genomes <- registered_UCSC_genomes()
    NCBI_assemblies <- UCSC_genomes[ , "NCBI_assembly"]
    idx <- match(assembly, NCBI_assemblies)
    if (!is.na(idx))
        return(UCSC_genomes[idx, "genome"])
    ## Remove patch level suffix (e.g. ".p2")
    base_assembly <- sub("^(.*)(\\.p[0-9]+)$", "\\1", assembly)
    NCBI_base_assemblies <- sub("^(.*)(\\.p[0-9]+)$", "\\1", NCBI_assemblies)
    idx <- match(base_assembly, NCBI_base_assemblies)
    UCSC_genomes[idx, "genome"]
}

### Will map hg38 to GRCh38.p14 because that's what hg38 is officially based
### on at the moment (as of Jan 31, 2023, used to be GRCh38.p13 before that).
### See https://genome.ucsc.edu/cgi-bin/hgGateway?db=hg38
### Note that this is not written in stone and the UCSC folks might
### change this at any time in the future.
### IMPORTANT: A round trip thru .map_NCBI_assembly_to_UCSC_genome() and
### .map_UCSC_genome_to_NCBI_assembly() is in general a no-op **except**
### for NCBI assemblies with patch levels! For example the round trip will
### map any GRCh38 patch level to GRCh38.p14.
.map_UCSC_genome_to_NCBI_assembly <- function(genome)
{
    stopifnot(isSingleString(genome))
    UCSC_genomes <- registered_UCSC_genomes()
    idx <- match(genome, UCSC_genomes[ , "genome"])
    UCSC_genomes[idx, "NCBI_assembly"]
}

.map_NCBI_or_RefSeq_seqlevels_to_UCSC <- function(seqlevels, new_genome)
{
    chrominfo <- getChromInfoFromUCSC(new_genome, map.NCBI=TRUE)
    UCSC_seqlevels <- chrominfo[ , "chrom"]
    SequenceName <- chrominfo[ , "NCBI.SequenceName"]
    RefSeqAccn <- chrominfo[ , "NCBI.RefSeqAccn"]
    m <- match(seqlevels, SequenceName)
    m2 <- match(seqlevels, RefSeqAccn)
    m[is.na(m)] <- m2[is.na(m)]
    UCSC_seqlevels[m]
}

### Returns the new seqlevels in a named character vector parallel
### to 'seqlevels'. The returned vector will contain NA's for input
### seqlevels that could not be mapped, and the names on those elements
### will be set to "". The names on the non-NA elements (mapped seqlevels)
### will be set to the NCBI assembly associated with 'genome'.
.map_UCSC_seqlevels_to_NCBI_or_RefSeq <- function(seqlevels, genome, new_style)
{
    chrominfo <- getChromInfoFromUCSC(genome, map.NCBI=TRUE)
    UCSC_seqlevels <- chrominfo[ , "chrom"]
    if (new_style == "NCBI") {
        NCBI_seqlevels <- chrominfo[ , "NCBI.SequenceName"]
    } else {
        NCBI_seqlevels <- chrominfo[ , "NCBI.RefSeqAccn"]
    }
    m <- match(seqlevels, UCSC_seqlevels)
    new_seqlevels <- NCBI_seqlevels[m]

    ## Set names (new genome) on 'new_seqlevels'.
    new_genome <- character(length(new_seqlevels))
    NCBI_assembly_info <- attributes(chrominfo)$NCBI_assembly_info
    new_genome[!is.na(new_seqlevels)] <- NCBI_assembly_info$assembly
    setNames(new_seqlevels, new_genome)
}

### UGLY HACK! We need to special-case hg38 because it contains 2 sequences
### that do NOT belong to GRCh38.p14. But they can be found in GRCh38.p13!
.hg38_FOREIGN_ASSEMBLY <- "GRCh38.p13"
.hg38_FOREIGN_MAPPINGS <- c(chr11_KQ759759v1_fix="KQ759759.1",
                            chr22_KQ759762v1_fix="KQ759762.1")

.map_NCBI_or_RefSeq_seqlevels_to_hg38 <- function(seqlevels)
{
    new_seqlevels <- .map_NCBI_or_RefSeq_seqlevels_to_UCSC(seqlevels, "hg38")

    ## Take care of the foreign sequences. Note that they are not
    ## necessarily present in 'seqlevels'.
    chrominfo <- getChromInfoFromNCBI(.hg38_FOREIGN_ASSEMBLY)
    foreign_idx <- match(.hg38_FOREIGN_MAPPINGS, chrominfo[ , "GenBankAccn"])
    stopifnot(!anyNA(foreign_idx))  # sanity check
    foreign_SequenceName <- chrominfo[foreign_idx, "SequenceName"]
    foreign_RefSeqAccn <- chrominfo[foreign_idx, "RefSeqAccn"]
    m <- match(seqlevels, foreign_SequenceName)
    m2 <- match(seqlevels, foreign_RefSeqAccn)
    m[is.na(m)] <- m2[is.na(m)]
    new_seqlevels2 <- names(.hg38_FOREIGN_MAPPINGS)[m]

    ## Merge 'new_seqlevels2' into 'new_seqlevels'.
    idx2 <- which(!is.na(new_seqlevels2))
    stopifnot(all(is.na(new_seqlevels[idx2])))  # sanity check
    new_seqlevels[idx2] <- new_seqlevels2[idx2]
    new_seqlevels
}

.map_hg38_seqlevels_to_NCBI_or_RefSeq <- function(seqlevels, new_style)
{
    new_seqlevels <- .map_UCSC_seqlevels_to_NCBI_or_RefSeq(
                                         seqlevels, "hg38", new_style)

    ## Take care of the foreign sequences. Note that they are not
    ## necessarily present in 'seqlevels'.
    chrominfo <- getChromInfoFromNCBI(.hg38_FOREIGN_ASSEMBLY)
    foreign_idx <- match(.hg38_FOREIGN_MAPPINGS, chrominfo[ , "GenBankAccn"])
    stopifnot(!anyNA(foreign_idx))  # sanity check
    m <- match(seqlevels, names(.hg38_FOREIGN_MAPPINGS))
    if (new_style == "NCBI") {
        NCBI_seqlevels <- chrominfo[ , "SequenceName"]
    } else {
        NCBI_seqlevels <- chrominfo[ , "RefSeqAccn"]
    }
    new_seqlevels2 <- NCBI_seqlevels[foreign_idx[m]]

    ## Merge 'new_seqlevels2' into 'new_seqlevels'.
    idx2 <- which(!is.na(new_seqlevels2))
    stopifnot(all(is.na(new_seqlevels[idx2])))  # sanity check
    new_seqlevels[idx2] <- new_seqlevels2[idx2]
    names(new_seqlevels)[idx2] <- .hg38_FOREIGN_ASSEMBLY
    new_seqlevels
}

### 'genome' must be a single string or NA.
### Return a 2-column DataFrame with 1 row per element in 'seqlevels'.
### The columns contain the (possibly) modified seqlevels and genome
### associated with each seqname.
.set_seqlevelsStyle_from_seqlevels_and_genome <-
    function(seqlevels, genome, new_style)
{
    ans <- DataFrame(seqlevels=seqlevels, genome=genome)
    if (is.na(genome) || !(new_style %in% c("NCBI", "RefSeq", "UCSC"))) {
        ## Switch style based on seqlevels only. 'genome' is untouched.
        seqlevelsStyle(ans[ , "seqlevels"]) <- new_style
        return(ans)
    }
    old_style <- .is_NCBI_assembly_or_UCSC_genome(genome)
    if (is.na(old_style)) {
        ## Switch style based on seqlevels only. 'genome' is untouched.
        seqlevelsStyle(ans[ , "seqlevels"]) <- new_style
        return(ans)
    }
    if (old_style == "NCBI")
        old_style <- .get_seqlevelsStyle_for_NCBI_seqlevels(seqlevels)
    ## 'old_style' can be c("RefSeq", "NCBI") so we cannot use == here.
    if (identical(new_style, old_style))
        return(ans)  # no-op

    ## The user wants to switch between styles NCBI, RefSeq, and UCSC.
    ## We want to make sure that this switch is **reversible** i.e. that
    ## switching back to the original style restores the original seqlevels
    ## and genome. Note that this is not always possible e.g. switching stuff
    ## based on GRCh38.p2 to UCSC then back to NCBI or RefSeq will set the
    ## genome to GRCh38.p14. See .map_UCSC_genome_to_NCBI_assembly() above
    ## in this file.
    if (new_style == "UCSC") {
        ## 'old_style' is "NCBI" or "RefSeq" or c("RefSeq", "NCBI") i.e. the            ## user wants to switch from NCBI or RefSeq to UCSC style.
        new_genome <- .map_NCBI_assembly_to_UCSC_genome(genome)
        if (is.na(new_genome)) {
            ## 'genome' is an NCBI assembly that this not linked to a UCSC
            ## genome. Note that we could still switch the style based on
            ## seqlevels only. However, since we cannot also switch the genome,
            ## this would result in a non-reversible operation because trying
            ## to switch back to NCBI would then be a no-op.
            warning(wmsg("cannot switch ", genome, "'s seqlevels ",
                         "to ", new_style, " style"))
            return(ans)
        }
        ## UGLY HACK!
        if (new_genome == "hg38") {
            new_seqlevels <- .map_NCBI_or_RefSeq_seqlevels_to_hg38(seqlevels)
        } else {
            new_seqlevels <- .map_NCBI_or_RefSeq_seqlevels_to_UCSC(
                                                 seqlevels, new_genome)
        }
    } else if (identical(old_style, "UCSC")) {
        ## 'new_style' is "NCBI" or "RefSeq" i.e. the user wants to switch
        ## from UCSC to NCBI or RefSeq style.
        new_genome <- .map_UCSC_genome_to_NCBI_assembly(genome)
        if (is.na(new_genome)) {
            ## 'genome' is an UCSC genome that this not based on an NCBI
            ## assembly. Note that we could still switch the style based on
            ## seqlevels only. However, since we cannot also switch the genome,
            ## this would result in a non-reversible operation because trying
            ## to switch back to UCSC would then be a no-op.
            warning(wmsg("cannot switch ", genome, "'s seqlevels ",
                         "from ", old_style, " to ", new_style, " style"))
            return(ans)
        }
        ## UGLY HACK!
        if (genome == "hg38") {
            new_seqlevels <- .map_hg38_seqlevels_to_NCBI_or_RefSeq(
                                                 seqlevels, new_style)
        } else {
            new_seqlevels <- .map_UCSC_seqlevels_to_NCBI_or_RefSeq(
                                                 seqlevels, genome, new_style)
        }
        new_genome <- names(new_seqlevels)[!is.na(new_seqlevels)]
    } else {
        ## The user wants to switch from NCBI to RefSeq style or vice-versa.
        ## This does NOT touch the genome.
        chrominfo <- getChromInfoFromNCBI(genome)
        SequenceName <- chrominfo[ , "SequenceName"]
        RefSeqAccn <- chrominfo[ , "RefSeqAccn"]
        if (new_style == "RefSeq") {
            ## 'old_style' is "NCBI" or c("RefSeq", "NCBI").
            m <- match(seqlevels, SequenceName)
            new_seqlevels <- RefSeqAccn[m]
        } else {
            ## 'old_style' is "RefSeq" or c("RefSeq", "NCBI")
            ## and 'new_style' is "NCBI".
            m <- match(seqlevels, RefSeqAccn)
            new_seqlevels <- SequenceName[m]
        }
        new_genome <- genome
    }
    ## Switch seqlevels **and** genome.
    replace_idx <- which(!is.na(new_seqlevels))
    if (length(replace_idx) == 0L) {
        ## Can happen if the current seqlevels don't match the current genome
        ## e.g.:
        ##   gr <- GRanges("chrA:1-10")
        ##   genome(gr) <- "GRCh38"
        ##   seqlevelsStyle(gr) <- "RefSeq"
        warning(wmsg("cannot switch ", genome, "'s seqlevels ",
                     "from ", paste(old_style, collapse="/"), " ",
                     "to ", new_style, " style"))
        return(ans)
    }
    if (length(replace_idx) < length(new_seqlevels))
        warning(wmsg("cannot switch some ", genome, "'s seqlevels ",
                     "from ", paste(old_style, collapse="/"), " ",
                     "to ", new_style, " style"))
    ans[replace_idx, "seqlevels"] <- new_seqlevels[replace_idx]
    ans[replace_idx, "genome"] <- new_genome
    ans
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### seqlevelsStyle() generic getter and setter
###

setGeneric("seqlevelsStyle",
    function(x) standardGeneric("seqlevelsStyle")
)

setGeneric("seqlevelsStyle<-", signature="x",
    function(x, value) standardGeneric("seqlevelsStyle<-")
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### seqlevelsStyle() getter and setter methods for Seqinfo objects
###

.get_genome_as_factor <- function(x)
{
    ## genome(x) can be a mix of several genomes (including NAs).
    x_genome <- unname(genome(x))
    factor(x_genome, levels=unique(x_genome),
           exclude=character(0))  # keep NA in levels
}

### 'genome' must be a single string or NA.
### Tries to get the style first based on 'genome', then based on 'seqlevels'.
### Can return more than 1 style.
.get_seqlevelsStyle_from_seqlevels_and_genome <- function(seqlevels, genome)
{
    if (is.na(genome))
        return(seqlevelsStyle(seqlevels))  # can return more than 1 style
    ans <- .is_NCBI_assembly_or_UCSC_genome(genome)
    if (is.na(ans))
        return(seqlevelsStyle(seqlevels))  # can return more than 1 style
    if (ans == "NCBI")
        ans <- .get_seqlevelsStyle_for_NCBI_seqlevels(seqlevels)
    ans
}

.normarg_seqlevelsStyle <- function(seqlevelsStyle)
{
    if (!(is.character(seqlevelsStyle) && length(seqlevelsStyle) >= 1L))
        stop(wmsg("the supplied seqlevels style must be a single string"))
    if (length(seqlevelsStyle) > 1L) {
        warning(wmsg("more than one seqlevels style supplied, ",
                     "using the 1st one only"))
        seqlevelsStyle <- seqlevelsStyle[[1L]]
    }
    if (is.na(seqlevelsStyle))
        stop(wmsg("the supplied seqlevels style cannot be NA"))
    seqlevelsStyle
}

.get_Seqinfo_seqlevelsStyle <- function(x)
{
    x_genome <- .get_genome_as_factor(x)
    if (length(x_genome) == 0L)
        stop(wmsg("no seqlevels present in this object"))
    genome2seqlevels <- split(seqlevels(x), x_genome)
    genome2style <- mapply(.get_seqlevelsStyle_from_seqlevels_and_genome,
                           genome2seqlevels, names(genome2seqlevels),
                           SIMPLIFY=FALSE, USE.NAMES=FALSE)
    unique(unlist(genome2style, use.names=FALSE))
}

.set_Seqinfo_seqlevelsStyle <- function(x, value)
{
    value <- .normarg_seqlevelsStyle(value)
    x_genome <- .get_genome_as_factor(x)
    if (length(x_genome) == 0L)
        return(x)
    genome2seqlevels <- split(seqlevels(x), x_genome)
    genome2DF <- mapply(.set_seqlevelsStyle_from_seqlevels_and_genome,
                        genome2seqlevels, names(genome2seqlevels),
                        MoreArgs=list(value),
                        SIMPLIFY=FALSE, USE.NAMES=FALSE)
    DF <- unsplit(as(genome2DF, "CompressedDataFrameList"), x_genome)
    seqlevels(x) <- DF[ , "seqlevels"]
    genome(x) <- DF[ , "genome"]
    x
}

setMethod("seqlevelsStyle", "Seqinfo", .get_Seqinfo_seqlevelsStyle)

setReplaceMethod("seqlevelsStyle", "Seqinfo", .set_Seqinfo_seqlevelsStyle)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Default seqlevelsStyle() getter and setter methods
###

### Works on any object 'x' with a working seqinfo() getter.
setMethod("seqlevelsStyle", "ANY", function(x) seqlevelsStyle(seqinfo(x)))

### Works on any object 'x' with a working seqinfo() getter and setter.
setReplaceMethod("seqlevelsStyle", "ANY",
     function (x, value)
     {
         x_seqinfo <- seqinfo(x)
         seqlevelsStyle(x_seqinfo) <- value
         seqinfo(x, new2old=seq_along(x_seqinfo)) <- x_seqinfo
         x
     }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### seqlevelsStyle() getter and setter methods for character vectors
###

.getDatadir <- function()
{
    system.file(package = "GenomeInfoDb","extdata","dataFiles")
}

.getNamedFiles <- function()
{
    filePath <- .getDatadir()
    files <- dir(filePath, full.names=TRUE, pattern =".txt$")
    setNames(files, sub(".txt$", "", basename(files)))
}

.supportedSeqnameMappings <- function()
{
    dom <-  lapply(.getNamedFiles(), read.table, header=TRUE, sep="\t",
                   stringsAsFactors=FALSE)
    lapply(dom, function(x) {x[,-c(1:3)] })
}

.normalize_organism <- function(organism)
{
    parts <- CharacterList(strsplit(organism, "_| "))
    parts_eltNROWS <- elementNROWS(parts)
    ## If 3 parts or more (e.g. "Canis_lupus_familiaris") then remove part 2.
    idx3 <- which(parts_eltNROWS >= 3L)
    if (length(idx3) != 0L)
        parts[idx3] <- parts[idx3][rep.int(list(-2L), length(idx3))]
    unstrsplit(parts, sep="_")
}

.guessSpeciesStyle <- function(seqnames)
{
    zz <- .supportedSeqnameMappings()
    got2 <- lapply(zz ,function(y) lapply(y, function(z)
        sum(z %in% seqnames)) )
    unlistgot2 <- unlist(got2, recursive=TRUE,use.names=TRUE)

    if (max(unlistgot2) == 0) {
       ans <- NA
    }else{
        ##vec is in format "Homo_sapiens.UCSC"
        vec <- names(which(unlistgot2==max(unlistgot2)))
        organism <- .normalize_organism(sub("(.*?)[.].*", "\\1", vec))
        style <- gsub("^[^.]+.","", vec)
        ans <- list(species=organism, style=style)
    }
    ans
}

setMethod("seqlevelsStyle", "character",
    function(x)
{
    if (length(x) == 0L)
        stop(wmsg("no seqlevels present in this object"))

    seqlevels <- unique(x)
    ans <- .guessSpeciesStyle(seqlevels)

    ## 3 cases -
    ## 1. if no style found - ans is na - stop with message
    ## 2. if multiple styles returned then print message saying that it could
    ##    be any of these styles
    ## 3. if one style returned - hurray!

    if(length(ans)==1){
        if(is.na(ans)){
            if (all(.is_RefSeq_accession(seqlevels)))
                return("RefSeq")
            txt <- "The style does not have a compatible entry for the
            species supported by Seqname. Please see
            genomeStyles() for supported species/style"
            stop(paste(strwrap(txt, exdent=2), collapse="\n"))
        }
    }
    unique(ans$style)
})

.replace_seqlevels_style <- function(x_seqlevels, value)
{
    renaming_maps <- mapSeqlevels(x_seqlevels, value, drop=FALSE)
    if (nrow(renaming_maps) == 0L) {
        msg <- c("found no sequence renaming map compatible ",
                 "with seqname style \"", value, "\" for this object")
        stop(msg)
    }
    ## Use 1st best renaming map.
    if (nrow(renaming_maps) != 1L) {
        msg <- c("found more than one best sequence renaming map ",
                 "compatible with seqname style \"", value, "\" for ",
                 "this object, using the first one")
        warning(msg)
        renaming_maps <- renaming_maps[1L, , drop=FALSE]
    }
    new_seqlevels <- as.vector(renaming_maps)
    na_idx <- which(is.na(new_seqlevels))
    new_seqlevels[na_idx] <- x_seqlevels[na_idx]
    new_seqlevels
}

setReplaceMethod("seqlevelsStyle", "character",
    function (x, value)
    {
        value <- .normarg_seqlevelsStyle(value)
        x_seqlevels <- unique(x)
        new_seqlevels <- .replace_seqlevels_style(x_seqlevels, value)
        new_seqlevels[match(x, x_seqlevels)]
    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Other user-facing low-level utilities related to the seqlevelsStyle()
### getter and setter methods for character vectors:
###   - genomeStyles()
###   - extractSeqlevels()
###   - extractSeqlevelsByGroup()
###   - mapSeqlevels()
###   - seqlevelsInGroup()

.isSupportedSeqnamesStyle <- function(organism, style)
{
    organism <- .normalize_organism(organism)
    possible <- lapply(.getNamedFiles(), scan, nlines=1, what=character(),
                       quiet=TRUE)
    availStyles <- possible[[organism]]
    style %in% availStyles[-which(availStyles %in% c("circular","auto","sex"))]
}

.getDataInFile <- function(organism)
{
    organism2 <- .normalize_organism(organism)
    filename <- paste0(.getDatadir(), "/", organism2, ".txt")
    if (file.exists(filename)) {
        read.table(filename, header=TRUE, sep="\t", stringsAsFactors=FALSE)
    } else {
        stop("Organism ", organism, " is not supported by GenomeInfoDb")
    }

}

.supportedSeqlevelsStyles <- function()
{
    dom <- lapply(.getNamedFiles(), scan, nlines=1, what=character(),
                  quiet=TRUE)
    lapply(dom, function(x) {x[!(x %in% c("circular","auto","sex"))] })
}

genomeStyles <- function(species)
{
    if (missing(species))
        lapply(.getNamedFiles(), read.table, header=TRUE, sep="\t",
           stringsAsFactors=FALSE)
    else
        .getDataInFile(species)
}

extractSeqlevels <- function(species, style)
{
    if (missing(species) || missing(style))
        stop("'species' or 'style' missing")

    if(.isSupportedSeqnamesStyle(species, style))
    {
        data <- .getDataInFile(species)
        result <- as.vector(data[,which( names(data) %in% style)])
    }else{
        stop("The style specified by '",style,
             "' does not have a compatible entry for the species ",species)}
    result
}

extractSeqlevelsByGroup <- function(species, style, group)
{
    if (missing(species) || missing(style) || missing(group))
        stop("'species', 'style', and / or 'group' missing")

    logic <-sapply(species, function(x) .isSupportedSeqnamesStyle(x, style))

    if(all(logic))
    {
        data <- .getDataInFile(species)
        if (group!="all"){
            colInd <- which(names(data)%in% group)
            Ind <- which(data[,colInd]==1)
            result <- as.vector(data[Ind,which( names(data) %in% style)])
        }
        else{
            result <- as.vector(data[,which( names(data) %in% style)])
        }
    }else{
        stop("The style specified by '",style,
             "' does not have a compatible entry for the species ",species)}
    result
}

mapSeqlevels <- function(seqnames, style, best.only=TRUE, drop=TRUE)
{
    if (!is.character(seqnames))
        stop("'seqnames' must be a character vector")
    if (!isSingleString(style))
        stop("the supplied seqlevels style must be a single string")
    if (!isTRUEorFALSE(best.only))
        stop("'best.only' must be TRUE or FALSE")
    if (!isTRUEorFALSE(drop))
        stop("'drop' must be TRUE or FALSE")
    supported_styles <- .supportedSeqlevelsStyles()
    tmp <- unlist(supported_styles, use.names = FALSE)
    compatible_species <- rep.int(names(supported_styles),
                                  sapply(supported_styles,NROW))
    compatible_species <- compatible_species[tolower(tmp) ==
                                                 tolower(style)]
    if (length(compatible_species) == 0L)
        stop("supplied seqname style \"", style, "\" is not supported")
    seqname_mappings <- .supportedSeqnameMappings()
    ans <- lapply(compatible_species, function(species) {
        mapping <- seqname_mappings[[species]]
        names(mapping) <- tolower(names(mapping))
        to_seqnames <- as.character(mapping[[tolower(style)]])
        lapply(mapping, function(from_seqnames)
            to_seqnames[match(seqnames, from_seqnames)])
    })
    ans_ncol <- length(seqnames)
    ans <- matrix(unlist(ans, use.names = FALSE), ncol = ans_ncol, byrow = TRUE)
    colnames(ans) <- seqnames
    score <- rowSums(!is.na(ans))
    idx <- score != 0L
    if (best.only)
        idx <- idx & (score == max(score))
    ans <- ans[idx, , drop = FALSE]
    ans <- as.matrix(unique(as.data.frame(ans, stringsAsFactors = FALSE)))
    if (nrow(ans) == 1L && drop)
        ans <- drop(ans)
    else rownames(ans) <- NULL
    ans
}

seqlevelsInGroup <-
    function(seqnames, group=c("all", "auto", "sex", "circular"),
             species, style)
{
    group <- match.arg(group)
    if (missing(species) && missing(style)) {
        ## guess the species and / or style for the object
        ans <- .guessSpeciesStyle(seqnames)
        species<- ans$species
        style <- unique(unlist(ans$style))
    }

    logic <-sapply(species, function(x) .isSupportedSeqnamesStyle(x, style))

    if (all(logic)) {
        seqvec <- sapply(unlist(species), function(x)
            extractSeqlevelsByGroup( x, style, group))
        unique(unlist(seqvec))[na.omit(match(seqnames, unique(unlist(seqvec))))]
    } else {
        txt <- paste0( "The style specified by ", sQuote(style),
                       " does not have a compatible entry for the species ",
                       sQuote(species))
        stop(paste(strwrap(txt, exdent=2), collapse="\n"))
    }
}

