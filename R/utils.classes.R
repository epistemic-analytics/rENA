
as.metadata <- function(x) {
  if(is.factor(x)) {
    x = as.character(x)
  }
  class(x) = c("metadata") #, class(x))
  x
}
as.code <- function(x) {
  if(is.factor(x)) {
    x = as.character(x)
  }
  class(x) = c("code") #, class(x))
  x
}
as.codes <- function(x) {
  if(is.factor(x)) {
    x = as.character(x)
  }
  class(x) = c("codes") #, class(x))
  x
}
as.co.occurrence <- function(x) {
  if(is.factor(x)) {
    x = as.character(x)
  }
  class(x) = c("co.occurrence") #, class(x))
  x
}
as.dimension <- function(x) {
  if(is.factor(x)) {
    x = as.character(x)
  }
  class(x) = c("dimension") #, class(x))
  x
}
