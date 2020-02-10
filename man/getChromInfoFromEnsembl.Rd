\name{getChromInfoFromEnsembl}

\alias{getChromInfoFromEnsembl}

\title{
  Get chromosome information for an Ensembl dataset
}

\description{
  WORK IN PROGRESS!

  \code{getChromInfoFromEnsembl} returns chromosome information like
  sequence names, lengths and circularity flags for a given Ensembl dataset
  e.g. hsapiens_gene_ensembl, scerevisiae_gene_ensembl, etc...
}

\usage{
getChromInfoFromEnsembl(dataset,
                        release=NA, use.grch37=FALSE, kingdom=NA,
                        assembled.molecules.only=FALSE,
                        coord.systems=NULL,
                        include.non_ref.sequences=FALSE,
                        include.contigs=FALSE,
                        include.clones=FALSE,
                        recache=FALSE,
                        as.Seqinfo=FALSE)
}

\arguments{
  \item{dataset}{
    A single string specifying the name of an Ensembl dataset (e.g.
    \code{"hsapiens_gene_ensembl"}).
  }
  \item{release}{
    The Ensembl release to query e.g. 89. If set to \code{NA} (the
    default), the current release is used.
  }
  \item{use.grch37}{
    NOT TESTED YET!

    \code{TRUE} or \code{FALSE} (the default).
  }
  \item{kingdom}{
    NOT TESTED YET!

    \code{NA} (the default) or one of the EnsemblGenomes marts i.e.
    \code{"bacteria"}, \code{"fungi"}, \code{"metazoa"}, \code{"plants"},
    or \code{"protists"}.
  }
  \item{assembled.molecules.only}{
    NOT IMPLEMENTED YET!
  }
  \item{coord.systems}{
    TODO: DOCUMENT THIS!
  }
  \item{include.non_ref.sequences}{
    TODO: DOCUMENT THIS!
  }
  \item{include.contigs}{
    Whether or not sequences for which \code{coord_system} is set to
    \code{"contig"} should be included. They are not included by
    default. Note that dataset \code{hsapiens_gene_ensembl} contains
    more than one hundred thousands \emph{contigs}.
  }
  \item{include.clones}{
    Whether or not sequences for which \code{coord_system} is set to
    \code{"clone"} should be included. They are not included by
    default. Note that dataset \code{hsapiens_gene_ensembl} contains
    more than one hundred thousands \emph{clones}.
  }
  \item{recache}{
    \code{getChromInfoFromEnsembl} uses a cache mechanism so the
    chromosome information of a given dataset only gets downloaded
    once during the current R session (note that the caching is done
    in memory so cached information does NOT persist across sessions).
    Setting \code{recache} to \code{TRUE} forces a new download (and
    recaching) of the chromosome information for the specified dataset.
  }
  \item{as.Seqinfo}{
    \code{TRUE} or \code{FALSE} (the default). If \code{TRUE} then a
    \link{Seqinfo} object is returned instead of a data frame. Note that
    only the \code{name}, \code{length}, and \code{circular} columns of
    the data frame are used to make the \link{Seqinfo} object. All the
    other columns are ignored (and lost).
  }
}

\details{
  COMING SOON...
}

\value{
  For \code{getChromInfoFromEnsembl}: By default, a 7-column data frame
  with columns:
  \enumerate{
    \item \code{name}: character.
    \item \code{length}: integer.
    \item \code{coord_system}: factor.
    \item \code{synonyms}: list.
    \item \code{toplevel}: logical.
    \item \code{non_ref}: logical.
    \item \code{circular}: logical.
  }
}

\author{
  H. Pagès
}

\seealso{
  \itemize{
    \item \code{\link{getChromInfoFromNCBI}} and
          \code{\link{getChromInfoFromUCSC}} for getting chromosome
          information for an NCBI or UCSC genome assembly.

    \item \link{Seqinfo} objects.
  }
}

