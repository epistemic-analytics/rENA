library(data.table)
library(sigma)

extractName <- function(name) {
  substring(name, regexec("[\\d]\\.[\\d]\\.(.*)", name, perl = T)[[1]][2]);
}
shinyUI(fluidPage(
  tags$head(
    tags$link(rel="stylesheet", href="bower_components/angular-material/angular-material.min.css"),
    tags$script(src="bower_components/angular/angular.min.js"),
    tags$script(src="bower_components/angular-aria/angular-aria.min.js"),
    tags$script(src="bower_components/angular-animate/angular-animate.min.js"),
    tags$script(src="bower_components/angular-messages/angular-messages.min.js"),
    tags$script(src="bower_components/angular-material/angular-material.min.js"),
    tags$script(src="bower_components/angular-drag-and-drop-lists/angular-drag-and-drop-lists.js"),
    tags$script(src="bower_components/underscore/underscore-min.js"),
    tags$script(src="gotena.js")
  ),

  tags$body("ng-app"="ENAapp",
    HTML('<filter id="blurMe">
            <feColorMatrix in="SourceGraphic" type="saturate" values="0.1" />
         </filter>'),
    tags$div("ng-controller" = "ENACtrl", #"class" = "container-fluid",
             "ng-class" = "{'showCharacters': opts.showCharacters, 'showEpisodeSummary': opts.showEpisodeSummary}",
      fluidRow(id="headerRow",
        headerPanel("Main Character: Jaime Lannister")
      ),
      fluidRow(id="timelineRow", "ng-controller"="TimelineCtrl",
        h4("Timeline"),
        div(
          HTML("<ena-timeline timeline='timeline'></ena-timeline>"),
          tags$span(id="timelineBtnWrap",
            tags$button(
              class="glyphicon glyphicon-play pull-left",
              tags$span("Play", class="hidden-sm hidden-xs"),
              "ng-click" = "play($event)", "ng-if" = "!opened.playing"),
            tags$button(class="glyphicon glyphicon-stop pull-left",
              tags$span("Stop", class="hidden-sm hidden-xs"),
              "ng-click" = "stopPlay($event)", "ng-if" = "opened.playing"
            ),
            tags$button(class="glyphicon glyphicon-resize-horizontal pull-left",
              tags$span("Split", class="hidden-sm hidden-xs"),
              "ng-click" = "split($event)", "ng-if" = "!opened.split"),
            tags$button(class="glyphicon glyphicon-ban-circle pull-left",
              tags$span("Clear", class="hidden-sm hidden-xs"),
              "ng-click" = "clearSplit($event)", "ng-if" = "opened.split")
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
              "ng-class" = "{ 'active-drag': activeDrag }",
              "dnd-list"="addedItems", "dnd-effect-allowed"="link",
              "dnd-drop"="dropCodeCallback(index, item, external, type)",
              tabsetPanel(id="",
                tabPanel("Units",
                  tags$h4("Characters", id="collapseLevel"),
                  sigmaOutput('sigma',nodeClick = "plot1_click")
                ),
                tabPanel("Comparison",
                  tags$h4("Comparison", id="collapseLevel"),
                  sigmaOutput('sigmaComparison', nodeClick = "comp_clickNode")
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
        column(width = 4, id="sidePlotColumn", class="column", "ng-controller"="NetworkPlotsCtrl",
          div( id="mainPlot",
            div(
              h5(
                tags$span("Main Plot"),
                tags$button(class="glyphicon glyphicon-remove",
                  tags$span("Close", class="hidden-sm hidden-xs"),
                  "ng-click"="clearPlot(1)"
                )
              ),
              h5(class="plotLabel", textOutput("unitClicked1")),
              div(

              )
            ),
            sigmaOutput('sigmaNet1', height="100%")
          ),
          div( id="secondPlot",
            div(
              h5(
                tags$span("Secondary Plot"),
                tags$button(class="glyphicon glyphicon-remove",
                  tags$span("Close", class="hidden-sm hidden-xs"),
                  "ng-click"="clearPlot(2)", "data-toggle"="tooltip",
                  "data-placement"="top",
                  title="Close plot"
                ),
                tags$button(class="glyphicon glyphicon-sort",tags$span("Switch", class="hidden-sm hidden-xs"),"ng-click"="switchPlots()")
              ),
              h5(class="plotLabel", textOutput("unitClicked2"))
            ),
            sigmaOutput('sigmaNet2')
          )
        ),
        column(width = 2, id = "episodeSummary", class="column", "ng-if" = "opts.showEpisodeSummary",
               "ng-controller" = "EpisodeSummaryCtrl", "ng-include" = "'templates/episodeSummary.html'")
      ),
      div(
        id = "sideMinimizedArea",
        tags$a(id = "minimizedTitle", "ng-click" = "toggleSideMinimized()",
               "ng-bind" = "(opts.showEpisodeSummary ? 'Characters' : 'Episode Summary')")
      )
    )
  )
  ,title = "GoT ENA", theme = "styles.css"
))
