function toggleToc(e) {
    alert(e);
    var toc = document.getElementById('toc').getElementsByTagName('ul')[0];
    /*var toggleLink = document.getElementById('togglelink')*/

	if (toc && toc.style.display == 'none') {
	    toc.style.display = 'block';
	} else {
	    toc.style.display = 'none';
	}
}


function Affiche(Texte) {
    alert(Texte);
}
