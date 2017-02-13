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
    codesSelected = gsub("\\.","_", c('Arya','Jaime','Cersei','Robert.Baratheon','Joffrey','Tommen','Robb','Catelyn','Ned','Tyrion','Bronn','Brienne','Tywin','Bran')),
    settings = list(
      "allowUpdate" = F,
      "conversationsBy" = c("season", "episode"),
      "grouping" = c("character","season", "episode"),
      "collapseTo" = c("character")
    ),
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
      # ,list(
      #    by=list(character=c("Jaime"),season=c(2)),
      #    collapseTo=c("character","season")
      #  )
      # ,list(
      #   by=list(character=c("Jaime"),season=c()),
      #   uuid=uuid::UUIDgenerate()
      # )
      #,list(
      #  by=list(character=c("Jaime"),season=c(1:6),episode=c(1:10))
      #)
      #,
      # list(
      #   by=list(character="Jaime"),
      #   collapseTo=c("character","season","episode")
      # )
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
    #browser();
    unitNames = gotSet$get('enaData')$get('unitsSelected'); # unitsSelected();

    values$unitNames.w.meta = lapply(unitNames, function(u) {
      setData[setData$character==u,c("character", "house")][1,]
    }); #lapply(unitNames, function(u) {setData[setData$character==u,which(lapply(setData[which(setData$character==u),], function(x) { length(unique(x)) == 1 && all(is.character(as.vector(x)))} ) == T)][1,]});

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
  unitsSelected <- reactive({
    #set = thisSet();
    #setData = set$get("enaData")$get("file");
    #unitNames = values$settings$unitsSelected; #c("Jaime") #, "Cersei"); #set$get("enaData")$get("unitsSelected");
    #unitNames.w.meta = lapply(unitNames, function(u) {
    #  setData[setData$character==u,which(lapply(setData[which(setData$character==u),], function(x) { length(unique(x)) == 1 && all(is.character(as.vector(x)))} ) == T)][1,]
    #})

    #unitNames.w.meta
    #browser();
    #file.dt = data.table(thisSet()$get('enaData')$get('file'));
    #thisHouse = unique(file.dt[which(file.dt$character == as.vector(val[x]$character)),]$house);
    unitNames = unique(unlist(Map(function(x) { x$by$character }, values$plottable)))
    #lapply((unitNames), function(u) { u })
    #@lapply((unitNames), function(u) { list(character = u) })
    #browser()
    unitNames
  });
  housesListChars <- function() {
    #set = thisSet();
    setData = values$enaFile; #set$get("enaData")$get("file");
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
    #browser()
    thisSet()$get('enaData')$get('unitsBy')

  })
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
    if(
      is.null(values$settings$collapseTo)
    ) {
      return(NULL)
    }
    # val = data.frame(thisSet()$data$centered$rotated);
    #
    # filters = attr(thisSet()$get('enaData')$get(), "filters");
    # valDT = data.table(val, filters);
    # rownames(valDT) = rownames(val);
    # colnames(valDT)[1] = "x";
    # colnames(valDT)[2] = "y";
    print("geting the dataRotated()");
    valDT = getFullData()
    #valDT = values$mainPlotData;

    valMeaned = collapseFullData(valDT, c(values$settings$collapseTo));
    rownames(valMeaned) = apply(valMeaned[,values$settings$collapseTo, with = F], 1, paste, collapse=".")

    df = data.table(valMeaned[,c("x","y"),with=F],valMeaned[,c(colnames(valMeaned)[!colnames(valMeaned) %in% c('x','y')]),with=F]);

    rownames(df) = rownames(valMeaned);
    df$rownames = rownames(valMeaned);

    browser(expr=debug);
    timelineBy = settings()$conversationsBy;
    timelineBy = timelineBy[timelineBy %in% colnames(df)]

    if(!is.null(timelineBy) && length(timelineBy > 0)) {
      setkeyv(df,timelineBy)
    }

    timelineFiltered = values$timelineFiltered;
    if(!is.null(timelineFiltered)) {
      df = df[.(timelineFiltered[timelineFiltered$included == T,timelineBy]), nomatch=0];
    }

    df
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
  updatePlot <- function(selectionObj, selectionObj2 = NULL) {
    set = thisSet();
    selection = selectionObj$id;

    if(!is.character(selection)) {
      selectionName = rownames(selection)[1];
    } else {
      selectionName = selection;
    }
    unitSelected_name = selectionObj$id; # FIXME extractName(selectionName);
    useData = set$data$normed;
    #dR = dataRotated();
    dR = getPlottableData();
    useData2 = data.frame(useData, attr(set$get('enaData')$get(), "filters"))
    useData2DT = data.table(useData2);
    useData2DT$handle = useData2DT[,{ apply(.SD,1,function(x){paste(trimws(x),collapse=".")})},with=T,.SDcols=unlist(selectionObj$by)]
    browser(expr=debug);

    if(all(dR$rownames != selectionObj$id)) {
      print("Network selection not found in current plot.")
      return(NULL)
    }

    #NOT SURE IF NEEDED (up to NEW VERSION)
      dRfilt = dR[, .SD[rownames == selectionObj$id], by="rownames", .SDcols = c(values$settings$collapseTo), with=T]
      unitRow_allDF = useData2DT[dRfilt, colSums(.SD[, sapply(.SD, is.numeric), with=F]) ,on=values$settings$collapseTo];
      unitRow_all = unitRow_allDF[!names(unitRow_allDF) %in% values$settings$grouping]

      unitRow_all2 = NULL;
      unitSelected_name2 = NULL;

      unitRow = unitRow_all[unitRow_all != 0];

      unitRow_colors = unitRow;
      unitRow_colors[] = "#eaa647";
      if(!is.null(unitRow_all2)) {
        unitRow_colors[unitRow_all  > unitRow_all2] = "#eaa647"; # TODO -> make config'd
        unitRow_colors[unitRow_all  < unitRow_all2] = "#5399c7"; # TODO -> make config'd
      }
      unitRow[which(unitRow < 0, arr.ind=TRUE)] = unitRow[which(unitRow < 0, arr.ind=TRUE)] * -1;

      unitRow_nodes = unlist(lapply(strsplit( names(unitRow), "...", fixed=T ), function(x) { return(x[x != selectionObj$character ]) }));
      # if(!is.null(unitSelected_name2)) {
      #   unitRow_nodes = c(unitRow_nodes[unitRow_nodes != unitSelected_name2], unitSelected_name2)
      # }
      #browser()
      unitMatrix = matrix(0, ncol=nrow(set$nodes$positions$scaled$positions), nrow=nrow(set$nodes$positions$scaled$positions));
      rownames(unitMatrix) = rownames(set$nodes$positions$scaled$positions);
      colnames(unitMatrix) = rownames(unitMatrix);
      unitMatrix[c(selectionObj$character),unitRow_nodes] = unitRow;
      unitMatrix[unitRow_nodes, c(selectionObj$character)] = unitRow;
      net3 = NULL;#network(unitMatrix, directed=F);
    #END: NOT SURE IF NEEDED (up to NEW VERSION)


    ### NEW VERSION
    uns = c(selectionObj$id, selectionObj2$id);
    filters = attr(thisSet()$get('enaData')$get(), "filters");
    sdcols=colnames(useData2DT)[sapply(useData2DT, is.numeric)];
    minDT = useData2DT[handle %in% uns,lapply(.SD,sum,na.rm=T),by=c(values$settings$collapseTo), .SDcols=sdcols];
    minDTc =minDT[,apply(.SD,2,makeCompNode, types=c("#eaa647","#5399c7")),.SDcols=sdcols, with = T];
    minDTsizes = minDTc[1,!is.na(minDTc[2,]), with=F];
    minDTcolors = minDTc[2,!is.na(minDTc[2,]), with=F];
    minDTsizes = minDTsizes[,which(!names(minDTcolors) %in% values$settings$grouping),with=F];
    minDTcolors = minDTcolors[,which(!names(minDTcolors) %in% values$settings$grouping),with=F];
    minDTnodes = minDTc[,!is.na(minDTc[2,]), with=F]
    minDTnodes = minDTnodes[,which(!names(minDTcolors) %in% values$settings$grouping),with=F]
    minDTnodes = minDTnodes[,{ cols=strsplit(colnames(.SD), "...", fixed=T); m=as.matrix(.SD[,,with=F]); lapply(1:length(cols),function(x){ c(m[1,x],m[2,x],cols[[x]]) }); },];

    return(list(
      "name" = unitSelected_name,
      "net" = net3, "label" = rownames(set$nodes$positions$scaled$positions),
      "edgeSize" = minDTsizes, "edgeColors" = minDTcolors,
      "matrix" = unitMatrix, "nodes" = unitRow_nodes,

      #NEEDED FOR SURE
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
        size = 0.1
      );
    });
    #browser()
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
    r.list2
  }
  createSigmaNet = function(val) {
    val$mode = as.data.frame(val$mode);
    val$mode[,1] = val$mode[,1] * 10; #Expand
    val$mode[,2] = val$mode[,2] * -10; #Expand and rotate
    val$mode[,3] = rownames(val$mode);
    val$mode[,4] = rownames(val$mode);
    colnames(val$mode) <- c("x","y","id","label");

    r.list2 = list();
    r.list2.nodes = lapply(1:nrow(val$mode), function(x) {
      list(
        label = rownames(val$mode)[x],
        id = rownames(val$mode)[x],
        x = val$mode[x,1],
        y = val$mode[x,2],
        size = 0.1
      );
    });
    r.list2$nodes = r.list2.nodes;

    connections = val$matrix[val$name, val$nodes];
    r.list2.edges = lapply(1:length(connections), function(x) {
      thisName = paste(val$name, names(connections)[x], sep=".");
      list(
        label = thisName,
        id = thisName,
        source = val$name, target = names(connections)[x],
        size = connections[[x]]*input$edgeZoom,
        color = val$edgeColors[[x]],
        type = "animate"
      );
    });

    r.list2
  };

  mainPlotData = reactive({
    if(is.null(values$mainPlotData)) {
      values$mainPlotData = dataRotated();
    }
    values$mainPlotData;
  });
  getPlottableData = reactive({
    dt = getFullData();

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
    }), fill=T)

        #Ensure all columns remain
    rbindlist(list(dtAll, read.table(text="",col.names=c(colnames(dt),"uuid"))), fill=T)
  })
  sigmaPlot = reactive({
    mainPlotData = getPlottableData(); #mainPlotData();
    if(is.null(values$mainPlotData)) {
      print("No data found for main plot.")
      return(NULL);
    }
    mainPlotData$x = mainPlotData$x * 10;
    mainPlotData$y = mainPlotData$y * 10;
    mainPlotData$id = rownames(mainPlotData);
    mainPlotData$label = rownames(mainPlotData);

    set = thisSet();
    percents = (set$data$centered$latent / sum(set$data$centered$latent)) * 100;
    allData = getFullData();
    r.list2 = list(
      nodes = list(),
      edges = list(),
      axisBounds = rep(max(allData[,.(x,y)])*10,2),  #as.numeric(apply(allData[,.(x,y)], 2, max) * 10), #apply(abs(set$nodes$positions$scaled$positions), 2, max),
      percents = percents[1:2]
    );
    #browser()
    f = thisSet()$get('enaData')$get('file');
    r.list2.nodes = lapply(1:nrow(mainPlotData), function(x) {
      nd = rowToNode(mainPlotData, x, values$settings$collapseTo, type="node", size = 1, file = f);
      nd
    })
    r.list2$nodes = r.list2.nodes;

    #meansBy = c(head(values$settings$collapseTo, length(values$settings$collapseTo)-1));
    rjson::toJSON(r.list2);
  });
  rowToNode = function(val, x, by, type="node", size=1, file =NULL) {
    file.dt = data.table(file)
    #f = thisSet()$get('enaData')$get('file')
    #thisHouse = as.character(unique(file[file$character == val[x]$character,]$house));
    thisHouse = unique(file.dt[which(file.dt$character == as.vector(val[x]$character)),]$house);
    #browser();
    list(
      label = val[x]$rownames,
      id = val[x]$rownames,
      character = val[x]$character, # FIXME
      x = val$x[x],
      y = val$y[x],
      size = 1 / length(by),
      type = type,
      #by = last(by),
      #expandTo = values$settings$grouping[which(values$settings$grouping == last(by)) + 1],
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
      val = updatePlot(input$unitClicked2);
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
    print("Getting comparison.");
    if(
      !is.null(input$unitClicked1) &&
      !is.null(input$unitClicked2)
    ) {
      #val = updatePlot(input$unitClicked1, input$unitClicked2);
      val = list(
        mode = values$network1$mode,
        matrix = data.table::copy(values$network1$matrix),
        name = paste(values$network1$name, values$network2$name, sep="."),
        nodes = unique(c(values$network1$nodes, values$network2$nodes)),
        edgeColors = NULL
      )
      val$matrix[] = 0;
      val$matrix = data.table(val$matrix, keep.rownames = T)
      combs = rbindlist(list(values$network1$edgeSize, values$network2$edgeSize), fill=T);
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
        val$matrix[which(val$matrix$rn==x[2]), x[1]] = (combs[,xN,with=F])
        val$matrix[which(val$matrix$rn==x[1]), x[2]] = (combs[,xN,with=F])
        val$fullNodes[3:4,xN] = (x);
      }
      valToPlot = createSigmaNet2(val);
      #browser()

      valToPlot$nodes = lapply(valToPlot$nodes, function(n) { n$color = "#4d4d4d"; n });
      values$sigmaNetComp = rjson::toJSON(valToPlot);
    }else {
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
        doubleClickNode=htmlwidgets::JS("ENA.graphs.unit.events.doubleClickNode")
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
    input$unitClicked1$id
  });
  output$unitClicked2 <- renderText({
    input$unitClicked2$id
  });
  # output$unitsClicked <- renderText({
  #   input$unitsClicked;
  # });
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
    session$sendCustomMessage("housesJSON", rjson::toJSON(housesListChars())); #housesListJSON);
  })
  observe({
    session$sendCustomMessage("collapseTo", jsonlite::toJSON(values$settings$collapseTo));

    session$sendCustomMessage("timelineNested", timeline());
    session$sendCustomMessage("timelineFilter", jsonlite::toJSON(timelineFilter()));

    session$sendCustomMessage("unitsSelected", rjson::toJSON(unitsSelectedMeta()));
    session$sendCustomMessage("codesSelected", rjson::toJSON(codesSelected()));
    session$sendCustomMessage("allExcerpts", jsonlite::toJSON(
      values$enaFile[match(unique(excerpt_id), values$enaFile$excerpt_id), c("season", "episode", values$codesSelected, "excerpt"), with=F]));
  })
  observeEvent(input$updateDataRotated, {
    values$mainPlotData = dataRotated();
  });
  observeEvent(input$codesSelected, {
    browser();
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
  observeEvent(input$updateUnits, {
    upUnits = jsonlite::fromJSON(input$updateUnits);
    values$plottable = apply(upUnits, 1, function(u) { list(by=list(character=c(u[1])),uuid=uuid::UUIDgenerate(),from=NULL) });
    units1 = apply(upUnits, 1, function(u) { data.frame(character=u[1], house=u[2]) });
    units2 = unitsSelectedMeta();
    unitsList = list();
    for(i in 1:nrow(upUnits)) {
      unitsList[[i]] = data.frame(character=upUnits[i,1], house=upUnits[i,2]);
      #browser();
      if(!any(values$codesSelected == upUnits[i,1])) {
        values$codesSelected[length(values$codesSelected)+1] = upUnits[i,1]
      }
    }
    session$sendCustomMessage("unitsSelected", rjson::toJSON(unitsList));
    #session$sendCustomMessage("unitsSelected", rjson::toJSON(units2));
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
  # observeEvent(input$unitsClicked, {
  #   session$sendCustomMessage("unitsClicked", input$unitsClicked);
  # });
  # observeEvent(input$edgeClicked, {
  #   session$sendCustomMessage("edgeClicked", "You clicked an edge!!");
  # });

  output
})
