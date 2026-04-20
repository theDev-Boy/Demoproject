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


















SWITCH FROM WEBRTC TO AGORA SDK (CRITICAL)
1.1 Reason for Change
Current WebRTC implementation is failing (no audio/video transmission). Migrate entirely to Agora SDK for reliability.

1.2 Agora Integration Code (Use Exactly This Pattern)
dart
import 'package:agora_uikit/agora_uikit.dart';

final AgoraClient client = AgoraClient(
  agoraConnectionData: AgoraConnectionData(
    appId: "e7f6e9aeecf14b2ba10e3f40be9f56e7",
    channelName: "test", // DYNAMIC: Use roomId from database
    tempToken: token,    // GENERATE: From your backend server
  ),
  enabledPermission: [
    Permission.camera,
    Permission.microphone,
  ],
);

@override
void initState() {
  super.initState();
  initAgora();
}

void initAgora() async {
  await client.initialize();
}
1.3 Token Generation (Backend Requirement)
IMPORTANT: Agora requires a token for secure channels.

Task: Create a Cloud Function (Firebase) or simple Node.js endpoint that generates an Agora RTC Token using the appId and appCertificate.

Flutter Side: Before joining call, fetch token from your backend.

1.4 Feature Parity with Agora
Video Call: Use AgoraVideoViewer and AgoraVideoButtons.

Audio Call: Set videoEnabled: false in connection data.

Voice Messages: USE AGORA RECORDING SDK or use simple flutter_sound + just_audio for voice messages. Do not use Agora for voice messages - use local recording and file upload (more reliable for async messages).

PART 2: REAL VOICE MESSAGE IMPLEMENTATION
2.1 Requirements
Not fake UI. Must record actual audio and send the file.

Library: Use record: ^5.0.0 and audioplayers: ^5.2.0.

2.2 Workflow
Long Press: Start recording with AudioRecorder.

Hold: Show duration timer and waveform visualization.

Release: Stop recording, encode to .m4a or .aac.

Upload: Upload file to Firebase Storage.

Send: Save download URL in Firestore message document.

Playback: Use AudioPlayer to stream from URL.

2.3 UI Requirements for Voice Message Bubble
Display: 🎤 Icon + Duration (e.g., 0:42).

Play/Pause button with waveform animation while playing.

Seek bar to scrub through audio.

PART 3: INCOMING CALL UI (iOS STYLE) - BOTH FOREGROUND & BACKGROUND
3.1 Visual Reference (Based on Your Image)
You described/sent:

Full screen background image/blur.

Name: John Doe centered.

Status text: "Incoming call" or "Calling..." or "Ringing...".

Bottom buttons: End Call (Red) and Pick Up (Green).

3.2 Status Text Logic (Dynamic)
Scenario	Text Displayed	End Call Button	Pick Up Button
Caller - Dialing user	"Calling..."	✅ Visible	❌ Hidden
Receiver - App Open	"Incoming call"	✅ Visible	✅ Visible
Receiver - Phone Ringing (Remote)	"Ringing..."	✅ Visible	❌ Hidden
Connected (Audio)	Call Duration Timer	✅ Visible	❌ Hidden
3.3 Swipe Animation & Gesture
Pick Up: Swipe up on green button area OR tap button.

End Call: Swipe down OR tap red button.

Animation: Scale and fade transition similar to iOS native phone app.

Library Suggestion: Use flutter_phone_direct_caller or custom AnimationController with SlideTransition.

3.4 Call Connected Screen (Audio Call UI)
Elements:

Avatar of other user (large, centered).

Name of user.

Call Duration Timer (e.g., 02:34).

Action Row:

Speaker (Toggle)

Mute (Toggle)

Message (Navigates to Chat Screen with that user)

End Call (Red button)

3.5 Call Connected Screen (Video Call UI)
Elements:

Remote Video: Full screen AgoraVideoViewer (remote user).

Local Video: Small draggable PIP window AgoraVideoViewer (local user).

Action Row (Bottom):

Mute Mic

Switch Camera (Front/Back)

