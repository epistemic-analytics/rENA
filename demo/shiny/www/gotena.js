(function(w, $, angular, Shiny, undefined) { "use strict";
  console.log("Installed.");

  var ENA = w.ENA = {
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

  ENA.graphs.unit.events["clickNode"] = function(clickData) {
    var
       selected = clickData.data.node.id
      ,selectedLen = ENA.graphs.unit.selections.length
    ;

    if(
      selected &&
      selectedLen < 2 &&
      ENA.graphs.unit.selections[0] != selected
    ) {
      Shiny.onInputChange("unitClicked"+(selectedLen+1), selected);
      ENA.graphs.unit.selections.push(selected);
    }
    Shiny.onInputChange("unitsClicked", ENA.graphs.unit.selections);
  };
  ENA.graphs.network.events["clickEdge"] = function(edge) {
    Shiny.onInputChange("edgeClicked", { camera: this.id, edge: edge, noce: Math.random() });
  };

  var ENAapp = angular.module("ENAapp", ['ngMaterial','dndLists']);

  ENAapp
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
        scope: true,
        templateUrl: "templates/timeline.html",
        link: function(scope, element, attrs) {
          scope.$on("timeline-selections", function(event, tl) {
            scope.timeline2 = tl;
          });
          scope.checkTimelineSection = function(season, episode) {
            var toInc = true, obj;
            if(scope.timeline2) {
              obj = scope.timeline2.filter(t => t.season==season && t.episode==episode)[0];
              toInc = obj.included;
            }
            return toInc;
          };
          scope.toggleTimeline = function(season, episode) {
            var toInc = scope.timeline2.filter(t => t.season==season && t.episode==episode)[0];
            toInc.included = !toInc.included;
            Shiny.onInputChange("timelineFiltered", JSON.stringify(scope.timeline2));
          };
        }
      }
    }])
    .directive("enaSplitTimeline", [function() {
      return {
        "restrict": "A",
        "templateUrl": "templates/splitTimeline.html",
        "scope": true,
        "link": function($scope, $element, $attrs) {
          $scope.splitSelect = function($event, season, episode) {
            var seasons = _.keys($scope.timeline);
            $scope.splitTimelineAt("center", season, episode);
            $scope.splitTimelineAt("left", _.first(seasons), _.first(_.first(seasons)));
            $scope.splitTimelineAt("right", _.last(seasons), _.last(_.last(seasons)));
            var $target = $($event.target),
              $center = $element.find(".splitGrabCenter"),
              xOffset = $target.position().left;
            $center.css("left", (xOffset - 6) + "px");
          };
        }
      };
    }])
    .directive("splitGrab", [function() {
      function noOverlap(which, $episode, positions) {
        let scope = $episode.scope();
        if (which === "left") {
          let pos = positions.center;
          return ((scope.season < pos.season) || (scope.season === pos.season && scope.episode < pos.episode));
        } else if (which === "right") {
          let pos = positions.center;
          return ((scope.season > pos.season) || (scope.season === pos.season && scope.episode > pos.episode));
        } //else
        let left = positions.left,
            right = positions.right;
        return (((scope.season > left.season) || (scope.season === left.season && scope.episode > left.episode)) &&
              ((scope.season < right.season) || (scope.season === right.season && scope.episode < right.episode)));
      }
      return {
        "restrict": "A",
        "template": `<span class="splitGrabOuter">
          <span class="splitGrabInner"> </span>
          <span class="splitGrabInner"> </span>
        </span>`,
        "link": function($scope, $element, $attrs) {
          $element.on("mousedown.enaGrab", function($event) {
            $event.preventDefault();
            var $timeline = $("#timeline-groups"),
                cl = $element.closest(".splitGrab")[0].classList,
                which = (cl.contains("splitGrabCenter") ? "center" :
                  (cl.contains("splitGrabLeft") ? "left" : "right")),
              episodes = $timeline.find(".timeline-episode").toArray(),
              $episode;
            $(window).on("mousemove.enaGrab", _.throttle(function($event) {
              $event.preventDefault();
              var x = Math.round($event.pageX);
              for (let i = 0; i < episodes.length; i++) {
                $episode = $(episodes[i]);
                let left = Math.round($episode.offset().left),
                  width = $episode.outerWidth();
                if (x <= (left + width) && x >= left && noOverlap(which, $episode, $scope.positions)){
                  break;
                } else {
                  $episode = null;
                }
              }
              if ($episode) {
                $element.closest(".splitGrab").css("left", ($episode.position().left - 6) + "px");
              }
            }, 50)).on("mouseup.enaGrab", function($event) {
              $(window).off("mouseup.enaGrab").off("mousemove.enaGrab");
              if ($episode) {
                $scope.splitTimelineAt(which, $episode.scope().season, $episode.scope().episode);
              }
            });
          });
        }
      };
    }])
    .directive("housesAdded", [function(){
      return {
        restrict: 'EA',
        scope: {},
        transclude: true,
        templateUrl: "templates/housesAdded.html",
        link: function(scope, element, attrs) {
          scope.housesAdded = [];
          scope.$on("house-added", function(event, item){
            if (scope.housesAdded.map(h=>h.house).filter(h=>h===item.house).length < 1) {
              scope.housesAdded.push(item);
            }
          });
          scope.$on("units-loaded", function(units) {
            scope.housesAdded = scope.$parent.unitsSelected.map(u=>{
              var foundHouse = scope.$parent.housesJSON.filter(h=>{
                  return( h.house === u.house );
                })[0];

              foundHouse.selected = foundHouse.selected || [];
              foundHouse.selected.push(u);
              return foundHouse;
            })
          });
        }
      }
    }])
    .directive("houseList", [function(){
      return {
        restrict: 'EA',
        scope: {
          houseList: '='
        },
        templateUrl: "templates/houseList.html",
        link: function(scope, element, attrs) {
          scope.$on("houses-changed", function(event, houses){
            scope.houseList = houses;
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
          characters: '='
        },
        templateUrl: "templates/houseCharacters.html",
        link: function(scope, element, attrs) {

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

      $timeout(function(){
        Shiny.addCustomMessageHandler("unitsSelected", function(units) {
          $scope.$apply(function(){
            $scope.unitsSelected = JSON.parse(units);
            $scope.$broadcast("units-loaded", $scope.unitsSelected);
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
      $scope.opened = {
        "split": false,
        "splitChosen": false,
        "playing": false
      };
      $scope.positions = {
        "right": {},
        "left": {},
        "center": {}
      };
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
        $scope.opened.playing = true;
      };
      $scope.stopPlay = function() {
        $scope.opened.playing = false;
      };
      $scope.split = function() {
          $scope.opened.split = true;
          $scope.opened.splitChosen = false;
      };
      $scope.clearSplit = function() {
        $scope.opened.split = false;
        $scope.opened.splitChosen = false;
        _.each($scope.positions, (o, which) => { $scope.positions[which] = {}; });
        $(".splitGrab").css("left", "");
      };
      $scope.splitTimelineAt = function(which, season, episode) {
        $scope.opened.splitChosen = true;
        $scope.positions[which].season = season;
        $scope.positions[which].episode = episode;
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
