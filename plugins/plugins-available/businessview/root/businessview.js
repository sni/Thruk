function toggleToc(e) {
    /*alert(e);*/
    var toc = document.getElementById(e);
    var toggleLink = document.getElementById('togglelink-'+e);
    var imgLink = document.getElementById('img-'+e);

    if (toc && toc.style.display == 'none') {
	toc.style.display = 'block';
	toggleLink.firstChild.nodeValue = 'Fold';
	imgLink.src = img_src+'go-up.png';
    } else {
	toc.style.display = 'none';
	toggleLink.firstChild.nodeValue = 'Expand';
	imgLink.src = img_src+'go-next.png';
    }

    
}


function Affiche(Texte) {
    alert(Texte);
}


function changeText(el, newText) {
    // Safari work around
    if (el.innerText)
        el.innerText = newText;
    else if (el.firstChild && el.firstChild.nodeValue)
        el.firstChild.nodeValue = newText;
}