Toggle Camera (Video On/Off)

Message Icon (Navigates to Chat)

End Call

PART 4: BACKGROUND CALL NOTIFICATIONS (APP CLOSED/KILLED) - CRITICAL FIX
4.1 Current Problem
When app is closed, no incoming call screen appears.

4.2 Solution: Full-Screen Intent with FCM & CallKeep
Android Steps:

FCM Data Message: Server sends a high priority data payload (as described in previous PRD).

Background Handler: In firebase_messaging_background_handler, call a method to launch a Full-Screen Activity.

Full-Screen Activity: Create CallActivity.kt (Android Native) or use flutter_callkeep / callkeep package to invoke native incoming call UI.

Permission: Add SYSTEM_ALERT_WINDOW and USE_FULL_SCREEN_INTENT in manifest.

iOS Steps:

Use CallKit (integrated via flutter_callkeep).

Use VoIP Push Notifications (not standard FCM) for reliable waking.

Ensure Background Modes -> Voice over IP is checked.

4.3 Expected Behavior
User gets a full-screen ring screen (even when phone is locked/app is killed).

User taps Accept -> App opens directly to the connected call screen (Agora).

User taps Decline -> Notification dismissed, caller receives "Busy/Declined" status.

PART 5: MESSAGING NOTIFICATIONS & CHAT LIST UPDATE
5.1 Message Notifications (App Closed)
Fix: Ensure AndroidNotificationChannel importance is set to Importance.high.

Task: In FirebaseMessaging.onBackgroundMessage, call FlutterLocalNotificationsPlugin.show().

Click Action: When user taps message notification, open app directly to that specific chat.

5.2 Chat List Auto-Update
Rule: When User A sends a message to User B (first time), the conversation should immediately appear in User A's Chat List without restarting app.

Implementation: Use Firestore StreamBuilder on chats collection ordered by timestamp.

PART 6: FINAL CHECKLIST FOR AI DEVELOPER
Category	Task	Tech Stack
Audio/Video Call	Replace WebRTC with Agora	agora_uikit
Voice Message	Implement real recording & playback	record + audioplayers + Firebase Storage
Call UI	Build iOS-style incoming/ongoing screens	Custom Widgets + Animations
Background Call	FCM Data Message -> Full Screen Intent	callkeep + Native Code
Notifications	Fix app closed behavior	firebase_messaging + flutter_local_notifications
Chat Sync	Auto-refresh on all social pages	StreamBuilder


add real backround call handling callkit and keepkit and detel and removed all files of webrtc and use agora every whareand base64 if working then okay bcz we have not storgae in freabse i am in free plan thats why i have not stiarge okay thats why fro now the base.. okay and please do this





























t to re-enable it, run 'Import-Module PSReadLine'.


