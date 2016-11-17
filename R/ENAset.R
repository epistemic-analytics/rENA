library(R6);
library(data.table);
Rcpp::sourceCpp('src/svector_to_ut.cpp');
Rcpp::sourceCpp('src/ref_window_df.cpp');
Rcpp::sourceCpp('src/ref_window_sum.cpp');
source('R/accumulate.R');
source('R/do_optimization.R');

ENAset = R6Class("ENAset",
  public = list(
    initialize = function(
      enaData,
      dims=2, samples=3, optimMethod="C", inPar=F,
      ...
    ) {
      private$enaData <- enaData;
      private$dimensions <- dims;
      private$samples <- samples;
      private$optimMethod <- optimMethod;
      private$inPar <- inPar;
    },
    process = function() {
      return(private$run());
    },
    update = function(data = private$enaData, dims = private$dimensions, ...) {
      private$enaData <- data;
      private$dimensions <- dims;

      return(self$process());
    },
    get = function(x) {
      return(private[[x]]);
    }
  ),
  private = list(
    enaData = NULL,
    dimensions = 2,
    samples = 3,
    optimMethod = "C",
    inPar = FALSE,
    data = list(
      normed = NULL,
      centered = list(),
      optim = NULL
    ),
    nodes = list(
      positions = list(
        optim = NULL,
        rotated = NULL
      )
    ),
    rotation_dists = NULL,
    run = function() {
      df = private$enaData$get();
      by_num = length(private$enaData$get("unitsBy"));

      private$data$normed = normIt(df[,(by_num+1):ncol(df), with=F]);
      private$data$centered$normed = centerData(private$data$normed);
      private$data$centered$pca = pca(private$data$centered$normed, dims = private$dimensions);
      private$data$centered$rotated = centerDataRotated(private$data$centered$normed, private$data$centered$pca);
      private$rotation_dists = getRotationDistances(private$data$centered$rotated);

      if(private$optimMethod == "C") {
        private$data$optim = do_optimization_2(enaset, inPar = private$inPar);
      } else {
        private$data$optim = do_optimization(enaset, inPar = private$inPar);
      }

      private$nodes$positions$optim = get_optimized_node_pos(private$data$normed, private$dimensions, private$samples, opted = private$data$optim);

      private$nodes$positions$rotated = full_opt(normed = private$data$normed, rotated = private$data$centered$rotated, optim_nodes = private$nodes$positions$optim, dims = private$dimensions);

      return(self);
    }
  )
)

ENAdata = R6Class("ENAdata",
  public = list(
    initialize = function(
      file,
      unitsBy = NULL, units = NULL,
      conversationsBy = NULL,
      codeNames = NULL,
      windowSize = 1,
      ...
    ) {
      private$file <- file;
      private$unitsBy <- unitsBy;
      private$units <- units;
      private$conversationsBy <- conversationsBy;
      private$codeNames <- codeNames;
      private$windowSize <- windowSize;
      private$data <- private$loadFile();
    },
    get = function(x = "data") {
      return(private[[x]]);
    },
    update = function(
      file = private$file,
      codeNames = private$codeNames,
      conversationsBy = private$conversationsBy,
      units = private$units
    ) {
      changed = F;

      if(file != private$file) {
        private$file <- file; changed = T;
      }

      if( all.equal(codeNames, private$codeNames) == F ) {
        private$codeNames <- codeNames; changed = T;
      }
      if( is.null(units) || !all(units == private$units) ) {
        private$units <- units; changed = T;
      }
      if( is.null(conversationsBy) || !all(conversationsBy == private$conversationsBy) ) {
        private$conversationsBy <- conversationsBy; changed = T;
      }

      if(changed == T) {
        private$data <- private$loadFile();
      }

      return(self);
    }
  ),
  private = list(
    file = NULL,
    data = NULL,
    windowSize = 1,
    unitsList = NULL,
    unitsBy = NULL,
    units = NULL,
    conversationsBy = NULL,
    codeNames = NULL,
    loadFile = function() {
      print(class(private$file))
      if(class(private$file) == "data.frame") {
        df = private$file;
      } else {
        df = read.csv(private$file);
      }
      df_DT = as.data.table(df);

      unitsListTable = data.frame(df[, private$unitsBy]);
      private$unitsList = unique(unitsListTable);
      colnames(unitsListTable) = private$unitsBy;
      unitsList = unitsListTable;

      conversations = df[, private$conversationsBy]
      conversationsList = unique(conversations)
      sList = trimws(unique(apply(df[, colnames(conversationsList)], 1, paste , collapse = " & ")));

      if(is.null(private$units)) {
        private$units = apply(as.matrix(as.matrix(unique(df[, colnames(unitsList)]), ncol=length(colnames(unitsList)))), 1, paste , collapse = ".");
      }

      newRes = accumulate.data(
        dfDT = df,
        stanzasBy = private$conversationsBy,
        unitsBy = private$unitsBy,
        units = private$units,
        codeNames = private$codeNames,
        window = private$windowSize
      );

     return(newRes);
   }
  )
)

codeNames_less = c("E.data","S.data","E.design","S.design");
codeNames = c("E.data","S.data","E.design","S.design","S.professional","E.client","V.client","E.consultant","V.consultant","S.collaboration","I.engineer","I.intern","K.actuator","K.rom","K.materials","K.power");

units_less = c("akash v.FirstGame","brandon f.SecondGame","kiana k.SecondGame");
units_all = c('robert z.FirstGame','steven z.FirstGame','akash v.FirstGame','devin c.FirstGame','alexander b.FirstGame','jordan l.FirstGame','peter s.FirstGame','tiffany x.FirstGame','amelia n.FirstGame','joseph h.FirstGame','brandon l.FirstGame','arden f.FirstGame','cameron k.FirstGame','margaret n.FirstGame','connor f.FirstGame','jimmy i.FirstGame','joseph k.FirstGame','fletcher l.FirstGame','amirah u.FirstGame','peter h.FirstGame','christian x.FirstGame','carl b.FirstGame','kevin g.FirstGame','luis t.FirstGame','mitchell h.FirstGame','amalia x.FirstGame','brandon f.SecondGame','keegan q.SecondGame','nicholas l.SecondGame','jackson p.SecondGame','brent p.SecondGame','kiana k.SecondGame','madeline g.SecondGame','justin y.SecondGame','shane t.SecondGame','cameron i.SecondGame','christina b.SecondGame','derek v.SecondGame','nicholas n.SecondGame','abigail z.SecondGame','caitlyn y.SecondGame','ruzhen e.SecondGame','cormick u.SecondGame','daniel t.SecondGame','nathan d.SecondGame','samuel o.SecondGame','luke u.SecondGame','casey f.SecondGame');
units_all_names = c("akash v","alexander b","amelia n","arden f","brandon l","cameron k","connor f","devin c","jimmy i","jordan l","joseph l","margaret n","peter p","robert z","steven z","tiffany x","abigail z","brandon f","brent p","cameron i","christina b","cormick u","daniel t","derek v","jackson p","keegan q","kiana k","luke u","madeline g","nathan d","nicholas l","nicholas n","ruzhen e","shane t","caitlyn y","justin y","samuel o","fletcher l","amirah u","carl b","christian x","kevin g","casey f","luis t","mitchell h","amalia x");

enadata = ENAdata$new(
  df, #"./data/rs.data.sorted.csv",
  unitsBy = c("UserName"), #,"Condition"),
  #units = units_less,
  conversationsBy = c("ActivityNumber", "GroupName"),
  codeNames = codeNames
);

enaset = ENAset$new(enadata)
#enaset$process();
print("Done.")
