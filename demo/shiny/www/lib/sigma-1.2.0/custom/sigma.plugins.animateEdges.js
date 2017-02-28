/**
 * This plugin provides a method to animate a sigma instance by interpolating
 * some node properties. Check the sigma.plugins.animate function doc or the
 * examples/animate.html code sample to know more.
 */
(function() {
  'use strict';

  if (typeof sigma === 'undefined')
    throw 'sigma is not declared';

  sigma.utils.pkg('sigma.plugins');

  var
     _id = 0
    ,easing = sigma.utils.easings.quadraticInOut
    ,_cache = {}
    ,durationDefault = 500
  ;

  /**
   * This function will animate some specified node properties. It will
   * basically call requestAnimationFrame, interpolate the values and call the
   * refresh method during a specified duration.
   *
   * Recognized parameters:
   * **********************
   * Here is the exhaustive list of every accepted parameters in the settings
   * object:
   *
   *   {?array}             edges      An array of node objects or node ids. If
   *                                   not specified, all edges of the graph
   *                                   will be animated.
   *   {?(function|string)} easing     Either the name of an easing in the
   *                                   sigma.utils.easings package or a
   *                                   function. If not specified, the
   *                                   quadraticInOut easing from this package
   *                                   will be used instead.
   *   {?number}            duration   The duration of the animation. If not
   *                                   specified, the "animationsTime" setting
   *                                   value of the sigma instance will be used
   *                                   instead.
   *   {?function}          onComplete Eventually a function to call when the
   *                                   animation is ended.
   *
   * @param  {sigma}   s       The related sigma instance.
   * @param  {?object} options Eventually an object with options.
   */
  sigma.plugins.animateEdges = function(s, options, animate, callback) {
    var o = options || {},
        id,
        duration = o.duration || s.settings('animationsTime'),
        easing = (typeof o.easing === 'string') ?
          sigma.utils.easings[o.easing] :
          (typeof o.easing === 'function') ? o.easing : sigma.utils.easings.quadraticInOut,
        start = sigma.utils.dateNow(),
        edges,
        k, c, line
        ,edgeCount = 0, drawEdges
        ,curX1, curY1, curX2, curY2, curSize
        ,toX1, toY1, toX2, toY2, toSize
        ,newX1, newX2, newY1, newY2, newSize
        ,source, target
        ,edgeLine, edge
    ;

    //** Find the edges to animate
      if (o.edges && o.edges.length) {
        if (typeof o.edges[0] === 'object')
          edges = o.edges;
        else {
          edges = s.graph.edges(o.edges).filter(e=>e); // argument is an array of IDs
          if(!edges.length) return;
        }
      } else {
        edges = s.graph.edges();
      }
      drawEdges = edges.slice([]);
    //** END: Find the edges


    s.animations = s.animations || Object.create({});
    //sigma.plugins.kill(s);

    //** Do not refresh edgequadtree during drag:
    for (k in s.cameras) {
      c = s.cameras[k];
      c.edgequadtree._enabled = false;
    }

    //** Main step function that is called intermittently
    function step(timestamp) {
      var
         curEdge = s.graph.edges(edge.id)
        ,p = (sigma.utils.dateNow() - start) / duration
        ,k ,c
        ,renderer
      ;

      if (p >= 1) {
        curEdge.p = (edge.hiding) ? 0: 1;
        if( typeof animate !== "undefined" ) {
          var newColor;
          Object.keys(animate).forEach(a=>{
            if(a==="color") {
              if(curEdge[animate[a]])
                newColor = curEdge[animate[a]];
              else
                newColor = curEdge[a];
            } else {
              newColor = curEdge[animate[a]];
            }
            curEdge[a] = newColor;
          });
        }
        for (k in s.cameras) {
          c = s.cameras[k];
          c.edgequadtree._enabled = true;
        }
        s.refresh();

        edge = drawEdges.shift();;
        if(edge) {
          edge.p = 0;
          start = sigma.utils.dateNow();
          step();
        } else {
          if (typeof o.onComplete === 'function') {
            o.onComplete();
          }
          callback && callback()
        }
      } else {
        p = easing(p);

        if(
          (edge.hiding && curEdge.p > 0) ||
          (!edge.hiding && curEdge.p < 1)
        ) {
          curEdge.p = ((edge.hiding) ? 1 - p : p);

          if( typeof animate !== "undefined" ) {
            var newColor;
            Object.keys(animate).forEach(a=>{
              if(a==="color") {
                if(curEdge[animate[a]])
                  newColor = interpolateColors(curEdge[a], curEdge[animate[a]], p);
                else
                  newColor = curEdge[a];
              } else {
                newColor = (edge[animate[a]] * p) + (curEdge["original"+a] * (1 - p));
              }
              if(curEdge[a] !== newColor) curEdge[a] = newColor;
            });
          }
          s.refresh();
          s.animations[id] = requestAnimationFrame(step);
        /*
        } else if (
          typeof animate !== "undfined" &&
          !Object.keys(animate).map(k=>curEdge[k]===curEdge[animate[k]]).every(e=>e)
        ) {
          console.log("Animation now")
          curEdge.p = ((edge.hiding) ? 1 - p : p);

          s.refresh();
          s.animations[id] = requestAnimationFrame(step);
        */
        } else if ( edge.size !== curEdge.size ) {
          if(curEdge.size < edge.size) {
            curEdge.size += (edge.size - curEdge.size) * p;
          } else {
            curEdge.size = curEdge.size - (curEdge.size * p);
          }

          s.refresh();
          s.animations[id] = requestAnimationFrame(step);
        } else {
          edge = drawEdges.shift();;
          if(edge) {
            edge.p = 0;
            start = sigma.utils.dateNow();
            step();
          }
        }

        s.refresh();
      }
    }

    /**
     * If there edges, verify they exist in the graph
     * and then call step() on the first edge
     */
    if(edges.length > 0) {
      edges.forEach(ee => {
        //** If the edge doesn't exist, add it here
        //** --> FIXME this shouldn't be necessary
        if(!s.graph.edges().map(e => { return e.id }).some(f => { return ee.id === f })) {
          ee.p = 0;
          ee.hiding = !!ee.hiding;

          s.graph.addEdge({
            id: ee.id, label: ee.id,
            source: s.graph.nodes().find(n => n.id == ee.source).id,
            target: s.graph.nodes().find(n => n.id == ee.target).id,
            size: ee.size,
            color: ee.color,
            type: "animate",
            p: ee.p,
            hiding: ee.hiding
          });
          s.refresh();
        }
      });

      edge = drawEdges.shift();
      edge.p = 0;
      step();
    }
  };

  sigma.plugins.kill = function(s) {
    for (var k in (s.animations || {})) {
      cancelAnimationFrame(s.animations[k]);
      delete s.animations[k];
    }

    // Allow to refresh edgequadtree:
    var k, c;
    for (k in s.cameras) {
      c = s.cameras[k];
      c.edgequadtree._enabled = true;
    }
  };


  // TOOLING FUNCTIONS:
  // ******************
  function parseColor(val) {
    if (_cache[val])
      return _cache[val];

    var result = [0, 0, 0];

    if (val.match(/^#/)) {
      val = (val || '').replace(/^#/, '');
      result = (val.length === 3) ?
        [
          parseInt(val.charAt(0) + val.charAt(0), 16),
          parseInt(val.charAt(1) + val.charAt(1), 16),
          parseInt(val.charAt(2) + val.charAt(2), 16)
        ] :
        [
          parseInt(val.charAt(0) + val.charAt(1), 16),
          parseInt(val.charAt(2) + val.charAt(3), 16),
          parseInt(val.charAt(4) + val.charAt(5), 16)
        ];
    } else if (val.match(/^ *rgba? *\(/)) {
      val = val.match(
        /^ *rgba? *\( *([0-9]*) *, *([0-9]*) *, *([0-9]*) *(,.*)?\) *$/
      );
      result = [
        +val[1],
        +val[2],
        +val[3]
      ];
    }

    _cache[val] = {
      r: result[0],
      g: result[1],
      b: result[2]
    };

    return _cache[val];
  }
  function interpolateColors(c1, c2, p) {
    c1 = parseColor(c1);
    c2 = parseColor(c2);

    var c = {
      r: c1.r * (1 - p) + c2.r * p,
      g: c1.g * (1 - p) + c2.g * p,
      b: c1.b * (1 - p) + c2.b * p
    };

    return 'rgb(' + [c.r | 0, c.g | 0, c.b | 0].join(',') + ')';
  }
}).call(window);
