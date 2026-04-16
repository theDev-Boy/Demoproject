now please in the measges or masengers page okay here if we block somone we will just have to see her in red okay if we wnna to delet we can delet the th user but still he will frdins like for exmple if i add perosn i msg him okay and then i blok her okay i will unable to ooen chat with him if i bloked okay and when i unblok this from like in the messenger we have all users okay wihc user i bloked i can see and i can also unbliked them okay and like when i block its will not be unfrids just he will bloked okay means he will unable to call us and unable to mgs us okay and we can also unblok okay and when we vice msg please fix this okay when we hold the vice msg we should see the vice durition okay and when we stop hold what we recrded okay its will traper by peer to peer device oka and free vice msg and then we see a msg also and he recive the msg vice and he can play the msg and can see the durtion o means ho long is the msg and can play please add thes all fetures whihc i said i atlk mixed but please udestand the project and add all fetures okay ferctly fiedx and add oka and also bro please fix the when we chating with somone okay then we ccclik at clear chat the chat shoudld be celare but just for us okay just for us and also like when we clcik clear chat show warining and then okay and ckear chat and also okay bro if we blcoked user user will not delet use bloced and then we can also unbalced it okay and if i hold on the msg i can edit te msg and can delet the sg from my self and delet from everyone okay bro are u udestand okay and please focues on every efures if u not udestanding then see this ( 1. Block / Unblock User Functionality
1.1 Blocking Behavior
Block a user: When User A blocks User B:

The chat with User B becomes inaccessible (cannot open, cannot send messages, cannot call).

User B can no longer call or message User A.

Friendship status remains unchanged – blocking does not unfriend.

Visual Indicator: In the main chat list, a blocked user's name/avatar should be displayed with a red tint or red border.

1.2 Deleting a Blocked User's Chat
If User A deletes the conversation with a blocked user:

The chat disappears from the chat list.

The user remains blocked in the system settings.

The friendship connection is not deleted.

1.3 Blocked Users Management Screen
Create a dedicated Blocked Users List (accessible via Messenger Settings).

This list shows all users currently blocked by the current user.

Unblock Action: Tapping on a user in this list provides an "Unblock" button.

Upon unblocking:

The chat becomes accessible again (if it wasn't deleted).

The user can message and call normally.

1.4 Edge Cases
If a blocked user tries to send a message, they should receive a silent failure or a "User unavailable" error (no notification delivered to the blocker).

Unblocking does not deliver any messages sent during the block period.

2. Voice Message Recording & Playback
2.1 Recording Interface
Trigger: Long press on the Microphone button (or dedicated voice record button).

Visual Feedback:

While holding, show a recording indicator (e.g., "Recording..." with a timer showing duration: 00:00).

The timer should update in real-time as the user holds.

Cancel Recording: If the user slides their finger off the button and releases, cancel the recording.

Send Recording: On release (after successful hold), the audio file is sent.

2.2 Transmission Method
Preference: Peer-to-Peer (P2P) transfer where possible to save server costs (e.g., WebRTC Data Channel or Socket.io file streaming).

Fallback: If P2P fails, upload to server and send URL (standard method).

Note to AI: The user explicitly wants "traper by peer to peer device". Prioritize direct device connection for file transfer.

2.3 Playback Interface (Receiver Side)
Message Bubble: The voice message appears as a distinct bubble with:

Play/Pause button (icon changes based on state).

Duration label (e.g., 0:32).

Waveform visualization (optional, but nice to have).

Functionality:

Tapping play downloads/streams the audio and plays it.

While playing, the button shows a pause icon.

Duration is visible at all times.

3. Clear Chat (Local Clear Only)
3.1 Functionality
Location: Option in chat detail screen (e.g., "Clear Chat History").

Behavior: Clears all messages only from the current user's device/database.

Other User Impact: The other participant in the chat should not have their messages deleted. The conversation remains intact for them.

3.2 Confirmation Dialog
Before executing, show a Warning Dialog:

Title: Clear Chat?

Message: This will delete all messages in this chat from this device only. This action cannot be undone.

Buttons: Cancel / Clear

On confirmation, delete the local chat history and refresh the screen to show an empty chat.

4. Message Actions (Long Press Menu)
4.1 Menu Options on Long Press of a Message Bubble
Edit Message: (Only for text messages, and only if sent by current user and within a time limit, e.g., 1 hour).

Delete for Me: Removes the message locally. Does not affect the recipient's view.

Delete for Everyone: Attempts to delete the message from both sender and recipient devices. (Requires server notification to trigger remote deletion).

4.2 Implementation Notes
Ensure the menu is context-aware (e.g., voice messages cannot be edited, only deleted).

Summary Checklist for AI Implementation
Feature	Priority	Key Implementation Detail
Block User Red Color	High	Modify ChatTile widget to check isBlocked flag.
Blocked List Screen	High	New screen querying local DB for blocked user IDs.
Voice Record Hold Gesture	High	Use GestureDetector with LongPressStart and LongPressEnd callbacks.
Voice Duration Timer	High	Use Stopwatch and Timer.periodic to update UI.
P2P Voice Transfer	Medium	Integrate flutter_webrtc or similar library.
Clear Chat Local Only	Medium	Execute DELETE query on local SQLite/Hive box scoped to that chat ID.
Edit / Delete Message Menu	High	Use showModalBottomSheet with options; implement soft delete logic. )



1. Random Call / WebRTC Connectivity Fix
1.1 Current Issue
Users connect to random people successfully (UI shows "Connected").

Problem: Audio and Video are not transmitted/received. Users cannot see or hear each other.

1.2 Required Fixes (Checklist for AI)
Permissions Check: Ensure both CAMERA and RECORD_AUDIO permissions are granted before initializing the media stream. If denied, show a prompt directing user to settings.

Media Stream Initialization: Verify that navigator.mediaDevices.getUserMedia (or Flutter equivalent flutter_webrtc mediaDevices.getUserMedia) is called with correct constraints:

dart
{
  'audio': true,
  'video': {
    'mandatory': {
      'minWidth': '640',
      'minHeight': '480',
      'minFrameRate': '30',
    }
  }
}
Renderer Attachment: Confirm that RTCVideoRenderer objects are properly attached to both srcObject (the local stream) and the remote stream after the peer connection onTrack event fires.

SDP Exchange: Ensure that after the offer/answer exchange, the setLocalDescription and setRemoteDescription are awaited correctly.

Signaling Server Status: Verify that the signaling server is relaying ICE candidates correctly.

1.3 Expected Result
When the call connects, the local video preview appears.

Remote video/audio is received and rendered within 2-3 seconds of connection.

2. Push Notifications & Background Calls (CRITICAL)
2.1 Current Issue
Notifications work only when the app is open.

App Closed/Killed: Incoming calls do not show a full-screen ring screen. Message notifications do not appear.

2.2 Required Implementation: Full-Screen Incoming Call (Background/Killed)
Technology Stack: Must use Firebase Cloud Messaging (FCM) with High Priority messages.

Payload Structure: The server must send a Data-Only message (not Notification-only) to trigger background execution.

Sample FCM Payload:

json
{
  "to": "device_token",
  "priority": "high",
  "data": {
    "type": "call",
    "caller_id": "123",
    "caller_name": "John",
    "room_id": "xyz",
    "video_call": "true"
  }
}
Flutter Implementation:

Configure AndroidManifest.xml and Info.plist for Background Modes (VoIP/Audio).
Use flutter_local_notifications with Full-Screen Intent (Android) or CallKit (iOS).
Android Specific: Create a High Importance Notification Channel and set setFullScreenIntent in the notification builder.
Important: In call_notification.dart, ensure the method showCallNotification uses the androidAllowWhileIdle: true and androidFullScreenIntent: true flags.
2.3 Message Notifications (App Closed)
Ensure the server is sending FCM messages.

In the Flutter app, ensure FirebaseMessaging Background Handler is registered at the top level (outside any class).

Code Snippet for AI:

dart
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Show local notification here
}
2.4 Fix: call_notification.dart Issues
Problem: Likely not showing or crashing.

