window.addEvent('domready', function(){
	// Categories
	var heads = $$('h2');
	var accordions = $$('ul');
	var spans = new Array();
	var collapsibles = new Array();
	heads.each( function(head, i) {
		var headimg = new Element('img');
		headimg.setProperty('src', 'images/interface/menu_less.gif');
		headimg.injectInside(heads[i]);
		heads[i].setStyles('cursor: pointer;');
		var collapsible = new Fx.Slide(accordions[i], {
			duration: 500,
			transition: Fx.Transitions.quadIn
		});
		collapsibles[i] = collapsible;
		head.onclick = function() {
			var img = $E('img', head);
			if (img) {
				var newHTML = img.getProperty('src') == 'images/interface/menu_more.gif' ? 'images/interface/menu_less.gif' : 'images/interface/menu_more.gif';
				img.setProperty('src', newHTML);
			}
			collapsible.toggle();
	                return false;
		}
	});
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