
var toc_states = from_location_hash();

function toggleToc(e) {
    var toc = document.getElementById(e);
    var imgLink = document.getElementById('img-'+e);

    if (toc && toc.style.display == 'none') {
        toc.style.display = '';
        imgLink.src = img_src+'go-up.png';
    } else {
        toc.style.display = 'none';
        imgLink.src = img_src+'go-next.png';
    }
    toc_states.set(e, toc.style.display);
    to_location_hash(toc_states);
    return false;
}

function set_initial_toc_states() {
    toc_states.each(function(pair) {
        var elem = $(pair.key);
        if(elem) {
            elem.style.display = pair.value;
            if(pair.value == '') {
                var imgLink = document.getElementById('img-'+pair.key);
                imgLink.src = img_src+'go-up.png';
            }
        }
    });
}
