<!-- PROGILONE - 06/05/10 -->
<script type="text/JavaScript" language="JavaScript">
 
var arrOldValues;
 

// Deselect all items 
function DeselectAllList(CONTROL){
	for(var i = 0;i < CONTROL.length;i++){
	CONTROL.options[i].selected = false;
	}
}

//Add new items which are selected 
function FillListValues(CONTROL){
	var arrNewValues;
	var intNewPos;
	var strTemp = GetSelectValues(CONTROL);
	arrNewValues = strTemp.split(",");
		for(var i=0;i<arrNewValues.length-1;i++){
		if(arrNewValues[i]==1){
		intNewPos = i;
		}
	}
 	
 	//Test if "All" is selected
 	if (intNewPos == 0){
 		DeselectAllList(CONTROL);
 		CONTROL.options[0].selected= true;
  	}
  	
  	else {
 		for(var i=0;i<arrOldValues.length-1;i++){
			if(arrOldValues[i]==1 && i != intNewPos){
			CONTROL.options[i].selected= true;
			}
			else if(arrOldValues[i]==0 && i != intNewPos){
			CONTROL.options[i].selected = false;
			}
	 
			if(arrOldValues[intNewPos]== 1){
			CONTROL.options[intNewPos].selected = false;
			}
			else{
			CONTROL.options[intNewPos].selected = true;
			}
		//Deselected "All" if another item is selected	
		CONTROL.options[0].selected= false;
		}
	}
}
 
//Get the current values selected 
function GetSelectValues(CONTROL){
	var strTemp = "";
		for(var i = 0;i < CONTROL.length;i++){
			if(CONTROL.options[i].selected == true){
			strTemp += "1,";
			}
			else{
			strTemp += "0,";
			}
		}
	return strTemp;
	} 

