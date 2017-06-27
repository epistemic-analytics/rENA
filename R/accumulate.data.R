accumulate.data <- function(
  dfDT,
  stanzasBy, unitsBy, units,
  code.names, stanzas = NULL,
  window = list("back" = 1, "forward" = NULL),
  append=F, binary=T, correction = NULL,
  units.exclude = c(),
  trajectory.by = NULL,
  trajectory.type = c("accumulated","non-accumulated")
) {

  ### We need data
    if(is.null(dfDT) || nrow(dfDT) < 1) return(-1);

    trajectory.type <- match.arg(trajectory.type);

  ###
  # We need a data.table, it's worth it.
  ###
    if(!data.table::is.data.table(dfDT)) {
      dfDT = data.table::as.data.table(dfDT);
    }

  ###
  # Make a copy of the data for safe usage
  ###
    dfDT_codes = data.table::copy(dfDT);

  ###
  # Create a column representing the ENA_UNIT as defined
  # by the the `unitsBy` parameter
  ###
    #dfDT_codes$ENA_UNIT = dfDT_codes[,{apply(.SD,1,function(x){paste(trimws(x),collapse=".")})},with=T,.SDcols=unitsBy];
    dfDT_codes$ENA_UNIT = merge_columns_c(dfDT_codes, cols=unitsBy, sep=".");
  ##
  # String vector of codesnames representing the names of the co-occurrences
  ##
    vL = length(code.names);
    adjacency.length = ( (vL * (vL + 1)) / 2) - vL ;
    codedTriNames = paste("adjacency.code",rep(1:adjacency.length), sep=".");

  ##
  # Accumulated windows appended to the end of each row
  #
  # FIXME: Don't append on the results to the initial data.table, keep a separate
  #        to lookup the results for the co-occurred values later on.
  ##
    # browser()
    if(window$back == 1) {
      dfDT.co.occurrences = dfDT_codes[,{
          ocs = data.table::as.data.table(rows_to_co_occurrences(.SD[,.SD,.SDcols=code.names, with=T]));

          # Return value from data.table back to dfDT.co.occurrences
          data.table::data.table(.SD,ocs)
        },
        .SDcols=c(code.names, stanzasBy, trajectory.by),
        with=T
      ];
    } else {
      dfDT.co.occurrences = dfDT_codes[,
          (codedTriNames) := ref_window_df(.SD[,.SD, .SDcols=code.names, with=T],windowSize=window$back, binary = binary),
        by=stanzasBy,
        .SDcols=c(unitsBy, code.names),
        with=T
      ];
    }

    message("FIX THE ENA UNIT, NOT SAFE TO COPY FROM dfDT_codes")
    dfDT.co.occurrences$ENA_UNIT = dfDT_codes$ENA_UNIT;


    colnames(dfDT.co.occurrences)[grep("V\\d+",colnames(dfDT.co.occurrences))] = codedTriNames
    #dfDT.co.occurrences$ENA_UNIT = merge_columns_c(dfDT.co.occurrences, cols=unitsBy, sep=".") #dfDT_codes$ENA_UNIT;

  ##
  # If units aren't supplied, use all available
  ##
    if(is.null(units)) {
      units = dfDT.co.occurrences$ENA_UNIT;
    }
    if(!is.null(units.exclude) && length(units.exclude)>0){
      units = units[which(!units %in% units.exclude)];
    }

  ###
  # Keep original columns used for units
  ###
    #dfDT.co.occurrences[, (unitsBy) := dfDT_codes[,.SD,.SDcols=unitsBy]];

  ###
  # Check whether operating as a Trajectory.
  ###

    ## Not a Trajectory
    if(is.null(trajectory.by)) {
      ###
      # Sum each unit found in dfDT.co.occurrences
      ###
        # dfDT.summed.units = dfDT.co.occurrences[ENA_UNIT %in% units, ref_window_sum(.SD),by = unitsBy, .SDcols = (codedTriNames)];
        dfDT.summed.units = dfDT.co.occurrences[ENA_UNIT %in% units, ref_window_sum(.SD),by = ENA_UNIT, .SDcols = (codedTriNames)];


        #dfDT.summed.units$ENA_UNIT = merge_columns_c(dfDT.summed.units, unitsBy, sep=".");
    }
    ## Trajectory
    else {
      ## First sum all units within each Trajectory Group (trajectory.by)
      dfDT.summed.traj.by = dfDT.co.occurrences[
        ENA_UNIT %in% units,
        {
          sums = lapply(.SD, sum);
          data.frame(ENA_ROW_IDX=.GRP, sums); # Return value
        },
        by=c(unitsBy, trajectory.by),
        .SDcols=(codedTriNames)
      ];
      dfDT.summed.traj.by$ENA_UNIT = merge_columns_c(dfDT.summed.traj.by, unitsBy, sep=".");
      dfDT.summed.traj.by$TRAJ_UNIT = merge_columns_c(dfDT.summed.traj.by,trajectory.by, sep = ".");

      # Accumulated
      if(trajectory.type == rENA::opts$TRAJ_TYPES[1]) {
        dfDT.summed.units = dfDT.summed.traj.by[
          ENA_UNIT %in% unique(units),
          {
            cols = colnames(.SD);
            ENA_UNIT = paste(as.character(.BY), collapse=".");
            TRAJ_UNIT = .SD[,c(trajectory.by),with=F];
            incCols = cols[! cols %in% c(trajectory.by, "ENA_ROW_IDX") ];
            lag = ref_window_lag(.SD[,.SD,.SDcols=incCols], .N);
            data.table(ENA_ROW_IDX, TRAJ_UNIT, lag, ENA_UNIT=ENA_UNIT);
          },
          by=c(unitsBy),
          .SDcols=c(codedTriNames,trajectory.by,"ENA_ROW_IDX")
        ]
      }
      # Non-accumulated
      else if(trajectory.type == rENA::opts$TRAJ_TYPES[2]) {
        dfDT.summed.units = dfDT.summed.traj.by;
      }
      else {
        stop("Unsupported Trajectory type.");
      }

    }
      # dfDT.summed.units$ENA_UNIT = merge_columns_c(dfDT.summed.units, unitsBy, sep=".");

  ###
  # Name the rows an columns accordingly
  ###
    colnames(dfDT.summed.units)[grep("V\\d+",colnames(dfDT.summed.units))] = codedTriNames;
    #rownames(dfDT.summed.units) = dfDT.summed.units$ENA_UNIT;

  ###
  # Set attributes containing matrix representations of the data used for
  # columns and rows
  ###
    codedRow1 = code.names[triIndices(length(code.names), 0)[,1]+1];
    codedRow2 = code.names[triIndices(length(code.names), 1)[,1]+1];
    attr(dfDT.summed.units, "adjacency.matrix") = rbind(codedRow1, codedRow2);
    attr(dfDT.summed.units, "adjacency.codes") = codedTriNames;
    attr(dfDT.summed.units, rENA::opts$UNIT_NAMES) = dfDT.summed.units[,  .SD ,with=T,.SDcols=c("ENA_UNIT")]

  return(list(
    "units.co.occurred" = dfDT.co.occurrences,
    "units.summed" = dfDT.summed.units,
    "units" = units
  ));
}
