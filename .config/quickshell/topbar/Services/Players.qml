pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Common

// Picks which MPRIS player the bar should follow and exposes it as one stable
// object, so every media surface (bar module, popup, dashboard) shows the same
// thing. Entirely event driven — no polling unless something is watching the
// playback position.
Singleton {
    id: root

    readonly property var allPlayers: Mpris.players.values
    property var activePlayer: null

    readonly property bool hasPlayer: activePlayer !== null
    readonly property bool isPlaying: !!activePlayer && activePlayer.isPlaying

    readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string album: activePlayer ? (activePlayer.trackAlbum || "") : ""
    readonly property string artUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    readonly property string identity: activePlayer ? (activePlayer.identity || "") : ""

    // "Title - Artist", falling back to just the title when there's no artist.
    readonly property string label: {
        if (!title)
            return "";
        return artist ? title + Config.media.separator + artist : title;
    }

    readonly property bool canGoNext: !!activePlayer && activePlayer.canGoNext
    readonly property bool canGoPrevious: !!activePlayer && activePlayer.canGoPrevious
    readonly property bool canSeek: !!activePlayer && activePlayer.canSeek
    readonly property real length: (activePlayer && activePlayer.lengthSupported) ? activePlayer.length : 0
    readonly property real position: activePlayer ? activePlayer.position : 0

    function isStopped(player) {
        return !player || player.playbackState === MprisPlaybackState.Stopped;
    }

    // Prefer whatever is actually playing. Otherwise hold onto the current
    // player so pausing doesn't make the widget vanish, and only fall back to
    // another player once the current one is gone or stopped.
    function resolveActivePlayer() {
        const players = allPlayers;
        const playing = players.filter(p => p.isPlaying);
        if (playing.length > 0) {
            const controllable = playing.find(p => p.canControl);
            activePlayer = controllable ?? playing[0];
            return;
        }
        if (activePlayer && players.indexOf(activePlayer) !== -1 && !isStopped(activePlayer))
            return;
        activePlayer = players.find(p => p.canControl && !isStopped(p)) ?? players.find(p => !isStopped(p)) ?? null;
    }

    onAllPlayersChanged: resolveActivePlayer()
    Component.onCompleted: resolveActivePlayer()

    // A binding can't see into list elements, so watch each player directly.
    Instantiator {
        model: root.allPlayers
        delegate: Connections {
            required property var modelData
            target: modelData
            ignoreUnknownSignals: true
            function onIsPlayingChanged() {
                root.resolveActivePlayer();
            }
            function onPlaybackStateChanged() {
                root.resolveActivePlayer();
            }
        }
    }

    function togglePlaying() {
        if (activePlayer && activePlayer.canTogglePlaying)
            activePlayer.togglePlaying();
    }

    function next() {
        if (activePlayer && activePlayer.canGoNext)
            activePlayer.next();
    }

    // Matches what most players do with a "previous" press: restart the track
    // first, and only skip back if you're already near the start.
    function previous() {
        if (!activePlayer)
            return;
        if (activePlayer.canSeek && activePlayer.position > 8)
            activePlayer.position = 0;
        else if (activePlayer.canGoPrevious)
            activePlayer.previous();
    }

    function seekToFraction(fraction) {
        if (!activePlayer || !activePlayer.canSeek || length <= 0)
            return;
        const clamped = Math.max(0, Math.min(1, fraction));
        activePlayer.position = Math.min(clamped * length, length * 0.99);
    }

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00";
        const total = Math.floor(seconds);
        const mins = Math.floor(total / 60);
        const secs = total % 60;
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    // MPRIS doesn't push position updates, so anything drawing a progress bar
    // has to ask for them. Surfaces call watchPosition(true) while visible and
    // (false) when they close, so a closed popup costs nothing.
    property int positionWatchers: 0

    function watchPosition(enabled) {
        positionWatchers = Math.max(0, positionWatchers + (enabled ? 1 : -1));
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.positionWatchers > 0 && root.isPlaying
        onTriggered: root.activePlayer?.positionChanged()
    }
}
