library(data.table)

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
    tags$div("ng-controller"="ENACtrl", "ng-class" = "{'showCharacters': showCharacters}",
      fluidRow(id="headerRow",
        headerPanel("Game of Thrones ENA")
      ),
      fluidRow(id="timelineRow", "ng-controller"="TimelineCtrl",
        h4("Timeline"),
        #uiOutput('collapseTo'),
        div(
          HTML("<ena-timeline timeline='timeline'></ena-timeline>"),
          tags$span(id="timelineBtnWrap",
            tags$button(
              tags$i(class="glyphicon glyphicon-play pull-left"), tags$span("Play"),
              "ng-click" = "play($event)", "ng-if" = "!opened.playing"),
            tags$button(
              tags$i(class="glyphicon glyphicon-stop pull-left"), tags$span("Stop"),
              "ng-click" = "stopPlay($event)", "ng-if" = "opened.playing"),
            tags$button(
              tags$i(class="glyphicon glyphicon-random pull-left"), tags$span("Split"),
              "ng-click" = "split($event)", "ng-if" = "!opened.split"),
            tags$button(
              tags$i(class="glyphicon glyphicon-ban-circle pull-left"), tags$span("Clear"),
              "ng-click" = "clearSplit($event)", "ng-if" = "opened.split")
          )
        )
      ),

      fluidRow(id="mainColumnWrap",
        column(width=8,
          fluidRow(id="plotRow",
            column(width=4, id="selectedColumn", class="column",

              h4('Characters'),
              tags$ul("houses-added"="",
                "dnd-list"="addedItems", "dnd-effect-allowed"="link",
                "dnd-drop"="dropCallback(index, item, external, type)"
              ),

              selectizeInput( 'unitsSelected', 'Units',
                selected = gotSet$get("enaData")$get("unitsSelected"),
                choices = unique(gotSet$get("enaData")$get("file")$character),
                multiple = TRUE
              ),

              selectizeInput('codesSelected', 'Codes',
                selected = gotSet$get("enaData")$get("codeNames"),
                choices = unique(gotSet$get("enaData")$get("file")$character),
                multiple = TRUE
              )
            ),
            column(width = 8, id="unitPlotColumn", class="column",
              tabsetPanel(id="",
                tabPanel("Units",
                  tags$h4("Units"),
                  sigmaOutput('sigma',nodeClick = "plot1_click")
                ),
                tabPanel("Comparison",
                  tags$h4("Comparison"),
                  sigmaOutput('sigmaComparison', nodeClick = "comp_clickNode")
                )
              ),
              div(id="plotOptions", "ng-controller" = "PlotOptionsCtrl",
                tags$div(id="thresholdSlider",
                  tags$span("Relationship Strength"),
                  sliderInput("edgeZoom", NULL,
                    min = 1, max = 10, value = 1, ticks=F, width="100"
                  )
                ),
                tags$span(HTML("<md-switch ng-model='data.units' class='md-primary'>Units</md-switch>")),
                tags$span(HTML("<md-switch ng-model='data.labels' class='md-primary'>Labels</md-switch>"))
              )
            )
          ),
          fluidRow(id="charactersRow",
            tags$div(id = "addCharsListColumn", "ng-class"="{'col-sm-12': showCharacters, 'col-sm-4': !showCharacters, 'hasActiveHouse': activeHouse !== undefined }",
              tags$div(id="addCharsWrap",
                tags$div(id="addCharsAction", "ng-click"="showCharacters=!showCharacters",
                  tags$h6("Add Characters"),
                  tags$i(class="glyphicon", "ng-class"="{'glyphicon-plus-sign': !showCharacters,'glyphicon-remove-sign': showCharacters}")
                )
              ),
              tags$div(id="addCharsListWrap", "ng-show"="showCharacters",
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
                tags$button(class="glyphicon glyphicon-remove",tags$span("Close"),"ng-click"="clearPlot(1)")
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
                tags$button(class="glyphicon glyphicon-remove",tags$span("Close"),"ng-click"="clearPlot(2)"),
                tags$button(class="glyphicon glyphicon-random",tags$span("Switch"),"ng-click"="switchPlots()")
              ),
              h5(class="plotLabel", textOutput("unitClicked2"))
            ),
            sigmaOutput('sigmaNet2')
          )
        )
      )
    )
  )
  ,title = "GoT ENA", theme = "styles.css"
))
