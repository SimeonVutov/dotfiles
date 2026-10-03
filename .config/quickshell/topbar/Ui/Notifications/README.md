# Topbar notifications

The radio waveform in the topbar is the notification indicator. Incoming
messages disturb the waveform and join its queue; they **do not open the panel**.
Click the waveform to read the next message. The panel also opens when the
queue is empty, and a new message will appear there if it arrives while the
empty panel is open.

Use **Close** to dismiss the current message or **Next** to advance through a
backlog. Notification action buttons call the action supplied by the sending
app. The panel does not take focus from the active app. The queue is in memory
only; there is no saved notification history.

The topbar shows the first four queued messages as segments, then `+N` for the
rest. In tight layouts it shows two segments and `+N`, then just the pending
count at the smallest size. Repeated messages are grouped.

## Connect it to desktop notifications

No app specific setup is needed. Quickshell's `NotificationServer` receives
messages sent to the standard `org.freedesktop.Notifications` D-Bus service,
including notifications from apps using `notify-send`. Only one program can
own that service at a time. Once you have stopped Dunst, restart the topbar
and check the owner:

```sh
sh ~/.config/scripts/quickshell-start.sh topbar restart
busctl --user status org.freedesktop.Notifications
```

The reported process should be `quickshell`. If it is `dunst`, Dunst still owns
the service and will receive the notifications instead.

## Send test notifications

```sh
notify-send -a 'Radio test' -t 10000 -i dialog-information \
  'Incoming signal' 'Click the waveform to read this message.'
```

To see the queue grow, run:

```sh
for i in 1 2 3 4 5 6; do
  notify-send -a 'Radio test' -t 12000 "Message $i" "Queue test $i"
  sleep 0.15
done
```

`notify-send -t` uses milliseconds. The panel's reading timer starts when a
message opens, including while its text is being typed. It uses the sender's
positive timeout with a six second minimum, eight seconds when unspecified,
and no automatic expiry when the timeout is zero. The track beside Close/Next
shows the time left and resets for each message.

## What appears in the panel

The panel shows the fields a sender provides: app name, summary, body, image
or icon, progress (`value` hint), actions, urgency, and a count for grouped
duplicates. Missing fields leave no empty labels. Bodies support basic markup
and links; long text scrolls. An image appears beside the text, while a
separate app icon appears beside the app name when both are available.

Dunst scripts, filtering rules, and stored history are not part of this
component. Optional protocol features such as inline replies, sounds, body
images, and action icons are not advertised.

## How it is wired

| File | Responsibility |
| --- | --- |
| [Notifications service](../../Services/Notifications.qml) | Owns the D-Bus service, captures fields, groups duplicates and stack tags, invokes actions, and closes notifications. |
| [Notifications module](../../Modules/NotificationsModule.qml) | Routes messages to the topbar on the focused screen and connects the indicator to the panel. |
| [Receiver](ChannelReceiver.qml) | Keeps the queue, handles arrival timing, opens the selected message, and runs its reading timer. |
| [Waveform](ChannelWaveform.qml) and [buffer](ChannelBuffer.qml) | Draw the live signal and the queued message count in the topbar. |
| [Terminal](ChannelTerminal.qml) | Renders the message and action buttons in the shared topbar popup style. |

The path is: app → desktop notification D-Bus service → Quickshell service →
topbar module → receiver queue → waveform and panel. Closing or expiring a
message reports that event to its sender through the notification service.
