
var toc_states = from_location_hash();

/* save variable decoded into location hash */
function to_location_hash(data) {
    window.location.hash = '#'+toQueryString(data);
}

/* create variable from a decoded location hash */
function from_location_hash() {
    var data = new Object();
    if(window.location.hash != '#') {
        var hash = new String(window.location.hash);
        hash = hash.replace(/^#/, '');
        data = toQueryParams(hash);
    }
    return data;
}

function toggleToc(e) {
    var toc     = document.getElementById(e);
    var imgLink = document.getElementById('img-'+e);

    if (toc && toc.style.display == 'none') {
        toc.style.display = '';
        imgLink.src = img_src+'go-up.png';
    } else {
        toc.style.display = 'none';
        imgLink.src = img_src+'go-next.png';
    }
    toc_states[e] = toc.style.display;
    to_location_hash(toc_states);
    return false;
}

function set_initial_toc_states() {
    for(key in toc_states) {
        var elem = jQuery('#'+key)[0];
        if(elem) {
            elem.style.display = toc_states[key];
            if(toc_states[key] == '') {
                var imgLink = document.getElementById('img-'+key);
                imgLink.src = img_src+'go-up.png';
            }
        }
    };
}
