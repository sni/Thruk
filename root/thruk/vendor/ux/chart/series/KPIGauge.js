// based on https://www.sencha.com/forum/showthread.php?159879-KPI-Gauge
Ext.define('Ext.ux.chart.series.KPIGauge', {
    extend: 'Ext.chart.series.Gauge',
    alias: 'series.kpigauge',
    type: 'kpigauge',
    drawSeries: function () {
        var me = this,
            chart = me.chart,
            store = chart.getChartStore(),
            group = me.group,
            animate = me.chart.animate,
            axis = me.chart.axes.get(0),
            minimum = axis && axis.minimum || me.minimum || 0,
            maximum = axis && axis.maximum || me.maximum || 0,
            ranges = me.ranges || [],
            lines = me.lines || [],
            field = me.angleField || me.field || me.xField,
            surface = chart.surface,
            chartBBox = chart.chartBBox,
            rad = me.rad,
            donut = +me.donut,
            values = {},
            items = [],
            seriesStyle = me.seriesStyle,
            seriesLabelStyle = me.seriesLabelStyle,
            cos = Math.cos,
            sin = Math.sin,
            rendererAttributes, centerX, centerY, slice, slices, sprite, value,
            item, ln, record, i, j, r, slice, splitAngle, rl, startAngle, endAngle, middleAngle, sliceLength, path,
            p, spriteOptions, bbox, valueAngle, pivotRadius, tempValue = 0;


        Ext.apply(seriesStyle, me.style || {});


        me.setBBox();
        bbox = me.bbox;


        //if not store or store is empty then there's nothing to draw
        if (!store || !store.getCount() || me.seriesIsHidden) {
            me.hide();
            me.items = [];
            return;
        }

        centerX = me.centerX = chartBBox.x + (chartBBox.width / 2);
        centerY = me.centerY = chartBBox.y + chartBBox.height;
        me.radius = Math.min(centerX - chartBBox.x, centerY - chartBBox.y);
        me.slices = slices = [];
        me.items = items = [];
        me.line_slices = line_slices = [];
        if(me.line_items == undefined) { me.line_items = []; }

        if (!me.value) {
            record = store.getAt(0);
            me.value = record.get(field);
        }

        value = me.value;
        // added by Irfan Maulana for temporary value
        tempValue = value;
        // added by Irfan maulana for set to maximum value when value > maximum value
        if(value > maximum){
            value = maximum;
        }

        for (r = 0, rl = ranges.length; r < rl; r++) {
            var from = ranges[r].from;
            if(from < minimum) { from = minimum; }
            if(from > maximum) { continue; }
            var to   = ranges[r].to;
            if(to < minimum) { continue; }
            if(to > maximum) { to = maximum; }
            splitFromAngle = -180 * (1 - (from - minimum) / (maximum - minimum));
            splitToAngle = -180 * (1 - (to - minimum) / (maximum - minimum));
            if(splitToAngle == splitFromAngle) { splitToAngle = splitToAngle- 2;}
            slices.push ({
                startAngle: splitFromAngle,
                endAngle: splitToAngle,
                rho: me.radius,
                color: ranges[r].color
            });
        }

        for (x = 0, ll = lines.length; x < ll; x++) {
            lineAngle = (-180 * (1 - (lines[x].value - minimum) / (maximum - minimum))) * Math.PI / 180;
            line_slices.push ({
                lineAngle: lineAngle,
                width: lines[x].width || 2,
                color: lines[x].color || '#222'
            });
        }

        //do pie slices after.
        for (i = 0, ln = slices.length; i < ln; i++) {
            slice = slices[i];
            sprite = group.getAt(i);
            //set pie slice properties
            rendererAttributes = Ext.apply({
                segment: {
                    startAngle: slice.startAngle,
                    endAngle: slice.endAngle,
                    margin: 0,
                    rho: slice.rho,
                    startRho: slice.rho * +donut / 100,
                    endRho: slice.rho
                }
            }, Ext.apply(seriesStyle, { fill: slice.color}));


            item = Ext.apply({},
            rendererAttributes.segment, {
                slice: slice,
                series: me,
                storeItem: record,
                index: i
            });
            items[i] = item;
            // Create a new sprite if needed (no height)
            if (!sprite) {
                spriteOptions = Ext.apply({
                    type: "path",
                    group: group
                }, Ext.apply(seriesStyle, { fill: slice.color }));
                sprite = surface.add(Ext.apply(spriteOptions, rendererAttributes));
                if(me.needleSprite) { me.needleSprite.destroy(); delete me.needleSprite; }
            }
            slice.sprite = slice.sprite || [];
            item.sprite = sprite;
            slice.sprite.push(sprite);
            if (animate) {
                rendererAttributes = me.renderer(sprite, record, rendererAttributes, i, store);
                sprite._to = rendererAttributes;
                me.onAnimate(sprite, {
                    to: rendererAttributes
                });
            } else {
                rendererAttributes = me.renderer(sprite, record, Ext.apply(rendererAttributes, {
                    hidden: false
                }), i, store);
                sprite.setAttributes(rendererAttributes, true);
            }
        }

        //render lines annotations
        for (i = 0, ln = me.line_items.length; i < ln; i++) {
            me.line_items[i].destroy();
        }
        me.line_items = [];
        for (i = 0, ln = line_slices.length; i < ln; i++) {
            line = line_slices[i];
            rendererAttributes = {
                type: "path",
                path: [
                    'M', centerX + (me.radius*(donut/100) * cos(line.lineAngle)),
                        centerY + -Math.abs((me.radius*(donut/100)) * sin(line.lineAngle)),
                    'L', centerX + me.radius * cos(line.lineAngle),
                        centerY + -Math.abs(me.radius * sin(line.lineAngle))
                ],
                'stroke-width': line.width,
                'stroke': line.color
            };
            sprite = surface.add(Ext.apply(rendererAttributes));
            me.line_items.push(sprite);
            if(me.needleSprite) { me.needleSprite.destroy(); delete me.needleSprite; }
            sprite.setAttributes({
                hidden: false
            }, true);
        }

        if (me.needle && value != undefined) {
            valueAngle = (-180 * (1 - (value - minimum) / (maximum - minimum))) * Math.PI / 180;
            pivotRadius = me.needle.pivotRadius || 7;
            if (!me.needleSprite) {
                if (!me.needlePivotSprite) {
                    me.needlePivotSprite = me.chart.surface.add({
                        type: 'circle',
                        fill: me.needle.pivotFill || '#222',
                        radius: pivotRadius,
                        x: centerX,
                        y: centerY
                    });
                }
                me.needleSprite = me.chart.surface.add({
                    type: 'path',
                    path: [
                        'M', centerX + (me.radius * 0 / 100) * cos(valueAngle),
                            centerY + -Math.abs((me.radius * 0 / 100) * sin(valueAngle)),
                        'L', centerX + me.radius * cos(valueAngle),
                            centerY + -Math.abs(me.radius * sin(valueAngle))
                    ],
                    'stroke-width': me.needle.width || 2,
                    'stroke': me.needle.pivotFill || '#222'
                });
            } else {
                if (animate) {
                    me.onAnimate(me.needlePivotSprite, {
                        to: {
                            x: centerX,
                            y: centerY
                        }
                    });
                    me.onAnimate(me.needleSprite, {
                        to: {
                            path: [
                                'M', centerX + (me.radius * 0 / 100) * cos(valueAngle),
                                    centerY + -Math.abs((me.radius * 0 / 100) * sin(valueAngle)),
                               'L', centerX + me.radius * cos(valueAngle),
                                    centerY + -Math.abs(me.radius * sin(valueAngle))
                            ]
                        }
                    });
                } else {
                    me.needlePivotSprite.setAttributes({
                        type: 'circle',
                        fill: me.needle.pivotFill || '#222',
                        radius: me.needle.pivotRadius || 7,
                        x: centerX,
                        y: centerY
                    });
                    me.needleSprite.setAttributes({
                        type: 'path',
                        path: ['M', centerX + (me.radius * 0 / 100) * cos(valueAngle),
                                    centerY + -Math.abs((me.radius * 0 / 100) * sin(valueAngle)),
                               'L', centerX + me.radius * cos(valueAngle),
                                    centerY + -Math.abs(me.radius * sin(valueAngle))]
                    });
                }
            }
            me.needlePivotSprite.setAttributes({
                hidden: false
            }, true);
            me.needleSprite.setAttributes({
                hidden: false
            }, true);
        }
    }
});
