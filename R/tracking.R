
#' @title Insert dependencies to track usage of a Shiny app
#'
#' @description If used in \code{ui} of an application,
#'  this will create new \code{input}s available in the server.
#'
#' @param on_unload Logical, save log when user close the browser window or tab,
#'  if \code{TRUE} it prevent to create \code{shinylogs}
#'  input during normal use of the application, there will
#'  be created only on close, downside is that a popup will appear asking to close the page.
#' @param exclude_input Regular expression to exclude inputs from tracking.
#'
#' @note The following \code{input}s will be accessible in the server:
#'
#'   - \strong{.shinylogs_lastInput} : last \code{input} used by the user
#'
#'   - \strong{.shinylogs_input} : all \code{input}s send from the browser to the server
#'
#'   - \strong{.shinylogs_error} : all errors generated by \code{output}s elements
#'
#'   - \strong{.shinylogs_output} : all \code{output}s generated from the server
#'
#'   - \strong{.shinylogs_browserData} : information about the browser where application is displayed.
#'
#' @export
#'
#' @importFrom htmltools attachDependencies tags singleton
#' @importFrom jsonlite toJSON
#' @importFrom nanotime nanotime
#' @importFrom bit64 as.integer64
#' @importFrom digest digest
tracking_ui <- function(on_unload = FALSE, exclude_input = NULL) {
  timestamp <- Sys.time()
  timestamp <- format(as.integer64(nanotime(timestamp)), scientific = FALSE)
  sessionid <- digest::digest(timestamp)
  tag_log <- tags$div(tags$script(
    id = "shinylogs-tracking",
    type = "application/json",
    `data-for` = "shinylogs",
    toJSON(list(
      logsonunload = isTRUE(on_unload),
      excludeinput = exclude_input,
      sessionid = sessionid
    ), auto_unbox = TRUE, json_verbatim = TRUE)
  ))
  attachDependencies(
    x = singleton(tag_log),
    value = list(
      localforage_dependencies(),
      dayjs_dependencies(),
      shinylogs_lf_dependencies()
    )
  )
}



#' @importFrom stats setNames
parse_log <- function(x, shinysession, name) {
  lapply(
    X = x,
    FUN = function(x) {
      setNames(x, NULL)
    }
  )
}

#' @importFrom anytime anytime
parse_lastInput <- function(x, shinysession, name) {
  if (!is.null(x)) {
    x$timestamp <- anytime(x$timestamp)
  }
  return(x)
}


#' @title Track usage of a Shiny app
#'
#' @description Used in Shiny \code{server} it will save everything that happens in a Shiny app.
#'
#' @param storage_mode Storage mode to use : \code{\link{store_json}}.
#' @param exclude_input_regex Regular expression to exclude inputs from tracking.
#' @param exclude_input_id Vector of \code{inputId} to exclude from tracking.
#' @param on_unload Logical, save log when user close the browser window or tab,
#'  if \code{TRUE} it prevent to create \code{shinylogs}
#'  input during normal use of the application, there will
#'  be created only on close, downside is that a popup will appear asking to close the page.
#' @param exclude_users Character vectors of user for whom it is not necessary to save the log.
#' @param get_user A \code{function} to get user name, it should return a character and take one argument: the Shiny session.
#' @param session The shiny session.
#'
#' @export
#'
#' @importFrom shiny getDefaultReactiveDomain insertUI onSessionEnded isolate
#' @importFrom nanotime nanotime
#' @importFrom bit64 as.integer64
#' @importFrom digest digest
#' @importFrom jsonlite toJSON
#' @importFrom htmltools tags singleton
track_usage <- function(storage_mode = store_json(),
                        exclude_input_regex = NULL,
                        exclude_input_id = NULL,
                        on_unload = FALSE,
                        exclude_users = NULL,
                        get_user = NULL,
                        session = getDefaultReactiveDomain()) {

  stopifnot(inherits(storage_mode, "shinylogs.storage_mode"))

  app_name <- basename(getwd())
  if (is.null(get_user))
    get_user <- get_user_
  if (!is.function(get_user))
    stop("get_user must be a function", call. = FALSE)
  user <- get_user(session)
  timestamp <- Sys.time()
  init_log <- data.frame(
    app = app_name,
    user = user,
    server_connected = get_timestamp(timestamp),
    stringsAsFactors = FALSE
  )
  storage_mode$appname <- app_name
  storage_mode$timestamp <- format(as.integer64(nanotime(timestamp)), scientific = FALSE)
  init_log$sessionid <- digest::digest(storage_mode$timestamp)

  insertUI(
    selector = "body", where = "afterBegin",
    ui = singleton(tags$script(
      id = "shinylogs-tracking",
      type = "application/json",
      `data-for` = "shinylogs",
      toJSON(dropNulls(list(
        logsonunload = isTRUE(on_unload),
        exclude_input_regex = exclude_input_regex,
        exclude_input_id = exclude_input_id,
        sessionid = init_log$sessionid
      )), auto_unbox = TRUE, json_verbatim = TRUE)
    )),
    immediate = TRUE,
    session = session
  )
  insertUI(
    selector = "body", where = "afterBegin",
    ui = attachDependencies(
      x = tags$div(),
      value = list(
        localforage_dependencies(),
        dayjs_dependencies(),
        shinylogs_lf_dependencies()
      )
    ),
    immediate = FALSE,
    session = session
  )


  onSessionEnded(
    fun = function() {
      init_log$server_disconnected <- get_timestamp(Sys.time())
      logs <- c(isolate(session$input$.shinylogs_input),
                isolate(session$input$.shinylogs_error),
                isolate(session$input$.shinylogs_output))
      browser_data <- isolate(session$input$.shinylogs_browserData)
      browser_data <- as.data.frame(browser_data)
      logs$session <- cbind(init_log, browser_data)
      if (isTRUE(!user %in% exclude_users)) {
        write_logs(storage_mode, logs)
      }
    },
    session = session
  )
}


get_user_ <- function(session) {
  if (!is.null(session$user))
    return(session$user)
  user <- Sys.getenv("SHINYPROXY_USERNAME")
  if (user != "") {
    return(user)
  } else {
    getOption("shinylogs.default_user", default = Sys.info()[['user']])
  }
}






