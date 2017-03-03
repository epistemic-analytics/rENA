(function(w, $, angular, Shiny, undefined) { "use strict";
  console.info("Installed.");

  _.mixin({
    "toInt": num => parseInt(num, 10)
  });

  var ENA = w.ENA = {
    app: undefined,
    collapseTo: undefined,
    graphs: {
      unit: {
        selections: [],
        events: { }
      },
      network: {
        plots: {
          "main": {},
          "secondary": {},
          "comparison": {}
        },
        events: { }
      }
    }
  };

  Shiny.addCustomMessageHandler("collapseTo", function(c) {
    ENA.collapseTo = c;
  });

  var clicks = 0, clickTimeout, clickedAt;
  ENA.graphs.unit.events["clickNode"] = function(clickData) {
    let now = Date.now();
    if (clicks === 0) {
      clickTimeout = setTimeout(function() {
        var selected = clickData.data.node.label,
          selectedLen = ENA.graphs.unit.selections.length;

        if (selected && selectedLen < 2 && (!ENA.graphs.unit.selections[0] || ENA.graphs.unit.selections[0].label != selected)) {
          Shiny.onInputChange("unitClicked"+(selectedLen+1), clickData.data.node); //selected);
          ENA.graphs.unit.selections.push(clickData.data.node); //selected);
        }
        Shiny.onInputChange("unitsClicked", { nodes: ENA.graphs.unit.selections, type: "animate", nonce: Math.random() });
        ENA.app.scope().$broadcast("unitClicked", ENA.graphs.unit.selections);

        clearTimeout(clickTimeout);
        clicks = 0;
        clickedAt = 0;
      }, sigma.settings.doubleClickTimeout);

      clickedAt = now;
      clicks++;
    } else if (now - clickedAt < sigma.settings.doubleClickTimeout) {
      clearTimeout(clickTimeout);
      clicks = 0;
      clickedAt = 0;
    }
  };
  ENA.graphs.unit.events["overNode"] = function(hoveredData) {
    var
      node = hoveredData.data.node,
      selected = node.label,
      selectedLen = ENA.graphs.unit.selections.length
    ;

    if (
      node.nodeType !== "code" &&
      selectedLen === 1 && ENA.graphs.unit.selections[0].id !== hoveredData.data.node.id
    ) {
      //ENA.graphs.unit.selections.push(hoveredData.data.node);
      Shiny.onInputChange("unitClicked2", hoveredData.data.node);
      Shiny.onInputChange("unitsClicked", { nodes: [ENA.graphs.unit.selections[0],hoveredData.data.node], type: "def", nonce: Math.random() });
    }
  };
  ENA.graphs.unit.events["outNode"] = function(hoveredData) {
    var
      node = hoveredData.data.node,
      selected = hoveredData.data.node.label,
      selectedLen
    ;
    selectedLen = ENA.graphs.unit.selections.length;

    if(
      node.nodeType !== "code" && selectedLen===1 && ENA.graphs.unit.selections[0].id !== hoveredData.data.node.id) {
      ENA.graphs.unit.selections = [ENA.graphs.unit.selections[0]] //.filter(s=>s.label!==selected);
      Shiny.onInputChange("unitClicked2", null);
      Shiny.onInputChange("unitsClicked", { nodes: [ENA.graphs.unit.selections[0]], type: "def", nonce: Math.random() });
      ENA.app.scope().$broadcast("plot.clear2", ENA.graphs.unit.selections);
    }
  };
  ENA.graphs.unit.events["overEdge"] = function(edgeData) {
    ENA.app.scope().$broadcast("hover-edge", edgeData.data.edge);
  };
  ENA.graphs.unit.events["outEdge"] = function(edgeData) {
    ENA.app.scope().$broadcast("unhover-edge", edgeData.data.edge);
  };
  ENA.graphs.unit.events["doubleClickNode"] = function(clickData) {
    if(clickData.data.node.expandTo.length > 0) {
      ENA.collapseTo.push(clickData.data.node.expandTo);
      clickData.data.node.nonce = Math.random();
      Shiny.onInputChange("toggleNode", JSON.stringify(clickData.data.node));
    }
  };
  //network events
  ENA.graphs.network.events["clickEdge"] = function(edge) {
    Shiny.onInputChange("edgeClicked", { camera: this.id, edge: edge, nonce: Math.random() });
    ENA.app.scope().$broadcast("click-edge", edge);
  };

  var ENAapp = angular.module("ENAapp", ['ngMaterial', 'dndLists']);
  ENAapp
    .run(["Shiny","$timeout", function(Shiny, $timeout) {
      $timeout(function(){
        ENA.app = angular.element("[ng-app='ENAapp']");
      });
    }])

    /** Factories **/
    .factory("Shiny", [ "$timeout", function($timeout) {
      return(window.Shiny);
    }])
    .factory("ENA", [ "$timeout", function($timeout) {
      return(window.ENA);
    }])

    /** Filters **/
    .filter("unitsBy", [ function() {
      return function(units, by) {
        console.info("Units: ", units);
      };
    }])
    .filter("Html", ["$sce", function($sce) {
      return html => $sce.trustAsHtml(html);
    }])
    .filter("Empty", [function() {
      return _.isEmpty;
    }])
    .filter("NotEmpty", [function() {
      return function(o) {
        return !_.isEmpty(o);
      };
    }])
    .filter("isPlotted", [ function() {
      return function(unit) {
        console.log(unit, ENA.graphs.unit.selections.map(s=>s.label))
        false
      }
    }])

    /** Services **/
    .service("Helper", [function() {
      return {
        "setTopBarGradient": function($top, $center) {
          let pos = $top.position().left,
            center = $center.position().left,
            topBarSplit = (center - pos) + 22;
          $top.css("background", ("linear-gradient(to right, #000 " + topBarSplit +
            "px, #FFFFFF " + topBarSplit + "px, #FFFFFF " + (topBarSplit + 1) +
            "px, #808080 " + (topBarSplit + 1) + "px)"));
        },
        "findHouse": function(houses, houseName) {
          return _.find(houses, h => h.house === houseName);
        }
      };
    }])


    /** Directives **/
    .directive("enaTimeline", [function(){
      return {
        restrict: 'E',
        scope: true,
        templateUrl: "templates/timeline.html",
        link: function(scope, element, attrs) {}
      }
    }])
    .directive("enaSplitTimeline", ["Helper", "$timeout", function(Helper, $timeout) {
      return {
        "restrict": "A",
        "templateUrl": "templates/splitTimeline.html",
        "scope": true,
        "link": function($scope, $element, $attrs) {

          $scope.splitSelect = function($event, season, episode) {
            $scope.splitTimelineAt("center", season, episode);
            $scope.opened.splitChosen = true;
            var $center = $element.find(".splitGrabCenter"),
              xOffset = $($event.target).position().left,
              $top = $("#timelineTopBar");
            $center.css("left", (xOffset - 6) + "px");
            $timeout(function() {
              Helper.setTopBarGradient($top, $center);
            }, 50);
          };

        }
      };
    }])
    .directive("splitGrab", ["Helper", function(Helper) {
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
                $splitGrabCenter = $("#timelineAdjusters .splitGrab.splitGrabCenter"),
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

                //topbar
                if (which !== "center") {
                  $top.css(which, (which === "left" ? left : timelineWidth - left - 23) + "px"); //23 == grabber width
                }
                if ($scope.opened.split && $scope.opened.splitChosen) {
                  Helper.setTopBarGradient($top, $splitGrabCenter);
                }
              }

            }, 50)).on("mouseup.enaGrab", function($event) {
              $(window).off("mouseup.enaGrab").off("mousemove.enaGrab");
              if ($episode) {
                $scope.splitTimelineAt(which, $episode.scope().season, $episode.scope().episode);
              }
            });

            function noOverlap(which, $episode) {
              let scope = $episode.scope(),
                s = _.toInt(scope.season),
                e = _.toInt(scope.episode),
                pos = $scope.positions,
                tl = $scope.timeline;
              // less than season and episode is at least one from other episode
              // equal seasons and episodes at least one from other episode
              // !last in season and !first in season
              if ($scope.opened.split) {
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
              } else {
                if (which === "left") {
                  return ((s < pos.right.season && (_.first(tl[pos.right.season]) !== pos.right.episode || _.last(tl[s]) !== e)) ||
                    (s === pos.right.season && (e + 1) < pos.right.episode));
                } else if (which === "right") {
                  return ((s > pos.left.season && (_.last(tl[pos.left.season]) !== pos.left.episode || _.first(tl[s]) !== e)) ||
                    (s === pos.left.season && (e - 1) > pos.left.episode));
                } //else
                return true;
              }
            }
          });
        }
      };
    }])
    .directive("housesAdded", [function(){
      return {
        restrict: 'EA',
        scope: true,
        transclude: true,
        templateUrl: "templates/housesAdded.html",
        link: function(scope, element, attrs) {
          scope.housesAdded = [];
          scope.showCharacters = null;

          scope.toggleShowCharacters = function(house) {
            scope.showCharacters = (scope.showCharacters === house ? null : house);
          };

          scope.$on("house-added", function(event, item) {
            //console.log("house added", item);
            var currentHouses = scope.housesAdded,
              currentHouse = currentHouses[item.house.house],
              haveHouse = !!currentHouse;

            item.house.selected = item.house.selected || [];
            if (item.type === "house" && !haveHouse) {
              scope.housesAdded[item.house.house] = item.house;

              var newUnits = item.house.characters.map(c=>{
                newUnit = { character: c, code: true, unit: true, house: item.house.house  }
                scope.unitsSelected.push(newUnit);
                return newUnit;
              });

              scope.showCharacters = item.house.house;
              Shiny.onInputChange("unitsSelected", scope.unitsSelected.map(u=> u.character));
              Shiny.onInputChange("unitAdded", JSON.stringify(newUnits));
            } else if (item.type === "character") {
              if (!haveHouse) scope.housesAdded[item.house.house] = item.house;
              var newUnit = {'character': item.character, 'house': item.house.house};
              scope.showCharacters = item.house.house;

              scope.unitsSelected.push(newUnit)
              Shiny.onInputChange("unitsSelected", scope.unitsSelected.map(u=> u.character));
              Shiny.onInputChange("unitAdded",  JSON.stringify([item]));
            }
          });

          scope.$on("units-loaded", function(event, units) {
            scope.housesAdded = Array.from(new Set(units.map(u => u.house))).map(h => {
              let hs = _.find(scope.housesJSON, hj => hj.house === h);
              hs.selected = [];
              return hs;
            });

            units.forEach(u => {
              let h = _.find(scope.housesJSON, h => h.house === u.house);
              h.selected.push(u);
            });
          });
        }
      }
    }])
    .directive("houseList", [function(){
      return {
        "restrict": 'EA',
        "scope": {},
        "templateUrl": "templates/houseList.html",
        "link": function(scope, element, attrs) {
          scope.houseList = [];
          scope.unitsKeyed = {};
          scope.$on("houses-changed", function(event, houses) {
            scope.houseList = houses;
          });
          scope.$on("units-loaded", function(event, units) {
            scope.unitsSelected = units;
            Object.keys(scope.unitsKeyed).forEach(u=>{
              scope.unitsKeyed[u].unit = false
            });
            units.forEach(u=> {
              scope.unitsKeyed[u.character] = u;
              scope.unitsKeyed[u.character].unit = true;
              scope.unitsKeyed[u.character].code = true;
            })
          });
          scope.$on("codes-loaded", function(event, codes) {
            scope.codesSelected = codes;
            Object.keys(scope.unitsKeyed).forEach(u=>{
              scope.unitsKeyed[u].code = false
            });
            codes.forEach(u=> {
              scope.unitsKeyed[u] = scope.unitsKeyed[u] || {}
              scope.unitsKeyed[u].code = true;
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
            scope.$emit("toggle-unit", char, !use, this.$parent.house);
          }
          scope.toggleCodeSelected = function(char, use) {
            scope.$emit("toggle-code", char, !use, this.$parent.house);
          }
          scope.dragHouseStarted = function() {
            console.log("Draggin' it")
            scope.$emit("item-drag", this);
          }
          scope.dragHouseEnded = function() {
            console.log("Done Draggin' it")
            scope.$emit("item-dragged", this);
          }
        }
      }
    }])
    .directive("scrollTracker", [function() {
      return {
        "restrict": "A",
        "scope": true,
        "link": function($scope, $element, $attrs) {
          $element.on("scroll", _.throttle(function(event) {
            let y = Math.round($element.scrollTop()),
              $tab = _.find($element.find(".tab-pane").toArray().map(t => $(t)), $t => {
                let top = Math.round($t.position().top),
                  bottom = (top + Math.round($t.height()));
                return ((bottom > 0) && top < y);
              });

            if ($tab && $tab.length) {
              $scope.$apply(function() {
                $scope.openTab($tab.scope().season, false);
              });
            }
          }, 150));
        }
      };
    }])
    .directive("hoverNames", [function() {
      return {
        "restrict": "A",
        "link": function($scope, $element, $attrs) {
          $element.on("mouseenter", ".highlightedWord", function($event) {
            let $el = $($event.target);
            $scope.hoverName($el.text(), $el[0].style.color);
          }).on("mouseleave", ".highlightedWord", function($event) {
            let $el = $($event.target);
            $scope.unhoverName($el.text());
          });
        }
      };
    }])
    .directive("colorCircle", ["$compile", function($compile) {
      const COLOR_CIRCLE_TEMP = `<span class="top-color semi-circle" ng-style="{'background-color': topColor}"></span><span
          class="bottom-color semi-circle" ng-style="{'background-color': bottomColor}"></span>`;
      return {
        "restrict": "A",
        "scope": {
          "topColor": "=",
          "bottomColor": "=",
          "house": "="
        },
        "template": COLOR_CIRCLE_TEMP,
        "link": function($scope, $element, $attrs) {
          var isOpen = false;
          $element.on("click", function($event) {
            $event.preventDefault();
            $event.stopPropagation();
            $scope.$apply(function() {
              isOpen = !isOpen;
              $("[color-circle]").not($element).popover("hide");
              $element.popover("toggle");
              if (!isOpen) {
                $(window).off("click.colorPicker");
              } else {
                setupOffClick();
              }
            });
            return false;
          });

          function setupOffClick() {
            $(window).on("click.colorPicker", function(ev) {
              if ($(ev.target).closest(".color-circle-popover").length === 0) {
                ev.preventDefault();
                ev.stopPropagation();
                $scope.$apply(function() {
                  $element.popover("hide");
                  $(window).off("click.colorPicker");
                  isOpen = false;
                });
                return false;
              }
            });
          }

          $scope.$watchGroup([() => $scope.topColor, () => $scope.bottomColor], function(colors) {
              $scope.$emit("house-colors-changed", $scope.house);
          });

          $element.popover({
            "trigger": "manual",
            "container": "body",
            "content": function() {
              return $compile(`<color-picker top-color="topColor" bottom-color="bottomColor" />`)($scope);
            },
            "animation": false,
            "html": true,
            "placement": "right",
            "template": `<div class="popover color-circle-popover">
              <div class="arrow"></div>
              <div class="popover-content"></div>
            </div>`
          });
        }
      };
    }])
    .directive("colorPicker", [function() {
      return {
        "restrict": "E",
        "replace": true,
        "scope": {
          "topColor": "=",
          "bottomColor": "="
        },
        "templateUrl": "templates/colorPicker.html",
        "link": function($scope, $element, $attrs) {
          $scope.active = { "main": true, "isOpen": true };
          $scope.colors = [
            "#305F42", "#52AA6E", "#61BE83", "#5A0502",
            "#860602", "#B40803", "#472C52", "#6C427B",
            "#9057A4", "#2771A3", "#3497DB", "#5DACE1",
            "#FF9300", "#FFAA33", "#FFBE66", "#000000",
            "#222222", "#366947", "#5F201E", "#D43862",
            "#DF6A89", "#21162E", "#362B58", "#6C55B1",
            "#143D5B", "#1C5279", "#7797AE", "#BE3D09",
            "#FF520D", "#FF976D"
          ];
          $scope.colorPairs = [
            ["#5399C7", "#EAA647"],
            ["#E74B3B", "#52AA6E"],
            ["#013D7E", "#99BD3A"],
            ["#EEB821", "#ED468B"],
            ["#92278F", "#70BE91"],
            ["#019FAD", "#572503"],
            ["#F15862", "#999999"]
          ];

          var $sc = $element.find("#spectrumColorPicker").spectrum({
            "color": ($scope.active.main ? $scope.topColor : $scope.bottomColor),
            "flat": true,
            "showInput": false,
            "allowEmpty": false,
            "showInitial": false,
            "showButtons": false,
            "preferredFormat": "hex",
          }).on("move.spectrum", _.debounce(function(ev) {
            let color = $sc.spectrum("get").toHexString();
            if (color && color !== ($scope.active.main ? $scope.topColor : $scope.bottomColor)) {
              $scope.$apply(function() {
                $scope.selectColor(color);
              });
            }
          }, 50));

          $scope.$watch('active.main', updateColorPicker);
          $scope.$watch('topColor', updateColorPicker);
          $scope.$watch('bottomColor', updateColorPicker);

          function updateColorPicker() {
            $sc.spectrum("set", ($scope.active.main ? $scope.topColor : $scope.bottomColor));
          }

          $scope.selectColor = function(color) {
            if (color !== $scope.topColor && color !== $scope.bottomColor) {
              if ($scope.active.main) {
                $scope.topColor = color;
              } else {
                $scope.bottomColor = color;
              }
            }
          }
          $scope.selectPreset = function(pair) {
            $scope.topColor = pair[0];
            $scope.bottomColor = pair[1];
          };
          $scope.activate = function(main) {
            $scope.active.main = main;
          };
          $scope.pairActive = function(pair) {
            return (pair[0] === $scope.topColor && pair[1] === $scope.bottomColor);
          };
        }
      };
    }])

    /** Controllers **/
    .controller("ENACtrl", ["$scope", "$timeout", "$q", "ENA", function($scope, $timeout, $q, ENA) {
      const LS_NAME = "ENA_SETTINGS";
      $scope.timeline = null;
      $scope.timeline2 = null;
      $scope.opts = {
        "showCharacters": true,
        "showEpisodeSummary": false,
        "houseColors": {}
      };
      loadSettings().then(settings => {
        if (!_.isEmpty(settings)) {
          _.extend($scope.opts, settings);
        }
      });
      $scope.data = {
        units: true,
        scaledUnits: true,
        labels: true,
        mainplot: undefined
      };
      $scope.plots = {
        comparison: undefined
      }
      $scope.settings = {
        groups: [ "Season", "Episode" ]
      };
      $scope.housesAdded = [];
      $scope.unitsSelected = undefined;
      $scope.unitsPlotted = [];
      $scope.activeHouse = undefined;
      $scope.activeDrag = false;

      $scope.$on("call.plot.clear",function(ev,wh) {
        $scope.$broadcast("plot.clear"+wh);
      });
      $scope.$on("house-colors-changed", function(ev, house) {
        $scope.opts.houseColors[house.house] = house.colors;
        saveSettings();
        //TODO: update plot/new colors
        //$scope.$broadcast("plottable-data-update")
      });
      $scope.$on("unitClicked", function(ev, selections) {
        $scope.unitsPlotted = selections;
        var text = "";
        var selNames = selections.map(s=>(".sigma-node-group circle.sigma-node[data-node-id='unit."+s.label+"']"))
        angular.element("g.activeNode").removeClass("activeNode");
        selections.forEach(s=>
          angular.element("g[data-node-id='unit."+s.label+"']").addClass("activeNode")
        )
        selNames.forEach((n,i)=>{
          text+=("\n"+n+" {\n\topacity: 1.0 !important;\n\tfill: " + (["blue", "green"])[i] + "\n}\n")
        });
        angular.element("#unitStyles").text(text);
      });
      $scope.$on("item-drag", function(ev, item) {
        console.info("Drag event")
        $scope.dragHouseStarted();
      });
      $scope.$on("item-dragged", function(ev, item) {
        console.info("Drag event")
        $scope.dragHouseEnded();
      });
      $scope.dragHouseEnded = function() {
        console.info("Ended the drag")
        $scope.activeDrag = false;
      }
      $scope.dragHouseStarted = function() {
        console.info("Started to drag")
        $scope.activeDrag = true;
      }
      $scope.dragHouseComplete = function() {
        $scope.activeDrag = false;
      };
      $scope.dropCodeCallback = function(index, item, external, type) {
        if(item.type==="character") {
          $scope.codesSelected.push(item.character)
        Shiny.onInputChange("updateCodes", JSON.stringify($scope.codesSelected));
        }
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

      $scope.timelineFilter = function() {
        Shiny.onInputChange("timelineFiltered", JSON.stringify($scope.timeline2));
        //TODO: remove this when 'inputFiltered' returns something from server
        $scope.$applyAsync(function() {
          $scope.$broadcast("timeline-selections", $scope.timeline2);
        });
      };

      $scope.$on("toggle-unit", function(event, char, use, house) {
        var newUnits = $scope.unitsSelected.filter(u=>{return(u.character!==char)})
        if(use) {
          newUnits.push({character: char, house: house.house, unit: true, code: true})
        }
        Shiny.onInputChange("updateUnits", JSON.stringify(newUnits));
      });
      $scope.$on("toggle-code", function(event, char, use) {
        var newCodes = [];
        if(use === true) {
          $scope.codesSelected.push(char);
          newCodes = $scope.codesSelected
        } else {
          newCodes = $scope.codesSelected.filter(u=>{return(u!==char)})
        }
        Shiny.onInputChange("updateCodes", JSON.stringify(newCodes));
      });

      function saveSettings() {
        localStorage.setItem(LS_NAME, JSON.stringify($scope.opts));
      }
      function loadSettings() {
        return $q(function(resolve, reject) {
          try {
            let s = localStorage.getItem(LS_NAME)
            resolve(JSON.parse(s));
          } catch (e) {
            reject();
          }
        });
      }

      $timeout(function() {
        Shiny.onInputChange("getPlotData", {});
        Shiny.addCustomMessageHandler("mainPlotData", function(data) {
          var
              broadcast = false
             ,newData = JSON.parse(data)
          ;

          if(typeof $scope.data.mainplot === "undefined" ||
              (newData.nodes && $scope.data.mainplot.nodes.length!==newData.nodes.length)) {
            broadcast = true;
          }
          $scope.data.mainplot = newData;
          if(broadcast === true){
            console.info("Have the data.")
            $scope.$broadcast("plottable-data-update", JSON.parse(data), true);
          }
        });
        Shiny.addCustomMessageHandler("hideNodes", function(nodePlottableIDs) {
          var removeNodes = nodePlottableIDs;
          $scope.$broadcast("plottable-hide-nodes", removeNodes);
        });
        Shiny.addCustomMessageHandler("showNodes", function(nodePlottableIDs) {
          var showNodes = JSON.parse(nodePlottableIDs);
          $scope.$broadcast("plottable-show-nodes", showNodes);
        });
        Shiny.addCustomMessageHandler("removeChildNodes", function(data){
          //console.log("Data: ", data);
          $scope.$broadcast("plottable-remove-nodes", data);
        })
        Shiny.addCustomMessageHandler("newPlottableData", function(data) {
          //console.log("new plottable data", data);
          $scope.$broadcast("plottable-data-update", data, false);
        });
        Shiny.addCustomMessageHandler("unitsSelected", function(units) {
          $scope.$apply(function() {
            $scope.unitsSelected = JSON.parse(units);
            $scope.$broadcast("units-loaded", $scope.unitsSelected);
          });
        });
        Shiny.addCustomMessageHandler("codesSelected", function(codes) {
          $scope.$apply(function(){
            $scope.codesSelected = JSON.parse(codes);
            $scope.$broadcast("codes-loaded", $scope.codesSelected);
          });
        });
        Shiny.addCustomMessageHandler("housesJSON", function(houses) {
          $scope.$apply(function() {
            $scope.housesJSON = JSON.parse(houses);
            _.each($scope.housesJSON, h => {
              if ($scope.opts.houseColors[h.house]) {
                h.colors = $scope.opts.houseColors[h.house];
              }
            });
            $scope.$broadcast("houses-changed", $scope.housesJSON);
          });
        });
        Shiny.addCustomMessageHandler("timelineFilter", function(timeline) {
          $scope.$apply(function() {
            $scope.timeline2 = (Array.isArray(timeline) ? timeline : JSON.parse(timeline));
            $scope.$broadcast("timeline-selections", $scope.timeline2);
          });
        });
        Shiny.addCustomMessageHandler("timelineNested", function(timeline) {
          $scope.$apply(function() {
            $scope.timeline = timeline;
          });
        });
        Shiny.addCustomMessageHandler("allExcerpts", function(ex) {
          $scope.$apply(function() {
            $scope.excerpts = ex;
            $scope.$broadcast("all-excerpts", ex);
          });
        });
        Shiny.addCustomMessageHandler("comparisonChanged", function(comp) {
          $scope.$apply(function() {
            var compJSON = (typeof comp === "object") ? comp : JSON.parse(comp);
            $scope.plots["comparison"] = ENA.graphs.network.plots["comparison"] = compJSON;
            $scope.$broadcast("comparison-changed", compJSON);
          });
        });
      });

      $scope.$watchCollection('opts', saveSettings);
    }])
    .controller("TimelineCtrl", ["$scope", "Shiny", function($scope, Shiny) {
      var episodeBackgroundColor = "";
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

      $scope.checkTimelineSection = function(season, episode) {
        if ($scope.timeline2) {
          let obj = _.find($scope.timeline2, t => t.season == season && t.episode == episode);
          return obj.included;
        }
        return true;
      };
      $scope.toggleTimeline = function(season, episode) {
        var toInc = _.find($scope.timeline2, t => t.season == season && t.episode == episode);
        toInc.included = !toInc.included;
        $scope.timelineFilter();
      };

      $scope.$watch('timeline', function() {
        if (!$scope.timeline) return;
        resetGrabbers();
      });
      //TODO: fix this
      //$scope.$watchCollection('unitsSelected', updateBackground);
      $scope.episodeColor = function(s, e) {
        //let active = $scope.checkTimelineSection(s, e);
        //return (active ? episodeBackgroundColor : "");
        return "";
      };

      function updateBackground() {
        var houses = [],
          backgroundStr = "linear-gradient(to bottom";
        _.each($scope.unitsSelected, u => {
          let h = _.find($scope.housesJSON, h => h.house === u.house);
          if (houses.indexOf(h) === -1) {
            houses.push(h);
          }
        });
        var perc = (100 / (houses.length * 2));
        _.each(houses, (h, i) => {
          let p = (perc * (i + 1));
          backgroundStr += ("," + h.colors[0] + " " + p + "%, " + h.colors[1] + " " + p + "%");
        });
        backgroundStr += ")";
        if (houses.length) {
          episodeBackgroundColor = backgroundStr;
        }
      }

      var updateGraphSplit = _.debounce(function() {
        $scope.$apply(function() {
          let pos = $scope.positions;
          _.each($scope.timeline2, tlo => {
            let s = _.toInt(tlo.season),
              e = _.toInt(tlo.episode);
            tlo.included = ((s > pos.left.season || (s === pos.left.season && e >= pos.left.episode)) &&
                            (s < pos.right.season || (s === pos.right.season && e <= pos.right.episode)));
          });
          $scope.timelineFilter();
        });
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
          resetGrabbers();
      };
      $scope.clearSplit = function() {
        $scope.opened.split = false;
        $scope.opened.splitChosen = false;
        resetGrabbers();
      };
      $scope.splitTimelineAt = function(which, season, episode) {
        $scope.opened.splitChosen = true;
        $scope.positions[which].season = _.toInt(season);
        $scope.positions[which].episode = _.toInt(episode);
        updateGraphSplit();
      };

      function resetGrabbers(season, episode) {
        var seasons = _.keys($scope.timeline),
          firstSeason = _.first(seasons),
          lastSeason = _.last(seasons);
        $scope.positions = {
          "left": {"season": _.toInt(firstSeason), "episode": _.toInt(_.first($scope.timeline[firstSeason])) },
          "right": {"season": _.toInt(lastSeason), "episode": _.toInt(_.last($scope.timeline[lastSeason])) },
          "center": {}
        };
        if (season && episode) {
          $scope.positions.center.season = _.toInt(season);
          $scope.positions.center.episode = _.toInt(episode);
        }
        $("#timelineTopBar").css({"left": "", "right" : "", "background": ""});
        $(".splitGrab").css("left", "");
        updateGraphSplit();
      };
      $scope.resetGrabbers = resetGrabbers;
    }])
    .controller("MainPlotCtrl", ["$scope", "Shiny","$timeout", function($scope, Shiny,$timeout) {

    }])
    .controller("NetworkPlotsCtrl", ["$scope","$timeout", function($scope, $timeout){
      $scope.unitsPlotted = [];
      $scope.$on("unitClicked", function(ev, selections) {
        $timeout(function(){
          $scope.unitsPlotted = selections;
        });
      });
      $scope.clearPlot = function(wh) {
        ENA.graphs.unit.selections.splice(wh-1,1)
        Shiny.onInputChange("unitClicked"+wh, null);
        $scope.$emit("call.plot.clear",wh);
        if (wh === 1 && ENA.graphs.unit.selections.length > 0) {
          Shiny.onInputChange("unitClicked"+2, null)
          Shiny.onInputChange("unitClicked"+1, ENA.graphs.unit.selections[0])
        }

        Shiny.onInputChange("unitsClicked", { nonce: Math.random(), nodes: ENA.graphs.unit.selections, type: "def" });
        $scope.$emit("unitClicked", ENA.graphs.unit.selections);

      };
      $scope.switchPlots = function() {
        ENA.graphs.unit.selections = ENA.graphs.unit.selections.reverse();
        [1,2].forEach(n=>{
          Shiny.onInputChange("unitClicked"+n, ENA.graphs.unit.selections[n-1])
        })
      };
    }])
    .controller("PlotOptionsCtrl", ["$scope", "Shiny", function($scope, Shiny){
      $scope.toggleScaling = function(s) {
        Shiny.onInputChange("scaledUnits", s.$parent.data.scaledUnits);
      };
    }])
    .controller("EpisodeSummaryCtrl", ["$scope", "$q", function($scope, $q) {
      var hoveredEdge = null,
        clickedEdge = null,
        allSeasons = null;

      $scope.position = {};
      $scope.seasons = [];
      $scope.closed = {};

      $scope.openTab = function(season, scroll) {
        if ($scope.position.active !== season) {
          $scope.position.active = season;
          if (scroll !== false) {
            $scope.$applyAsync(function() {
              let tab = document.querySelector("#s" + season.name + "-tab");
              if (tab) {
                let content = document.querySelector("#episodeSummaryContent > .tab-content");
                content.scrollTo(0, $(content).scrollTop() + $(tab).position().top);
              }
            });
          }
        }
      };

      $scope.hoverName = function(name, color) {
        let $e = $(".sigma-label[data-label-target*='" + name + "']").addClass("hovered");
        if (color) {
          $e.attr("fill", color);
        }
      };
      $scope.unhoverName = function(name) {
        $(".sigma-label[data-label-target*='" + name + "']").removeClass("hovered").attr("fill", "#000");
      };

      var updateEpisodeSummary = _.debounce(function() {
        //TODO: filter excerpts by $scope.timeline
        if ($scope.excerpts) {
          var seasons = {},
            organized = [];
          _.each($scope.excerpts, ex => {
            seasons[ex.season] = (seasons[ex.season] || {});
            seasons[ex.season][ex.episode] = (seasons[ex.season][ex.episode] || []);
            var text = ex.excerpt,
              codes = (_.chain(ex).keys(ex).without("season", "episode", "excerpt")
                          .filter(key => ex[key] === 1 && codeIncluded(ex)).value());
            _.each(codes, name => {
              let color = (getColor(name) || "#00F");
              text = text.replace(new RegExp("\\b(" + name +")\\b", "gi"),
                "<span class=\"highlightedWord\" style=\"color: " + color + ";\">$1</span>");
            });
            seasons[ex.season][ex.episode].push({
              "text": text,
              "codes": codes
            });
          });
          _.each(seasons, (episodes, seasonName) => {
            organized.push({
              "name": seasonName,
              "episodes": _.map(episodes, (excerpts, episode) => ({"name": episode, "excerpts": excerpts}))
            });
          });
          allSeasons = $scope.seasons = organized;
          $scope.openTab(_.first($scope.seasons));
          $scope.$apply();
        }
      }, 50),
      filterByEdge = _.debounce(function(edge) {
        var filteredSeasons = [];
        _.each(allSeasons, s => {

          var episodes = [];
          _.each(s.episodes, e => {
            var excerpts = [];
            _.each(e.excerpts, ex => {
              let target = _.some(ex.codes, c => c === edge.target),
                source = _.some(ex.codes, c => c === edge.source);
              if (target && source) {
                excerpts.push(ex);
              }
            });

            if (excerpts.length) {
              episodes.push({
                "name": e.name,
                "excerpts": excerpts
              });
            }
          });

          if (episodes.length) {
            filteredSeasons.push({
              "name": s.name,
              "episodes": episodes
            });
          }
        });

        $scope.seasons = filteredSeasons;
        $scope.openTab(_.first($scope.seasons));
        $scope.$apply();
      }, 50);
      updateEpisodeSummary();

      $scope.$on("timeline-selections", function($event, timeline) {
        updateEpisodeSummary();
        if (clickedEdge) {
          filterByEdge(clickedEdge);
        }
      });
      $scope.$on("all-excerpts", function($event, ex) {
        updateEpisodeSummary();
      });
      $scope.$on("hover-edge", function($event, edge) {
        hoveredEdge = edge;
        filterByEdge(edge);
      });
      $scope.$on("unhover-edge", function($event, edge) {
        if (!clickedEdge) {
          clickedEdge = null;
          hoveredEdge = null;
          $scope.seasons = allSeasons;
          $scope.openTab(_.first($scope.seasons));
          $scope.$apply();
        } else if (edge.id !== clickedEdge.id) {
          hoveredEdge = null;
          filterByEdge(clickedEdge);
        }
      });
      $scope.$on("click-edge", function($event, edge) {
        clickedEdge = edge;
        if (!hoveredEdge || edge.id !== hoveredEdge.id) {
          filterByEdge(edge);
        }
      });

      function codeIncluded(ex) {
        if (_.isEmpty($scope.timeline2)) return true;
        var o = _.find($scope.timeline2, t => t.season === ex.season && t.episode === ex.episode);
        return (o && o.included);
      }
      function getColor(name) {
        if (!_.isEmpty($scope.housesJSON) && !_.isEmpty($scope.unitsSelected)) {
          var char = _.find($scope.unitsSelected, u => name === u.character),
            house = (char ? _.find($scope.housesJSON, h => h.house === char.house) : null);
          if (house) {
            return house.color;
          }
        }
        return false;
      }
    }])
  ;
})(window, jQuery, angular, Shiny);
