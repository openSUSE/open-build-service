var DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

var toTwoChars = function(number, leadingChar) {
  return (leadingChar + number).slice(-2);
};

// The jshint ignore:line is needed to ignore the offense: `'addChangesEntryTemplate' is defined but never used.` This is used in the view directly
function addChangesEntryTemplate() { // jshint ignore:line
  var date = new Date(),
      weekDay = DAYS[date.getUTCDay()],
      month = MONTHS[date.getUTCMonth()],
      day = toTwoChars(date.getUTCDate(), ' '),
      hours = toTwoChars(date.getUTCHours(), '0'),
      minutes = toTwoChars(date.getUTCMinutes(), '0'),
      seconds = toTwoChars(date.getUTCSeconds(), '0'),
      changesSelector = $("a.changes-link"),
      packagerName = changesSelector.data('packagername'),
      packagerEmail = changesSelector.data('packageremail');

  var template = "-------------------------------------------------------------------\n" +
                 weekDay + " " + month + " " + day + " " +
                 hours + ":" + minutes + ":" + seconds + " UTC " + date.getUTCFullYear() +
                 " - " + packagerName + " <" + packagerEmail + ">\n\n- \n\n";

  editors[0].setValue(template + editors[0].getValue());
  editors[0].focus();
  editors[0].setCursor(3, 3);
}

