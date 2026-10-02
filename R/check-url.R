check_tutorial_url <- function(url, online, timeout) {
  if (!online) {
    return(tutorial_check("not_run", "URL requests were disabled.", url = url))
  }
  method <- "HEAD"
  response <- tryCatch({
    response <- fetch_tutorial_url(url, method, timeout)
    # These statuses explicitly reject HEAD. Other failures must not be hidden
    # by retries that can turn an inconclusive check into an apparent pass.
    if (response$status_code %in% c(405L, 501L)) {
      method <- "GET"
      response <- fetch_tutorial_url(url, method, timeout)
    }
    response
  }, error = function(error) error)
  if (inherits(response, "error")) {
    return(tutorial_check(
      "not_run", paste("HTTP check could not complete:", conditionMessage(response)),
      url = url, method = method
    ))
  }
  code <- response$status_code
  status <- if (code >= 200L && code < 300L) {
    "pass"
  } else if (code %in% c(401L, 403L, 408L, 429L)) {
    "not_run"
  } else {
    "fail"
  }
  reason <- switch(status,
    pass = "The URL returned a successful HTTP response; content was not verified.",
    not_run = "Access restrictions, a timeout, or rate limiting prevented assessment.",
    fail = "The URL did not return a successful HTTP response."
  )
  tutorial_check(status, reason, url = url, method = method,
                 http_status = code, final_url = response$url)
}

fetch_tutorial_url <- function(url, method, timeout) {
  handle <- curl::new_handle(
    nobody = identical(method, "HEAD"), followlocation = TRUE, maxredirs = 5L,
    timeout = timeout, connecttimeout = timeout,
    protocols_str = "http,https", redir_protocols_str = "http,https",
    useragent = "tutorialverse prototype URL check"
  )
  if (method == "GET") {
    curl::handle_setopt(handle, range = "0-0")
  }
  # A server can ignore the range header. Discard streamed content rather than
  # accumulating a potentially large lesson or repository page in memory.
  response <- curl::curl_fetch_stream(url, function(chunk) invisible(NULL), handle)
  list(status_code = response$status_code, url = response$url)
}
