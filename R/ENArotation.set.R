#######
# ENARotationSet R6class
#
## Node positions
## Rotation matrix
#
# @docType class
# @importFrom R6 R6Class
# @import data.table
# @export
#
# @param file CSV, data.frame, or data.table
# @param unitsBy String vector representing column names to use for units
# @param units String vector of which units to include in the ENAset
# @param conversationsBy String vector of column names to create the conversations
# @param codeNames String vector of column names to use as codes
# @param windowSize Integer used to select the size of each stanza window within a conversation
# @param binary Logical, whether to convert code values to binary or allow for weigthed values
# @param unitsSelected deprecated
#
# @section Public ENAdata methods:
#######
ENARotationSet = R6::R6Class("ENARotationSet",
  public = list(

    #######
    ### Constructor - documented in main class declaration
    #######
    initialize = function(
      file,
      unitsBy = NULL, units = NULL,
      conversationsBy = NULL,
      codeNames = NULL,
      windowSize = 1,
      binary = T,
      unitsSelected = NULL,
      units.exclude = c(),
      ...
    ) {

    }
  )
);
