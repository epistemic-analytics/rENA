(function(w, $, angular, Shiny, undefined) { "use strict";
  console.info("Installed.");

  _.mixin({
    "toInt": num => parseInt(num, 10)
  });

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
    var selected = clickData.data.node.id,
      selectedLen = ENA.graphs.unit.selections.length;

    if(selected && selectedLen < 2 && ENA.graphs.unit.selections[0] != selected) {
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
        console.info("Units: ", units);
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
            var seasons = _.keys($scope.timeline),
              firstSeason = _.first(seasons),
              lastSeason = _.last(seasons);
            $scope.splitTimelineAt("center", season, episode);
            $scope.splitTimelineAt("left",firstSeason, _.first($scope.timeline[firstSeason]));
            $scope.splitTimelineAt("right", lastSeason, _.last($scope.timeline[lastSeason]));
            var $target = $($event.target),
              $center = $element.find(".splitGrabCenter"),
              xOffset = $target.position().left;
            $center.css("left", (xOffset - 6) + "px");
          };
        }
      };
    }])
    .directive("splitGrab", [function() {
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
              $episode = null,
              $top = $("#timelineTopBar"),
              timelineWidth = $("#timelineAdjustersWrapper").width();
            $(window).on("mousemove.enaGrab", _.throttle(function($event) {
              $event.preventDefault();
              var x = Math.round($event.pageX),
                episode = _.find(episodes, e => {
                  let $e = $(e),
                      left = Math.round($e.offset().left),
                      width = $e.outerWidth();
                  return (x <= (left + width) && x >= left && noOverlap(which, $e));
                });
              if (episode) {
                $episode = $(episode);
                let left = ($episode.position().left - 6);
                $element.closest(".splitGrab").css("left", left + "px");
                updateTopBar(which, left, $top, timelineWidth);
              }
            }, 50)).on("mouseup.enaGrab", function($event) {
              $(window).off("mouseup.enaGrab").off("mousemove.enaGrab");
              if ($episode) {
                $scope.splitTimelineAt(which, $episode.scope().season, $episode.scope().episode);
              }
            });

            function updateTopBar(which, left, $top, width) {
              $top.css(which, (which === "left" ? left : width - left - 23) + "px"); //23 == grabber width
            }
            function noOverlap(which, $episode) {
              let scope = $episode.scope(),
                s = _.toInt(scope.season),
                e = _.toInt(scope.episode),
                pos = $scope.positions,
                tl = $scope.timeline;
              // less than season and episode is at least one from other episode
              // equal seasons and episodes at least one from other episode
              // !last in season and !first in season
              if (which === "left") {
                return ((s < pos.center.season && (_.first(tl[pos.center.season]) !== pos.center.episode || _.last(tl[s]) !== e)) ||
                  (s === pos.center.season && (e + 1) < pos.center.episode));
              } else if (which === "right") {
                return ((s > pos.center.season && (_.last(tl[pos.center.season]) !== pos.center.episode || _.first(tl[s]) !== e)) ||
                  (s === pos.center.season && (e - 1) > pos.center.episode));
              } //else
              return (((s > pos.left.season && (_.last(tl[pos.left.season]) !== pos.left.episode || _.first(tl[s]) !== e)) ||
                        (s === pos.left.season && e > (pos.left.episode + 1)))
                    && ((s < pos.right.season && (_.first(tl[pos.right.season]) !== pos.right.episode || _.last(tl[s]) !== e)) ||
                        (s === pos.right.season && e < (pos.right.episode - 1))));
            }
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
              var foundHouse = scope.$parent.housesJSON.filter(h=>h.house === u.house)[0];
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
      $scope.opts = {
        "showCharacters": true,
        "showEpisodeSummary": false
      };
      $scope.settings = {
        groups: [ "Season", "Episode" ]
      };
      $scope.housesAdded = [];
      $scope.unitsSelected = undefined;
      $scope.activeHouse = undefined;

      $scope.dragHouseComplete = function() {
        console.info("Done dragging.");
      };
      $scope.dropCallback = function(index, item, external, type) {
        $scope.$broadcast("house-added", item);
      };
      $scope.toggleSideMinimized = function() {
        $scope.opts.showEpisodeSummary = !$scope.opts.showEpisodeSummary;
        $scope.opts.showCharacters = !$scope.opts.showEpisodeSummary;
      };
      $scope.toggleCharacters = function() {
        $scope.opts.showCharacters = !$scope.opts.showCharacters;
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
            $scope.timeline2 = (Array.isArray(timeline) ? timeline : JSON.parse(timeline));
            $scope.$broadcast("timeline-selections", $scope.timeline2);
          });
        });
        Shiny.addCustomMessageHandler("timelineNested", function(timeline) {
          $scope.$apply(function(){
            $scope.timeline = timeline;
          });
        });
      });

      var updateGraphSplit = _.debounce(function() {
        console.log("update graph", $scope.timeline);
        console.log("tmime2", $scope.timeline2);
        //Shiny.onInputChange("timelineFiltered", JSON.stringify(scope.timeline2));
      }, 50);

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
        //this should be somewhere else... ooooooooh well
        $(".splitGrab").css("left", "");
        $("#timelineTopBar").css({"left": "", "right" : ""});
      };
      $scope.splitTimelineAt = function(which, season, episode) {
        $scope.opened.splitChosen = true;
        $scope.positions[which].season = _.toInt(season);
        $scope.positions[which].episode = _.toInt(episode);
        updateGraphSplit();
      };
    }])
    .controller("NetworkPlotsCtrl", ["$scope", function($scope){
      $scope.clearPlot = function(wh) {
        console.info("Clearing: ", wh);
        ENA.graphs.unit.selections.splice(wh-1,1)
        Shiny.onInputChange("unitClicked"+wh, null);

        if (wh === 1 && ENA.graphs.unit.selections.length > 0) {
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
    .controller("EpisodeSummaryCtrl", ["$scope", function($scope) {

    }])
  ;
})(window, jQuery, angular, Shiny);
