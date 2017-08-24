##
#' @title Accumulate Data from separate data frames
#'
#' @description This function accumulates rows of data.
#'
#' @details [TBD]
#'
#' @export
#'
#' @param file The csv file location or data.frame for the function
#' @param units.by Columns to be used in the unit accumulation (list of column names)
#' @param units Data frame of unit columns and values
#' @param conversations.by Columns to be used in the conversation accumulation (list of column names)
#' @param conversation NEW data frame of conversation columns w/ values
#' @param codes Columns used based on codes
#' @param window.size.back Number of lines back to include window in stanza
#' @param window.size.forward Number of lines forward in stanza window
#' @param binary [TBD]
#' @param correction [TBD]
#' @param trajectory.type [TBD]
#' @param output [TBD]
#' @param ... additional parameters addressed in inner function
#'
#' @keywords data, accumulate
#'
#' @seealso \code{\link{ena.split.codes}}, \code{\link{ena.make.set}}
#'
#' @examples
#' \dontrun{
#' codeNames = c(
#'   "E.data","S.data","E.design","S.design","S.professional","E.client",
#'   "V.client","E.consultant","V.consultant","S.collaboration","I.engineer",
#'   "I.intern","K.actuator","K.rom","K.materials","K.power"
#' )
#'
#' df.file <- system.file("extdata", "rs.data.csv", package="rENA")
#'
#' # Given a csv file location
#' ena.accumulate.data(
#'   df.file, units.by = c("UserName","Condition"),
#'   conversations.by = c("ActivityNumber","GroupName"),
#'   codes = codeNames
#' )
#' }
#' @return \code{\link{ENAdata}} class object with accumulated data
#'
##
ena.accumulate.data <- function(

  ##### NOTE: units, conversations, codes, and metadata must be data frames with the same number of rows
  units = NULL,   # data frame containing units
  conversation = NULL,    # df containing conversation lines
  codes = NULL,   # df containing codes
  metadata = NULL,   #optional - df containing metadata

  model = c("EndPoint", "AccumulatedTrajectory", "SeparateTrajectory"),   #use match arg and list?

  weight.by = "binary",
<<<<<<< HEAD

=======
  window = c("Moving Stanza", "Conversation"),
>>>>>>> 215a9f02e75f2d18d407e1cea1dd219a6140da2a
  window.size.back = 1,
  window.size.forward = 0,

  mask = NULL, #matrix (default - upper triangle of 1's)

  ### PARAMS NOT IN SPECS
  # output = c("class","json"),    #keep for now
  # output.fields = NULL,       #keep for now
  ...
) {

  if(is.null(units) || is.null(conversation) || is.null(codes)) {
    print("ACCUMULATION FROM DATA FRAMES REQUIRES: units, conversation, and codes");
  }
  if(nrow(units) != nrow(conversation) || nrow(conversation) != nrow(codes)) {
    print("Data Frames do not have the same number of rows!");
    ### throw error
  }

  df <- cbind(units, conversation);
  df <- cbind(df, codes);

  if(!is.null(metadata) && nrow(metadata) == nrow(df)) {
    df <- cbind(df, metadata);
  }

  units.by = colnames(units);   #accumulating by all unit columns provided in units df
  conversations.by = colnames(conversation); #accumulating by all columns provided in conversation df
  if(identical(window, "Conversation")) {
    conversations.by = c(conversations.by, units.by);
    window.size.back = window;
  }

  units.used = NULL;   # when accumulating from data frames, all units are used

  model = match.arg(model)

  data = ENAdata$new(
    file = df,

    units = units,    #data frame of unit columns (including values)
    units.used = units.used,

    units.by = units.by,    # KEEP- automatically uses all units for accumulation from separate data frames
    conversations.by = conversations.by,    #column names of conversation df, automatically accumulating by all cols for accum from dfs

<<<<<<< HEAD
    codes = codes,
=======
    window.size.back,
    window.size.forward,
>>>>>>> 215a9f02e75f2d18d407e1cea1dd219a6140da2a

    window.size.back = window.size.back,
    window.size.forward = window.size.forward,

    weight.by = weight.by,

    model = model,

    ...
  );

  data$function.call = sys.call();
<<<<<<< HEAD
  # output = match.arg(output);
  # if(output == "json") {
  #   output.class = get(class(data))
  #
  #   if(is.null(output.fields)) {
  #     output.fields = names(output.class$public_fields)
  #   }
  #
  #   r6.to.json(data, o.class = output.class, o.fields = output.fields)
  # }
  #else
  data
=======
  output = match.arg(output);
  if(output == "json") r6.to.json(data)
  else data
>>>>>>> 215a9f02e75f2d18d407e1cea1dd219a6140da2a
}

