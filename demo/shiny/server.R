library(data.table)

extractName <- function(name) {
  last(strsplit(name, ".", fixed=T)[[1]])
}
emptyNetwork <- function() list(nodes = list(), edges = list());
xyCols = c("x","y");

shinyServer(function(input, output, session) {
  getTimeline <- function(set,timelineBy,nest=T) {
    seasons=unique(set$get('enaData')$get('file')[timelineBy]);

    if(nest == T) {
      timeline = list();

      for(i in unique(seasons$season)) {
        timeline[[as.character(i)]] = seasons[which(seasons$season == i), ]$episode;
      }

      timeline;
    } else {
      seasons$included = T;
      seasons;
    }
  };

  parentUUID=uuid::UUIDgenerate();
  values <- reactiveValues(
    timelineFiltered = data.frame(season=rep(1:6, each=10), episode=1:10, included=T),
    unitsSelected = c("Jaime","Cersei"),
    codesSelected = gsub("\\.","_", c('Arya','Jaime','Cersei','Robert.Baratheon','Joffrey','Tommen','Robb','Catelyn','Ned','Tyrion','Tywin','Bran')),
    scaleRatio = 1,
    settings = list(
      "allowUpdate" = T,
      "conversationsBy" = c("season", "episode"),
      "grouping" = c("character","season", "episode"),
      "collapseTo" = c("character")
    ),
    scaledUnits = T,
    enaFile = NULL,
    plottable = list(
      list(
        hidden=F,
        by=list(character=c("Jaime")),
        plottableUUID=parentUUID,
        plottableParentUUID=NULL,
        nodeParentUUID=NULL
      ),
      list(
        hidden=F,
        by=list(character=c("Cersei")),
        plottableUUID=uuid::UUIDgenerate(),
        plottableParentUUID=NULL,
        nodeParentUUID=NULL
      )
    )
  );
  values$nodeSize = 3;
  values$sigmaNet1 = emptyNetwork();
  values$sigmaNet2 = emptyNetwork();
  values$sigmaNetComp = emptyNetwork();

  settings <- reactive({ values$settings });
  thisSet <- reactive({
    settings = settings();
    set = NULL;
    setData = gotSet$get('enaData')$get('file');
    unitNames = values$unitsSelected;

    values$unitNames.w.meta = lapply(unitNames, function(u) {
      setData[setData$character==u,c("character", "house")][1,]
    });

    if(settings$allowUpdate == T) {
      set = gotSet$update("data",
        unitsSelected=unitNames,
        codeNames=values$codesSelected
      );
      values$resetMainData = T;
    } else {
      set = gotSet;
    }
    values$timeline = getTimeline(set, values$settings$conversationsBy);
    values$enaFile = data.table(set$get("enaData")$get("file"));

    return(set);
  });
  unitsSelectedMeta <- reactive({
    values$unitNames.w.meta
  });
  codesSelected <- reactive({
    values$codesSelected
  });
  housesListChars <- function() {
    setData = values$enaFile;
    housesList.w.chars = lapply(housesList, function(x) {
      x$characters = as.list(unique(setData[which(x$house==setData$house),]$character))
      x
    });
    housesList.w.chars
  };
  timeline <- reactive({
    getTimeline(thisSet(),settings()$conversationsBy, TRUE)
  });
  timelineFilter <- reactive({
    getTimeline(thisSet(),settings()$conversationsBy, FALSE)
  });

  #collapseTo = reactive({ thisSet()$get('enaData')$get('unitsBy'); });
  getFullData <- function() {
    set = thisSet();
    val = data.frame(set$data$centered$rotated);

    filters = attr(set$get('enaData')$get(), "filters");
    valDT = data.table(val, filters);
    rownames(valDT) = rownames(val);
    colnames(valDT)[1] = "x";
    colnames(valDT)[2] = "y";

    p = max(abs(set$nodes$positions$scaled$positions));
    values$scaleRatio = p / max(abs(valDT[,.(x,y)]))

    valDT
  };
  collapseFullData <- function(data, collapse, sep=".", cols = c("x","y")) {
    d = data[, lapply(.SD, mean), by = c(collapse), .SDcols = cols];

    # This needs to have an option for accumulation, currently it is separte
    # -> For each unique `by`, find all previous as well
    d$rownames = d[,{apply(.SD,1,function(x){paste(trimws(x),collapse=sep)})},with=T,.SDcols=collapse]
    setcolorder(d, c(cols, setdiff(colnames(d), cols)))
    d
  }
  # dataRotated <- reactive({
  #   if(is.null(values$settings$collapseTo) ) {
  #     return(NULL)
  #   }
  #
  #   valDT = getFullData();
  #
  #   browser(expr=debug);
  #
  #   timelineFiltered = values$timelineFiltered;
  #   if(!is.null(timelineFiltered)) {
  #     setkeyv(valDT,c("season","episode"))
  #     valDT = valDT[.(timelineFiltered[timelineFiltered$included==T,c("season","episode")]), nomatch=0]
  #   }
  #
  #   valMeaned = collapseFullData(valDT, c(values$settings$collapseTo));
  #   rownames(valMeaned) = apply(valMeaned[,values$settings$collapseTo, with = F], 1, paste, collapse=".")
  #   df = data.table(valMeaned[,c("x","y"),with=F],valMeaned[,c(colnames(valMeaned)[!colnames(valMeaned) %in% c('x','y')]),with=F]);
  #   rownames(df) = rownames(valMeaned);
  #   df$rownames = rownames(valMeaned);
  #
  #
  #   df
  # });

  makeCompNode <- function(vals, types=c("A","B") ) {
    if(length(vals) == 1) {
      if(vals[1] == 0) {
        list(size=0,type=NA)
      } else {
        list(size=vals[1], type=types[1])
      }
    } else if (vals[1] > vals[2]) {
      list(size=vals[1]-vals[2], type=types[1])
    } else if (vals[1] < vals[2]) {
      list(size=vals[2]-vals[1], type=types[2])
    } else {
      list(size=0, type=NA)
    }
  };
  updatePlot <- function(selectionObj, selectionObj2 = NULL, color = "#5399c7") {
    set = thisSet();

    unitSelected_name = selectionObj$label;
    useData = set$data$normed;
    dR = getPlottableData();
    useData2 = data.frame(useData, attr(set$get('enaData')$get(), "filters"))
    useData2DT = data.table(useData2);
    useData2DT$handle = useData2DT[,{ apply(.SD,1,function(x){paste(trimws(x),collapse=".")})},with=T,.SDcols=unlist(selectionObj$by)]

    timelineFiltered = values$timelineFiltered;
    if(!is.null(timelineFiltered)) {
      #browser();
      setkeyv(useData2DT,c("season","episode"))
      useData2DT = useData2DT[.(timelineFiltered[timelineFiltered$included==T,c("season","episode")]), nomatch=0]
    }

    if(all(dR$rownames != selectionObj$label)) {
      print("Network selection not found in current plot.")
      #return(NULL)
    }

    ### NEW VERSION
    uns = c(selectionObj$label, selectionObj2$label);
    sdcols=colnames(useData2DT)[sapply(useData2DT, is.numeric)];
    minDT = useData2DT[handle %in% uns,lapply(.SD,sum,na.rm=T),by=c(values$settings$collapseTo), .SDcols=sdcols];
    minDTc =minDT[,apply(.SD,2,makeCompNode, types=c(color)),.SDcols=sdcols, with = T];
    minDTsizes = minDTc[1,!is.na(minDTc[2,]), with=F];
    minDTcolors = minDTc[2,!is.na(minDTc[2,]), with=F];
    minDTsizes = minDTsizes[,which(!names(minDTcolors) %in% values$settings$grouping),with=F];
    minDTcolors = minDTcolors[,which(!names(minDTcolors) %in% values$settings$grouping),with=F];
    minDTnodes = minDTc[,!is.na(minDTc[2,]), with=F]
    minDTnodes = minDTnodes[,which(!names(minDTcolors) %in% values$settings$grouping),with=F]
    minDTnodes = minDTnodes[,{ cols=strsplit(colnames(.SD), "...", fixed=T); m=as.matrix(.SD[,,with=F]); lapply(1:length(cols),function(x){ c(m[1,x],m[2,x],cols[[x]]) }); },];

    return(list(
      "mode" = set$nodes$positions$scaled$positions,
      "fullNodes" = minDTnodes
    ));
  }
  createSigmaNet2= function(val) {
    val$mode = as.data.frame(val$mode);
    val$mode[,1] = val$mode[,1] * 10; #Expand
    val$mode[,2] = val$mode[,2] * -10; #Expand and rotate
    val$mode[,3] = rownames(val$mode);
    val$mode[,4] = rownames(val$mode);
    colnames(val$mode) <- c("x","y","id","label");

    r.list2 = list();
    r.list2$nodes = lapply(1:nrow(val$mode), function(x) {
      list(
        label = rownames(val$mode)[x],
        id = rownames(val$mode)[x],
        x = val$mode[x,1],
        y = val$mode[x,2],
        size = 1
      );
    });

    r.list2$edges = list()
    r.list2$edges = lapply(1:length(val$fullNodes), function(n) {
      d = as.data.frame(t(val$fullNodes[,n,with=F]));
      label=paste(d[,3],d[,4],sep=".");
      d$label = label;
      d$id = label;
      d$type = ifelse(!is.null(val$type), val$type, input$unitsClicked$type); #"animate";
      colnames(d) = c("size","color","source","target","label","id","type")
      d
    })
    r.list2$edges = rbindlist(r.list2$edges);
    r.list2$edges[, size := abs(as.numeric(as.matrix(size)))];
    r.list2$edges = r.list2$edges[order(-rank(unlist(size))),];
    eSizeSum = sum(r.list2$edges$size)
    r.list2$nodes = lapply(r.list2$nodes, function(cn) {
      cn$size=r.list2$edges[source==cn$id|target==cn$id, sum(size)] / eSizeSum;
      #if(cn$size>0) cn$size = cn$size + 0.5;
      cn;
    });
    r.list2$axisBounds = rep(max(abs(val$mode[,c('x','y')])),2);
    r.list2
  }

  mainPlotData <- reactive({
    if(is.null(values$mainPlotData)) {
      values$mainPlotData = getPlottableData();
    }
    values$mainPlotData;
  });
  getPlottableData = function(plottable = values$plottable) { #reactive({
    dt = getFullData();

    # Filter the data to plot by the timeline selections
    if(!is.null(values$timelineFiltered)) {
      setkeyv(dt,c("season","episode"))
      dt = dt[.(values$timelineFiltered[values$timelineFiltered$included==T,c("season","episode")]), nomatch=0]
    }
    dtAll = rbindlist(lapply(plottable, function(x) {
      for(name in names(x$by)) {
        if(is.null(x$by[[name]]) || is.na(x$by[[name]])) {
          x$by[[name]] = as.vector(unique( dt[,name,with=F][[1]] ))
        }
      }
      srch3 = data.table(expand.grid(x$by[names(x$by)]));
      setkeyv(srch3, cols=names(x$by));
      dt.filtered = dt[srch3, .SD[!is.na(.SD$x)] ,on=names(x$by), with=T]
      dt.collapsed = collapseFullData(dt.filtered, names(x$by),cols=c("x","y"))

      dt.collapsed$plottable.uuid = x$plottableUUID
      if(!is.null(x$plottableParentUUID))
        dt.collapsed$plottable.parent.uuid = x$plottableParentUUID;
      if(!is.null(x$nodeParentUUID))
        dt.collapsed$node.parent.uuid = x$nodeParentUUID;

      dt.collapsed$node.uuid = replicate(nrow(dt.collapsed), uuid::UUIDgenerate())
      dt.collapsed
    }), fill=T);

    dtAll$id = rownames(dtAll);
    dtAll$label = rownames(dtAll);
    dtAll[, house := houseForCharacter(character)];

    # Ensure all columns remain
    rbindlist(list(dtAll, read.table(text="",col.names=c(colnames(dt)))), fill=T)
  };
  plotNodes = reactive({
    set = thisSet();
    allData = getFullData();
    mainPlotData = mainPlotData(); #getPlottableData();

    scaleRatio = 1;
    if(values$scaledUnits == T) {
      scaleRatio = values$scaleRatio;
    }

    mainPlotData$id = rownames(mainPlotData);
    mainPlotData$label = rownames(mainPlotData);

    mainNetwork = sigmaNetComp();
    retList = list(
      nodes = lapply(1:nrow(mainPlotData), function(x) {
        by = values$settings$grouping[which(!is.na(mainPlotData[x, values$settings$grouping,with=F]))]
        nd = rowToNode(mainPlotData, x, by, type="unit", size = 1, file = values$enaFile, scaleRatio = scaleRatio);
        nd
      }),
      network = mainNetwork,
      network1 = values$sigmaNet1, #sigmaNet1(),
      network2 = sigmaNet2(),
      axisBounds = rep(max(abs(set$nodes$positions$scaled$positions), max(abs(allData[,.(x,y)]))),2)*10
    );

    session$sendCustomMessage("houseMeans", jsonlite::toJSON(getPlotMeans(mainPlotData, scaleRatio), auto_unbox = T));

    retList
  });
  getPlotMeans = function(data, scaleRatio) {
    means = data[, lapply(.SD, mean), by = c("house"), .SDcols = xyCols];

    nodes = lapply(1:nrow(means), function(x) {
      val = means[x];
      list(
        label=val$house,
        id=val$house,
        x=val$x * 10 * scaleRatio,
        y=val$y * 10 * scaleRatio,
        size = 3,
        nodeType = "mean",
        node.uuid = uuid::UUIDgenerate(),
        color = housesList[sapply(housesList, get, x="house") == val$house][[1]]$color
      )
    })
    nodes;
  }
  houseForCharacter <- function(char){
    file.dt = data.table(values$enaFile)
    thisHouse = unlist(lapply(as.character(char), function(x) {unique(file.dt[which(file.dt$character == x),]$house)}))
    thisHouse;
  }
  rowToNode = function(val, x, by, type="unit", size=1, file =NULL, scaleRatio = 1) {
    thisHouse = houseForCharacter(as.vector(val[x]$character));
    nodeList = list(
      label = val[x]$rownames,
      id = paste("unit",val[x]$rownames, sep="."),
      character = val[x]$character, # FIXME (...I don't remember why...)

      x = val$x[x] * 10 * scaleRatio, #Expand
      y = val$y[x] * -10 * scaleRatio, #Expand and Rotate
      size = (1 / length(by)) * 2,
      nodeType = type,
      by = values$settings$grouping[!is.na(val[x,values$settings$grouping, with=F])],
      expandTo = head(values$settings$grouping[is.na(val[x,values$settings$grouping, with=F])], 1),
      node.uuid = val[x]$node.uuid,
      node.parent.uuid = val[x]$node.parent.uuid,
      plottable.uuid = val[x]$plottable.uuid,
      house = thisHouse,
      color = housesList[sapply(housesList, get, x="house") == thisHouse][[1]]$color
    )
    found = which(val$node.uuid == val[x]$from);
    if(length(found)>0) {
      nodeList$x = val[found,]$x;
      nodeList$y = val[found,]$y;
      nodeList$tox = val$x[x];
      nodeList$toy = val$y[x];
    }

    if(length(by) == 1) {
      nodeList$type = "circle";
      nodeList$image = list(url = paste("images/characters/",tolower(val[x]$character),".jpg",sep=""),clip=1.0,scale=1.5);
    }
    nodeList
  };
  sigmaNet1 = reactive({
    if(!is.null(input$unitClicked1)) {
      val = updatePlot(input$unitClicked1);
      if(!is.null(val$mode)) {
        values$network1 = val;
        valToPlot = createSigmaNet2(val);
        valToPlot$nodes = lapply(valToPlot$nodes, function(n) { n$color = "#4d4d4d"; n$nodeType="code"; n });
        values$sigmaNet1 = valToPlot;
      }
    } else {
      values$sigmaNet1 = emptyNetwork();
    }
    values$sigmaNet1
  });
  sigmaNet2 = reactive({
    if(!is.null(input$unitClicked2)) {
      val = updatePlot(input$unitClicked2, color = "#eaa647");
      values$network2 = val;
      valToPlot = createSigmaNet2(val);
      valToPlot$nodes = lapply(valToPlot$nodes, function(n) { n$color = "#4d4d4d"; n$nodeType="code"; n });
      values$sigmaNet2 = valToPlot;
    }else {
      values$sigmaNet2 = emptyNetwork();
    }
    values$sigmaNet2
  });
  sigmaNetComp = reactive({
    if (!is.null(input$unitClicked1) && !is.null(input$unitClicked2)) {
      val = list(
        mode = values$network1$mode,
        name = paste(values$network1$name, values$network2$name, sep="."),
        nodes = unique(c(values$network1$nodes, values$network2$nodes)),
        edgeColors = NULL
      )
      sigmaNet2();
      eS1 = data.table::copy(values$network1$fullNodes[1,]);
      eS2 = data.table::copy(values$network2$fullNodes[1,]);
      colnames(eS1) = apply(values$network1$fullNodes[3:4], 2, paste, collapse="...");
      colnames(eS2) = apply(values$network2$fullNodes[3:4], 2, paste, collapse="...");
      combs = rbindlist(list(eS1, eS2), fill=T);
      is.na(combs) <- combs == "NULL";
      combs[is.na(combs)] = 0;
      combs = combs[, lapply(.SD, function(x) { x[[1]] - x[[2]]; }), .SDcols=names(combs)];
      val$edgeColors = data.table::copy(combs);
      val$edgeColors[combs[1] > 0] = "#5399c7"
      val$edgeColors[combs[1] < 0] = "#eaa647"
      blankRowDT = data.table::copy(combs)
      val$fullNodes = rbindlist(list(combs,val$edgeColors, blankRowDT, blankRowDT), use.names=T);
      for(xN in names(combs)) {
        x = unlist(strsplit(xN, "...", fixed = T));
        val$fullNodes[3:4,xN] = (x);
      }
      valToPlot = createSigmaNet2(val);

      valToPlot$nodes = lapply(valToPlot$nodes, function(n) { n$color = "#4d4d4d"; n$nodeType="code"; n });
      values$sigmaNetComp = valToPlot;
    } else if (!is.null(input$unitClicked1)) {
      values$sigmaNetComp = sigmaNet1();
    } else {
      values$sigmaNetComp = emptyNetwork();
    }
    values$sigmaNetComp
  });

  output$unitClicked1 <- renderText({ input$unitClicked1$label });
  output$unitClicked2 <- renderText({ input$unitClicked2$label });

  observe({
    session$sendCustomMessage("housesJSON", rjson::toJSON(housesListChars()));
  });
  observe({
    session$sendCustomMessage("comparisonChanged", values$sigmaNetComp);
  });
  observe({
    session$sendCustomMessage("collapseTo", jsonlite::toJSON(values$settings$collapseTo));

    session$sendCustomMessage("timelineNested", timeline());
    session$sendCustomMessage("timelineFilter", jsonlite::toJSON(timelineFilter()));

    session$sendCustomMessage("unitsSelected", rjson::toJSON(unitsSelectedMeta()));
    session$sendCustomMessage("codesSelected", rjson::toJSON(codesSelected()));
    session$sendCustomMessage("allExcerpts", jsonlite::toJSON(
      values$enaFile[match(unique(excerpt_id), values$enaFile$excerpt_id), c("season", "episode", values$codesSelected, "excerpt"), with=F]));
  });
  observeEvent(input$meanClicked, {
    print("Show mean equiload.");
    useNetwork = ifelse(is.null(values$network1),"1","2");
    if(!is.null(input$meanClicked)) {
      values$settings$collapseTo = c("house");
      val = updatePlot(input$meanClicked);
      values$settings$collapseTo = c("character");

      if(!is.null(val$mode)) {
        values[[paste0("network",useNetwork)]] = val;
        val$type = "animate";
        valToPlot = createSigmaNet2(val);
        valToPlot$nodes = lapply(valToPlot$nodes, function(n) {n$color = "#4d4d4d";  n$nodeType="code"; n });
        values[[paste0("sigmaNet",useNetwork)]] = valToPlot;
        output[[paste0("unitClicked",useNetwork)]] <- renderText({ input$meanClicked$label });
      }
    } else {
      values[[paste0("sigmaNet",useNetwork)]] = emptyNetwork();
    }

    #values[[paste0("sigmaNet",useNetwork)]]
    session$sendCustomMessage("newPlottableData", jsonlite::toJSON(plotNodes(), auto_unbox = T))
  });
  observeEvent(input$codesSelected, {
    values$codesSelected=input$codesSelected
    session$sendCustomMessage("codesSelected", rjson::toJSON(codesSelected()));
  });
  observeEvent(input$unitsSelected, {
    values$settings$unitsSelected = input$unitsSelected;
  });
  observeEvent(input$unitAdded, {
    newUnits = rjson::fromJSON(input$unitAdded);
    lapply(newUnits, function(x) {
      newLen = length(values$plottable) + 1;

      values$plottable[[newLen]] = list(
        by=list(
          character=x$character
        ),
        uuid=uuid::UUIDgenerate(),
        from=NULL
      )
    });
    NULL
  })
  observeEvent(input$collapseTo, {
    values$settings$collapseTo = jsonlite::fromJSON(input$collapseTo);
  });
  observeEvent(input$timelineFiltered, {
    #browser();
    values$timelineFiltered = jsonlite::fromJSON(input$timelineFiltered);
    #session$sendCustomMessage("newPlottableData", rjson::toJSON(plotNodes()));
    values$mainPlotData = getPlottableData();
    session$sendCustomMessage("newPlottableData", jsonlite::toJSON(plotNodes(), auto_unbox = T))
  });
  observeEvent(input$scaledUnits, {
    values$scaledUnits = input$scaledUnits;
    #session$sendCustomMessage("newPlottableData", rjson::toJSON(plotNodes()));
    session$sendCustomMessage("newPlottableData", jsonlite::toJSON(plotNodes(), auto_unbox = T))
  });
  observeEvent(input$updateUnits, {
    upUnits = jsonlite::fromJSON(input$updateUnits);
    values$unitsSelected = upUnits$character;
    values$unitNames.w.meta =  lapply(values$unitsSelected, function(u) {
      values$enaFile[values$enaFile$character == u,c("character","house"), with=F][1,]
    });
    values$plottable = apply(upUnits, 1, function(u) {
      list(by=list(character=c(u[1])),
      hidden=F,
      plottableUUID=uuid::UUIDgenerate(),
      plottableParentUUID=NULL,
      nodeParentUUID=NULL
      )
    });
    units1 = apply(upUnits, 1, function(u) { data.frame(character=u[1], house=u[2]) });
    units2 = unitsSelectedMeta();
    unitsList = list();

    for(i in 1:nrow(upUnits)) {
      unitsList[[i]] = data.frame(character=upUnits[i,1], house=upUnits[i,2]);
      if(!any(values$codesSelected == upUnits[i,1])) {
        values$codesSelected[length(values$codesSelected)+1] = upUnits[i,1]
      }
    }

    values$mainPlotData = getPlottableData();
    session$sendCustomMessage("mainPlotData", rjson::toJSON(plotNodes()));
    session$sendCustomMessage("unitsSelected", rjson::toJSON(unitsList));
  });
  observeEvent(input$updateCodes, {
    upCodes = jsonlite::fromJSON(input$updateCodes);
    values$codesSelected = upCodes;
  });
  observeEvent(input$toggleNode, {
    itJ = jsonlite::fromJSON(input$toggleNode);
    toRemove=numeric();
    forceHide=numeric();
    labelParts = strsplit(itJ$label,"\\.",perl=TRUE)[[1]];

    plottableSource=Filter(function(p){p$plottableUUID==itJ$plottable.uuid}, values$plottable)[[1]];
    dependablePlottables=Filter(function(p){ifelse(identical(p$plottableParentUUID,plottableSource$plottableUUID),T,F)}, values$plottable);
    topLevelToHide=unlist(Map(function(w){ if(w$plottableUUID==itJ$plottable.uuid) w$plottableParentUUID },values$plottable))
    forceHide = which(unlist(Map(function(v){ ifelse(v$plottableUUID==topLevelToHide,T,F) }, values$plottable)))

    if(itJ$expandTo=="episode" && length(forceHide) > 0 && length(dependablePlottables) == 0 ) {
      if(values$plottable[[forceHide]]$hidden != T) {
        session$sendCustomMessage("hideNodes", jsonlite::toJSON(as.character(unlist(Map(function(x) { x$plottableUUID },values$plottable[forceHide])))))
        values$plottable[[forceHide]]$hidden <- T;
      }
    }

    plottableSource = unlist(Map(function(x){x$plottableUUID},Filter(function(x){
      identical(paste(x$by[itJ$by], collapse="."), itJ$label) &&
        identical(x$plottableParentUUID,itJ$plottable.uuid);
    },values$plottable)));

    toRemove = which(as.character(Map(function(x){x$plottableUUID},values$plottable)) == plottableSource);
    if(length(toRemove) > 0 && paste(values$plottable[[toRemove]]$by[itJ$by], collapse=".")==itJ$label) {
      if(length(labelParts) > 1) {
        if(any(values$plottable[[toRemove]]$by$season == labelParts[2])) {
          if(length(values$plottable[[toRemove]]$by$season) == 0) {
            values$plottable[[toRemove]] <- NULL;
            values$plottable=append(
              values$plottable,
              list(list(
                hidden=F,
                by=list(character=c(itJ$character)),
                plottable.uuid=uuid::UUIDgenerate(),
                plottable.parent.uuid=NULL
              ))
            ,0)
          } else {
            values$plottable[[toRemove]] <- NULL;
          }
        } else {
          values$plottable[[toRemove]]$by$season = as.integer(c(values$plottable[[toRemove]]$by$season, labelParts[2]));
        }
      } else {
        values$plottable[[toRemove]] <- NULL;
      }

      for(p in 1:length(values$plottable)) {
        parent = values$plottable[[p]];
        if(is.null(parent$plottableParentUUID)) {
          secLevel = unlist(Map(function(o) o$plottableUUID, Filter(function(n){identical(n$plottableParentUUID,parent$plottableUUID)}, values$plottable)));
          triLevel = Filter(function(n){
            (n$plottableParentUUID %in% secLevel)
          }, values$plottable);
          if(length(triLevel)==0) {
            values$plottable[[p]]$hidden = F;
            session$sendCustomMessage("showNodes", rjson::toJSON(list(parent$plottableUUID)));
          }
        }
      };

      session$sendCustomMessage("removeChildNodes", itJ$node.uuid)
    } else {
      newLen = length(values$plottable)+1;
      newListItem = list(
        hidden=F,
        by=list(
          character=itJ$character,
          season=as.integer(labelParts[2]),
          episode=as.integer(labelParts[3])
        ),
        plottableUUID=uuid::UUIDgenerate(),
        plottableParentUUID=itJ$plottable.uuid,
        nodeParentUUID=itJ$node.uuid
      );
      aa=values$settings$grouping[1:(last(which(values$settings$grouping %in% itJ$by)) + 1)]
      aaV=vector(mode="list", length=length(aa))
      names(aaV) = aa
      for(aaN in 1:length(aa)){
        if(is.null(itJ[[aa[aaN]]])) {
          if(aaN <= length(labelParts)) {
            aaV[aa[aaN]] = labelParts[aaN]
          } else {
            aaV[aa[aaN]] = NA;
          }
        } else {
          aaV[aa[aaN]] = itJ[[aa[aaN]]];
        }
      }

      if(any(names(aaV) == "season")) {
        aaV$season = as.integer(aaV$season)
      }
      if(any(names(aaV) == "episode")) {
        aaV$episode = as.integer(aaV$episode)
      }
      newListItem$by = aaV;
      values$plottable[[newLen]] = newListItem

      newItems = getPlottableData(list(newListItem));
      values$mainPlotData = rbindlist(l=list(values$mainPlotData, newItems), fill=T)

      scaleRatio = 1;
      if(values$scaledUnits == T) {
        scaleRatio = values$scaleRatio;
      }
      newNodes = lapply(1:nrow(newItems), function(x) {
        by = values$settings$grouping[which(!is.na(newItems[x, values$settings$grouping,with=F]))]
        nd = rowToNode(newItems, x, by, type="node", size = 1, file = values$enaFile, scaleRatio = scaleRatio);
        nd
      });
      session$sendCustomMessage("newPlottableData", jsonlite::toJSON(list(
        nodes=newNodes,
        network=emptyNetwork(),
        network1=emptyNetwork(),
        network2=emptyNetwork()
      ), auto_unbox = T))
    }
  });
  observeEvent(input$unitsClicked, {
    session$sendCustomMessage("newPlottableData", jsonlite::toJSON(plotNodes(), auto_unbox = T))
  });
  observeEvent(input$colorsUpdated, {
    #session$sendCustomMessage
  });
  observeEvent(input$getPlotData, {
    session$sendCustomMessage("mainPlotData", rjson::toJSON(plotNodes()))
  });

  output
})
