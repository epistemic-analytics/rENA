;(function() {
  'use strict';

  sigma.utils.pkg('sigma.svg.edges');

  /**
   * The animated edge renderer. It animates the
   * rendering of the line.
   */
  sigma.svg.edges.animate = {
    /**
     * SVG Element creation.
     *
     * @param  {object}                   edge       The edge object.
     * @param  {object}                   source     The source node object.
     * @param  {object}                   target     The target node object.
     * @param  {configurable}             settings   The settings function.
     */
    create: function(edge, source, target, settings) {
      var color = edge.color,
          prefix = settings('prefix') || '',
          edgeColor = settings('edgeColor'),
          defaultNodeColor = settings('defaultNodeColor'),
          defaultEdgeColor = settings('defaultEdgeColor'),
          direction = settings('edgeAnimation') || 'outsideIn',
          line = document.createElementNS(settings('xmlns'), 'line'),
          line2, //Created below if necessary
          lineGroup = document.createElementNS(settings('xmlns'), 'g')
      ;

      lineGroup.setAttributeNS(null, "class", "sigma-group");

      if (!color) {
        switch (edgeColor) {
          case 'source':
            color = source.color || defaultNodeColor;
            break;
          case 'target':
            color = target.color || defaultNodeColor;
            break;
          default:
            color = defaultEdgeColor;
            break;
        }
        edge.color = color;
      }

      lineGroup.onclick = function() {
        var s = sigmaGraphs[settings("id")];
        settings('events').clickEdge.apply(s, [edge]) ;
      };
      //line.onmouseover = settings('onEdgeHover');

      // Attributes
      lineGroup.setAttributeNS(null, 'data-edge-id', edge.id);
      lineGroup.setAttributeNS(null, 'data-edge-source', ((source.size >= target.size)?source:target).id);
      lineGroup.setAttributeNS(null, 'data-edge-target', ((target.size <= source.size)?target:source).id);
      lineGroup.setAttributeNS(null, 'class', settings('classPrefix') + '-edge');
      line.setAttributeNS(null, 'data-edge-id', edge.id);
      line.setAttributeNS(null, 'data-edge-source', ((source.size >= target.size)?source:target).id);
      line.setAttributeNS(null, 'data-edge-target', ((target.size <= source.size)?target:source).id);
      line.setAttributeNS(null, 'stroke-width', edge.size);
      line.setAttributeNS(null, 'stroke', color);
      line.setAttributeNS(null, 'class', settings('classPrefix') + '-edge');

      var
         x1 = ((source.size >= target.size)?source:target)[prefix + 'x']
        ,x2 = ((target.size <= source.size)?target:source)[prefix + 'x']
        ,y1 = ((source.size >= target.size)?source:target)[prefix + 'y']
        ,y2 = ((target.size <= source.size)?target:source)[prefix + 'y']
        ,xM = (x1 + x2) / 2
        ,yM = (y1 + y2) / 2
      ;

      lineGroup.appendChild(line);
      if(direction === "outsideIn") {
        line2 =document.createElementNS(settings('xmlns'), 'line');
        line2.setAttributeNS(null, 'data-edge-id', edge.id);
        line2.setAttributeNS(null, 'data-edge-source', ((source.size >= target.size)?source:target)['id']);
        line2.setAttributeNS(null, 'data-edge-target', target.id);
        line2.setAttributeNS(null, 'class', settings('classPrefix') + '-edge');
        line2.setAttributeNS(null, 'stroke-width', edge.size);
        line2.setAttributeNS(null, 'stroke', color);

        line.setAttributeNS(null, 'x1', x1);
        line.setAttributeNS(null, 'y1', y1);
        line.setAttributeNS(null, 'x2', x1);
        line.setAttributeNS(null, 'y2', y1);
        line2.setAttributeNS(null, 'x1', x2);
        line2.setAttributeNS(null, 'y1', y2);
        line2.setAttributeNS(null, 'x2', x2);
        line2.setAttributeNS(null, 'y2', y2);
        line2.setAttributeNS(null, 'data-edge-clone', edge.id);
        lineGroup.appendChild(line2);
      } else if (direction === 'outward') {
        line.setAttributeNS(null, 'x1', x1);
        line.setAttributeNS(null, 'y1', y1);
        line.setAttributeNS(null, 'x1', x1);
        line.setAttributeNS(null, 'y1', y1);
      } else {
        line.setAttributeNS(null, 'x1', xM);
        line.setAttributeNS(null, 'y1', yM);
        line.setAttributeNS(null, 'x2', xM);
        line.setAttributeNS(null, 'y2', yM);
      }
      edge.p = 0;

      return lineGroup;
    },

    /**
     * SVG Element update.
     *
     * @param  {object}                   edge       The edge object.
     * @param  {DOMElement}               line       The line DOM Element.
     * @param  {object}                   source     The source node object.
     * @param  {object}                   target     The target node object.
     * @param  {configurable}             settings   The settings function.
     */
    update: function(edge, lineGroup, source, target, settings) {
      lineGroup.style.display = '';

      var
         prefix = settings('prefix') || ''
        ,direction = settings('edgeAnimation') || 'outsideIn'
        //,lines = lineGroup.getElementsByName("line")
        ,line = lineGroup.querySelector('line[data-edge-id="'+edge.id+'"]')
        ,line2= lineGroup.querySelector('line[data-edge-clone="'+edge.id+'"]')
        ,p = (edge.p <= 1) ? edge.p : 1
        ,x1 = ((source.size >= target.size)?source:target)[prefix + 'x']
        ,x2 = ((target.size <= source.size)?target:source)[prefix + 'x']
        ,y1 = ((source.size >= target.size)?source:target)[prefix + 'y']
        ,y2 = ((target.size <= source.size)?target:source)[prefix + 'y']
        ,xM = (x1 + x2) / 2
        ,yM = (y1 + y2) / 2
        ,x1a,x2a,y1a,y2a
        ,hide = !!edge.hiding
        ,ends = ( (x1a-x1!==0)||(y1a-y1!==0)||(x2a-x2!==0)||(y2a-y2!==0) )
        ,size = ((!hide) ? edge.size : parseFloat(line.getAttribute("stroke-width"))) * p
        ,drawn = !!lineGroup.getAttributeNS(null, 'drawn')
      ;
      if( drawn === null || drawn !== true) {
        if(direction==='outsideIn') {
          x1a  = x1 + ((xM - x1) * p);
          y1a  = y1 + ((yM - y1) * p);
          x2a  = x2 + ((xM - x2) * p);
          y2a  = y2 + ((yM - y2) * p);

          line.setAttributeNS(null, 'x2', x1a);
          line.setAttributeNS(null, 'y2', y1a);
          line2.setAttributeNS(null, 'x2', x2a);
          line2.setAttributeNS(null, 'y2', y2a);
        } else if (direction === 'outward') {
          x1a  = x1 + ((x2 - x1) * p);
          y1a  = y1 + ((y2 - y1) * p);

          line.setAttributeNS(null, 'x2', x1a);
          line.setAttributeNS(null, 'y2', y1a);
        } else {
          x1a  = xM - ((xM - x1) * p);
          x2a  = xM - ((xM - x2) * p);
          y1a  = yM - ((yM - y1) * p);
          y2a  = yM - ((yM - y2) * p);

          line.setAttributeNS(null, 'x1', x1a);
          line.setAttributeNS(null, 'y1', y1a);
          line.setAttributeNS(null, 'x2', x2a);
          line.setAttributeNS(null, 'y2', y2a);
        }
      } else if ((drawn === true || drawn === "true") && p === 1){
        /*
        */
        if(direction==='outsideIn') {
          line.setAttributeNS(null, 'x1', x1);
          line.setAttributeNS(null, 'y1', y1);
          line.setAttributeNS(null, 'x2', xM);
          line.setAttributeNS(null, 'y2', yM);
          line2.setAttributeNS(null, 'x1', x2);
          line2.setAttributeNS(null, 'y1', y2);
          line2.setAttributeNS(null, 'x2', xM);
          line2.setAttributeNS(null, 'y2', yM);
        } else if (direction === 'outward') {
          line.setAttributeNS(null, 'x1', x1);
          line.setAttributeNS(null, 'y1', y1);
          line.setAttributeNS(null, 'x2', x2);
          line.setAttributeNS(null, 'y2', y2);
        } else {
          line.setAttributeNS(null, 'x1', x1);
          line.setAttributeNS(null, 'y1', y1);
          line.setAttributeNS(null, 'x2', x2);
          line.setAttributeNS(null, 'y2', y2);
        }
      }

      line.setAttributeNS(null, 'stroke-width', edge.size);
      line.setAttributeNS(null, 'stroke', edge.color);
      if(line2) {
        line2.setAttributeNS(null, 'stroke', edge.color);
        line2.setAttributeNS(null, 'stroke-width', edge.size);
      }

      if( drawn === false && ((p === 0 && hide) || (p >= 1 && !hide)) ) {
        lineGroup.setAttributeNS(null, 'drawn', true);
        edge.drawn = true;
      }
      /*
      else {
        lineGroup.setAttributeNS(null, 'drawn', false);
        edge.drawn = false;
      }
      */
      return this;
    }
  };
})();