\examples{
## ---------------------------------------------------------------------
## A. BASIC EXAMPLES
## ---------------------------------------------------------------------

## Internet access required!

getChromInfoFromEnsembl("celegans_gene_ensembl")

getChromInfoFromEnsembl("celegans_gene_ensembl", as.Seqinfo=TRUE)

getChromInfoFromEnsembl("scerevisiae_gene_ensembl")

getChromInfoFromEnsembl("scerevisiae_gene_ensembl", as.Seqinfo=TRUE)

## ---------------------------------------------------------------------
## Temporary stuff that needs to go away...
## ---------------------------------------------------------------------
\dontrun{
## WORK IN PROGRESS!!!
library(GenomeInfoDb)

.do_join <- GenomeInfoDb:::.do_join
.map_Ensembl_seqlevels_to_NCBI_seqlevels <-
    GenomeInfoDb:::.map_Ensembl_seqlevels_to_NCBI_seqlevels

.map_Ensembl_seqlevels_to_NCBI_seqlevels(
    paste0("ENS_", 1:26),
    CharacterList(c(list(c(aa="INSDC1", bb="GNBK7"), c("INSDC2", "RefSeq3")),
                    rep(list(NULL), 23), list("NCBI_7"))),
    paste0("NCBI_", 1:10),
    paste0("GNBK", c(1:8, NA, 9)),
    c(paste0("REFSEQ", c(1:7, 1, 1)), NA),
    verbose=TRUE
)

map_to_NCBI <- function(Ensembl_chrom_info, NCBI_chrom_info,
                        special_mappings=NULL)
{
    .map_Ensembl_seqlevels_to_NCBI_seqlevels(
         Ensembl_chrom_info[ , "name"],
         Ensembl_chrom_info[ , "synonyms"],
         NCBI_chrom_info[ , "SequenceName"],
         NCBI_chrom_info[ , "GenBankAccn"],
         NCBI_chrom_info[ , "RefSeqAccn"],
         special_mappings=special_mappings,
         verbose=TRUE)
}

## ------------------------------------------------------------------------
## Yeast
## https://uswest.ensembl.org/Saccharomyces_cerevisiae/Info/Index
## Based on R64-1-1 (GCA_000146045.2, called R64 at NCBI)

## Return 17 rows
yeast_chrom_info <- getChromInfoFromEnsembl("scerevisiae_gene_ensembl")

## Mapping to NCBI is one-to-one!
R64 <- getChromInfoFromNCBI("R64")
## Same sequence names except that Mito is called MT at NCBI.
## Mito (GenBank=AJ011856.1) and MT (GenBank=KP263414.1,
## RefSeq=NC_001224.1) are exactly the same DNA sequence. Don't ask me why
## we need 2 GenBank entries for that and why only the latter is associated
## with a RefSeq accession!
special_mappings <- c(Mito="MT")
L2R <- map_to_NCBI(yeast_chrom_info, R64, special_mappings)
yeast_chrom_info <- .do_join(yeast_chrom_info, R64, L2R)

## ------------------------------------------------------------------------
## Worm
## https://uswest.ensembl.org/Caenorhabditis_elegans/Info/Index
## Based on WBcel235 (GCA_000002985.3)

## Return 7 rows
worm_chrom_info <- getChromInfoFromEnsembl("celegans_gene_ensembl")

## Mapping to NCBI is one-to-one!
WBcel235 <- getChromInfoFromNCBI("WBcel235")
## Same sequence names except that MtDNA is called MT at NCBI (MtDNA and MT
## are both associated with RefSeqAccn NC_001328.1).
L2R <- map_to_NCBI(worm_chrom_info, WBcel235)
worm_chrom_info <- .do_join(worm_chrom_info, WBcel235, L2R)
table(worm_chrom_info$SequenceRole, worm_chrom_info$toplevel)

## ------------------------------------------------------------------------
## Human
## https://uswest.ensembl.org/Homo_sapiens/Info/Index
## Based on GRCh38.p13 (GCA_000001405.28)

## Return 944 rows
human_chrom_info <- getChromInfoFromEnsembl("hsapiens_gene_ensembl")
#                 1 id: 131550  <- ref chromosome
# CHR_HSCHR1_1_CTG3 id: 131561  <- non-ref chromosome
#     HSCHR1_1_CTG3 id: 131562  <- scaffold (no scaffold is non_ref)

## Map to NCBI
## Summary:
## - 639/640 NCBI sequences are reverse-mapped.
## - Restricted mapping is one-to-one.
GRCh38.p13 <- getChromInfoFromNCBI("GRCh38.p13")
L2R <- map_to_NCBI(human_chrom_info, GRCh38.p13)
## The only sequence in GRCh38.p13 that cannot be mapped to Ensembl is
## HG2139_PATCH (was introduced in GRCh38.p2)! Why? What's special about
## this patch?
GRCh38.p13$mapped <- tabulate(L2R, nbins=nrow(GRCh38.p13)) != 0L
table(GRCh38.p13$SequenceRole, GRCh38.p13$mapped)
#                        FALSE TRUE
#   assembled-molecule       0   25
#   alt-scaffold             0  261
#   unlocalized-scaffold     0   42
#   unplaced-scaffold        0  127
#   pseudo-scaffold          0    0
#   fix-patch                1  112
#   novel-patch              0   72
human_chrom_info <- .do_join(human_chrom_info, GRCh38.p13, L2R)
table(human_chrom_info$SequenceRole, human_chrom_info$toplevel)
#                       FALSE TRUE
#  assembled-molecule       0   25
#  alt-scaffold           261    0
#  unlocalized-scaffold     0   42
#  unplaced-scaffold        0  127
#  pseudo-scaffold          0    0
#  fix-patch              112    0
#  novel-patch             72    0

#hsa_seqlevels <- readRDS("hsapiens_gene_ensembl_txdb_seqlevels.rds")

## ------------------------------------------------------------------------
## Mouse
## https://uswest.ensembl.org/Mus_musculus/Info/Index
## Based on GRCm38.p6 (GCA_000001635.8)

## Valid coord.systems: contig, chromosome, scaffold, clone, lrg
## Return 258 rows
mouse_chrom_info <- getChromInfoFromEnsembl("mmusculus_gene_ensembl")

## Map to NCBI
## Summary:
## - 139/239 NCBI sequences are reverse-mapped.
## - Restricted mapping is NOT one-to-one: 2 Ensembl sequences (NC_005089.1
##   and MT) are both mapped to NCBI MT.
GRCm38.p6 <- getChromInfoFromNCBI("GRCm38.p6")
L2R <- map_to_NCBI(mouse_chrom_info, GRCm38.p6)
## 100 sequences in GRCm38.p6 are not mapped:
GRCm38.p6$mapped <- tabulate(L2R, nbins=nrow(GRCm38.p6)) != 0L
table(GRCm38.p6$SequenceRole, GRCm38.p6$mapped)
#                        FALSE TRUE
#   assembled-molecule       0   22
#   alt-scaffold            99    0
#   unlocalized-scaffold     0   22
#   unplaced-scaffold        0   22
#   pseudo-scaffold          0    0
#   fix-patch                1   64
#   novel-patch              0    9
## OK so Ensembl doesn't include the alt-scaffolds for Mouse. BUT WHAT
## HAPPENED TO THIS ONE fix-patch SEQUENCE (MG4237_PATCH) THAT IS NOT
## MAPPED? Found it in seq_region_synonym table! It's seq_region_id=100405.
## Hey but that seq_region_id is **NOT** in the seq_region table!!! THIS
## VIOLATES FOREIGN KEY CONSTRAINT!!!!
mouse_chrom_info <- .do_join(mouse_chrom_info, GRCm38.p6, L2R)
## Ensembl does NOT comsider NC_005089.1 (duplicate entry for MT) toplevel:
mouse_chrom_info[mouse_chrom_info$SequenceName %in% "MT", c(1:5, 8, 11, 13)]
#            name length coord_system                      synonyms toplevel
# 184 NC_005089.1  16299     scaffold                                  FALSE
# 201          MT  16299   chromosome NC_005089.1, chrM, AY172335.1     TRUE
#     SequenceName GenBankAccn  RefSeqAccn
# 184           MT  AY172335.1 NC_005089.1
# 201           MT  AY172335.1 NC_005089.1

## ------------------------------------------------------------------------
## Rat
## https://uswest.ensembl.org/Rattus_norvegicus/Info/Index
## Based on Rnor_6.0 (GCA_000001895.4)

# Return 1418 rows
rat_chrom_info <- getChromInfoFromEnsembl("rnorvegicus_gene_ensembl")

## Map to NCBI
## Summary:
## - 955/955 NCBI sequences are reverse-mapped.
## - Reverse mapping is one-to-many: 2 Ensembl sequences (NC_001665.2 and MT)
##   are mapped to NCBI MT.
Rnor_6.0 <- getChromInfoFromNCBI("Rnor_6.0")
L2R <- map_to_NCBI(rat_chrom_info, Rnor_6.0)
rat_chrom_info <- .do_join(rat_chrom_info, Rnor_6.0, L2R)

## Ensembl does NOT comsider NC_001665.2 (duplicate entry for MT) toplevel:
rat_chrom_info[rat_chrom_info$SequenceName %in% "MT", c(1:5, 8, 11, 13)]
#             name length coord_system                      synonyms toplevel
# 1417 NC_001665.2  16313     scaffold                                  FALSE
# 1418          MT  16313   chromosome NC_001665.2, AY172581.1, chrM     TRUE
#      SequenceName GenBankAccn  RefSeqAccn
# 1417           MT  AY172581.1 NC_001665.2
# 1418           MT  AY172581.1 NC_001665.2

table(rat_chrom_info$SequenceRole, rat_chrom_info$toplevel)
#                        FALSE TRUE
#   assembled-molecule       1   23
#   alt-scaffold             0    0
#   unlocalized-scaffold     0  354
#   unplaced-scaffold        0  578
#   pseudo-scaffold          0    0
#   fix-patch                0    0
#   novel-patch              0    0

## ------------------------------------------------------------------------
## Cow
## https://uswest.ensembl.org/Bos_taurus/Info/Index
## Based on ARS-UCD1.2 (GCA_002263795.2)

## Return 2211 rows
cow_chrom_info <- getChromInfoFromEnsembl("btaurus_gene_ensembl")

## Map to NCBI:
## Summary:
## - All 2211 Ensembl sequences are mapped.
## - 2211/2212 NCBI sequences are reverse-mapped.
## - M is the only NCBI sequence that is not reverse-mapped (ARS-UCD1.2
##   has MT and M).
NCBI_cow <- getChromInfoFromNCBI("GCA_002263795.2")
L2R <- map_to_NCBI(cow_chrom_info, NCBI_cow)
cow_chrom_info <- .do_join(cow_chrom_info, NCBI_cow, L2R)
cow_chrom_info[ , c(1:5, 8, 11, 13)]
}
}

\keyword{manip}