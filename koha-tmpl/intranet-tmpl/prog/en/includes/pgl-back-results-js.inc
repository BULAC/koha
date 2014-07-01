<!-- PROGILONE - june 2010 - C1 -->
<script type="text/javascript" language="javascript">
$("#backtoresults").ready(function() {
	var currsearch = getContextSearchHref();
	if(currsearch) {
		$("#backtoresults a").attr("href", currsearch);
		$("#backtoresults").show();
	}
});
</script>
<!-- End PROGILONE -->