//Get the current list 
function GetCurrentListValues(CONTROL){
	var strValues = "";
	strValues = GetSelectValues(CONTROL);
	arrOldValues = strValues.split(",")
}
</script> 
<!-- PROGILONE - 06/05/10 -->
    
    <fieldset>
    <legend>Coded Fields</legend>
    <p>
    <label>Audience</label>
    <select name="limit" class="subtype">
            <option value="" SELECTED="selected" >Any</option>
      <option value="aud:a">juvenile, general</option>
      <option value="aud:b">pre-primary (0-5)</option>
      <option value="aud:c">Primary (5-8)</option>
      <option value="aud:d">children (9-14)</option>
      <option value="aud:e">Young Adult</option>
      <option value="aud:k">Adult, serious</option>
      <option value="aud:m">Adult, General</option>
      <option value="aud:u">Unknown</option>
    </select>
    </p>
    <p>
    <label>Print</label>
        <select name="limit" class="subtype">
      <option value="" selected="selected" >any</option>
        <option value="Material-type:r">regular print</option>
        <option value="Material-type:d">large print</option>
        <option value="Material-type:e">newspaper format</option>
        <option value="Material-type:f">Braille or Moon script</option>
        <option value="Material-type:g">microprint</option>
        <option value="Material-type:h">hand-written</option>
        <option value="Material-type:i">multimedia</option>
        <option value="Material-type:j">mini-print</option>
        <option value="Material-type:z">other form of textual material</option>
    </select>
    </p>
    <p>
    <!-- PROGILONE - 06/05/10 -->
	<!-- [F7]- Select multiple items listbox -->
    <label>Feschrift Ind.</label>
    <select name="limit" class="subtype" multiple="multiple" size="5" onMouseDown="GetCurrentListValues(this);" onchange="FillListValues(this);">
      <option value="" selected="selected" >Any</option>
            <option value="Literature-Code:a">fiction</option>
            <option value="Literature-Code:b">drama</option>
            <option value="Literature-Code:c">essays</option>
            <option value="Literature-Code:d">humour, satire</option>
            <option value="Literature-Code:e">letters</option>
            <option value="Literature-Code:f">short stories</option>
            <option value="Literature-Code:g">poetry</option>
            <option value="Literature-Code:h">speeches, oratory</option>
            <option value="Literature-Code:y">not a literary text</option>
            <option value="Literature-Code:z">multiple/other lit. forms</option>
    </select>
    </p>
        <p>
    <!-- PROGILONE - 06/05/10 -->
	<!-- [F7]- Select multiple items listbox -->
    <label>Biography</label>
        <select name="limit" class="subtype" multiple="multiple" size="5" onMouseDown="GetCurrentListValues(this);" onchange="FillListValues(this);">
            <option value="" selected="selected" >Any</option>
            <option value="Biography-code:y">Not a biography</option>
            <option value="Biography-code:a">autobiography</option>
            <option value="Biography-code:b">individual biography</option>
            <option value="Biography-code:c">collective biography</option>
            <option value="Biography-code:d">contains biogr. data</option>
    </select>
        </p>
        <p>
    <!-- PROGILONE - 06/05/10 -->
	<!-- [F7]- Select multiple items listbox -->
    <label>Illustration</label>
        <select name="limit" class="subtype" multiple="multiple" size="5" onMouseDown="GetCurrentListValues(this);" onchange="FillListValues(this);">
            <option value="" selected="selected" >Any</option>
            <option value="Illustration-Code:a">illustrations</option>
            <option value="Illustration-Code:b">maps</option>
            <option value="Illustration-Code:c">portraits</option>
            <option value="Illustration-Code:d">charts</option>
            <option value="Illustration-Code:e">plans</option>
            <option value="Illustration-Code:f">plates</option>
            <option value="Illustration-Code:g">music</option>
            <option value="Illustration-Code:h">facsimiles</option>
            <option value="Illustration-Code:i">coats of arms</option>
            <option value="Illustration-Code:j">genealogical tables</option>
            <option value="Illustration-Code:k">forms</option>
            <option value="Illustration-Code:l">samples</option>
            <option value="Illustration-Code:m">sound recordings</option>
            <option value="Illustration-Code:n">transparencies</option>
            <option value="Illustration-Code:o">illuminations</option>
            <option value="Illustration-Code:y">no illustrations</option>
        </select>
        </p>
    <p>
    <!-- PROGILONE - 06/05/10 -->
	<!-- [F7]- Select multiple items listbox -->
    <label>Content</label>
    <select name="limit" class="subtype" multiple="multiple" size="5" onMouseDown="GetCurrentListValues(this);" onchange="FillListValues(this);">
      <option value="" selected="selected" >Any</option>
            <option value="ctype:a" >bibliography</option>
            <option value="ctype:b" >catalogue</option>
            <option value="ctype:c" >index</option>
            <option value="ctype:d" >abstract</option>
            <option value="ctype:e" >dictionary</option>
            <option value="ctype:f" >encyclopaedia</option>
            <option value="ctype:g" >directory</option>
            <option value="ctype:h" >project description</option>
            <option value="ctype:i" >statistics</option>
            <option value="ctype:j" >programmed text books</option>
            <option value="ctype:k" >patent</option>
            <option value="ctype:l" >standard</option>
            <option value="ctype:m" >dissertation or thesis</option>
            <option value="ctype:n" >laws and legislation</option>
            <option value="ctype:o" >numeric table</option>
            <option value="ctype:p" >technical report</option>
            <option value="ctype:q" >examination paper</option>
            <option value="ctype:r" >literature surveys/reviews</option>
            <option value="ctype:s" >treaties</option>
            <option value="ctype:t" >cartoons or comic strips</option>
            <option value="ctype:z" >other</option>
    </select>
        </p>
        <p>
    <label>Video Types</label>
    <select name="limit" class="subtype">
            <option value="">Any</option>
      <option value="Video-mt:a">motion picture</option>
      <option value="Video-mt:b">visual projection</option>
      <option value="Video-mt:c">video recording</option>
    </select>
        </p>
    </fieldset>
    <fieldset>
    <legend>Serials</legend><p>
    <p>
    <label>Serial Type</label>
    <select name="limit" class="subtype">
           <option value="">Any type</option>
           <option value="Type-Of-Serial:a">Periodical</option>
      <option value="Type-Of-Serial:b">Monographical series</option>
      <option value="Type-Of-Serial:c">Newspaper</option>
      <option value="Type-Of-Serial:z">Other</option>
    </select>
    </p>
    <p>
    <!-- PROGILONE - 06/05/10 -->
	<!-- [F7]- Select multiple items listbox -->
    <label>Periodicity</label>
    <select name="limit" class="subtype" multiple="multiple" size="5" onMouseDown="GetCurrentListValues(this);" onchange="FillListValues(this);">
      <option value="" selected="selected" >Any</option>
        <option value="Frequency-code:a">Daily</option>
        <option value="Frequency-code:b">Semiweekly</option>
        <option value="Frequency-code:c">Weekly</option>
        <option value="Frequency-code:d">Biweekly</option>
        <option value="Frequency-code:e">Semimonthly</option>
        <option value="Frequency-code:f">Monthly</option>
        <option value="Frequency-code:g">Bimonthly</option>
        <option value="Frequency-code:h">Quarterly</option>
        <option value="Frequency-code:i">Three times a year</option>
        <option value="Frequency-code:j">Semiannual</option>
        <option value="Frequency-code:k">Annual</option>
        <option value="Frequency-code:l">Biannual</option>
        <option value="Frequency-code:m">Triennial</option>
        <option value="Frequency-code:n">Three times a week</option>
        <option value="Frequency-code:o">Three times a month</option>
        <option value="Frequency-code:u">Unknown</option>
        <option value="Frequency-code:y">Without periodicity</option>
        <option value="Frequency-code:i">Other</option>
    </select>
    </p>
    <p>
    <label>Regularity</label>
    <select name="limit" class="subtype">
            <option value="">Any regularity</option>
        <option value="Regularity-code:u">Unknown</option>
        <option value="Regularity-code:a">Regular</option>
        <option value="Regularity-code:b">Normalised irregular</option>
        <option value="Regularity-code:y">irregular</option>
    </select>
        </p>

        </fieldset>
    <!-- PROGILONE - 06/05/10 -->
	<!-- [F7]- Select multiple items listbox -->
    <fieldset>
    <legend>Picture</legend><p>
    <select name="limit" class="subtype" multiple="multiple" size="5" onMouseDown="GetCurrentListValues(this);" onchange="FillListValues(this);">
        <option value="" selected="selected" >Any</option>
        <option value="Graphics-type:a">collage</option>
        <option value="Graphics-type:b">drawing</option>
        <option value="Graphics-type:c">painting</option>
        <option value="Graphics-type:d">photomechanical reproduction</option>
        <option value="Graphics-type:e">photonegative</option>
        <option value="Graphics-type:f">photoprint</option>
        <option value="Graphics-type:h">picture</option>
        <option value="Graphics-type:i">print</option>
        <option value="Graphics-type:k">technical drawing</option>
        <option value="Graphics-type:z">other non-projected graphic type</option>
    </select>
    <!-- PROGILONE - 06/05/10 -->
	<!-- [F7]- Select multiple items listbox -->
    <select name="limit" class="subtype" multiple="multiple" size="5" onMouseDown="GetCurrentListValues(this);" onchange="FillListValues(this);">
            <option value="" selected="selected" >Any</option>
            <option value="Graphics-support:a">canvas</option>
            <option value="Graphics-support:b">bristol board</option>
            <option value="Graphics-support:c">cardboard/illustration board</option>
            <option value="Graphics-support:d">glass</option>
            <option value="Graphics-support:j">plaster</option>
            <option value="Graphics-support:k">hardboard</option>
            <option value="Graphics-support:l">porcelaine</option>
            <option value="Graphics-support:m">stone</option>
            <option value="Graphics-support:n">wood</option>
            <option value="Graphics-support:u">unknown</option>
            <option value="Graphics-support:v">mixed collection</option>
            <option value="Graphics-support:e">synthetics</option>
            <option value="Graphics-support:f">skin</option>
            <option value="Graphics-support:g">textile</option>
            <option value="Graphics-support:h">metal</option>
            <option value="Graphics-support:i">paper</option>
            <option value="Graphics-support:z">others</option>
    </select>
        </p>
