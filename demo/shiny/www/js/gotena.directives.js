(function(w, $, angular, Shiny, undefined) { "use strict";

  var
     ENAapp = angular.module("ENAapp")
    ,ENA = w.ENA
  ;

  if(!ENAapp) throw "ENAapp is undefined";
  if(!ENA) throw "ENA is undefined";

  ENAapp
    .directive("sigmaNodePlot", ["$timeout", function($timeout){
      return {
        restrict: 'E',
        template: '<div class="sigma-plot" ng-class=\'{"has-network": hasNetwork===true }\'></div>',
        scope: {
          plotNetworks: "=",
          plotUnits: "=",
          plotSelection: "="
        },
        link: function(scope, element, attrs) {
          scope.sig = null;
          scope.hasNetwork = false;
          scope.hasUnits = false;

          var
             data = {
               axisBounds: [-20]
             }
            ,plotSelection = scope.plotSelection || ''
            ,i, o
            ,g = { nodes: [] }
            ,plotter = angular.element(element).find(".sigma-plot")
            ,plotterID = Math.round(Math.random()*1000)
          ;

          function resetCamera(bounds) {
            plotterID = Math.round(Math.random()*1000);
            plotter.attr("id", "plot-"+plotterID);

            if(scope.sig !== null) {
              scope.sig.graph.clear();
              scope.sig.refresh();
              plotter.find(" > *").remove()
              scope.sig.kill();
            }

            scope.sig = new sigma({
              renderers: [{
                container: document.getElementById("plot-"+plotterID),
                type: 'svg'
              }],
              settings : {
                backgroundColor: "#FFFFFF",
                sideMargin: 0,
                animationsTime: 400,
                zoomMin: 1,
                zoomMax: 1,
                enableCamera: false,
                minNodeSize: 0.1,
                maxNodeSize: 5,

                // Edge settings
                minEdgeSize: 0,
                maxEdgeSize: 10,
                batchEdgesDrawing: true,
                webglEdgesBatchSize: 1,
                edgeAnimation: "outward",

                // Label settings
                labelThreshold: 1,
                defaultLabelSize: 10
              }
            });
            if(typeof bounds !== "undefined") {
              scope.sig.settings('bounds',{
                minX: -bounds[0],
                maxX: bounds[0],
                minY: -bounds[0],
                maxY: bounds[0],
                sizeMax: 1,
                weightMax: -Infinity
              });
            }
            CustomShapes.init(scope.sig);

            scope.sig.bind("clickNode", ENA.graphs.unit.events.clickNode);
            scope.sig.bind("doubleClickNode", ENA.graphs.unit.events.doubleClickNode);
            scope.sig.bind("overNode", ENA.graphs.unit.events.overNode);
            scope.sig.bind("outNode", ENA.graphs.unit.events.outNode);

            scope.sig.addAxisLines({color: "#CCCCCC", bounds: bounds}); //data.axisBounds);
            scope.sig.refresh();
          }
          function animateNodes(toAnimate) {
            if(toAnimate.nodes.length > 0) {
              sigma.plugins.animate(
                scope.sig,
                {x: 'tox', y:'toy', size: 'tosize', color: 'tocolor'},
                toAnimate
              );
              scope.sig.refresh();
            }
          }

          scope.$on("plot.stop", function(event) {
            $timeout.cancel(scope.isPlaying);
          });
          scope.$on("plot.play", function(ev){
            if(plotSelection == ''){
              var
                 toPlay = ENA.graphs.unit.selections[0]
                ,matcher = /unit\.[^\.]*\.([\d]+)/
                ,currentId = parseInt(matcher.exec(toPlay.id)[1])
                ,nextNode
                ,playTimeout
              ;

              function playNext( nextToPlay ) {
                  console.log("Playing node:", nextToPlay);
                  nextNode = scope.sig.graph.nodes("unit."+toPlay.character+"."+(nextToPlay))
                  Shiny.onInputChange("unitClicked1", nextNode);
                  ENA.graphs.unit.selections = [nextNode];
                  Shiny.onInputChange("unitsClicked", { nodes: ENA.graphs.unit.selections, type: "def", nonce: Math.random() });

                  if(nextToPlay<=6) {
                    scope.isPlaying = $timeout(function(){
                      playNext(nextToPlay+1)
                    }, 2000);
                    scope.isPlaying.then(()=>console.log("Done."),()=>console.log("Cancelled."))
                  } else {
                    $timeout.cancel(scope.isPlaying);

                    scope.$emit("call.plot.stop");
                    Shiny.onInputChange("unitClicked1", toPlay);
                    ENA.graphs.unit.selections = [toPlay];
                    Shiny.onInputChange("unitsClicked", { nodes: ENA.graphs.unit.selections, type: "def", nonce: Math.random() });
                  }
              }
              playNext(currentId+1);
            }
          });
          scope.$on("plot.clear"+plotSelection, function(ev) {
            console.log("Clearing plot: ", plotSelection)
            var
               edgesToAnimate = []
              ,toAnimate = {
                  nodes: []
                 ,onComplete: function() {
                   this.nodes.forEach(n=>n.hidden=true);
                   scope.sig.graph.edges().forEach(e=>e.hidden=true);
                   scope.sig.refresh();
                 }
               }
              ,hideNodes = function() {
                scope.sig.graph.nodes()
                  .filter(n=>n.nodeType==="code")
                  .forEach(n=>{
                    if(n.nodeType==="code") {
                      n.tosize = 0;
                      n.tocolor = scope.sig.settings("backgroundColor");
                      toAnimate.nodes.push(n);
                    } else {
                      //n.originalx = n.x;
                      //n.originaly = n.y;
                      //n.tox = 0;
                      //n.toy = 0;
                      //toAnimate.nodes.push(n);
                    }
                  })
                ;
                animateNodes(toAnimate);
              }
            ;

            //scope.sig.graph.edges()
            scope.sig.graph.edges(scope.plotData["network"+plotSelection].edges.map(e=>e.id))
              .forEach(e=>{
                e.tosize = 0;
                e.tocolor = scope.sig.settings("backgroundColor");
                edgesToAnimate.push(e.id);
              })
            ;
            if(edgesToAnimate.length > 0) {
              sigma.plugins.animateEdges(
                scope.sig,
                {
                  edges: edgesToAnimate,
                  duration: 100
                },
                { size: 'tosize', color: 'tocolor'},
                function() {
                  console.log("Done with edges.");
                  hideNodes();
                }
              );
            } else {
              hideNodes();
            }

            if(
              //plotSelection===2 ||
              (plotSelection === 1 && ENA.graphs.unit.selections.length===0)
            ) {
              scope.$emit("call.plot.clear",'');
            }
          });
          scope.$on("plottable-show-nodes", function(event, ids) {
            var
               nodes = scope.sig.graph.nodes().filter(n=>ids.filter(i=>i===n["plottable.uuid"]).length>0)
              ,toAnimate = {
                nodes: [],
                onComplete: function(){
                  console.log("Unhide the nodes");
                }
              }
            ;
            nodes.forEach(n=>{
              n.tosize = n.originalsize || 1;
              n.tocolor = n.originalcolor || "#000000";
              n.tox = n.x;
              n.toy = n.y;
              n.hidden = false;
              toAnimate.nodes.push(n.id);
            });
            animateNodes(toAnimate);
          });
          scope.$on("plottable-hide-nodes", function(event, ids) {
            var
               nodes = scope.sig.graph.nodes().filter(n=>ids.filter(i=>i===n["plottable.uuid"]).length>0)
              ,toAnimate = {
                nodes: [],
                onComplete: function() {
                  nodes.map(n=>{n.hidden=true;})
                  scope.sig.refresh();
                }
              }
            ;
            nodes.forEach(n=>{
              n.originalsize = n.size;
              n.originalcolor = n.color;
              n.tosize = 0;
              n.tox = n.x;
              n.toy = n.y;
              n.tocolor = "#FFFFFF";
              toAnimate.nodes.push(n.id);
            });
            //$timeout(function() {
              animateNodes(toAnimate);
            //},1000)
          });
          scope.$on("plottable-remove-nodes", function(event, data){
            var
              parentNode = scope.sig.graph.nodes().filter(n=>n["node.uuid"]===data)
              ,toAnimate = {
                nodes: [ ],
                onComplete: function(){
                  this.nodes.forEach(n=>scope.sig.graph.dropNode(n));
                  scope.sig.refresh();
                }
              }
            ;
            scope.sig.graph.nodes().filter(nn=>nn["node.parent.uuid"]===data).forEach(n=>{
              n.tox = parentNode[0].x;
              n.toy = parentNode[0].y;
              n.tosize = n.size;
              n.tocolor = n.color;
              toAnimate.nodes.push(n.id);
            });

            animateNodes(toAnimate);
          });
          scope.$on("plottable-data-update", function(event,originalData,reset) {
            var
               hasParent
              ,data = angular.copy(originalData)
              ,toAnimate
              ,nodesToPlot = []
            ;
            if(reset === true) resetCamera(data.axisBounds);
            scope.$apply(()=>scope.hasNetwork = (data["network"+plotSelection].edges.length > 0));

            var
               curEdge
              ,toRemove
              ,existingEdges = []
              ,newEdges = []
              ,removeNodes = []
              ,_e, newEdge
            ;
            toAnimate = {
               nodes: []
              ,onComplete: function() {

                if(scope.plotNetworks) {
                  if(data["network"+plotSelection].nodes.length !== 0) {
                    toRemove = scope.sig.graph.edges()
                      .filter(el=>
                        data["network"+plotSelection].edges.map(e=>e.id).indexOf( el.id ) < 0
                      )
                    ;

                    if(toRemove.length > 0) {
                      toRemove.forEach(e=>{
                        e.originalsize = e.size;
                        e.tosize = 0;
                      });
                      sigma.plugins.animateEdges(scope.sig, { edges: toRemove, duration: 100 }, { size: 'tosize'});
                    }
                  } else {
                    removeNodes = scope.sig.graph.nodes()
                      .filter(n=>
                        n.nodeType === "code" && data["network"+plotSelection].nodes.map(e=>e.id).indexOf( n.id ) < 0
                      )
                      .map(n=>{
                        n.originalsize = n.size;
                        n.originalx = n.x;
                        n.originaly = n.y;
                        n.tox = 0;
                        n.toy = 0;
                        n.tosize = 0;
                        return n
                      })

                    if(removeNodes.length > 0) {
                      animateNodes({nodes: removeNodes})
                    }
                  }
                  /*
                  scope.sig.graph.nodes()
                    .filter(n=>n.nodeType==="code")
                    .map(e=>e.id)
                    .filter(el=>data["network"+plotSelection].nodes.map(e=>e.id).indexOf( el ) < 0)
                    .forEach(e=>scope.sig.graph.dropNode(e))
                  ;
                  */

                  newEdges = data["network"+plotSelection].edges
                    .filter(e=>!scope.sig.graph.edges(e.id))
                  ;
                  if(newEdges.length > 0) {
                    sigma.plugins.animateEdges(scope.sig, { edges: newEdges });
                  }

                  /*
                  data["network"+plotSelection].edges
                    .forEach(function(e,i) {
                      //_e = angular.copy(e);
                      //scope.sig.graph.addEdge(e);
                      newEdges.push(e);
                    });
                  _e = undefined;
                  */
                }
              }
            }

            if(scope.plotUnits)
              nodesToPlot = nodesToPlot.concat(data.nodes);
            if(scope.plotNetworks)
              nodesToPlot = nodesToPlot.concat(data["network"+plotSelection].nodes);

            existingEdges = scope.sig.graph.edges()
              .filter(el=>
                data["network"+plotSelection].edges.map(e=>e.id).indexOf( el.id ) >= 0
              )
            ;
            if(existingEdges.length > 0) {
              var existingEdges2 = existingEdges.map(e=>{
                newEdge = data["network"+plotSelection].edges.find(ee=>ee.id===e.id);
                e.originalsize = e.size;
                e.originalcolor = e.color;
                e.tosize = newEdge.size;
                e.tocolor = newEdge.color;
                e.hidden = false;
                return e;
              }).filter(e=>
                e !== undefined && e.tosize !== e.size // || e.tocolor !== e.color
              )
              sigma.plugins.animateEdges(scope.sig, { edges: existingEdges2 }, { size: 'tosize', color: 'tocolor' }, toAnimate.onComplete)
              scope.sig.refresh();
              //return;
            }

            nodesToPlot.forEach(function(n,i) {
              var
                 _g = scope.sig.graph
                ,hasParent = _g.nodes().filter(nn=>nn["node.uuid"]===n["node.parent.uuid"])
                ,curNode = _g.nodes(n.id)
                ,_n = angular.copy(n)
                ,n = curNode || n
                ,isNew = !curNode
              ;

              n.tox = _n.x;
              n.toy = _n.y;
              n.tocolor = _n.color; // n.character to lookup the color
              n.tosize = n.originalsize = _n.size;
              if(_n.nodeType === "code"){
                n.tosize = n.originalsize += 0.5;
              }
              n.hidden = false;
              if(curNode) {
                n.x = curNode.x
                n.y = curNode.y
              } else if(hasParent.length > 0) {
                n.x = hasParent[0].x;
                n.y = hasParent[0].y;
              } else {
                n.x = 0;
                n.y = 0;
              }
              toAnimate.nodes.push(n.id);

              if(isNew) scope.sig.graph.addNode(n)
              _n = undefined;
            });
            //scope.sig.refresh();
            animateNodes(toAnimate);
          });
        }
      }
    }])
  ;

})(window, jQuery, angular, Shiny);
