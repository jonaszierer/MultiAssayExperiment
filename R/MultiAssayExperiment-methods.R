#' @include MultiAssayExperiment-subset-methods.R
NULL

.generateMap <- function(colData, experiments) {
    samps <- colnames(experiments)
    assay <- factor(rep(names(samps), lengths(samps)), levels=names(samps))
    colname <- unlist(samps, use.names=FALSE)
    matches <- match(colname, rownames(colData))
    if (length(matches) && all(is.na(matches)))
        stop("no way to map colData to ExperimentList")
    primary <- rownames(colData)[matches]
    autoMap <- S4Vectors::DataFrame(
        assay=assay, primary=primary, colname=colname)

    if (nrow(autoMap) && any(is.na(autoMap[["primary"]]))) {
        notFound <- autoMap[is.na(autoMap[["primary"]]), ]
        warning("Data from rows:",
                sprintf("\n %s - %s", notFound[, 2], notFound[, 3]),
                "\ndropped due to missing phenotype data")
        autoMap <- autoMap[!is.na(autoMap[["primary"]]), ]
    }
    autoMap
}

### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Getters
###

#' @describeIn ExperimentList Get the dimension names for
#' an \code{ExperimentList} using \code{\link[IRanges]{CharacterList}}
setMethod("dimnames", "ExperimentList", function(x) {
    list(IRanges::CharacterList(lapply(x, rownames)),
    IRanges::CharacterList(lapply(x, colnames)))
})

#' @describeIn MultiAssayExperiment Get the dimension names
#' for a \code{MultiAssayExperiment} object
setMethod("dimnames", "MultiAssayExperiment", function(x) {
    dimnames(experiments(x))
})

#' @export
.DollarNames.MultiAssayExperiment <- function(x, pattern = "")
    grep(pattern, names(colData(x)), value = TRUE)

#' @aliases $,MultiAssayExperiment-method
#' @exportMethod $
#' @rdname MultiAssayExperiment-methods
setMethod("$", "MultiAssayExperiment", function(x, name) {
    colData(x)[[name]]
})

#' @describeIn MultiAssayExperiment A \code{logical} value indicating an empty
#' \code{MultiAssayExperiment}
#' @exportMethod isEmpty
setMethod("isEmpty", "MultiAssayExperiment", function(x)
    length(x) == 0L)

#' @exportMethod complete.cases
#' @describeIn MultiAssayExperiment Return a logical vector of biological units
#' with data across all experiments
setMethod("complete.cases", "MultiAssayExperiment", function(...) {
    args <- list(...)
    if (length(args) == 1L) {
        oldMap <- sampleMap(args[[1L]])
        listMap <- mapToList(oldMap)
        allPrimary <- Reduce(intersect,
                             lapply(listMap,
                                    function(element) {
                                        element[["primary"]]
                                    }))
        rownames(colData(args[[1L]])) %in% allPrimary
    }
})

.splitArgs <- function(args) {
    assayArgNames <- c("mcolname", "background", "type",
                       "make.names", "ranges")
    assayArgs <- args[assayArgNames]
    altArgs <- args[!names(args) %in% assayArgNames]
    assayArgs <- Filter(function(x) !is.null(x), assayArgs)
    list(assayArgs, altArgs)
}

#' @describeIn MultiAssayExperiment Add an element to the
#' \code{ExperimentList} data slot
#'
#' @param sampleMap \code{c} method: a \code{sampleMap} \code{list} or
#' \code{DataFrame} to guide merge
#' @param mapFrom Either a \code{logical}, \code{character}, or \code{integer}
#' vector indicating the experiment(s) that have an identical colname order as
#' the experiment input(s)
#'
#' @examples
#' example("MultiAssayExperiment")
#'
#' ## Add an experiment
#' test1 <- myMultiAssayExperiment[[1L]]
#' colnames(test1) <- rownames(colData(myMultiAssayExperiment))
#'
#' ## Combine current MultiAssayExperiment with additional experiment
#' ## (no sampleMap)
#' c(myMultiAssayExperiment, newExperiment = test1)
#'
#' test2 <- myMultiAssayExperiment[[1L]]
#' c(myMultiAssayExperiment, newExp = test2, mapFrom = 3L)
#'
setMethod("c", "MultiAssayExperiment", function(x, ..., sampleMap = NULL,
                                                mapFrom = NULL) {
    newExperiments <- list(...)
    if (!length(newExperiments))
        stop("No arguments provided")
    if (is.list(newExperiments[[1L]]) || is(newExperiments[[1L]], "List") &&
        !is(newExperiments[[1L]], "DataFrame"))
        newExperiments <- ExperimentList(newExperiments[[1L]])
    else
        newExperiments <- ExperimentList(newExperiments)
    if (is.null(names(newExperiments)))
        stop("Additional experiments must be named")
    if (is.null(sampleMap)) {
        if (!is.null(mapFrom)) {
            warning("Assuming column order in the data provided ",
                    "\n matches the order in 'mapFrom' experiment(s) colnames")
            addMaps <- mapToList(sampleMap(x))[mapFrom]
            names(addMaps) <- names(newExperiments)
            sampleMap <- mapply(function(x, y) {
                x[["colname"]] <- colnames(y)
                return(x)
            }, addMaps, newExperiments)
        } else {
        sampleMap <- .generateMap(colData(x), newExperiments)
        }
    }
    if (is(sampleMap, "DataFrame") || is.data.frame(sampleMap))
        sampleMap <- mapToList(sampleMap)
    else if (!is.list(sampleMap))
        stop("Provided 'sampleMap' must be either a 'DataFrame' or a 'list'")
    newListMap <- c(mapToList(sampleMap(x)),
                    IRanges::SplitDataFrameList(sampleMap))
    sampleMap(x) <- listToMap(newListMap)
    experiments(x) <- c(experiments(x), newExperiments)
    validObject(x)
    return(x)
})
