/* jshint ignore:start */
App.messages = App.cable.subscriptions.create("NotificationsChannel", {
  connected() {
    console.log('connected to notifications_channel');
  },

  received(data) {
    if (notificationSupport() && Notification.permission === "granted") {
      createNotification(data);
    }
  }
});

$(document).ready(function() {
  $('.ask-for-notification-permission').click(function() {
    askNotificationPermission();
  });
});

function askNotificationPermission() {
  if (notificationSupport() && Notification.permission === "default") {
    Notification.requestPermission();
  }
}

function notificationSupport() {
  if (!('Notification' in window)) {
    console.log("This browser does not support notifications.");
    return false;
  } else {
    return true;
  }
}

function createNotification(data) {
  new Notification(data.title, { body: data.body });
}
/* jshint ignore:end */
