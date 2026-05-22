HTMLWidgets.widget({
  name: "qeviz",
  type: "output",

  factory: function(el, width, height) {
    // Inject the two qeviz custom elements into the widget container.
    // <qe-visual> is hidden — it holds model data and fires model-updated events.
    // <qe-graph>  is the visible SVG plot surface.
    el.innerHTML =
      '<qe-visual id="vis-' + el.id + '" style="display:none"></qe-visual>' +
      '<qe-graph  id="graph-' + el.id + '"' +
      '           style="width:' + width + 'px;height:' + height + 'px"' +
      '           for="vis-' + el.id + '"' +
      '           label-nodes="on"' +
      '           label-means="on"' +
      '           label-points="off">' +
      '</qe-graph>';

    var vis   = el.querySelector('qe-visual');
    var graph = el.querySelector('qe-graph');

    return {
      renderValue: function(x) {
        // Apply display attributes from R options before feeding data.
        // Unset options (null/undefined) are left as their HTML defaults.
        var opts = x.options || {};
        var set = function(attr, val) {
          if (val !== null && val !== undefined) graph.setAttribute(attr, String(val));
        };
        set('group',        opts.group);
        set('unit',         opts.unit);
        set('compare',      opts.compare);
        set('also',         opts.also);
        set('label-nodes',  opts.labelNodes);
        set('label-means',  opts.labelMeans);
        set('label-points', opts.labelPoints);
        // CI bounds are now carried in the groups frame — no 'confidence' attribute needed.
        // 'outlier' is still a deprecated separate frame; keep the escape-hatch.
        set('outlier',      opts.outlier);
        set('scale-points', opts.scalePoints);

        // Feed data to the <ena-visual> element.
        // This fires a model-updated CustomEvent which <ena-graph> listens for.
        vis.setModelData(x.model);
      },

      resize: function(width, height) {
        graph.style.width  = width  + 'px';
        graph.style.height = height + 'px';
      }
    };
  }
});
