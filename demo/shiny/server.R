library(ggplot2)
library(GGally)
library(network)
library(sna)
library(visNetwork)
library(data.table)
library(ggrepel)
library(ggnetwork)
library(gridSVG)

extractName <- function(name) {
  last(strsplit(name, ".", fixed=T)[[1]])
}

shinyServer(function(input, output, session) {
  values <- reactiveValues();
  values$nodeSize = 3;
  values$sigmaNet1 = list(nodes = list(), edges = list());
  values$sigmaNet2 = list(nodes = list(), edges = list());
  values$sigmaNetComp = list(nodes = list(), edges = list());
  values$settings = list(
    "grouping" = c("character","season", "episode"),
    "collapseTo" = c("character")
  );

  thisSet <- reactive({
    print("Updating the set.");
    settings = settings();
    if(settings$allowUpdate == T) {
      gotSet$update("data",
        unitsSelected=input$unitsSelected,
        codeNames=input$codesSelected
      );
    }
  });
  unitsSelected <- reactive({
    set = thisSet();
    setData = set$get("enaData")$get("file");
    unitNames = set$get("enaData")$get("unitsSelected");

    unitNames.w.meta = lapply(set$get("enaData")$get("unitsSelected"), function(u) {
      setData[setData$character==u,which(lapply(setData[which(f$character==u),], function(x) { length(unique(x)) == 1 && all(is.character(as.vector(x)))} ) == T)][1,]
    })

    unitNames.w.meta
  });
  housesListChars <- reactive({
    set = thisSet();
    setData = set$get("enaData")$get("file");
    housesList.w.chars = lapply(housesList, function(x) {
      x$characters = unique(setData[which(x$house==setData$house),]$character)
      x
    });
    housesList.w.chars
  });
  timeline <- reactive({
    set = thisSet();
    timeline = list();

    seasons=unique(set$get('enaData')$get('file')[c("season","episode")]);
    for(i in unique(seasons$season)) {
      timeline[[as.character(i)]] = seasons[which(seasons$season == i), ]$episode;
    }

    timeline;
  });
  settings <- reactive({
    values$settings
  });
  collapseTo = reactive({
    thisSet()$get('enaData')$get('unitsBy')
  })
  dataRotated <- reactive({
    if(
      is.null(input$collapseTo)
    ) {
      return(NULL)
    }
    val = data.frame(thisSet()$data$centered$rotated);

    filters = attr(thisSet()$get('enaData')$get(), "filters");
    valDT = data.table(val, filters);
    rownames(valDT) = rownames(val);
    colnames(valDT)[1] = "x";
    colnames(valDT)[2] = "y";

    valMeaned = valDT[, lapply(.SD, mean), by = c(input$collapseTo), .SDcols = c('x','y')];
    rownames(valMeaned) = apply(valMeaned[,input$collapseTo, with = F], 1, paste, collapse=".")

    valMeanedDT = as.data.frame(valMeaned)
    df = data.table(valMeanedDT[,c('x','y')], valMeanedDT[,!(colnames(valMeanedDT) %in% c('x','y'))])

    rownames(df) = rownames(valMeaned);
    df$rownames = rownames(valMeaned);
    df
  });

  updatePlot <- function(selection, selection2 = NULL) {
    set = thisSet();

    if(!is.character(selection)) {
      selectionName = rownames(selection)[1];
    } else {
      selectionName = selection;
    }
    unitSelected_name = extractName(selectionName);
    useData = set$data$normed;

    dR = dataRotated();
    useData2 = data.frame(useData, attr(set$get('enaData')$get(), "filters"))
    useData2DT = data.table(useData2);
    browser(expr=debug);

    if(all(dR$rownames != selection)) {
      print("Network selection not found in current plot.")
      return(NULL)
    }

    dRfilt = dR[, .SD[rownames == selection], by="rownames", .SDcols = c(input$collapseTo), with=T]
    unitRow_allDF = useData2DT[dRfilt, colSums(.SD[, sapply(.SD, is.numeric), with=F]) ,on=input$collapseTo];
    unitRow_all = unitRow_allDF[!names(unitRow_allDF) %in% values$settings$grouping]

    if(!is.null(selection2)) {
      if(!is.character(selection2)) {
        selectionName2 = rownames(selection2)[1];
      } else {
        selectionName2 = selection2;
      }
      unitSelected_name2 = extractName(selectionName2);

      dRfilt2 = dR[, .SD[rownames == selection2], by="rownames", .SDcols = c(input$collapseTo), with=T]
      unitRow_allDF2 = useData2DT[dRfilt2, colSums(.SD[, sapply(.SD, is.numeric), with=F]) ,on=input$collapseTo];
      unitRow_all2 = unitRow_allDF2[!names(unitRow_allDF2) %in% values$settings$grouping]
      unitRow_all = unitRow_all - unitRow_all2;
    }

    unitRow = unitRow_all[unitRow_all != 0];
    unitRow_colors = unitRow;
    unitRow_colors[which(unitRow_colors > 0, arr.ind=T)] = "#5399c7";
    unitRow_colors[which(unitRow_colors < 0, arr.ind=T)] = "#eaa647";
    unitRow[which(unitRow < 0, arr.ind=TRUE)] = unitRow[which(unitRow < 0, arr.ind=TRUE)] * -1;

    unitRow_nodes = unlist(lapply(strsplit( names(unitRow), "...", fixed=T ), function(x) { return(x[x != unitSelected_name]) }));
    unitMatrix = matrix(0, ncol=nrow(set$nodes$positions$scaled$positions), nrow=nrow(set$nodes$positions$scaled$positions));
    rownames(unitMatrix) = rownames(set$nodes$positions$scaled$positions);
    colnames(unitMatrix) = rownames(unitMatrix);
    unitMatrix[c(unitSelected_name),unitRow_nodes] = unitRow;
    unitMatrix[unitRow_nodes, c(unitSelected_name)] = unitRow;
    net3 = network(unitMatrix, directed=F);

    return(list(
      "name" = unitSelected_name,
      "net" = net3, "label" = rownames(set$nodes$positions$scaled$positions),
      "mode" = set$nodes$positions$scaled$positions,
      "edgeSize" = unitRow, "edgeColors" = unitRow_colors,
      "matrix" = unitMatrix, "nodes" = unitRow_nodes
    ));
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
        label = rownames(val$mode)[x], id = rownames(val$mode)[x],
        x = val$mode[x,1],y = val$mode[x,2],
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
    r.list2$edges = r.list2.edges;

    r.list2
  };
  sigmaPlot = reactive({
    val = dataRotated();
    if(is.null(val)) {
      return(NULL);
    }
    #browser();
    #val[,1] = val[,1] * 10; #Expand
    #val[,2] = val[,2] * -10; #Expand and rotate
    #val[,ncol(val)] = rownames(val);
    #val[,ncol(val)] = rownames(val);
    val$x = val$x * 10;
    val$y = val$y * 10;
    val$id = rownames(val);
    val$label = rownames(val);
    #browser();
    #colnames(val) <- c("x","y","id","label");

    r.list2 = list(nodes = list(), edges = list());
    r.list2.nodes = lapply(1:nrow(val), function(x) {
      list(
        label = rownames(val)[x],
        id = rownames(val)[x],
        #x = val[x,1],
        #y = val[x,2],
        x = val$x[x],
        y = val$y[x],
        size = 1
      )
    })
    r.list2$nodes = r.list2.nodes;

    rjson::toJSON(r.list2);
  });
  sigmaNet1 = reactive({
    if(!is.null(input$unitClicked1)) {
      val = updatePlot(input$unitClicked1);
      if(!is.null(val$mode)) {
        values$sigmaNet1 = rjson::toJSON(createSigmaNet(val));
      }
    } else {
      values$sigmaNet1 = list(nodes = list(), edges = list())
    }
    values$sigmaNet1
  });
  sigmaNet2 = reactive({
    if(!is.null(input$unitClicked2)) {
      val = updatePlot(input$unitClicked2);

      values$sigmaNet2 = rjson::toJSON(createSigmaNet(val));
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
      val = updatePlot(input$unitClicked1, input$unitClicked2);
      values$sigmaNetComp = rjson::toJSON(createSigmaNet(val));
    }else {
      values$sigmaNetComp = list(nodes = list(), edges = list())
    }
    values$sigmaNetComp
  });

  #####
  # Begin: Plots
  #####
    output$sigma <- renderSigma(
      sigma(sigmaPlot(),drawEdges = T, drawNodes = T, name="mainPlot", clickNode=htmlwidgets::JS("ENA.graphs.unit.events.clickNode"))
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
    input$unitClicked1
  });
  output$unitClicked2 <- renderText({
    input$unitClicked2
  });
  output$unitsClicked <- renderText({
    input$unitsClicked;
  });
  output$timeline <- renderTable({
    timeline()
  });

  output$grouping <- renderUI({
    selectizeInput('grouping', 'Collapse by',
      selected = grouping(),
      choices = unique(colnames(thisSet()$get("enaData")$get("file"))),
      multiple = TRUE)
  });
  output$collapseTo <- renderUI({
    selectizeInput('collapseTo', 'Collapse by',
       selected = collapseTo(),
       choices = unique(colnames(thisSet()$get("enaData")$get("file"))),
       multiple = TRUE)
  });

  observe({
    session$sendCustomMessage("timelineUpdated", timeline());
    session$sendCustomMessage("housesJSON", rjson::toJSON(housesListChars())); #housesListJSON);
    session$sendCustomMessage("unitsSelected", rjson::toJSON(unitsSelected()));
  })
  observeEvent(input$timelime, {
    session$sendCustomMessage("timelineUpdated", output$timelime);
  });
  observeEvent(input$unitsClicked, {
    session$sendCustomMessage("unitsClicked", input$unitsClicked);
  });
  observeEvent(input$edgeClicked, {
    session$sendCustomMessage("edgeClicked", "You clicked an edge!!");
  });

  output
})