PS C:\flutter_app_website\Hunt-yt\Demoproject\app> flutter analyze
Analyzing app...                                                        

   info - Use 'const' with the constructor to improve performance -
          lib\screens\blocked_users_screen.dart:33:20 -
          prefer_const_constructors
   info - Use 'const' with the constructor to improve performance -
          lib\screens\blocked_users_screen.dart:33:42 -
          prefer_const_constructors
   info - Use 'const' with the constructor to improve performance -       
          lib\screens\blocked_users_screen.dart:75:19 -
          prefer_const_constructors
   info - Use 'const' with the constructor to improve performance -       
          lib\screens\blocked_users_screen.dart:75:51 -
          prefer_const_constructors
  error - The values in a const list literal must be constants -
         lib\screens\call_screen.dart:210:19 - non_constant_list_element  
  error - There's no constant named 'endCall' in 'BuiltInButtons' -       
         lib\screens\call_screen.dart:210:34 - undefined_enum_constant    
   info - Don't use 'BuildContext's across async gaps -
          lib\screens\chat_screen.dart:199:19 -
          use_build_context_synchronously
   info - Don't use 'BuildContext's across async gaps -
          lib\screens\chat_screen.dart:208:7 -
          use_build_context_synchronously
   info - Use 'const' with the constructor to improve performance -       
          lib\screens\chat_screen.dart:299:42 - prefer_const_constructors 
   info - Use 'const' with the constructor to improve performance -       
          lib\screens\chat_screen.dart:631:20 - prefer_const_constructors 
   info - Use 'const' with the constructor to improve performance -       
          lib\screens\custom_avatar_screen.dart:170:20 -
          prefer_const_constructors
   info - Use 'const' with the constructor to improve performance -       
          lib\screens\friends_screen.dart:461:33 -
          prefer_const_constructors
   info - Use 'const' with the constructor to improve performance -       
          lib\screens\messenger_screen.dart:144:38 -
          prefer_const_constructors
   info - Use 'const' with the constructor to improve performance -
          lib\screens\messenger_screen.dart:216:18 -
          prefer_const_constructors
   info - Use 'const' with the constructor to improve performance -       
          lib\screens\messenger_screen.dart:220:20 -
          prefer_const_constructors
   info - Use 'const' with the constructor to improve performance -       
          lib\screens\messenger_screen.dart:220:42 -
          prefer_const_constructors
   info - Use 'const' with the constructor to improve performance -       
          lib\screens\messenger_screen.dart:285:15 -
          prefer_const_constructors
   info - Use 'const' with the constructor to improve performance -       
          lib\screens\messenger_screen.dart:285:64 -
          prefer_const_constructors
   info - The imported package 'flutter_webrtc' isn't a dependency of the 
          importing package - lib\services\webrtc_service.dart:2:8 -      
          depend_on_referenced_packages
  error - Target of URI doesn't exist:
         'package:flutter_webrtc/flutter_webrtc.dart' -
         lib\services\webrtc_service.dart:2:8 - uri_does_not_exist        
  error - Undefined class 'MediaStream' -
         lib\services\webrtc_service.dart:8:40 - undefined_class
  error - Undefined class 'RTCPeerConnectionState' -
         lib\services\webrtc_service.dart:9:49 - undefined_class
  error - Undefined class 'RTCIceCandidate' -
         lib\services\webrtc_service.dart:10:40 - undefined_class
  error - Undefined class 'RTCPeerConnection' -
         lib\services\webrtc_service.dart:20:3 - undefined_class
  error - Undefined class 'MediaStream' -
         lib\services\webrtc_service.dart:21:3 - undefined_class
  error - Undefined class 'MediaStream' -
         lib\services\webrtc_service.dart:22:3 - undefined_class
  error - Undefined class 'MediaStream' -
         lib\services\webrtc_service.dart:35:3 - undefined_class
  error - Undefined class 'MediaStream' -
         lib\services\webrtc_service.dart:36:3 - undefined_class
  error - The name 'MediaStream' isn't a type, so it can't be used as a   
         type argument - lib\services\webrtc_service.dart:80:10 -
         non_type_as_type_argument
  error - Undefined name 'navigator' -
         lib\services\webrtc_service.dart:88:17 - undefined_identifier    
  error - The method 'createPeerConnection' isn't defined for the type    
         'WebRTCService' - lib\services\webrtc_service.dart:107:31 -      
         undefined_method
  error - Undefined name 'Helper' -
         lib\services\webrtc_service.dart:110:13 - undefined_identifier   
  error - The method 'RTCRtpTransceiverInit' isn't defined for the type   
         'WebRTCService' - lib\services\webrtc_service.dart:115:35 -      
         undefined_method
  error - Undefined name 'TransceiverDirection' -
         lib\services\webrtc_service.dart:116:24 - undefined_identifier   
  error - Undefined class 'RTCTrackEvent' -
         lib\services\webrtc_service.dart:127:35 - undefined_class        
  error - Undefined class 'RTCIceCandidate' -
         lib\services\webrtc_service.dart:136:42 - undefined_class        
  error - Undefined class 'RTCIceGatheringState' -
         lib\services\webrtc_service.dart:144:12 - undefined_class        
  error - Undefined class 'RTCIceConnectionState' -
         lib\services\webrtc_service.dart:150:12 - undefined_class        
  error - Undefined name 'RTCIceConnectionState' -
         lib\services\webrtc_service.dart:152:22 - undefined_identifier   
  error - Undefined class 'RTCPeerConnectionState' -
         lib\services\webrtc_service.dart:160:12 - undefined_class        
  error - The name 'RTCSessionDescription' isn't a type, so it can't be
         used as a type argument - lib\services\webrtc_service.dart:177:10         - non_type_as_type_argument
  error - The method 'RTCSessionDescription' isn't defined for the type   
         'WebRTCService' - lib\services\webrtc_service.dart:188:26 -      
         undefined_method
  error - The name 'RTCSessionDescription' isn't a type, so it can't be   
         used as a type argument - lib\services\webrtc_service.dart:195:10         - non_type_as_type_argument
  error - The method 'RTCSessionDescription' isn't defined for the type   
         'WebRTCService' - lib\services\webrtc_service.dart:203:27 -      
         undefined_method
  error - Undefined class 'RTCSessionDescription' -
         lib\services\webrtc_service.dart:265:37 - undefined_class        
  error - Undefined class 'RTCIceCandidate' -
         lib\services\webrtc_service.dart:271:32 - undefined_class        
  error - Undefined name 'Helper' -
         lib\services\webrtc_service.dart:309:13 - undefined_identifier   
   info - Use 'const' with the constructor to improve performance -       
          lib\widgets\custom_button.dart:44:23 - prefer_const_constructors   info - Use 'const' with the constructor to improve performance -       
          lib\widgets\offline_wrapper.dart:62:26 -
          prefer_const_constructors
   info - Use 'const' literals as arguments to constructors of
          '@immutable' classes - lib\widgets\offline_wrapper.dart:63:31 - 
          prefer_const_literals_to_create_immutables
   info - The imported package 'flutter_webrtc' isn't a dependency of the 
          importing package - lib\widgets\video_card.dart:2:8 -
          depend_on_referenced_packages
  error - Target of URI doesn't exist:
         'package:flutter_webrtc/flutter_webrtc.dart' -
         lib\widgets\video_card.dart:2:8 - uri_does_not_exist
  error - Undefined class 'RTCVideoRenderer' -
         lib\widgets\video_card.dart:6:9 - undefined_class
  error - The method 'RTCVideoView' isn't defined for the type 'VideoCard'         - lib\widgets\video_card.dart:35:16 - undefined_method
  error - Undefined name 'RTCVideoViewObjectFit' -
         lib\widgets\video_card.dart:38:22 - undefined_identifier

