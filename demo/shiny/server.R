library(data.table)

extractName <- function(name) {
  last(strsplit(name, ".", fixed=T)[[1]])
}
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

  values <- reactiveValues(
    timelineFiltered = NULL,
    unitsSelected = c("Jaime", "Ned"),
    codesSelected = gsub("\\.","_", c('Arya','Jaime','Cersei','Robert.Baratheon','Joffrey','Tommen','Robb','Catelyn','Ned','Tyrion','Tywin','Bran')),
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
        by=list(character=c("Jaime")),
        uuid=uuid::UUIDgenerate(),
        from=NULL
      )
      ,list(
        by=list(character=c("Ned")),
        uuid=uuid::UUIDgenerate(),
        from=NULL
      )
    )
  );
  values$nodeSize = 3;
  values$sigmaNet1 = list(nodes = list(), edges = list());
  values$sigmaNet2 = list(nodes = list(), edges = list());
  values$sigmaNetComp = list(nodes = list(), edges = list());

  thisSet <- reactive({
    settings = settings();
    set = NULL;
    setData = gotSet$get('enaData')$get('file');
    unitNames = values$unitsSelected; #gotSet$get('enaData')$get('unitsSelected');

    print("Getting the set.");
    values$unitNames.w.meta = lapply(unitNames, function(u) {
      setData[setData$character==u,c("character", "house")][1,]
    });

    if(settings$allowUpdate == T) {
      print("Updating the set.");
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

  settings <- reactive({
    values$settings
  });
  collapseTo = reactive({
    thisSet()$get('enaData')$get('unitsBy')
  });
  getFullData <- function() {
    val = data.frame(thisSet()$data$centered$rotated);

    filters = attr(thisSet()$get('enaData')$get(), "filters");
    valDT = data.table(val, filters);
    rownames(valDT) = rownames(val);
    colnames(valDT)[1] = "x";
    colnames(valDT)[2] = "y";

    valDT
  };
  collapseFullData <- function(data, collapse, sep=".", cols = c("x","y")) {
    d = data[, lapply(.SD, mean), by = c(collapse), .SDcols = cols];
    d$rownames = d[,{apply(.SD,1,function(x){paste(trimws(x),collapse=sep)})},with=T,.SDcols=collapse]
    setcolorder(d, c(cols, setdiff(colnames(d), cols)))
    d
  }
  dataRotated <- reactive({
    if(is.null(values$settings$collapseTo) ) {
      return(NULL)
    }

    valDT = getFullData();

    browser(expr=debug);
    timelineBy = settings()$conversationsBy;
    timelineBy = timelineBy[timelineBy %in% colnames(df)]

    timelineFiltered = values$timelineFiltered;
    if(!is.null(timelineFiltered)) {
      #df = df[.(timelineFiltered[timelineFiltered$included == T,timelineBy]), nomatch=0];
      #browser()
      setkeyv(valDT,c("season","episode"))
      valDT = valDT[.(timelineFiltered[timelineFiltered$included==T,c("season","episode")]), nomatch=0]
    }

    valMeaned = collapseFullData(valDT, c(values$settings$collapseTo));
    rownames(valMeaned) = apply(valMeaned[,values$settings$collapseTo, with = F], 1, paste, collapse=".")
    df = data.table(valMeaned[,c("x","y"),with=F],valMeaned[,c(colnames(valMeaned)[!colnames(valMeaned) %in% c('x','y')]),with=F]);
    rownames(df) = rownames(valMeaned);
    df$rownames = rownames(valMeaned);


    df
  });
  observe({
    values$mainPlotData = dataRotated()
  });
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

    if(all(dR$rownames != selectionObj$label)) {
      print("Network selection not found in current plot.")
      return(NULL)
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
    val$mode[,1] = val$mode[,1] * 1; #Expand
    val$mode[,2] = val$mode[,2] * -1; #Expand and rotate
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

    r.list2$edges = data.table(sapply(1:length(val$fullNodes), function(n) {
      x = as.data.frame(val$fullNodes[,n,with=F]);
      label=paste(x[3,],x[4,],sep=".");
      list(
        label=label, id=label,
        size=abs(as.numeric(x[1,][[1]])*log(input$edgeZoom)+0.1),
        color=as.character(x[2,]),
        source=x[3,], target=x[4,],
        type="animate"
      );
    }));
    r.list2$edges = r.list2$edges[,sort.list(as.vector(unlist(r.list2$edges[3,,with=T])), decreasing=T), with=F]

    #nodeCoords = data.table(t(as.data.frame(lapply(r.list2$nodes, function(n) { return(c(x=n$x,y=n$y)) }))));
    #browser();
    #r.list2$axisBounds = rep(max(nodeCoords[,.(x,y)])*2,2);
    r.list2$axisBounds = rep(max(abs(val$mode[,c('x','y')])),2);
    r.list2
  }

  mainPlotData = reactive({
    if(is.null(values$mainPlotData)) {
      values$mainPlotData = dataRotated();
    }
    values$mainPlotData;
  });
  getPlottableData = reactive({
    dt = getFullData();
    if(!is.null(values$timelineFiltered)) {
      #df = df[.(timelineFiltered[timelineFiltered$included == T,timelineBy]), nomatch=0];
      #browser()
      setkeyv(dt,c("season","episode"))
      dt = dt[.(values$timelineFiltered[values$timelineFiltered$included==T,c("season","episode")]), nomatch=0]
    }
    #browser();
    dtAll = rbindlist(lapply(values$plottable, function(x) {
      for(name in names(x$by)) {
        if(is.null(x$by[[name]]) || is.na(x$by[[name]])) {
          x$by[[name]] = as.vector(unique( dt[,name,with=F][[1]] ))
        }
      }
      srch3 = data.table(expand.grid(x$by[names(x$by)]));
      setkeyv(srch3, cols=names(x$by));
      dt.filtered = dt[srch3, .SD[!is.na(.SD$x)] ,on=names(x$by), with=T]
      dt.collapsed = collapseFullData(dt.filtered, names(x$by),cols=c("x","y"))
      dt.collapsed$uuid = x$uuid
      dt.collapsed
    }), fill=T);

    #Ensure all columns remain
    rbindlist(list(dtAll, read.table(text="",col.names=c(colnames(dt),"uuid"))), fill=T)
  })
  sigmaPlot = reactive({
    mainPlotData = getPlottableData();
    if(is.null(values$mainPlotData)) {
      print("No data found for main plot.")
      return(NULL);
    }
    mainPlotData$x = mainPlotData$x * 10; # Expand
    mainPlotData$y = mainPlotData$y * -10; # Expand and Rotate
    mainPlotData$id = rownames(mainPlotData);
    mainPlotData$label = rownames(mainPlotData);

    set = thisSet();
    percents = (set$data$centered$latent / sum(set$data$centered$latent)) * 100;
    allData = getFullData();
    r.list2 = list(
      nodes = list(),
      edges = list(),
      axisBounds = rep(max(abs(set$nodes$positions$scaled$positions), max(abs(allData[,.(x,y)]))),2)*10,
      percents = percents[1:2]
    );

    if(values$scaledUnits == T) {
      #scaleRatio = max(abs(allData[,.(x,y)])) / max(abs(set$nodes$positions$scaled$positions));
      scaleRatio = max(abs(set$nodes$positions$scaled$positions)) / max(abs(allData[,.(x,y)]))
      mainPlotData[,c("x","y")] = mainPlotData[,.(x,y)] * (1+scaleRatio)
      #mainPlotData[,c("x","y")] = scale(mainPlotData[,.(x,y)], center = F, rep(scaleRatio,2));
    }
    f = thisSet()$get('enaData')$get('file');
    r.list2.nodes = lapply(1:nrow(mainPlotData), function(x) {
      nd = rowToNode(mainPlotData, x, values$settings$collapseTo, type="node", size = 1, file = f);
      nd
    })

    r.list2$nodes = r.list2.nodes;

    rjson::toJSON(r.list2);
  });
  rowToNode = function(val, x, by, type="node", size=1, file =NULL) {
    file.dt = data.table(file)
    thisHouse = unique(file.dt[which(file.dt$character == as.vector(val[x]$character)),]$house);
    list(
      label = val[x]$rownames,
      id = paste("unit",val[x]$rownames, sep="."),
      character = val[x]$character, # FIXME
      x = val$x[x],
      y = val$y[x],
      size = 1 / length(by),
      type = type,
      by = values$settings$grouping[!is.na(val[x,values$settings$grouping, with=F])],
      expandTo = head(values$settings$grouping[is.na(val[x,values$settings$grouping, with=F])], 1),
      uuid = val[x]$uuid,
      house = thisHouse,
      color = housesList[sapply(housesList, get, x="house") == thisHouse][[1]]$color
    )
  };
  sigmaNet1 = reactive({
    if(!is.null(input$unitClicked1)) {
      val = updatePlot(input$unitClicked1);
      if(!is.null(val$mode)) {
        values$network1 = val;
        valToPlot = createSigmaNet2(val);
        valToPlot$nodes = lapply(valToPlot$nodes, function(n) { n$color = "#4d4d4d"; n });
        values$sigmaNet1 = rjson::toJSON(valToPlot);
      }
    } else {
      values$sigmaNet1 = list(nodes = list(), edges = list())
    }
    values$sigmaNet1
  });
  sigmaNet2 = reactive({
    if(!is.null(input$unitClicked2)) {
      val = updatePlot(input$unitClicked2, color = "#eaa647");
      values$network2 = val;
      valToPlot = createSigmaNet2(val);
      valToPlot$nodes = lapply(valToPlot$nodes, function(n) { n$color = "#4d4d4d"; n });
      values$sigmaNet2 = rjson::toJSON(valToPlot);
    }else {
      values$sigmaNet2 = list(nodes = list(), edges = list())
    }
    values$sigmaNet2
  });
  sigmaNetComp = reactive({
    if(
      !is.null(input$unitClicked1) &&
      !is.null(input$unitClicked2)
    ) {
      val = list(
        mode = values$network1$mode,
        name = paste(values$network1$name, values$network2$name, sep="."),
        nodes = unique(c(values$network1$nodes, values$network2$nodes)),
        edgeColors = NULL
      )
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

      valToPlot$nodes = lapply(valToPlot$nodes, function(n) { n$color = "#4d4d4d"; n });
      values$sigmaNetComp = rjson::toJSON(valToPlot);
    } else if (!is.null(input$unitClicked1)) {
      values$sigmaNetComp = values$sigmaNet1
    } else {
      values$sigmaNetComp = list(nodes = list(), edges = list())
    }
    values$sigmaNetComp
  });

  #####
  # Begin: Plots
  #####
    output$sigma <- renderSigma(
      sigma(
        sigmaPlot(), name="mainPlot",
        drawEdges = T, drawNodes = T,
        clickNode=htmlwidgets::JS("ENA.graphs.unit.events.clickNode"),
        doubleClickNode=htmlwidgets::JS("ENA.graphs.unit.events.doubleClickNode"),
        overNode=htmlwidgets::JS("ENA.graphs.unit.events.overNode"),
        outNode=htmlwidgets::JS("ENA.graphs.unit.events.outNode")
      )
    );
    output$sigmaNet1 <- renderSigma(
      sigma(sigmaNet1(),drawEdges = T, drawNodes = T, name="edgePlot1", clickNode=htmlwidgets::JS("ENA.graphs.network.events.clickNode"), clickEdge=htmlwidgets::JS("ENA.graphs.network.events.clickEdge"))
    );
    output$sigmaNet2 <- renderSigma(
      sigma(sigmaNet2(),drawEdges = T, drawNodes = T, name="edgePlot2", clickNode=htmlwidgets::JS("ENA.graphs.network.events.clickNode"), clickEdge=htmlwidgets::JS("ENA.graphs.network.events.clickEdge"))
    );
    output$sigmaComparison <- renderSigma(
      sigma(sigmaNetComp(),drawEdges = T, drawNodes = T, name="edgePlotComp")
    );
  #####
  # End: Plots
  #####

  output$unitClicked1 <- renderText({
    input$unitClicked1$label
  });
  output$unitClicked2 <- renderText({
    input$unitClicked2$label
  });
  output$collapseToText <- renderText({
    collapseTo()
  })
  output$collapseTo <- renderUI({
    selectizeInput('collapseTo', 'Collapse by',
      selected = collapseTo(),
      choices = unique(colnames(thisSet()$get("enaData")$get("file"))),
      multiple = TRUE
    )
  });
  output$unitSelector <- renderUI({
    selectizeInput( 'unitsSelected', 'Units',
      selected = thisSet()$get("enaData")$get("unitsBy"),
      choices = unique(thisSet()$get("enaData")$get("file")$character),
      multiple = TRUE
    )
  });
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
  })
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
    values$timelineFiltered = jsonlite::fromJSON(input$timelineFiltered);
  });
  observeEvent(input$scaledUnits, {
    values$scaledUnits = input$scaledUnits;
  });
  observeEvent(input$updateUnits, {
    upUnits = jsonlite::fromJSON(input$updateUnits);
    values$unitsSelected = upUnits$character;
    values$unitNames.w.meta =  lapply(values$unitsSelected, function(u) {
      values$enaFile[values$enaFile$character == u,c("character","house"), with=F][1,]
    });
    values$plottable = apply(upUnits, 1, function(u) { list(by=list(character=c(u[1])),uuid=uuid::UUIDgenerate(),from=NULL) });
    units1 = apply(upUnits, 1, function(u) { data.frame(character=u[1], house=u[2]) });
    units2 = unitsSelectedMeta();
    unitsList = list();

    for(i in 1:nrow(upUnits)) {
      unitsList[[i]] = data.frame(character=upUnits[i,1], house=upUnits[i,2]);
      if(!any(values$codesSelected == upUnits[i,1])) {
        values$codesSelected[length(values$codesSelected)+1] = upUnits[i,1]
      }
    }

    session$sendCustomMessage("unitsSelected", rjson::toJSON(unitsList));
  });
  observeEvent(input$updateCodes, {
    upCodes = jsonlite::fromJSON(input$updateCodes);
    values$codesSelected = upCodes;
  });
  observeEvent(input$toggleNode, {
    itJ = jsonlite::fromJSON(input$toggleNode);
    toRemove=numeric();

    labelParts = strsplit(itJ$label,"\\.",perl=TRUE)[[1]];
    for(i in 1:length(values$plottable)) {
      x = values$plottable[[i]];
      if(!is.null(x$from) && x$from == itJ$uuid) {
        toRemove[length(toRemove)+1] = i
      }
    }
    if(length(toRemove) > 0) {
      if(length(labelParts) > 1) {
        if(any(values$plottable[[toRemove]]$by$season == labelParts[2])) {
          values$plottable[[toRemove]]$by$season = as.integer(values$plottable[[toRemove]]$by$season[values$plottable[[toRemove]]$by$season != labelParts[2]])
          if(length(values$plottable[[toRemove]]$by$season) == 0) {
            values$plottable[[toRemove]] <- NULL;
          }
        } else {
          values$plottable[[toRemove]]$by$season = as.integer(c(values$plottable[[toRemove]]$by$season, labelParts[2]));
        }
      } else {
        values$plottable[[toRemove]] <- NULL;
      }
    } else {
      newLen = length(values$plottable)+1;
      newListItem = list(
        by=list(
          character=itJ$character,
          season=as.integer(labelParts[2]),
          episode=as.integer(labelParts[3])
        ),
        uuid=uuid::UUIDgenerate(),
        from=itJ$uuid
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
    }
  });
  observeEvent(input$unitsClicked, {
    session$sendCustomMessage("unitsClicked", input$unitsClicked);
  });
  observeEvent(input$edgeClicked, {
    session$sendCustomMessage("edgeClicked", "You clicked an edge!!");
  });

  output
})
