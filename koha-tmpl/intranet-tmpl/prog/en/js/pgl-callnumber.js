// PROGILONE B10: Callnumber related javascript functions

function toggleVisibility(checkbox, idElement, reverse) {
	var is_checked = checkbox.checked;
	if (reverse) {
		is_checked = !is_checked;
	}
	
	if (is_checked) {
		document.getElementById(idElement).style.visibility = '';
	} else {
		document.getElementById(idElement).style.visibility = 'hidden';
	}
}

function toggleDisplay(checkbox, idElement, reverse) {
	var is_checked = checkbox.checked;
	if (reverse) {
		is_checked = !is_checked;
	}
	
	if (is_checked) {
		document.getElementById(idElement).style.display = '';
	} else {
		document.getElementById(idElement).style.display = 'none';
	}
}

function findSubfieldsWithProperty(property) {
	var fields = document.getElementsByName(property);
	var found_fields = new Array()
	for (var i = 0; i < fields.length; i++) {
		var el = fields.item(i);
		parent = el.parentNode;
		found_fields.push(parent);
	}
	return found_fields;
}

function getDivSubfields(doc, subfield) {
	var elements = doc.getElementsByName('subfield');
	var parent = null;
	var subfields = new Array();

	for (var i = 0; i < elements.length; i++) {
		var el = elements.item(i);
		if (el.value == subfield) {
			parent = el.parentNode;
			subfields.push(parent);
		}
	}

	return subfields;
}

function getInputSubfield(divSubfield) {
	for (var i = 0; i < divSubfield.children.length; i++) {
		var el = divSubfield.children[i];
		if((el.type == 'select-one') || (el.type == 'text')) {
			return el;
		}
	}
}

function copySubfieldValueToSubfield(divSubfieldSource, divSubfieldTarget) {
	var inputSource = getInputSubfield(divSubfieldSource);
	var inputTarget = getInputSubfield(divSubfieldTarget);
	inputTarget.value = inputSource.value;
}

function reportToSubfield(doc, source, target, value) {
	var divSource = getDivSubfields(doc, source)[0];
	var divTarget = getDivSubfields(doc, target)[0];
	copySubfieldValueToSubfield(divSource, divTarget);
}

function duplicateSubfield(divSubfield, newValue) {
	var span_onclick;

	for (var i = 0; i < divSubfield.children.length; i++) {
		ch = divSubfield.children[i];
		if (ch.getAttribute('name') == 'repeatable') {
			span_onclick = ch;
		}
	}
	span_onclick.onclick();
	
	var newElement = divSubfield.nextSibling;
	for (var i = 0; i < newElement.children.length; i++) {
		var ch = newElement.children[i];
		if (ch.getAttribute('name') == 'field_value') {
			ch.value = newValue;
		}
	}
}

function splitField(divSubfield) {
	var original_value;
	var span_onclick;
	
	for (var j = 0; j < divSubfield.children.length; j++) {
		var ch = divSubfield.children[j];
		if (ch.getAttribute('name') == 'field_value') {
			original_value = ch.value;
		}
		if (ch.getAttribute('name') == 'repeatable') {
			span_onclick = ch;
		}
	}

	var values = original_value.split('|');
	for (var i = 1; i < values.length; i++) {
		span_onclick.onclick();
	}
	
	var topElement = divSubfield.parentNode;
	for (var i = 0; i < topElement.children.length; i++) {
		var divElement = topElement.children[i];
		for (var j = 0; j < divElement.children.length; j++) {
			ch = divElement.children[j];
			if (ch.getAttribute('name') == 'field_value') {
				ch.value = values[i];
			}
		}
	}
}

function makeFieldReadonly(subfield) {
	var field = getInputSubfield(subfield);
	if (field.type == 'select-one') {
		field.disabled = 'disabled';
	} else if (field.type == 'text') {
		field.readOnly = 'readonly';
	}
}

function isParent(parentName, childObj) {
    var testObj = childObj.parentNode;
    while(testObj.getAttribute('name') != parentName) {
        testObj = testObj.parentNode;
        if (testObj == document) {
            return false;
        }
    }
    return true;
}
	