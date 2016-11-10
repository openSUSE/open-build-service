(function($) {
  /*
  * Function: fnGetColumnData
  * Purpose:  Return an array of table values from a particular column.
  * Returns:  array string: 1d data array 
  * Inputs:   object:oSettings - dataTable settings object. This is always the last argument past to the function
  *           int:iColumn - the id of the column to extract the data from
  *           bool:bUnique - optional - if set to false duplicated values are not filtered out
  *           bool:bFiltered - optional - if set to false all the table data is used (not only the filtered)
  *           bool:bIgnoreEmpty - optional - if set to false empty values are not filtered from the result array
  * Author:   Benedikt Forchhammer <b.forchhammer /AT\ mind2.de>
  */
  $.fn.dataTableExt.oApi.fnGetColumnData = function ( oSettings, iColumn, bUnique, bFiltered, bIgnoreEmpty ) {
    // check that we have a column id
    if ( typeof iColumn == "undefined" ) return new Array();

    // by default we only wany unique data
    if ( typeof bUnique == "undefined" ) bUnique = true;

    // by default we do want to only look at filtered data
    if ( typeof bFiltered == "undefined" ) bFiltered = true;

    // by default we do not wany to include empty values
    if ( typeof bIgnoreEmpty == "undefined" ) bIgnoreEmpty = true;

    // list of rows which we're going to loop through
    var aiRows;

    // use only filtered rows
    if (bFiltered == true) aiRows = oSettings.aiDisplay; 
    // use all rows
    else aiRows = oSettings.aiDisplayMaster; // all row numbers

    // set up data array    
    var asResultData = new Array();

    for (var i=0,c=aiRows.length; i<c; i++) {
      iRow = aiRows[i];
      var sValue = this.fnGetData(iRow, iColumn);

      // ignore empty values?
      if (bIgnoreEmpty == true && sValue.length == 0) continue;

      // ignore unique values?
      else if (bUnique == true && jQuery.inArray(sValue, asResultData) > -1) continue;

      // else push the value onto the result data array
      else asResultData.push(sValue);
    }

    return asResultData;
  }

}(jQuery));