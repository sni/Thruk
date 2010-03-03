window.addEvent('domready', function(){
	// Links
	var list = $$('div#menu ul li a');
	list.each(function(element) {
		var fx = new Fx.Styles(element, {'duration': 300, 'wait': false});
		var fxparent = new Fx.Styles(element.getParent(), {'duration': 300, 'wait': false});
		element.mouseouted = true;
		element.addEvent('mouseenter', function(){
			fx.stop();
			element.setStyle('color','#000');
			fxparent.stop();
			element.getParent().setStyle('padding-left', '20px');
		});
		element.addEvent('mouseleave', function(){
			fx.start({
				'color': '#6e7475'
			});
			fxparent.start({
				'padding-left': '10px'
			});
		});
	});
});
