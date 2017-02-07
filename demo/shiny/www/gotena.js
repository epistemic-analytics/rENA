(function(w, $, angular, Shiny, undefined) {
  console.log("Installed.");

  var ENA = w.ENA = {
    collapseTo: undefined,
    graphs: {
      unit: {
        selections: [],
        events: { }
      },
      network: {
        events: { }
      }
    }
  };

  Shiny.addCustomMessageHandler("allExcerpts", function(ex) {
    console.log("All the excerpts: ", ex.length);
    ENA.excerpts = ex;
  });
  Shiny.addCustomMessageHandler("collapseTo", function(c) {
    ENA.collapseTo = c;
  });

  var clicks = 0, clickTimeout, clickedAt;
  ENA.graphs.unit.events["clickNode"] = function(clickData) {
    console.log("Clicked: ", clickData)
    if(clicks === 0) {
      clickTimeout = setTimeout(function() {
        console.log("Plotting the network.");

        var
           selected = clickData.data.node.id
          ,selectedLen = ENA.graphs.unit.selections.length
        ;

        if(
          selected &&
          selectedLen < 2 &&
          (
            !ENA.graphs.unit.selections[0] ||
            ENA.graphs.unit.selections[0].id != selected
          )
        ) {
          Shiny.onInputChange("unitClicked"+(selectedLen+1), clickData.data.node); //selected);
          ENA.graphs.unit.selections.push(clickData.data.node); //selected);
        }
        Shiny.onInputChange("unitsClicked", ENA.graphs.unit.selections);

        clearTimeout(clickTimeout);
        clicks = 0;
        clickedAt = 0;
      }, sigma.settings.doubleClickTimeout);
      clickedAt = event.timeStamp;
      clicks++;
    } else if (event.timeStamp - clickedAt < sigma.settings.doubleClickTimeout) {
      console.log("double click clear -> ", clickTimeout);
      clearTimeout(clickTimeout);
      clicks = 0; clickedAt = 0;
    }
  };
  ENA.graphs.network.events["clickEdge"] = function(edge) {
    Shiny.onInputChange("edgeClicked", { camera: this.id, edge: edge, noce: Math.random() });
  };
  ENA.graphs.unit.events["doubleClickNode"] = function(clickData) {
    console.log("Double click: ", clickData);
    if(!ENA.collapseTo.filter(c=>{return c === clickData.data.node.expandTo}).length) {
      ENA.collapseTo.push(clickData.data.node.expandTo);

      // Set collapseTo to a unitClicked instead, update DataROtated or something
      //Shiny.onInputChange("collapseTo", JSON.stringify(ENA.collapseTo));
      Shiny.onInputChange("toggleNode", JSON.stringify(clickData.data.node));
    }
  };

  var ENAapp = angular.module("ENAapp", ['ngMaterial','dndLists']);
  ENAapp
    .run(["Shiny","$timeout", function(Shiny,$timeout) {
      $timeout(function(){
        Shiny.onInputChange("updateDataRotated", true);
      })
    }])
    /** Factories **/
    .factory("Shiny", [ "$timeout", function($timeout) {
      return(window.Shiny);
    }])

    /** Filters **/
    .filter("unitsBy", [ function() {
      return function(units, by) {
        console.log("Units: ", units);
      };
    }])

    /** Directives **/
    .directive("enaTimeline", [function(){
      return {
        restrict: 'E',
        scope: {
          timeline: '='
        },
        templateUrl: "templates/timeline.html",
        link: function(scope, element, attrs) {
          scope.$on("timeline-selections", function(event, tl) {
            scope.timeline2 = tl;
          });
          scope.checkTimelineSection = function(season, episode) {
            var toInc = true, obj;
            if(scope.timeline2) {
              obj = scope.timeline2.filter(t=>{return t.season==season && t.episode==episode})[0]
              toInc = obj.included;
            }
            return toInc;
          };
          scope.toggleTimeline = function(season, episode) {
            var toInc = scope.timeline2.filter(t=>{return t.season==season && t.episode==episode})[0]
            toInc.included = !toInc.included;
            Shiny.onInputChange("timelineFiltered", JSON.stringify(scope.timeline2));
          };
        }
      }
    }])
    .directive("housesAdded", [function(){
      return {
        restrict: 'EA',
        scope: {},
        transclude: true,
        templateUrl: "templates/housesAdded.html",
        link: function(scope, element, attrs) {
          scope.housesAdded = [];
          scope.showCharacters;

          scope.toggleShowCharacters = function(house) {
            if(scope.showCharacters === house) scope.showCharacters = undefined
            else scope.showCharacters = house;
          };

          scope.$on("house-added", function(event, item){
            var
              currentHouses = scope.housesAdded, //.map(h=>{ return h }),
              currentHouse = currentHouse = currentHouses[item.house.house],
              haveHouse = !!currentHouse, // && currentHouse.length > 0,
              haveUnit = currentHouse && currentHouse.selected.filter(u=>{ return u === item.character })
            ;

            item.house.selected = item.house.selected || [];
            if(
              item.type === "house" &&
              !haveHouse
            ) {
              scope.housesAdded[item.house.house] = item.house;
            } else if (
              item.type === "character"
            ) {
              if(!haveHouse) scope.housesAdded[item.house.house] = item.house;
              var newUnit = {'character': item.character, 'house': item.house.house};
              //item.house.selected.push(newUnit);
              scope.housesAdded[item.house.house].selected.push(newUnit);
              scope.showCharacters = item.house.house;

              scope.$parent.unitsSelected.push(newUnit)
              console.log("Now what:", scope.$parent.unitsSelected.map(u=>{return u.character}));
              Shiny.onInputChange("unitsSelected", scope.$parent.unitsSelected.map(u=>{return u.character}));
              Shiny.onInputChange("unitAdded", item);
            }
          });
          scope.$on("units-loaded", function(event, units) {

            scope.housesAdded = {};
            units.forEach(u=>{
              scope.housesAdded[u.house] = scope.housesAdded[u.house] || scope.$parent.housesJSON.filter(h=>{return( h.house === u.house );})[0];
              scope.housesAdded[u.house].selected = scope.housesAdded[u.house].selected || [];
              scope.housesAdded[u.house].selected.push(u);
            });
          });
        }
      }
    }])
    .directive("houseList", [function(){
      return {
        restrict: 'EA',
        scope: {},
        templateUrl: "templates/houseList.html",
        link: function(scope, element, attrs) {
          scope.houseList = [];
          scope.unitsKeyed = {};
          scope.$on("houses-changed", function(event, houses){
            scope.houseList = houses;
          });
          scope.$on("units-loaded", function(event, units) {
            scope.unitsSelected = units;
            units.forEach(u=> {
              console.log(u);
              scope.unitsKeyed[u.character] = u;
              scope.unitsKeyed[u.character].unit = true;
            })
          });

          scope.setActiveHouse = function(h) {
            if(scope.$parent.activeHouse === h.house) {
              scope.$parent.activeHouse = undefined;
              h.active = false;
            } else {
              scope.$parent.activeHouse = h.house;
              h.active = true;
            }
          };
        }
      }
    }])
    .directive("houseCharacters", [function(){
      return {
        restrict: 'EA',
        scope: {
          house: '=',
          characters: '='
        },
        templateUrl: "templates/houseCharacters.html",
        link: function(scope, element, attrs) {
          scope.toggleUnitSelected = function(char, use) {
            scope.$emit("toggle-unit", char, !use);
          }
        }
      }
    }])

    /** Controllers **/
    .controller("ENACtrl", ["$scope", "$timeout", function($scope, $timeout) {
      $scope.showCharacters = true;
      $scope.settings = {
        groups: [ "Season", "Episode" ]
      };
      $scope.housesAdded = [];
      $scope.unitsSelected = undefined;
      $scope.activeHouse = undefined;

      $scope.dragHouseComplete = function() {
        console.log("Done dragging.");
      };
      $scope.dropCallback = function(index, item, external, type) {
        $scope.$broadcast("house-added", item);
      };

      $scope.$on("toggle-unit", function(event, char, use) {
        console.log("Toggling:", char, "to", use);
      });

      $timeout(function(){
        Shiny.addCustomMessageHandler("unitsSelected", function(units) {
          $scope.$apply(function(){
            $scope.unitsSelected = JSON.parse(units);
            $scope.$broadcast("units-loaded", $scope.unitsSelected);
            $scope.$emit("units-loaded", $scope.unitsSelected);
          });
        });
        Shiny.addCustomMessageHandler("housesJSON", function(houses) {
          $scope.$apply(function(){
            $scope.housesJSON = JSON.parse(houses);
            $scope.$broadcast("houses-changed", $scope.housesJSON);
          });
        });
      });

      /*
      Shiny.addCustomMessageHandler("unitsClicked", function(a) {
        console.log("Clicked a node: ", a);
      });
      Shiny.addCustomMessageHandler("edgeClicked", function(a) {
        console.log("Clicked an edge.")
      });
      */
    }])
    .controller("TimelineCtrl", ["$scope", "Shiny", "$timeout", function($scope, Shiny, $timeout){
      $scope.timeline;
      $scope.timeline2;
      $timeout(function(){
        Shiny.addCustomMessageHandler("timelineFilter", function(timeline) {
          $scope.$apply(function(){
            $scope.timeline2 = (Array.isArray(timeline) ? timeline :JSON.parse(timeline));
            $scope.$broadcast("timeline-selections", $scope.timeline2);
          });
        });
        Shiny.addCustomMessageHandler("timelineNested", function(timeline) {
          $scope.$apply(function(){
            $scope.timeline = timeline;
          });
        });
      });

      $scope.play = function() {

      };
      $scope.split = function() {

      };
    }])
    .controller("NetworkPlotsCtrl", ["$scope", function($scope){
      $scope.clearPlot = function(wh) {
        console.log("Clearing: ", wh);
        ENA.graphs.unit.selections.splice(wh-1,1)
        Shiny.onInputChange("unitClicked"+wh, null);

        if(wh === 1 && ENA.graphs.unit.selections.length > 0) {
          Shiny.onInputChange("unitClicked"+2, null)
          Shiny.onInputChange("unitClicked"+1, ENA.graphs.unit.selections[0])
        }
      };
    }])
    .controller("PlotOptionsCtrl", ["$scope", function($scope){
      $scope.data = {
        units: true,
        labels: true
      };
    }])
  ;
})(window, jQuery, angular, Shiny);
