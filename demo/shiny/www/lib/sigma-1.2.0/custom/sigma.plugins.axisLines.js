//sigma.plugins.axisLines.js

;(function(undefined) {
  'use strict';

  if (typeof sigma === 'undefined')
    throw new Error('sigma is not declared');

  // Initialize package:
  sigma.utils.pkg('sigma.layout.axisLines');
  
  
  /**
   * Interface
   * ----------
   */
  sigma.prototype.addAxisLines = function(config) {
    var 
       _s = this
      ,r  = _s.renderers[0]
      ,g  = r.settings().domElements.graph
      ,c  = _s.cameras[0]
      ,rec= g.getClientRects()[0]
      ,ns = g.getAttribute("xmlns")
      ,pfx= r.options.prefix
      ,xAxis
      ,yAxis
      ,gAxis
    ;
    
    if(!g.getElementById("sigma-group-axes")){
      xAxis = document.createElementNS(ns,"line")
      yAxis = document.createElementNS(ns,"line")
      gAxis = document.createElementNS(ns,"g")
      
      gAxis.setAttribute("id", "sigma-group-axes");
      gAxis.setAttribute("class", "sigma-group");
        xAxis.setAttribute("stroke-width","1");
        xAxis.setAttribute("stroke",config.color || "#CCCCCC");
        xAxis.setAttribute("class","sigma-axis");
        gAxis.appendChild(xAxis);
        
        yAxis.setAttribute("stroke-width","1");
        yAxis.setAttribute("stroke",config.color || "#CCCCCC");
        yAxis.setAttribute("class","sigma-axis");
        gAxis.appendChild(yAxis);
      g.insertBefore(gAxis, g.getElementsByTagName("g")[0]);
    } else {
      gAxis = g.getElementById("sigma-group-axes");
      xAxis = g.getElementsByTagName("line")[0];
      yAxis = g.getElementsByTagName("line")[1];
    }
    /*
    var axisNodes = [{
      x: config[0],
      y: config[0]
    }];
    var bk = this.settings("scalingMode")
    var bkIg = this.settings("rescaleIgnoreSize")
    //this.settings("scalingMode", "outside")
    this.settings("rescaleIgnoreSize", true)
    sigma.middlewares.rescale.call(
      { 
        settings: this.settings, 
        graph: { 
          nodes:()=>axisNodes,
          edges:()=>[]
        }
      },
      '',
      c.readPrefix,
      {
        width: g.getClientRects()[0].width,
        height: g.getClientRects()[0].height
      }
    );
    this.settings("scalingMode", bk)
    this.settings("rescaleIgnoreSize", bkIg)
    this.camera.applyView(
      c.readPrefix,
      r.options.prefix,
      {
        nodes: axisNodes,
        edges: [],
        width: g.getClientRects()[0].width,
        height: g.getClientRects()[0].height
      }
    );
    console.log(axisNodes);
    */
    _s.renderers[0].bind("render", function() { 
      var rec = g.getClientRects()[0];
      xAxis.setAttribute("x1",0);
      xAxis.setAttribute("y1",rec.height/2);
      xAxis.setAttribute("x2",rec.width);
      xAxis.setAttribute("y2",rec.height/2);
      
      yAxis.setAttribute("x1",rec.width/2);
      yAxis.setAttribute("y1",0);
      yAxis.setAttribute("x2",rec.width/2);
      yAxis.setAttribute("y2",rec.height);
    });
  };
  
}).call(this);