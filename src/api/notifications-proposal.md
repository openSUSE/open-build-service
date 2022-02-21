### Example
```
NotificationsChannel.broadcast_to(User.first, {title: 'New things!', body: 'All the news fit to print'})
```

### Proposal:
- Firefox and Safari require a short event to ask the notification permission. If you try to request permission outside an event, they'll throw this error
`The Notification permission may only be requested from inside a short running user-generated event handler.`
Chrome doesn't require that. For Chrome, we can even ask the permissions on page load.

- How and when should we ask for permission?
  I'd propose we ask permission in a similar way we show announcements. We can have a small banner/notice asking for permission, with the options `Accept` or `Deny`. If user clicks `Accept` we can trigger the notification request permission function `Notification.requestPermission();`.