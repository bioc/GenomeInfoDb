### =========================================================================
### Seqinfo objects
### -------------------------------------------------------------------------
###
### A Seqinfo object is a table-like object that contains basic information
### about a set of genomic sequences. The table has one entry per sequence,
### with each entry containing the following sequence attributes:
###   - sequence name (primary key)
###   - sequence length
###   - circularity flag
###   - genome (e.g. hg19)
###

setClass("Seqinfo",
    representation(
        seqnames="character",
        seqlengths="integer",
        is_circular="logical",
        genome="character"
    )
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Getters
###

setMethod("seqnames", "Seqinfo", function(x) x@seqnames)

setMethod("names", "Seqinfo", function(x) seqnames(x))

setMethod("length", "Seqinfo", function(x) length(seqnames(x)))

setMethod("seqlevels", "Seqinfo", function(x) seqnames(x))

setMethod("seqlengths", "Seqinfo",
    function(x)
    {
        ans <- x@seqlengths
        names(ans) <- seqnames(x)
        ans
    }
)

setMethod("isCircular", "Seqinfo",
    function(x)
    {
        ans <- x@is_circular
        names(ans) <- seqnames(x)
        ans
    }
)

setMethod("genome", "Seqinfo",
    function(x)
    {
        ans <- x@genome
        names(ans) <- seqnames(x)
        ans
    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Validity
###

.valid.Seqinfo.seqnames <- function(x_seqnames, what="'seqnames(x)'")
{
    if (!is.character(x_seqnames))
        return(paste0(what, " must be a character vector"))
    if (!is.null(names(x_seqnames)))
        return(paste0(what, " must be unnamed"))
    if (any(x_seqnames %in% c(NA, "")))
        return(paste0(what, " cannot contain NAs or empty strings (\"\")"))
    if (anyDuplicated(x_seqnames))
        return(paste0(what, " cannot contain duplicated sequence names"))
    NULL
}

### Not really checking the slot itself but the value returned by the
### slot accessor.
.valid.Seqinfo.seqlengths <- function(x)
{
    x_seqlengths <- seqlengths(x)
    if (!is.integer(x_seqlengths)
     || length(x_seqlengths) != length(x)
     || !identical(names(x_seqlengths), seqnames(x)))
        return("'seqlengths(x)' must be an integer vector of the length of 'x' and with names 'seqnames(x)'")
    if (any(x_seqlengths < 0L, na.rm=TRUE))
        return("'seqlengths(x)' contains negative values")
    NULL
}

### Not really checking the slot itself but the value returned by the
### slot accessor.
.valid.Seqinfo.isCircular <- function(x)
{
    x_is_circular <- isCircular(x)
    if (!is.logical(x_is_circular)
     || length(x_is_circular) != length(x)
     || !identical(names(x_is_circular), seqnames(x)))
        return("'isCircular(x)' must be a logical vector of the length of 'x' and with names 'seqnames(x)'")
    NULL
}

### Not really checking the slot itself but the value returned by the
### slot accessor.
.valid.Seqinfo.genome <- function(x)
{
    x_genome <- genome(x)
    if (!is.character(x_genome)
     || length(x_genome) != length(x)
     || !identical(names(x_genome), seqnames(x)))
        return("'genome(x)' must be a character vector of the length of 'x' and with names 'seqnames(x)'")
    NULL
}

.valid.Seqinfo <- function(x)
{
    c(.valid.Seqinfo.seqnames(seqnames(x)),
      .valid.Seqinfo.seqlengths(x),
      .valid.Seqinfo.isCircular(x),
      .valid.Seqinfo.genome(x))
}

setValidity2("Seqinfo", .valid.Seqinfo)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Constructor
###
### The .normarg_*() helper functions below do only partial checking of the
### arguments. The full validation is performed by the validity method when
### new() is called.
###

.make_Seqinfo_from_genome <- function(genome)
{
    if (!isSingleString(genome) || genome == "")
        stop("'genome' must be a single non-empty string")
    NCBI_assemblies <- registered_NCBI_assemblies()
    if (genome %in% NCBI_assemblies[ , "assembly"] ||
        genome %in% NCBI_assemblies[ , "assembly_accession"])
        return(getChromInfoFromNCBI(genome, as.Seqinfo=TRUE))
    UCSC_genomes <- registered_UCSC_genomes()
    if (genome %in% UCSC_genomes[ , "genome"])
        return(getChromInfoFromUCSC(genome, as.Seqinfo=TRUE))
    stop(wmsg("\"", genome, "\" is not a registered NCBI assembly ",
              "or UCSC genome (use registered_NCBI_assemblies() or ",
              "registered_UCSC_genomes() to list the NCBI or UCSC ",
              "assemblies/genomes currently registered in the ",
              "GenomeInfoDb package)"))
}

### Make sure this always returns an *unnamed* character vector.
.normarg_seqlevels <- function(seqlevels)
{
    if (is.null(seqlevels))
        return(character(0))
    seqlevels <- unname(seqlevels)
    errmsg <- .valid.Seqinfo.seqnames(seqlevels, what="supplied 'seqlevels'")
    if (!is.null(errmsg))
        stop(errmsg)
    seqlevels
}

### Make sure this always returns an *unnamed* integer vector.
.normarg_seqlengths <- function(seqlengths, seqnames)
{
    if (identical(seqlengths, NA))
        return(rep.int(NA_integer_, length(seqnames)))
    if (!is.vector(seqlengths))
        stop(wmsg("supplied 'seqlengths' must be a vector"))
    if (length(seqlengths) != length(seqnames))
        stop(wmsg("the length of the supplied 'seqlengths' vector ",
                  "must be equal to the number of sequences"))
    if (!is.null(names(seqlengths))
     && !identical(names(seqlengths), seqnames))
        stop(wmsg("the names on the supplied 'seqlengths' vector ",
                  "must be identical to the seqnames"))
    if (is.logical(seqlengths)) {
        if (all(is.na(seqlengths)))
            return(as.integer(seqlengths))
        stop(wmsg("bad supplied 'seqlengths' vector"))
    }
    if (!is.numeric(seqlengths))
        stop(wmsg("bad supplied 'seqlengths' vector"))
    if (is.integer(seqlengths)) {
        seqlengths <- unname(seqlengths)
    } else {
        seqlengths <- as.integer(seqlengths)
    }
    if (any(seqlengths < 0L, na.rm=TRUE))
        stop(wmsg("the supplied 'seqlengths' vector contains negative values"))
    seqlengths
}

### Make sure this always returns an *unnamed* logical vector.
.normarg_isCircular <- function(isCircular, seqnames)
{
    if (identical(isCircular, NA))
        return(rep.int(NA, length(seqnames)))
    if (!is.vector(isCircular))
        stop(wmsg("supplied 'isCircular' must be a vector"))
    if (length(isCircular) != length(seqnames))
        stop(wmsg("the length of the supplied 'isCircular' vector ",
                  "must be equal to the number of sequences"))
    if (!is.null(names(isCircular))
     && !identical(names(isCircular), seqnames))
        stop(wmsg("the names on the supplied 'isCircular' vector ",
                  "must be identical to the seqnames"))
    if (!is.logical(isCircular))
        stop(wmsg("bad supplied 'isCircular' vector"))
    unname(isCircular)
}

### Make sure this always returns an *unnamed* character vector parallel to
### 'seqnames'.
.normarg_genome <- function(genome, seqnames)
{
    if (!(is.vector(genome) || is.factor(genome)))
        stop(wmsg("supplied 'genome' must be a vector or factor"))
    if (!is.character(genome))
        genome <- as.character(genome)

    if (length(genome) == 0L) {
        if (length(seqnames) == 0L)
            return(unname(genome))
        stop(wmsg("supplied 'genome' vector is empty"))
    }

    ## The most common situation is that the supplied 'genome' vector contains
    ## a single (possibly NA) unique value. Note that, in that case, the names
    ## on 'genome' are ignored.
    ugenome <- unique(genome)
    if (length(ugenome) == 1L)
        return(rep.int(ugenome, length(seqnames)))

    if (!is.null(names(genome))) {
        if (identical(names(genome), seqnames))
            return(unname(genome))
        stop(wmsg("when the supplied 'genome' vector contains more ",
                  "than one distinct value, the names on it must be ",
                  "identical to the seqlevels of the object"))
    }
    if (length(genome) == length(seqnames))
        return(genome)
    if (length(genome) != 1L)
        stop(wmsg("when the length of the supplied 'genome' vector is not 1, ",
                  "then it must be equal to the number of sequences"))
    rep.int(genome, length(seqnames))
}

Seqinfo <- function(seqnames=NULL, seqlengths=NA, isCircular=NA, genome=NA)
{
    ## Handle special case where only 'genome' is specified e.g.:
    ##   Seqinfo(genome="hg38")
    if (is.null(seqnames)
     && identical(seqlengths, NA)
     && identical(isCircular, NA)
     && isSingleString(genome))
        return(.make_Seqinfo_from_genome(genome))

    if (is.null(seqnames)) {
        ## If 'seqnames' is omitted, then we try to infer it
        ## from the other arguments.
        seqnames1 <- seqnames2 <- seqnames3 <- NULL
        if (!identical(seqlengths, NA)) {
            if (!is.numeric(seqlengths))
                stop(wmsg("when specified, 'seqlengths' ",
                          "must be a numeric vector"))
            seqnames1 <- names(seqlengths)
        }
        if (!identical(isCircular, NA)) {
            if (!is.logical(isCircular))
                stop(wmsg("when specified, 'isCircular' ",
                          "must be a logical vector"))
            seqnames2 <- names(isCircular)
        }
        if (!identical(genome, NA)) {
            if (!(is.vector(genome) || is.factor(genome)))
                stop(wmsg("when specified, 'genome' ",
                          "must be a vector or factor"))
            seqnames3 <- names(genome)
        }
        seqnames <- unique(c(seqnames1, seqnames2, seqnames3))
        if (!(is.null(seqnames1) || identical(seqnames, seqnames1))
         || !(is.null(seqnames2) || identical(seqnames, seqnames2))
         || !(is.null(seqnames3) || identical(seqnames, seqnames3)))
            stop(wmsg("the names on the supplied 'seqlengths', ",
                      "'isCircular', and 'genome' vectors, if any, ",
                      "must be identical"))
    }
    seqnames <- .normarg_seqlevels(seqnames)
    seqlengths <- .normarg_seqlengths(seqlengths, seqnames)
    is_circular <- .normarg_isCircular(isCircular, seqnames)
    genome <- .normarg_genome(genome, seqnames)
    new("Seqinfo", seqnames=seqnames,
                   seqlengths=seqlengths,
                   is_circular=is_circular,
                   genome=genome)
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Updating old Seqinfo objects
###

setMethod("updateObject", "Seqinfo",
    function(object, ..., verbose=FALSE)
    {
        if (verbose)
            message("updateObject(object = 'Seqinfo')")
        if (!is(try(object@genome, silent=TRUE), "try-error"))
            return(genome)
        as(Seqinfo(seqnames=object@seqnames,
                   seqlengths=object@seqlengths,
                   isCircular=object@is_circular),
           class(object))
    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Subsetting
###

### Support subsetting only by name.
setMethod("[", "Seqinfo",
    function(x, i, j, ..., drop=TRUE)
    {
        if (!missing(j) || length(list(...)) > 0L)
            stop("invalid subsetting")
        if (missing(i))
            return(x)
        if (!is.character(i))
            stop("a Seqinfo object can be subsetted only by name")
        if (!identical(drop, TRUE))
            warning("'drop' argument is ignored when subsetting ",
                    "a Seqinfo object")
        x_names <- names(x)
        i2names <- match(i, x_names)
        new_seqlengths <- unname(seqlengths(x))[i2names]
        new_isCircular <- unname(isCircular(x))[i2names]
        new_genome <- unname(genome(x))[i2names]
        Seqinfo(seqnames=i, seqlengths=new_seqlengths,
                isCircular=new_isCircular, genome=new_genome)

    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Setters
###

setReplaceMethod("seqnames", "Seqinfo",
    function(x, value)
    {
        value <- .normarg_seqlevels(value)
        if (length(value) != length(x))
            stop("length of supplied 'seqnames' vector must equal ",
                 "the number of sequences")
        x@seqnames <- value
        x
    }
)

setReplaceMethod("names", "Seqinfo",
    function(x, value) `seqnames<-`(x, value)
)

setReplaceMethod("seqlevels", "Seqinfo",
    function(x,
             pruning.mode=c("error", "coarse", "fine", "tidy"),
             value)
    {
        pruning.mode <- match.arg(pruning.mode)
        if (pruning.mode != "error")
            warning("'pruning.mode' is ignored in \"seqlevels<-\" method ",
                    "for Seqinfo objects")
        new2old <- getSeqlevelsReplacementMode(value, seqlevels(x))
        if (identical(new2old, -3L)) {
            ## "renaming" mode
            seqnames(x) <- value
            return(x)
        }
        if (identical(new2old, -2L) || identical(new2old, -1L)) {
            ## "subsetting" mode
            return(x[value])
        }
        new_seqlengths <- unname(seqlengths(x))[new2old]
        new_isCircular <- unname(isCircular(x))[new2old]
        new_genome <- unname(genome(x))[new2old]
        Seqinfo(seqnames=value, seqlengths=new_seqlengths,
                isCircular=new_isCircular, genome=new_genome)
    }
)

setReplaceMethod("seqlengths", "Seqinfo",
    function(x, value)
    {
        x@seqlengths <- .normarg_seqlengths(value, seqnames(x))
        x
    }
)

setReplaceMethod("isCircular", "Seqinfo",
    function(x, value)
    {
        x@is_circular <- .normarg_isCircular(value, seqnames(x))
        x
    }
)

setReplaceMethod("genome", "Seqinfo",
    function(x, value)
    {
        x@genome <- .normarg_genome(value, seqnames(x))
        x
    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Coercion
###

### S3/S4 combo for as.data.frame.Seqinfo
as.data.frame.Seqinfo <- function(x, row.names=NULL, optional=FALSE, ...)
{
    if (!is.null(row.names))
        warning("supplied 'row.names' value was ignored")
    if (!identical(optional, FALSE))
        warning("supplied 'optional' value was ignored")
    if (length(list(...)) != 0L)
        warning("extra arguments were ignored")
    data.frame(seqlengths=unname(seqlengths(x)),
               isCircular=unname(isCircular(x)),
               genome=unname(genome(x)),
               row.names=seqnames(x),
               check.names=FALSE,
               stringsAsFactors=FALSE)
}
setMethod("as.data.frame", "Seqinfo", as.data.frame.Seqinfo)

.from_DataFrame_to_Seqinfo <- function(from)
{
    if (!is.data.frame(from) && !is(from, "DataFrame"))
        stop("'from' must be a data.frame or DataFrame object")
    from_colnames <- colnames(from)

    ## Extract seqnames.
    if ("seqnames" %in% from_colnames) {
        ans_seqnames <- from[ , "seqnames"]
    } else if ("seqlevels" %in% from_colnames) {
        ans_seqnames <- from[ , "seqlevels"]
    } else {
        ans_seqnames <- rownames(from)
        seqnames_as_ints <- suppressWarnings(as.integer(ans_seqnames))
        if (!any(is.na(seqnames_as_ints))
          && all(seqnames_as_ints == ans_seqnames))
            stop("no sequence names found in input")
    }
    if (!is.character(ans_seqnames))
        ans_seqnames <- as.character(ans_seqnames)

    ## Extract seqlengths.
    if ("seqlengths" %in% from_colnames) {
        ans_seqlengths <- from[ , "seqlengths"]
    } else {
        ans_seqlengths <- rep.int(NA_integer_, nrow(from))
    }
    if (!is.integer(ans_seqlengths))
        ans_seqlengths <-  as.integer(ans_seqlengths)

    ## Extract isCircular.
    if ("isCircular" %in% from_colnames) {
        ans_isCircular <- from[ , "isCircular"]
    } else if ("is_circular" %in% from_colnames) {
        ans_isCircular <- from[ , "is_circular"]
    } else {
        ans_isCircular <- rep.int(NA, nrow(from))
    }
    if (!is.logical(ans_isCircular))
        ans_isCircular <-  as.logical(ans_isCircular)

    ## Extract genome.
    if ("genome" %in% from_colnames) {
        ans_genome <- from[ , "genome"]
    } else {
        ans_genome <- rep.int(NA_character_, nrow(from))
    }
    if (!is.character(ans_genome))
        ans_genome <-  as.character(ans_genome)

    Seqinfo(seqnames=ans_seqnames, seqlengths=ans_seqlengths,
            isCircular=ans_isCircular, genome=ans_genome)
}
setAs("data.frame", "Seqinfo", .from_DataFrame_to_Seqinfo)
setAs("DataFrame", "Seqinfo", .from_DataFrame_to_Seqinfo)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Display
###

### S3/S4 combo for summary.Seqinfo
summary.Seqinfo <- function(object, ...)
{
    ## nb of sequences
    object_len <- length(object)
    if (object_len == 0L)
        return("no sequences")
    ans <- c(object_len, " sequence")
    if (object_len > 1L)
        ans <- c(ans, "s")
    ## circularity
    circ_count <- sum(isCircular(object), na.rm=TRUE)
    if (circ_count != 0L)
        ans <- c(ans, " (", circ_count, " circular)")
    ## genomes
    ugenomes <- unique(genome(object))
    genome_count <- length(ugenomes)
    if (genome_count == 1L) {
        if (is.na(ugenomes))
            ans <- c(ans, " from an unspecified genome")
        else
            ans <- c(ans, " from ", ugenomes, " genome")
    } else {
        if (genome_count > 3L)
            ugenomes <- c(ugenomes[1:2], "...")
        genomes_in1string <- paste0(ugenomes, collapse=", ")
        ans <- c(ans, " from ", genome_count, " genomes ",
                      "(", genomes_in1string, ")")
    }
    ## seqlengths
    seqlengths <- seqlengths(object)
    if (all(is.na(seqlengths)))
        ans <- c(ans, "; no seqlengths")
    paste0(ans, collapse="")
}
setMethod("summary", "Seqinfo", summary.Seqinfo)

### cat(.showOutputAsCharacter(x), sep="\n") is equivalent to show(x).
.showOutputAsCharacter <- function(x)
{
    tmp <- tempfile()
    sink(file=tmp, type="output")
    show(x)
    sink(file=NULL)
    readLines(tmp)
}

.compactDataFrame <- function(x)
{
    head_nrow <- get_showHeadLines()
    tail_nrow <- get_showTailLines()
    max_nrow <- head_nrow + tail_nrow + 1L
    if (nrow(x) <= max_nrow)
        return(x)
    head <- head(x, n=head_nrow)
    tail <- tail(x, n=tail_nrow)
    dotrow <- rep.int("...", ncol(x))
    names(dotrow) <- colnames(x)
    dotrow <- data.frame(as.list(dotrow),
                         row.names="...",
                         check.names=FALSE,
                         stringsAsFactors=FALSE)
    ## Won't handle properly the situation where one row in 'head' or 'tail'
    ## happens to be named "...".
    rbind(head, dotrow, tail)
}

### Should work properly on "narrow" data frames. Untested on data frames
### that are wider than the terminal.
showCompactDataFrame <- function(x, rownames.label="", left.margin="")
{
    compactdf <- .compactDataFrame(x)
    label_nchar <- nchar(rownames.label)
    if (label_nchar != 0L)
        row.names(compactdf) <- format(row.names(compactdf), width=label_nchar)
    showme <- .showOutputAsCharacter(compactdf)
    if (label_nchar != 0L)
        substr(showme[1L], 1L, label_nchar) <- rownames.label
    cat(paste0(left.margin, showme), sep="\n")
}

setMethod("show", "Seqinfo",
    function(object)
    {
        cat(class(object), " object with ", summary(object), sep="")
        if (length(object) == 0L) {
            cat("\n")
            return(NULL)
        }
        cat(":\n")
        showCompactDataFrame(as.data.frame(object),
                             rownames.label="seqnames", left.margin="  ")
    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Combining
###
### Why no c() or rbind() method for Seqinfo objects?
###
### c() is expected to follow an "appending semantic", that is, 'c(x, y)' is
### expected to form a new object by **appending** the entries in 'y' to the
### entries in 'x', thus resulting in an object with 'length(x) + length(y)'
### entries. Problem with such operation is that it won't be very useful in
### general, because it will tend to break the constraint that the seqnames
### of a Seqinfo object must be unique (primary key).
### A more useful operation is a "merge" operation that does the following:
### - If an entry in Seqinfo object 'x' has the same seqname as an entry in
###   Seqinfo object 'y', then the 2 entries are fusioned/melded together
###   to produce a single entry in the result. This fusion only happens if
###   the 2 entries contain compatible information.
### - If 2 entries cannot be fusioned/melded because they contain incompatible
###   information (e.g. different seqlengths or different circularity flags),
###   then the "merge" operation fails with an informative error of why 'x'
###   and 'y' could not be merged.
###
### We also implement an "update" operation for Seqinfo objects. See below.
###

### Binary merge.
.merge_two_Seqinfo_objects <- function(x, y)
{
    ans_seqnames    <- union(seqnames(x), seqnames(y))
    ans_genome      <- mergeNamedAtomicVectors(genome(x), genome(y),
                           what=c("sequence", "genomes"))
    ans_seqlengths  <- mergeNamedAtomicVectors(seqlengths(x), seqlengths(y),
                           what=c("sequence", "seqlengths"))
    ans_is_circular <- mergeNamedAtomicVectors(isCircular(x), isCircular(y),
                           what=c("sequence", "circularity flags"))

    common_seqnames <- intersect(seqnames(x), seqnames(y))
    x_proper_seqnames <- setdiff(seqnames(x), common_seqnames)
    y_proper_seqnames <- setdiff(seqnames(y), common_seqnames)
    if (length(x_proper_seqnames) != 0L && length(y_proper_seqnames) != 0L) {
        if (length(common_seqnames) == 0L) {
            msg <- c("The 2 combined objects have no sequence levels in ",
                     "common. (Use\n  suppressWarnings() to suppress this ",
                     "warning.)")
            warning(msg)
        } else if (any(is.na(genome(x)[common_seqnames]))
                || any(is.na(genome(y)[common_seqnames]))) {
            msg <- c("Each of the 2 combined objects has sequence levels ",
                     "not in the other:\n",
                     "  - in 'x': ",
                     paste(x_proper_seqnames, collapse=", "), "\n",
                     "  - in 'y': ",
                     paste(y_proper_seqnames, collapse=", "), "\n",
                     "  Make sure to always combine/compare objects based on ",
                     "the same reference\n  genome (use suppressWarnings() ",
                     "to suppress this warning).")
            warning(msg)
        }
    }
    Seqinfo(seqnames=ans_seqnames, seqlengths=ans_seqlengths,
            isCircular=ans_is_circular, genome=ans_genome)
}

## N-ary merge.
.merge_Seqinfo_objects <- function(...)
{
    args <- unname(list(...))
    ## Remove NULL elements...
    arg_is_null <- sapply(args, is.null)
    if (any(arg_is_null))
        args[arg_is_null] <- NULL  # ... by setting them to NULL!
    if (length(args) == 0L)
        return(Seqinfo())
    x <- args[[1L]]
    if (length(args) == 1L)
        return(x)
    args <- args[-1L]
    if (!all(sapply(args, is, class(x))))
        stop("all arguments in must be ", class(x), " objects (or NULLs)")
    for (y in args)
        x <- .merge_two_Seqinfo_objects(x, y)
    x
}

### S3 merge() method for Seqinfo objects.
merge.Seqinfo <- function(x, y, ...) .merge_Seqinfo_objects(x, y, ...)

### These methods should not be called with named arguments: this tends to
### break dispatch!
setMethod("merge", c("Seqinfo", "missing"),
    function(x, y, ...) .merge_Seqinfo_objects(x, ...)
)

setMethod("merge", c("missing", "Seqinfo"),
    function(x, y, ...) .merge_Seqinfo_objects(y, ...)
)

setMethod("merge", c("Seqinfo", "NULL"),
    function(x, y, ...) .merge_Seqinfo_objects(x, ...)
)

setMethod("merge", c("NULL", "Seqinfo"),
    function(x, y, ...) .merge_Seqinfo_objects(y, ...)
)

setMethod("merge", c("Seqinfo", "Seqinfo"),
    function(x, y, ...) .merge_Seqinfo_objects(x, y, ...)
)

setMethod("intersect", c("Seqinfo", "Seqinfo"), function(x, y) {
  merge(x, y)[intersect(seqnames(x), seqnames(y))]
})

### Update the entries in Seqinfo object 'object' with the corresponding
### entries in Seqinfo object 'value'. Note that the seqnames in 'value'
### must be a subset of the seqnames in 'object'.
.update_Seqinfo <- function(object, value)
{
   if (!is(object, "Seqinfo"))
        stop("object to update 'object' must be a Seqinfo object")
   if (!is(value, "Seqinfo"))
        stop("replacement value must be a Seqinfo object")

    ## Infer 'i'.
    i <- match(seqnames(value), seqnames(object))
    if (anyNA(i))
        stop(wmsg("the seqnames in replacement Seqinfo object must be ",
                  "a subset of the seqnames in Seqinfo object to update"))

    ## Modify and return 'object'.
    object@seqlengths[i] <- value@seqlengths
    object@is_circular[i] <- value@is_circular
    object@genome[i] <- value@genome
    object
}

### S3/S4 combo for update.Seqinfo
update.Seqinfo <- function(object, ...) .update_Seqinfo(object, ...)
setMethod("update", "Seqinfo", update.Seqinfo)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### checkCompatibleSeqinfo()
###

checkCompatibleSeqinfo <- function(x, y) merge(seqinfo(x), seqinfo(y))

