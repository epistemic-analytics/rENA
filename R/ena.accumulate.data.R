##
#' @title Accumulate Data from separate data frames
#'
#' @description This function initializes an ENAdata object, processing conversations from coded data to generate adjacency vectors.
#'
#' @details ENAData R6 Objects are created using this function. This accumulation receives separate data frames for units, codes, conversation, and optionally, metadata. It iterates through the data using information including units, conversation, and window size to process the conversations. Options for how the data is accumulated are endpoint, which is the standard, non-trajectory model, and two trajectory model types: accumulated and separate.
#'
#' @export
#'
#' @param units A data frame where the columns are the properties by which units will be constructed
#' @param conversation A data frame where the columns are the properties by which conversations will be accumulated
#' @param codes A data frame where the columns are the codes for which the text data has been coded
#' @param metadata (optional) A data frame with additional columns to be include with other data (units/conversation/codes)
#' @param model A character, choices: EndPoint(E), AccumulatedTrajectory(A), or SeparateTrajectory(S), default: EndPoint
#' @param weight.by (optional) A function to apply to values after accumulation
#' @param mask (optional) A binary matrix where 0s can be used to mask certain code co-occurences
#' @param window A character, choices are conversation(C) or the default moving stanza (MS or S)
#' @param window.size.back An integer or character, can be a positive int or INF (infinite), determines the number of lines back to include window in stanza, default: 1
#' @param window.size.forward (optional) An integer that determines the number of lines forward in stanza window, default to NULL
#' @param ... additional parameters addressed in inner function
#'
#' @keywords data, accumulate
#'
#' @seealso \code{\link{ENAdata}}, \code{\link{ena.make.set}}
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
#' @return \code{\link{ENAdata}} object with data (adjacency vectors) accumulated from the provided data frames including unit and conversation info as well as code co-occurrences.
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
  window = c("Moving Stanza", "Conversation"),
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

  metadata = data.table::as.data.table(metadata)
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
    codes = codes,

    window.size.back = window.size.back,
    window.size.forward = window.size.forward,

    weight.by = weight.by,

    model = model,
    mask = mask,
    ...
  );

  data$function.call = sys.call();

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
}

