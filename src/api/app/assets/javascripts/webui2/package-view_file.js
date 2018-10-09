// FIXME: Refactor this code
var DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

var toTwoDigits = function(number) {
  return ('0' + number).slice(-2);
};

// The jshint ignore:line is needed to ignore the offense: `'addChangesEntryTemplate' is defined but never used.` This is used in the view directly
function addChangesEntryTemplate() { // jshint ignore:line
  var date = new Date(),
      day = date.getUTCDate().toString(),
      hours = toTwoDigits(date.getUTCHours()),
      minutes = toTwoDigits(date.getUTCMinutes()),
      seconds = toTwoDigits(date.getUTCSeconds()),
      template;

  if (day.length === 1) { day = " " + day; } // Pad single character day value

  template = "-------------------------------------------------------------------\n" +
    DAYS[date.getUTCDay()] + " " + MONTHS[date.getUTCMonth()] + " " + day + " " +
    hours + ":" + minutes + ":" + seconds + " UTC " + date.getUTCFullYear() +
    " - " + $("a.changes-link").data('packagername') +
    " <" + $("a.changes-link").data('packageremail') + ">" +"\n\n" + "- \n" + "\n";

  editors[0].setValue(template + editors[0].getValue());
  editors[0].focus();
  editors[0].setCursor(3, 3);
}

