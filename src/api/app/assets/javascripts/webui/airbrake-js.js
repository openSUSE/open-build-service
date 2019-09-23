//= require airbrake-js-client

/* global airbrakeJs */
var errbitId = $("meta[property='errbit:key']").attr('content');
var errbitHost = $("meta[property='errbit:host']").attr('content');

if (errbitId) {
  var airbrake = new airbrakeJs.Client({
    projectId: 1,
    projectKey: errbitId,
    host: errbitHost,
    environment: 'production',
  });

  window.onerror = function (message, file, line, col, error) {
    var promise = airbrake.notify(error);
    promise.then(function(notice) {
      if (notice.id) {
        // console.log('Notified errbit. Notice:', notice.id);
        console.log('Notified errbit.');
      } else {
        // console.log('Notifying errbit failed. Reason:', notice.error);
        console.log('Notifying errbit failed!');
      }
    });
  };
}
