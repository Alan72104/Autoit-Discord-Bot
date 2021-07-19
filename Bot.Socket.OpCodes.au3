#include-once

Global Const $OPCODE_DISPATCH = 0              ; Receive        An event was dispatched.
Global Const $OPCODE_HEARTBEAT = 1             ; Send/Receive   Fired periodically by the client to keep the connection alive.
Global Const $OPCODE_IDENTIFY = 2              ; Send           Starts a new session during the initial handshake.
Global Const $OPCODE_PRESENCE_UPDATE = 3       ; Send           Update the client's presence.
Global Const $OPCODE_VOICE_STATE_UPDATE = 4    ; Send           Used to join/leave or move between voice channels.
Global Const $OPCODE_RESUME = 6                ; Send           Resume a previous session that was disconnected.
Global Const $OPCODE_RECONNECT = 7             ; Receive        You should attempt to reconnect and resume immediately.
Global Const $OPCODE_REQUEST_GUILD_MEMBERS = 8 ; Send           Request information about offline guild members in a large guild.
Global Const $OPCODE_INVALID_SESSION = 9       ; Receive        The session has been invalidated. You should reconnect and identify/resume accordingly.
Global Const $OPCODE_HELLO = 10                ; Receive        Sent immediately after connecting, contains the `heartbeat_interval` to use.
Global Const $OPCODE_HEARTBEAT_ACK = 11        ; Receive        Sent in response to receiving a heartbeat to acknowledge that it has been received.