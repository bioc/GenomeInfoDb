### =========================================================================
### The "GenomeDescription" class
### -------------------------------------------------------------------------

setClass("GenomeDescription",
    representation(
        ## organism: "Homo sapiens", "Mus musculus", etc...
        organism="character",

        ## common_name: "Human", "Mouse", etc...
        common_name="character",

        ## provider: "UCSC", "BDGP", etc...
        provider="character",

        ## provider_version: "hg18", "mm8", "sacCer1", etc...
        provider_version="character",

        ## release_date: "Mar. 2006", "Feb. 2006", "Oct. 2003", etc...
        release_date="character",

        ## release_name: "NCBI Build 36.1", "NCBI Build 36",
        ## "SGD 1 Oct 2003 sequence", etc...
        release_name="character",

        ## names, lengths, and circularity flags of the genome sequences
        seqinfo="Seqinfo"
    )
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Accessor methods.
###

setMethod("organism", "GenomeDescription", function(object) object@organism)

setGeneric("commonName", function(object) standardGeneric("commonName"))
setMethod("commonName", "GenomeDescription",
    function(object) object@common_name
)

setGeneric("provider", function(x) standardGeneric("provider"))
setMethod("provider", "GenomeDescription", function(x) x@provider)

setGeneric("providerVersion", function(x) standardGeneric("providerVersion"))
setMethod("providerVersion", "GenomeDescription", function(x) x@provider_version)

setGeneric("releaseDate", function(x) standardGeneric("releaseDate"))
setMethod("releaseDate", "GenomeDescription", function(x) x@release_date)

setGeneric("bsgenomeName", function(x) standardGeneric("bsgenomeName"))
setMethod("bsgenomeName", "GenomeDescription",
    function(x)
    {
        part1 <- "BSgenome"
        tmp <- strsplit(organism(x), " ", fixed=TRUE)[[1L]]
        part2 <- paste(substr(tmp[1L], start=1L, stop=1L), tmp[2L], sep="")
        part3 <- provider(x)
        part4 <- providerVersion(x)
        paste(part1, part2, part3, part4, sep=".")
    }
)

setMethod("seqinfo", "GenomeDescription", function(x) x@seqinfo)

setMethod("seqnames", "GenomeDescription",
    function(x)
    {
        ## Do NOT use 'seqnames(x)' here or you'll get infinite recursion!
        ans <- seqnames(seqinfo(x))
        if (length(ans) == 0L)
            ans <- NULL
        ans
    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Validity.
###

setValidity("GenomeDescription",
    function(object)
    {
        SINGLE_STRING_SLOTS <- setdiff(slotNames("GenomeDescription"),
                                       "seqinfo")
        .validSlot <- function(slotname)
        {
            slotval <- slot(object, slotname)
            if (isSingleStringOrNA(slotval))
                return(NULL)
            problem <- paste("slot '", slotname, "' must be a ",
                             "single string (or NA)", sep="")
            return(problem)
        }
        unlist(lapply(SINGLE_STRING_SLOTS, .validSlot))
    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Constructor-like functions
###

.norm_GenomeDescription_arg <- function(arg, argname)
{
    if (!isSingleStringOrNA(arg))
        stop(wmsg("'", argname, "' must be a single string or NA"))
    if (toupper(arg) %in% c(NA, "NA", ""))
        arg <- NA_character_
    arg
}

### NOTE: In BioC 3.1, the 'species' argument was replaced with the
### 'common_name' argument but the former was kept for backward compatibility
### (essentially with existing SNPlocs and XtraSNPlocs packages).
### TODO: At some point the 'species' argument needs to be deprecated.
GenomeDescription <- function(organism=NA, common_name=NA,
                              provider=NA, provider_version=NA,
                              release_date=NA, release_name=NA,
                              seqinfo,
                              species=NA)
{
    organism <- .norm_GenomeDescription_arg(organism, "organism")
    species <- .norm_GenomeDescription_arg(species, "species")
    if (missing(common_name)) {
        common_name <- species
    } else {
        common_name <- .norm_GenomeDescription_arg(common_name, "common_name")
    }
    provider <- .norm_GenomeDescription_arg(provider, "provider")
    provider_version <- .norm_GenomeDescription_arg(provider_version,
                                                    "provider_version")
    release_date <- .norm_GenomeDescription_arg(release_date, "release_date")
    release_name <- .norm_GenomeDescription_arg(release_name, "release_name")
    new("GenomeDescription",
        organism=organism,
        common_name=common_name,
        provider=provider,
        provider_version=provider_version,
        release_date=release_date,
        release_name=release_name,
        seqinfo=seqinfo)
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### The 'show' method
###

### NOT exported but used in BSgenome package.
### Kind of very low-level. Could go into S4Vectors if someone else needed
### this...
compactPrintNamedAtomicVector <- function(x, margin="")
{
    x_len <- length(x)
    halfWidth <- (getOption("width") - nchar(margin)) %/% 2L
    first <- max(1L, halfWidth)
    showMatrix <-
      rbind(as.character(head(names(x), first)),
            as.character(head(x, first)))
    if (x_len > first) {
        last <- min(x_len - first, halfWidth)
        showMatrix <-
          cbind(showMatrix,
                rbind(as.character(tail(names(x), last)),
                      as.character(tail(x, last))))
    }
    showMatrix <- format(showMatrix, justify="right")
    cat(S4Vectors:::labeledLine(margin, showMatrix[1L, ], count=FALSE,
                                        labelSep=""), sep="")
    cat(S4Vectors:::labeledLine(margin, showMatrix[2L, ], count=FALSE,
                                        labelSep=""), sep="")
}

### NOT exported (but used in the BSgenome package).
showGenomeDescription <- function(x, margin="", print.seqlengths=FALSE)
{
    cat(margin, "organism: ", organism(x), sep="")
    common_name <- commonName(x)
    if (!is.na(common_name))
        cat(" (",  common_name, ")", sep="")
    cat("\n")
    cat(margin, "provider: ", provider(x), "\n", sep="")
    cat(margin, "genome: ", providerVersion(x), "\n", sep="")
    release_date <- releaseDate(x)
    if (!is.na(release_date))
        cat(margin, "release date: ", release_date, "\n", sep="")
    if (print.seqlengths) {
        cat(margin, "---\n", sep="")
        cat(margin, "seqlengths:\n", sep="")
        compactPrintNamedAtomicVector(seqlengths(x), margin=margin)
    }
}

setMethod("show", "GenomeDescription",
    function(object)
    {
        showGenomeDescription(object, margin="| ", print.seqlengths=TRUE)
    }
)

