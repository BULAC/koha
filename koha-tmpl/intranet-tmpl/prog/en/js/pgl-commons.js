// PROGILONE - june 2010 : common javascript functions
function paramOfUrl( url, param ) {
    param = param.replace(/[\[]/,"\\\[").replace(/[\]]/,"\\\]");
    var regexS = "[\\?&]"+param+"=([^&#]*)";
    var regex = new RegExp( regexS );
    var results = regex.exec( url );
    if( results == null ) {
        return "";
    } else {        
        return results[1];
    }
}

function getContextSearchHref() {
	var shref = $.session("context_searchhref");
	if ("#" == shref) {
		shref = "";
	}
	return shref;
}

function setContextSearchHref(shref) {
	$.session("context_searchhref", shref);
}

function getContextBiblioNumbers() {
	return $.session("context_bibnums");
}

function setContextBiblioNumbers(bibnums) {
	$.session("context_bibnums", bibnums);
}

function resetSearchContext() {
	$.session("context_bibnums", []);
	$.session("context_searchhref", "#");
}

$(document).ready(function(){
	// forms with action leading to search
	$("form[action*=catalogue\/search\.pl]").submit(function(){
		resetSearchContext();
	});
	// any link to search but those with class=searchwithcontext
    $("[href*=catalogue\/search\.pl?]").not(".searchwithcontext").click(function(){
    	resetSearchContext();
    });
});