Task:

Refactor this file to use Android 13+ POST_NOTIFICATIONS permission request at runtime.

Ensure the Notification Channel ID matches exactly between the creation code and the display code.

Add CallKeep (or flutter_callkeep) integration for iOS to ensure native incoming call UI.

3. Auto-Refresh Everywhere (Real-Time Updates)
3.1 Requirement
The following pages must update automatically without the user pulling down manually:

Friends List Page

Friend Requests Page

Chat/Messages List Page

3.2 Implementation Specification
Do NOT use Timer.periodic for polling (bad for battery).

Use StreamBuilder with Firestore Snapshots or WebSocket Events.

Page	Data Source	Auto-Refresh Logic
Chat List	Firestore chats collection	StreamBuilder listening to chats ordered by lastMessageTime.
Friends List	Firestore friends subcollection	StreamBuilder listening to friends with status changes.
Requests Page	Firestore requests collection	StreamBuilder listening to incoming requests where status == 'pending'.
UI Note: Add a silent refresh (no spinning wheel in center of screen, just updating the list). Optionally add a Pull-to-Refresh for manual override, but auto-refresh is mandatory.






okay, bro please i am getting few issue bro 1 please when i open my app its not navigating to the min page its stuk just white screen please fix now! and another issue is please fix this bro use icon.png as app icon okay appp icon oky and whic logo i prvided okay use that logo.png as a logo everywhare okay in the app please quickly please fix this or update this!