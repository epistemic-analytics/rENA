accumulate.data <- function(enadata) {

  dfDT = enadata$raw;

  units.used = enadata$get("units.used"); ###new - replaces old "units"     #### THIS IS ACTUAL UNITS TO USE

  units.by = enadata$get("units.by"); ### COLUMNS TO BE COMBINED TO FORM ENA_UNIT

  #### FIX FOR ISSUE - codes given as vector for accum.data.file but is a df for accum.data
  codes = enadata$codes;
  if(is.data.frame(codes)) codes = colnames(codes);

  conversations.by = enadata$get("conversations.by");

  window = enadata$get("window.size");

  binary = T;

  units.exclude = enadata$get("units.exclude");

  model = enadata$model;

  trajectory.by = enadata$get("trajectory.by");
  trajectory.type = NULL;

  ### should work to determine if binary is desired
  if(!identical(enadata$get("weight.by"), "binary")) {
    binary = F;
  }

  if(model == "EndPoint") trajectory.by = NULL;

  ### We need data
  if(is.null(dfDT) || nrow(dfDT) < 1) return(-1);

  if(model == "AccumulatedTrajectory") {
    trajectory.type <- "accumulated";
  } else if(model == "SeparateTrajectory") {
    trajectory.type <- "non-accumulated";
  }

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
  # by the the `units.by` parameter
  ###
    #dfDT_codes$ENA_UNIT = dfDT_codes[,{apply(.SD,1,function(x){paste(trimws(x),collapse=".")})},with=T,.SDcols=units.by];
  dfDT_codes$ENA_UNIT = merge_columns_c(dfDT_codes, cols=units.by, sep=".");
  ##
  # String vector of codesnames representing the names of the co-occurrences
  ##
  vL = length(codes);
  adjacency.length = ( (vL * (vL + 1)) / 2) - vL ;
  codedTriNames = paste("adjacency.code",rep(1:adjacency.length), sep=".");

  ##
  # Accumulated windows appended to the end of each row
  #
  # FIXME: Don't append on the results to the initial data.table, keep a separate
  #        to lookup the results for the co-occurred values later on.
  ##
  if(window$back == 1) {
    dfDT.co.occurrences = dfDT_codes[,{
      ocs = data.table::as.data.table(rows_to_co_occurrences(.SD[,.SD,.SDcols=codes, with=T]));

      # Return value from data.table back to dfDT.co.occurrences
        data.table::data.table(.SD,ocs)
      },
      .SDcols=c(codes, conversations.by, trajectory.by),
        with=T
    ];

  } else {
    dfDT.co.occurrences = dfDT_codes[,{
        ocs = ref_window_df(.SD, windowSize=window$back, binary = binary);

        # Return value from data.table back to dfDT.co.occurrences
        data.table::data.table(.SD,ocs)
      },
      by=conversations.by,
      .SDcols=codes,
      with=T
    ];
  }

  colnames(dfDT.co.occurrences)[grep("V\\d+",colnames(dfDT.co.occurrences))] = codedTriNames;
  dfDT.co.occurrences$ENA_UNIT = dfDT_codes$ENA_UNIT;

  ##
  # If units aren't supplied, use all available
  ## --- MAY BE ABLE TO REMOVE THIS SECTION - should have already been
  if(is.null(units.used)) {
    units.used = dfDT_codes$ENA_UNIT;
  }
  if(!is.null(units.exclude) && length(units.exclude)>0){
    units.used = units.used[which(!units.used %in% units.exclude)];
  }

  ###
  # Keep original columns used for units
  ###
  dfDT.co.occurrences[, (units.by) := dfDT_codes[,.SD,.SDcols=units.by]];

  ###
  # Check whether operating as a Trajectory.
  ###

  ## Not a Trajectory
  if(is.null(trajectory.type)) {
    ###
    # Sum each unit found in dfDT.co.occurrences
    ###
      dfDT.summed.units = dfDT.co.occurrences[
        ENA_UNIT %in% units.used,
        {
          sums = ref_window_sum(.SD);
          data.frame(ENA_ROW_IDX=.GRP, sums)
        },
        by=units.by,
        .SDcols=(codedTriNames)
      ];

      dfDT.summed.units$ENA_UNIT = merge_columns_c(dfDT.summed.units, units.by, sep=".");
    }
    ## Trajectory
    else {
      ## First sum all units within each Trajectory Group (trajectory.by)
      dfDT.summed.traj.by = dfDT.co.occurrences[
        ENA_UNIT %in% units.used,
        {
          sums = lapply(.SD, sum);
          data.frame(ENA_ROW_IDX=.GRP, sums); # Return value
        },
        by=c(units.by, trajectory.by),
        .SDcols=(codedTriNames)
      ];
      dfDT.summed.traj.by$ENA_UNIT = merge_columns_c(dfDT.summed.traj.by, units.by, sep=".");
      dfDT.summed.traj.by$TRAJ_UNIT = merge_columns_c(dfDT.summed.traj.by,trajectory.by, sep = ".");

      # Accumulated
      if(trajectory.type == rENA::opts$TRAJ_TYPES[1]) {
        dfDT.summed.units = dfDT.summed.traj.by[
          ENA_UNIT %in% unique(units.used),
          {
            cols = colnames(.SD);
            ENA_UNIT = paste(as.character(.BY), collapse=".");
            TRAJ_UNIT = .SD[,c(trajectory.by),with=F];
            incCols = cols[! cols %in% c(trajectory.by, "ENA_ROW_IDX") ];
            lag = ref_window_lag(.SD[,.SD,.SDcols=incCols], .N);
            data.table(ENA_ROW_IDX, TRAJ_UNIT, lag, ENA_UNIT=ENA_UNIT);
          },
          by=c(units.by),
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

      dfDT.summed.units$ENA_UNIT = merge_columns_c(dfDT.summed.units, units.by, sep=".");
    }

  ###
  # Name the rows an columns accordingly
  ###
    colnames(dfDT.summed.units)[grep("V\\d+",colnames(dfDT.summed.units))] = codedTriNames;
    #rownames(dfDT.summed.units) = dfDT.summed.units$ENA_UNIT;

  ###
  # Set attributes containing matrix representations of the data used for
  # columns and rows
  ###
    codedRow1 = codes[triIndices(length(codes), 0)[,1]+1];
    codedRow2 = codes[triIndices(length(codes), 1)[,1]+1];
    attr(dfDT.summed.units, "adjacency.matrix") = rbind(codedRow1, codedRow2);
    attr(dfDT.summed.units, "adjacency.codes") = codedTriNames;
    attr(dfDT.summed.units, rENA::opts$UNIT_NAMES) = dfDT.summed.units[,  .SD ,with=T,.SDcols=units.by]

    enadata$accumulated.adjacency.vectors = dfDT.co.occurrences;
    enadata$adjacency.vectors = dfDT.summed.units;

    #### CAN'T ALTER THE PRIVATE PROPERTY units.used FROM HERE - MAKE PUBLIC OR ACCEPT IT CAN'T BE ALTERED FROM HERE
    #### update unit.names w/ the created unique unit column

    #### SHOULDN'T ACTUALLY NEED TO UPDATE THIS, units was never altered
    if(is.null(enadata$units)) {
      #enadata$units = dfDT.summed.units[,units.by, with=F];
      enadata$units = dfDT.co.occurrences[,units.by, with=F];
    }

    return(enadata);
}
