#' Two way table
#'
#' Creates two way tables of categorical variables. The tables created can be
#' visualized as barplots and mosaicplots.
#'
#' @param data A \code{data.frame} or a \code{tibble}.
#' @param var1 First categorical variable.
#' @param var2 Second categorical variable.
#' @param x An object of class \code{cross_table}.
#' @param stacked If \code{FALSE}, the columns of height are portrayed
#' as stacked bars, and if \code{TRUE} the columns are portrayed as juxtaposed bars.
#' @param proportional If \code{TRUE}, the height of the bars is proportional.
#' @param ... Further arguments to be passed to or from methods.
#'
#' @examples
#' k <- ds_cross_table(mtcarz, cyl, gear)
#' k
#'
#' # bar plots
#' plot(k)
#' plot(k, stacked = TRUE)
#' plot(k, proportional = TRUE)
#'
#' # alternate
#' ds_twoway_table(mtcarz, cyl, gear)
#'
#' @export
#'
ds_cross_table <- function(data, var1, var2) UseMethod("ds_cross_table")

#' @export
ds_cross_table.default <- function(data, var1, var2) {

  check_df(data)
  var1_name <- deparse(substitute(var1))
  var2_name <- deparse(substitute(var2))
  var_1 <- rlang::enquo(var1)
  var_2 <- rlang::enquo(var2)
  check_factor(data, !! var_1, var1_name)
  check_factor(data, !! var_2, var2_name)

  var_names <-
    data %>%
    dplyr::select(!! var_1, !! var_2) %>%
    names()

  varone   <- dplyr::pull(data, !! var_1)
  vartwo   <- dplyr::pull(data, !! var_2)
  row_name <- get_names(varone)
  col_name <- get_names(vartwo)

  x <- 
    table(varone, vartwo) %>%
    as.matrix() %>%
    magrittr::set_rownames(NULL)
  
  n <- sum(x)
  
  per_mat <- 
    x %>%
    magrittr::divide_by(n) %>%
    round(3)

  row_pct  <- apply(per_mat, 1, sum)
  col_pct  <- apply(per_mat, 2, sum)
  rowtotal <- apply(x, 1, sum)
  coltotal <- apply(x, 2, sum)
  finalmat <- prep_per_mat(per_mat, row_pct, col_pct)  
  rcent    <- prep_rcent(x, rowtotal, row_pct)
  ccent    <- prep_ccent(x, coltotal)
  finaltab <- prep_table(x, rowtotal, row_name)
  

  result <- list(
    obs = n, var2_levels = col_name, var1_levels = row_name, varnames = var_names,
    twowaytable = finaltab, percent_table = finalmat, row_percent = rcent, column_percent = ccent,
    column_totals = coltotal, percent_column = col_pct, data = data
  )


  class(result) <- "ds_cross_table"
  return(result)
}

#' @export
print.ds_cross_table <- function(x, ...) {
  print_cross(x)
}

#' @export
#' @rdname ds_cross_table
#'
plot.ds_cross_table <- function(x, stacked = FALSE, proportional = FALSE, ...) {

  x_lab <-
    x %>%
    magrittr::use_series(varnames) %>%
    magrittr::extract(1)

  y_lab <-
    x %>%
    magrittr::use_series(varnames) %>%
    magrittr::extract(2)

  k <- string_to_name(x)
  j <- string_to_name(x, 2)

  if (proportional) {
    p <-
      x %>%
      magrittr::use_series(data) %>%
      dplyr::select(x = !! k, y = !! j) %>%
      table() %>%
      tibble::as_tibble() %>%
      ggplot2::ggplot(ggplot2::aes(x = x, y = n, fill = y)) +
      ggplot2::geom_bar(stat = "identity", position = "fill") +
      ggplot2::scale_y_continuous(labels = scales::percent_format()) +
      ggplot2::xlab(x_lab) + ggplot2::ggtitle(paste(x_lab, "vs", y_lab)) +
      ggplot2::labs(fill = y_lab)
  } else {
    if (stacked) {
      p <-
        x %>%
        magrittr::use_series(data) %>%
        dplyr::select(x = !! k, y = !! j) %>%
        ggplot2::ggplot() +
        ggplot2::geom_bar(ggplot2::aes(x, fill = y), position = "stack") +
        ggplot2::xlab(x_lab) + ggplot2::ggtitle(paste(x_lab, "vs", y_lab)) +
        ggplot2::labs(fill = y_lab)
    } else {
      p <-
        x %>%
        magrittr::use_series(data) %>%
        dplyr::select(x = !! k, y = !! j) %>%
        ggplot2::ggplot() +
        ggplot2::geom_bar(ggplot2::aes(x, fill = y), position = "dodge") +
        ggplot2::xlab(x_lab) + ggplot2::ggtitle(paste(x_lab, "vs", y_lab)) +
        ggplot2::labs(fill = y_lab)
    }
  }

  print(p)
  result <- list(plot = p)
  invisible(result)
}

#' @importFrom magrittr %<>%
#' @rdname ds_cross_table
#' @export
#'
ds_twoway_table <- function(data, var1, var2) {

  check_df(data)
  var1_name <- deparse(substitute(var1))
  var2_name <- deparse(substitute(var2))
  
  var_1 <- rlang::enquo(var1)
  var_2 <- rlang::enquo(var2)
  check_factor(data, !! var_1, var1_name)
  check_factor(data, !! var_2, var2_name)

  group <-
    data %>%
    dplyr::select(!! var_1, !! var_2) %>%
    tidyr::drop_na() %>%
    dplyr::group_by(!! var_1, !! var_2) %>%
    dplyr::summarise(count = dplyr::n())

  total <-
    group %>%
    dplyr::pull(count) %>%
    sum()

  div_by <-
    data %>%
    dplyr::group_by(!! var_2) %>%
    tidyr::drop_na() %>%
    dplyr::tally() %>%
    dplyr::pull(n)


  group2 <-
    data %>%
    dplyr::select(!! var_1, !! var_2) %>%
    tidyr::drop_na() %>%
    dplyr::group_by(!! var_2, !! var_1) %>%
    dplyr::summarise(count = dplyr::n()) %>%
    dplyr::mutate(
      col_percent = count / sum(count)
    ) %>%
    dplyr::ungroup()

  group %<>%
    dplyr::mutate(
      percent     = count / total,
      row_percent = count / sum(count)
    ) %>%
    dplyr::ungroup()

  result <- dplyr::inner_join(group, group2)
  return(result)

}

get_names <- function(x) {
  
  if (is.factor(x)) {
    varname <- levels(x)
  } else {
    varname <- 
      x %>%
      sort() %>%
      unique()
  }
  
  return(varname)
  
}

prep_table <- function(x, rowtotal, row_name) {

  x1 <- cbind(x, rowtotal)
  cbind(unname(row_name), x1)

}

prep_per_mat <- function(per_mat, row_pct, col_pct) {

  per_mat_1             <- cbind(per_mat, row_pct)
  per_mat_2             <- suppressWarnings(rbind(per_mat_1, col_pct))
  d                     <- dim(per_mat_2)
  per_mat_2[d[1], d[2]] <- 1
  return(per_mat_2)

}

prep_rcent <- function(x, rowtotal, row_pct) {

  rcent_1 <- row_pct(x, rowtotal)
  rcent_2 <- cbind(rcent_1, row_pct)
  apply(rcent_2, c(1, 2), rounda)

}

prep_ccent <- function(x, coltotal) {

  ccent_1 <- col_pct(x, coltotal)
  apply(ccent_1, c(1, 2), rounda)

}