55 issues found. (ran in 291.5s)
PS C:\flutter_app_website\Hunt-yt\Demoproject\app> 


































rescent erorrs: 

Microsoft Windows [Version 10.0.19045.6466]                        
(c) Microsoft Corporation. All rights reserved.                    
                                                                   
C:\flutter_app_website\Hunt-yt\Demoproject\app>flutter analyze
Analyzing app...                                                        

  error - A value of type 'StreamSubscription<dynamic>' can't be assigned to a
         variable of type 'StreamSubscription<CallEvent?>?' - lib\app.dart:159:21 -
         invalid_assignment
warning - Unused import: 'package:firebase_database/firebase_database.dart' -
       lib\screens\chat_screen.dart:8:8 - unused_import
   info - The imported package 'flutter_webrtc' isn't a dependency of the importing
          package - lib\services\webrtc_service.dart:2:8 -
          depend_on_referenced_packages
  error - Target of URI doesn't exist: 'package:flutter_webrtc/flutter_webrtc.dart' -         lib\services\webrtc_service.dart:2:8 - uri_does_not_exist
  error - Undefined class 'MediaStream' - lib\services\webrtc_service.dart:8:40 -
         undefined_class
  error - Undefined class 'RTCPeerConnectionState' -
         lib\services\webrtc_service.dart:9:49 - undefined_class
  error - Undefined class 'RTCIceCandidate' - lib\services\webrtc_service.dart:10:40
         - undefined_class
  error - Undefined class 'RTCPeerConnection' - lib\services\webrtc_service.dart:20:3         - undefined_class
  error - Undefined class 'MediaStream' - lib\services\webrtc_service.dart:21:3 -
         undefined_class
  error - Undefined class 'MediaStream' - lib\services\webrtc_service.dart:22:3 -
         undefined_class
  error - Undefined class 'MediaStream' - lib\services\webrtc_service.dart:35:3 -
         undefined_class
  error - Undefined class 'MediaStream' - lib\services\webrtc_service.dart:36:3 -
         undefined_class
  error - The name 'MediaStream' isn't a type, so it can't be used as a type argument         - lib\services\webrtc_service.dart:80:10 - non_type_as_type_argument
  error - Undefined name 'navigator' - lib\services\webrtc_service.dart:88:17 -
         undefined_identifier
  error - The method 'createPeerConnection' isn't defined for the type
         'WebRTCService' - lib\services\webrtc_service.dart:107:31 - undefined_method  error - Undefined name 'Helper' - lib\services\webrtc_service.dart:110:13 -
         undefined_identifier
  error - The method 'RTCRtpTransceiverInit' isn't defined for the type
         'WebRTCService' - lib\services\webrtc_service.dart:115:35 - undefined_method  error - Undefined name 'TransceiverDirection' -
         lib\services\webrtc_service.dart:116:24 - undefined_identifier
  error - Undefined class 'RTCTrackEvent' - lib\services\webrtc_service.dart:127:35 -         undefined_class
  error - Undefined class 'RTCIceCandidate' - lib\services\webrtc_service.dart:136:42         - undefined_class
  error - Undefined class 'RTCIceGatheringState' -
         lib\services\webrtc_service.dart:144:12 - undefined_class
  error - Undefined class 'RTCIceConnectionState' -
         lib\services\webrtc_service.dart:150:12 - undefined_class
  error - Undefined name 'RTCIceConnectionState' -
         lib\services\webrtc_service.dart:152:22 - undefined_identifier
  error - Undefined class 'RTCPeerConnectionState' -
         lib\services\webrtc_service.dart:160:12 - undefined_class
  error - The name 'RTCSessionDescription' isn't a type, so it can't be used as a
         type argument - lib\services\webrtc_service.dart:177:10 -
         non_type_as_type_argument
  error - The method 'RTCSessionDescription' isn't defined for the type
         'WebRTCService' - lib\services\webrtc_service.dart:188:26 - undefined_method  error - The name 'RTCSessionDescription' isn't a type, so it can't be used as a
         type argument - lib\services\webrtc_service.dart:195:10 -
         non_type_as_type_argument
  error - The method 'RTCSessionDescription' isn't defined for the type
         'WebRTCService' - lib\services\webrtc_service.dart:203:27 - undefined_method  error - Undefined class 'RTCSessionDescription' -
         lib\services\webrtc_service.dart:265:37 - undefined_class
  error - Undefined class 'RTCIceCandidate' - lib\services\webrtc_service.dart:271:32         - undefined_class
  error - Undefined name 'Helper' - lib\services\webrtc_service.dart:309:13 -
         undefined_identifier
   info - The imported package 'flutter_webrtc' isn't a dependency of the importing
          package - lib\widgets\video_card.dart:2:8 - depend_on_referenced_packages
  error - Target of URI doesn't exist: 'package:flutter_webrtc/flutter_webrtc.dart' -         lib\widgets\video_card.dart:2:8 - uri_does_not_exist
  error - Undefined class 'RTCVideoRenderer' - lib\widgets\video_card.dart:6:9 -
         undefined_class
  error - The method 'RTCVideoView' isn't defined for the type 'VideoCard' -
         lib\widgets\video_card.dart:35:16 - undefined_method
  error - Undefined name 'RTCVideoViewObjectFit' - lib\widgets\video_card.dart:38:22
         - undefined_identifier

36 issues found. (ran in 647.3s)

C:\flutter_app_website\Hunt-yt\Demoproject\app>