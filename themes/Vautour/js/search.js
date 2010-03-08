window.addEvent('domready', function(){
	// Search
	var srch = $('search');
	srch.setProperty('value', 'Search ...');	
	srch.addEvents({
		'focus': function() { srch.value = (srch.value == 'Search ...' ? '' : srch.value); },
		'blur': function()  { srch.value = (srch.value == '' ? 'Search ...' : srch.value); }
	});
});