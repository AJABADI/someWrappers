#' Install a list of packages in R
#'
#' @param pkgs a character vector of packages
#' @param max_size size (in bytes) beyond which the pkgs will not be installed
#' @param file.path the path to a R/Rmd file containing library() and/or require() statements, or to the /Resources/library directory
#' of another R version
#'
#' @return a data.frame containing successful and failed/non-installation info
#' @rdname install_utils
#' @export install_pkgs
#' @family install_utils
install_pkgs <- function(pkgs=NULL, file.path=NULL, max_size = 1000000) {
  #### if path to a file given ---------------------------------------
  if(is.null(pkgs) & !is.null(file.path)){
    if(grepl('R.framework/Versions/.*Resources/library$', file.path)){
      .dirsize <- function(pkgdir) {
        sum(file.info(list.files(path = pkgdir, recursive = T, full.names = T))$size)
      }
      pkgs <- list.files(file.path, full.names = TRUE)
      ## if 'file.path' is the path to another version's library folder --------------------
      pkgs <- data.frame(row.names = NULL, package = basename(pkgs),
                 size = sapply(pkgs, .dirsize))
      pkgs <- pkgs[order(pkgs$size),]
    } else {
      ## if it is a path to a single file --------------------
      foo <- readLines(file.path)
      foo <- foo[grepl("library", foo) | grepl("require", foo)]
      .libExtract <- function(foo)
        sapply(foo, function(foo) regmatches(foo, gregexpr("(?<=\\().*?(?=\\))", foo, perl=T))[[1]]) %>% unname()

      pkgs <- .libExtract(foo = foo)
      pkgs <- pkgs[!duplicated(pkgs)]
      pkgs <- data.frame(package = pkgs)
      pkgs$size <- 1
    }

    #### if pkg names given ---------------------------------------

  } else if(!is.null(pkgs) & is.null(file.path)){
    if (is(pkgs, "character")){
      pkgs <- pkgs[!duplicated(pkgs)]
      pkgs <- data.frame(package = pkgs)
      pkgs$size <- 1
    }


  } else {
    stop("exactly one of 'pkgs' or 'file.path' should be NULL")
  }

  big_pkgs <- as.character(pkgs[pkgs$size > max_size, ]$package)

  options("install.packages.compile.from.source" = "no")
  if (!requireNamespace("BiocManager"))
    install.packages('BiocManager')

  out <- data.frame(row.names = pkgs$package)
  out$status <- "preinstalled"
  out[big_pkgs,'status'] <- "size exceeded"
  out$VERSION <- NA ## just to keep it a data.frame after subsetting
  pkgs <- pkgs[!pkgs$package %in% installed.packages()[, "Package"], ]
  pkgs <- pkgs[!pkgs$package %in% big_pkgs, ]
  message(paste("installing: ", pkgs$package, collapse = "\n"))
  a <- readline("Press Enter")
  for (i in pkgs$package) {
    try(BiocManager::install(i, update = FALSE, ask = FALSE))
    if(!i %in% installed.packages()[,"Package"]){
      try(install.packages(i,))
    }
    if(!i %in% installed.packages()[,"Package"]){
      out[i, "status"] <- "failed"
    } else {
      out[i, "status"] <- "successful"
    }

  }

  message("\n\nPkgs skipped due to size being greater than ", max_size," bytes: ")
  message(paste(big_pkgs, collapse = ", "))

  message("\n\npackages failed to install: ")
  message(paste(rownames(out[out$status == "failed", ]), collapse = ", "))

  message("\n\npackages already installed: ")
  message(paste(rownames(out[out$status == "preinstalled", ]), collapse = ", "))

  invisible(out)
}
