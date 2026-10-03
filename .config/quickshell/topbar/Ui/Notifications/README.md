# Topbar notifications

`Services/Notifications.qml` owns `org.freedesktop.Notifications` through
Quickshell's `NotificationServer`. It normalizes notification fields, invokes
client actions, handles close reasons, and groups duplicate messages or Dunst
compatible stack tags. `ChannelReceiver.qml` queues and times one visible
message at a time. `ChannelWaveform.qml` draws incoming signals in the bar.
`ChannelTerminal.qml` is a normal `PopupPanel`, so it shares the other topbar
menus' placement, colors, typography, and open/close motion.

The panel shows fields only when supplied: app name, summary, body (including
basic markup and hyperlinks), image or icon, progress (`value` hint), actions,
urgency, and duplicate count. When both artwork and an app icon exist, the
artwork sits by the text and the icon sits by the app name. Repeated messages
are grouped. Incoming messages wait in a single queue rather than forming a
stack of windows. Long bodies scroll inside the compact panel. A sender timeout
is honored with a 6 second minimum; the default is 8 seconds and timeout 0
stays until closed. Hover pauses the timer. The track beside the Close/Next
button shows the remaining reading time and resets for each new message.

The waveform animates at the display's frame rate. Its single stroke is drawn
at twice the component's size and scaled down for a continuous thin trace.
Slow idle motion becomes a sustained modulation while a message is open.
Arrivals excite the carrier from the right, spread across it, then settle;
closely spaced arrivals reinforce a reception burst. Duplicate arrivals also
make a signal, but closing a duplicate or opening an empty panel does not.

`ChannelBuffer.qml` previews the first four waiting messages as anchored segments
inside the pill, with `+N` for the remaining backlog. The pill grows for each
visible segment, then grows only as the overflow number needs more digits.
Appending messages does not move existing segments. Reading or dismissing a
message advances its successors. The popup uses the module's stable left edge
as its anchor, and the outgoing content remains during its fade to the next
message. Reception effects expire separately from the queue; waiting messages
never occupy or compete for waveform positions.

Click the waveform to open the panel immediately, including when no message is
present. Click Close or Next to dismiss the current message. Action buttons
invoke the sending application's D-Bus action. The notification panel does not
take focus from the active application. The unused notification design demos
were removed.

When the bar is tight, the carrier shrinks from 138 to 76 pixels, then to a
30 pixel mark. The buffer reduces to two segments plus overflow in compact mode,
and a total waiting count in the smallest mode. Compression measurements include
the buffer in each size.

## Verify the live server

The desktop bus permits one owner of `org.freedesktop.Notifications`. After
removing Dunst, restart the topbar and check that Quickshell owns that name:

```sh
sh ~/.config/scripts/quickshell-start.sh topbar restart
busctl --user status org.freedesktop.Notifications
notify-send -a 'Notification test' -i dialog-information 'Quickshell' 'The new notification server is receiving messages.'
```

`busctl` should report the Quickshell process as owner. Quickshell does not
reproduce Dunst's scripts, filtering rules, or stored history; these are
separate behavior features, not message content. The freedesktop protocol's
optional inline replies, sounds, body images, and action icons are not
advertised.
