const admin = require("firebase-admin");
const functions = require("firebase-functions");
const { RtcTokenBuilder, RtcRole } = require("agora-access-token");

admin.initializeApp();

function toAgoraUid(uid) {
  const parsed = Number(uid);
  if (!Number.isNaN(parsed)) return parsed;
  let hash = 0;
  for (let i = 0; i < uid.length; i += 1) {
    hash = (hash * 31 + uid.charCodeAt(i)) >>> 0;
  }
  return hash;
}

exports.generateAgoraRtcToken = functions.https.onRequest((req, res) => {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Only POST is allowed" });
  }

  const appId = process.env.AGORA_APP_ID;
  const appCertificate = process.env.AGORA_APP_CERTIFICATE;
  if (!appId || !appCertificate) {
    return res.status(500).json({ error: "Agora credentials not configured" });
  }

  const { channelName, uid, role, expireSeconds } = req.body || {};
  if (!channelName || !uid) {
    return res.status(400).json({ error: "channelName and uid are required" });
  }

  const rtcRole = role === "subscriber" ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER;
  const expiration = Math.floor(Date.now() / 1000) + (expireSeconds || 3600);
  const token = RtcTokenBuilder.buildTokenWithUid(
    appId,
    appCertificate,
    channelName,
    toAgoraUid(uid),
    rtcRole,
    expiration,
  );

  return res.status(200).json({ token, channelName, expiresAt: expiration });
});

