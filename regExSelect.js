// Tommaso Leonardi (tom@itm6.xyz), 2016
// This script for Adobe Illustrator selects text
// elements whose content matches a regular expression.
// The search applies only to the selected objects.
// If no objects are selected it searches the whole document.
//
// Tested in Illustrator CS6


var doc = app.activeDocument; 
var scope = app.activeDocument.selection.length ? app.activeDocument.selection : app.activeDocument.pageItems;

var find = prompt("Find: (Text or GREP/regex)","");
if(find !== null){
	var toSelect = Array();  
	var selected = 0;
	for(var i=0;i<scope.length;i++){  
            var text = scope[i];
            var string = text.contents;  
            if(typeof string == "string"){
                var match = string.match( new RegExp(find, 'g'));
                if (match !== null) {
			toSelect.push(text);
			selected++;
		}
            }
        }
        alert( selected==1 ? "1 text object found" : selected + " text objects found");
	doc.selection = toSelect; 
}
