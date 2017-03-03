library(data.table)
library(sigma)

extractName <- function(name) {
  substring(name, regexec("[\\d]\\.[\\d]\\.(.*)", name, perl = T)[[1]][2]);
}
shinyUI(fluidPage(
  withTags(
    head(
      link(rel="stylesheet", href="bower_components/angular-material/angular-material.min.css"),
      link(rel="stylesheet", href="bower_components/spectrum/spectrum.css"),
      script(src="bower_components/angular/angular.min.js"),
      script(src="bower_components/angular-aria/angular-aria.min.js"),
      script(src="bower_components/angular-animate/angular-animate.min.js"),
      script(src="bower_components/angular-messages/angular-messages.min.js"),
      script(src="bower_components/angular-material/angular-material.min.js"),
      script(src="bower_components/angular-drag-and-drop-lists/angular-drag-and-drop-lists.js"),
      script(src="bower_components/spectrum/spectrum.js"),
      script(src="bower_components/underscore/underscore-min.js"),
      script(src="lib/sigma-1.2.0/sigma.js"),
      script(src="lib/sigma-1.2.0/plugins/sigma.parsers.gexf.min.js"),
      script(src="lib/sigma-1.2.0/custom/sigma.svg.edges.animate.js"),
      script(src="lib/sigma-1.2.0/custom/sigma.plugins.animate2.js"),
      script(src="lib/sigma-1.2.0/custom/sigma.plugins.animate.js"),
      script(src="lib/sigma-1.2.0/custom/sigma.plugins.animateEdges.js"),
      script(src="lib/sigma-1.2.0/custom/sigma.plugins.axisLines.js"),
      script(src="lib/sigma-1.2.0/plugins/sigma.renderers.customShapes.min.js"),
      script(src="gotena.js"),
      script(src="js/gotena.directives.js")
    )
  ),

  tags$body("ng-app"="ENAapp",
    HTML('<filter id="blurMe">
            <feColorMatrix in="SourceGraphic" type="saturate" values="0.1" />
         </filter>'),
    # tags$div(
    #   textOutput("plotNodes")
    # ),
    tags$div("ng-controller" = "ENACtrl",
             "ng-class" = "{'showCharacters': opts.showCharacters, 'showEpisodeSummary': opts.showEpisodeSummary}",
      tags$style(id="unitStyles",type="text/css"),
      fluidRow(id="headerRow"),
      fluidRow(id="timelineRow", "ng-controller"="TimelineCtrl",
        h4("Timeline"),
        div(
          HTML("<ena-timeline timeline='timeline'></ena-timeline>"),
          withTags(
            span(id="timelineBtnWrap",
              span("class"="clearfix",
                button('class'="glyphicon glyphicon-play pull-left", 'title'="Play Seasons",
                  'ng-disabled'='!hasSeason',
                  'ng-click'="play($event,'seasons')", 'ng-if'="!opened.playing",
                  HTML("<md-tooltip md-direction='left'>Play Seasons</md-tooltip>"),
                  tags$span("Seasons", class="hidden-sm hidden-xs")
                ),
                button('class'="glyphicon glyphicon-play pull-left", 'title'="Play Episodes",
                  'ng-disabled'='!hasEpisode',
                  'ng-click'="play($event,'episodes')", 'ng-if'="!opened.playing",
                  HTML("<md-tooltip md-direction='left'>Play Episodes</md-tooltip>"),
                  tags$span("Episodes", class="hidden-sm hidden-xs")
                )
              ),
              span('class'="clearfix bigTimelineButtons",
                button('class'="glyphicon glyphicon-stop pull-left",
                  'ng-click'="stopPlay($event)",'ng-if'="opened.playing",
                  HTML("<md-tooltip md-direction='left'>Stop Playing</md-tooltip>"),
                  tags$span("Stop", class="hidden-sm hidden-xs")
                ),
                button('class'="glyphicon glyphicon-resize-horizontal pull-left",
                  'ng-click'="split($event)", 'ng-if'="!opened.split",
                  HTML("<md-tooltip md-direction='left'>Split Timeline</md-tooltip>"),
                  tags$span("Split Timeline", class="hidden-sm hidden-xs")
                ),
                button('class'="glyphicon glyphicon-ban-circle pull-left",
                  'ng-click'="clearSplit($event)",'ng-if'="opened.split",
                  HTML("<md-tooltip md-direction='left'>Clear Timeline</md-tooltip>"),
                  tags$span("Clear Timeline", class="hidden-sm hidden-xs")
                )
              )
            )
          )
        )
      ),

      fluidRow(id="mainColumnWrap",
        column(width=8, id="centerColumn", "ng-class"="{'col-xs-12 col-md-8': !opts.showEpisodeSummary, 'col-xs-6': opts.showEpisodeSummary}",
          fluidRow(id="plotRow",
            column(width=4, id="selectedColumn", class="column",
              "ng-show" = "!opts.showEpisodeSummary",
              h4('Characters'),
              tags$ul("houses-added"="",
                "dnd-list"="addedItems", "dnd-effect-allowed"="link",
                "ng-class" = "{ 'active-drag': activeDrag }",
                "dnd-drop"="dropCallback(index, item, external, type)"
              )
            ),
            column(width = 8, id="unitPlotColumn", class="column",
              "ng-class" = "{ 'active-drag': activeDrag, 'hide-labels': !data.labels, 'hasComparison': plots.comparison.nodes.length > 0 }",
              "dnd-list"="addedItems", "dnd-effect-allowed"="link",
              "dnd-drop"="dropCodeCallback(index, item, external, type)",
              tabsetPanel(id="",
                tabPanel("Units",
                  tags$h4("Characters", id="collapseLevel"),
                  tags$div(id="sigmaPlot", "ng-controller"="MainPlotCtrl",
                    HTML("<sigma-node-plot plot-networks=\"true\" plot-units=\"true\" \"></sigma-node-plot>")
                  )
                  #,sigmaOutput('sigma',nodeClick = "plot1_click")
                  #,sigmaOutput('sigmaComparison', nodeClick = "comp_clickNode")
                ),
                tabPanel("Comparison",
                  tags$h4("Comparison", id="collapseLevel")
                )
              ),
              div(id="plotOptions", "ng-controller" = "PlotOptionsCtrl",
                tags$div(id="thresholdSlider",
                  tags$span("Relationship Strength"),
                  sliderInput("edgeZoom", NULL,
                    min = 1, max = 10, value = 3, ticks=F, width="100"
                  )
                ),
                tags$span(HTML("<md-switch ng-model='data.units' class='md-primary'>Units</md-switch>")),
                tags$span(HTML("<md-switch ng-model='data.scaledUnits' ng-change='toggleScaling(this)' class='md-primary onOff'>Scaled Units</md-switch>")),
                tags$span(HTML("<md-switch ng-model='data.labels' class='md-primary'>Labels</md-switch>"))
              )
            )
          ),
          fluidRow(id="charactersRow", "ng-show" = "!opts.showEpisodeSummary",
            tags$div(id = "addCharsListColumn",
                     "ng-class" = "{'col-sm-12': opts.showCharacters, 'col-sm-4': !opts.showCharacters, 'hasActiveHouse': activeHouse !== undefined }",
              tags$div(id="addCharsWrap",
                tags$div(id="addCharsAction", "ng-click" = "toggleCharacters()",
                  tags$h6("Add Characters"),
                  tags$i(class="glyphicon",
                    "ng-class" = "{'glyphicon-plus-sign': !opts.showCharacters, 'glyphicon-remove-sign': opts.showCharacters}")
                )
              ),
              tags$div(id="addCharsListWrap", "ng-show"="opts.showCharacters",
                tags$ul(id="addCharsList", "house-list"="")
              )
            )
          )
        ),
        column(width = 4, id="sidePlotColumn", class="column boxShadow", "ng-controller"="NetworkPlotsCtrl",
          div( id="mainPlot",
            div(
              h5(
                tags$span("Main Plot"),
                tags$button(class="glyphicon glyphicon-remove",
                  tags$span("Close", class="hidden-sm hidden-xs"),
                  "ng-click"="clearPlot(1)", "ng-disabled"="unitsPlotted.length < 1"
                )
              ),
              h5(class="plotLabel", textOutput("unitClicked1"))
            )
            #,sigmaOutput('sigmaNet1')
            ,tags$div(id="sigmaPlotNetwork1"#, #"ng-controller"="",
              ,HTML("<sigma-node-plot plot-networks=\"true\" plot-selection=\"1\" ></sigma-node-plot>")
            )
          ),
          div( id="secondPlot",
            div(
              h5(
                tags$span("Secondary Plot"),
                tags$button(class="glyphicon glyphicon-remove",
                  tags$span("Close", class="hidden-sm hidden-xs"),
                  "ng-click"="clearPlot(2)", "ng-disabled"="unitsPlotted.length < 2",
                  "data-toggle"="tooltip", "data-placement"="top",
                  title="Close plot"
                ),
                tags$button(class="glyphicon glyphicon-sort",
                  tags$span("Switch", class="hidden-sm hidden-xs"),
                  "ng-click"="switchPlots()", "ng-disabled"="unitsPlotted.length < 2"
                )
              ),
              h5(class="plotLabel", textOutput("unitClicked2"))
            )
            #,sigmaOutput('sigmaNet1')
            ,tags$div(id="sigmaPlotNetwork2"#, #"ng-controller"="",
              ,HTML("<sigma-node-plot plot-networks=\"true\" plot-selection=\"2\" ></sigma-node-plot>")
            )
          )
        ),
        column(width = 2, id = "episodeSummary", class="column", "ng-if" = "opts.showEpisodeSummary",
               "ng-controller" = "EpisodeSummaryCtrl", "ng-include" = "'templates/episodeSummary.html'")
      ),
      div(
        id = "sideMinimizedArea", class="boxShadow", "ng-click" = "toggleSideMinimized()",
        tags$a(id = "minimizedTitle",
               "ng-bind" = "(opts.showEpisodeSummary ? 'Characters' : 'Episode Summary')")
      )
    )
  )
  ,title = "GoT ENA", theme = "styles.css"
))
