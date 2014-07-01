<!-- PROGILONE - april 2010 - F21 -->
<script type="text/javascript" language="javascript">
// show branch details tooltip
function showBranchDetails(brname){
    var $brdetails = $(brname).next(".branchdetails");
    // absolute position	
    var position = $(brname).offset();
	var top = position.top + $(brname).outerHeight();
	$brdetails.css("position","absolute").css("top",top);
	$brdetails.css("position","absolute").css("left",position.left);
    // show	
    $brdetails.fadeIn("fast");
}

// hide branch details tooltip
function hideBranchDetails(brname) {
    $(brname).next(".branchdetails").fadeOut("slow");
}
// End PROGILONE
</script>
