# .onLoad <- function(libname, pkgname) {
#   op <- options()
#   op.rENA <- list(
#     UNIT_NAMES = "ena.unit.names",
#     TRAJ_TYPES = c("accumulated","non-accumulated")
#   );
#
#   toset <- !("rENA" %in% names(op))
#   print(paste("ToSet:", toset));
#
#   if(toset) {
#     options(rENA = op.rENA)
#   }
#
#   invisible()
# }
