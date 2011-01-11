function toggleToc(e) {
    /*alert(e);*/
    var toc = document.getElementById(e);
    var imgLink = document.getElementById('img-'+e);

    if (toc && toc.style.display == 'none') {
	toc.style.display = 'block';
	imgLink.src = img_src+'go-up.png';
    } else {
	toc.style.display = 'none';
	imgLink.src = img_src+'go-next.png';
    }

    
}


