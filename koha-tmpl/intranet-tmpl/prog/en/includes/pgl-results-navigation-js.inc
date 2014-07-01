<!-- PROGILONE - june 2010 - C1 -->
<script type="text/javascript" language="javascript">
$("#resultsnavigation").ready(function() { 
	var bibnums = getContextBiblioNumbers();
	if (bibnums) {
	    // current biblio number from URL
	    var currbibnum = paramOfUrl(location.href, "biblionumber");
	    var currbibnumindex = -1;
	    var pages = "";
	    for (var i=0; i < bibnums.length; i++) {
	        var bibnum = bibnums[i];
	        var pagenum = i + 1;
	        if (bibnum == currbibnum) {
		        // current page
	            pages += " <span class=\"current\">" + pagenum + "</span>";
	            currbibnumindex = i;
	        } else {
		        // other pages
	            pages += " <a class=\"nav\" href=\"" + location.pathname + "?biblionumber=" + bibnum + "\" >" + pagenum + "</a>";
	        }
	    }
	    if (currbibnumindex != -1) {
            // previous pages
	        if (currbibnumindex > 0 ) {
                var prevhref = location.pathname + "?biblionumber=" + bibnums[currbibnumindex - 1];
                $("#navprev").attr("href", prevhref);
                $("#navprev").show();
            } else {
            	$("#navprev").hide();
	        } 
            // next page
	        if (currbibnumindex < (bibnums.length - 1) ) {
                var nexthref = location.pathname + "?biblionumber=" + bibnums[currbibnumindex + 1]
                $("#navnext").attr("href", nexthref);
                $("#navnext").show();
            } else {
            	$("#navnext").hide();
	        } 
            // other 
            $("#navprev").after(pages);
	    }
	}
});
</script>
<!-- End PROGILONE -->