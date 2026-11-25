const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const crypto = require("node:crypto");

initializeApp();
const db = getFirestore();
const bootstrapCode = defineSecret("ADMIN_BOOTSTRAP_CODE");
const emailFor = (username) => `${username.toLowerCase()}@alshaikha.app`;

exports.createAdminAccount = onCall(
  { secrets: [bootstrapCode], enforceAppCheck: false },
  async (request) => {
    const username = String(request.data?.username ?? "").trim().toLowerCase();
    const password = String(request.data?.password ?? "");
    const setupCode = String(request.data?.setupCode ?? "");
    const displayName = String(request.data?.displayName ?? username).trim();

    if (!/^[a-z0-9._]{3,24}$/.test(username) || password.length < 8) {
      throw new HttpsError("invalid-argument", "اسم المستخدم غير صالح أو كلمة المرور أقصر من 8 أحرف.");
    }

    let isExistingAdmin = false;
    if (request.auth) {
      const caller = await db.collection("profiles").doc(request.auth.uid).get();
      isExistingAdmin = caller.exists && caller.data().role === "admin";
    }

    const claimRef = db.collection("system").doc("adminBootstrap");
    let bootstrapRequestId = null;
    if (!isExistingAdmin) {
      if (request.auth || !setupCode || setupCode !== bootstrapCode.value()) {
        throw new HttpsError("permission-denied", "يلزم مدير مسجل أو رمز الإعداد الأول.");
      }
      bootstrapRequestId = crypto.randomUUID();
      await db.runTransaction(async (tx) => {
        const claim = await tx.get(claimRef);
        if (claim.exists) {
          throw new HttpsError("failed-precondition", "تم إنشاء حساب الإدارة الأول مسبقاً. اطلب من مدير قائم إنشاء حسابك.");
        }
        tx.create(claimRef, {
          state: "creating",
          requestId: bootstrapRequestId,
          createdAt: FieldValue.serverTimestamp()
        });
      });
    }

    let user;
    try {
      user = await getAuth().createUser({
        email: emailFor(username),
        password,
        displayName,
        disabled: false
      });
      const profile = {
        uid: user.uid,
        username,
        displayName,
        role: "admin",
        createdAt: FieldValue.serverTimestamp(),
        createdBy: request.auth?.uid ?? "bootstrap"
      };
      const batch = db.batch();
      batch.set(db.collection("profiles").doc(user.uid), profile);
      if (bootstrapRequestId) {
        batch.update(claimRef, { state: "complete", uid: user.uid, completedAt: FieldValue.serverTimestamp() });
      }
      await batch.commit();
      return { uid: user.uid, username };
    } catch (error) {
      if (user) {
        try { await getAuth().deleteUser(user.uid); } catch (_) {}
      }
      if (bootstrapRequestId) {
        await db.runTransaction(async (tx) => {
          const claim = await tx.get(claimRef);
          if (claim.exists && claim.data().requestId === bootstrapRequestId) tx.delete(claimRef);
        });
      }
      if (error instanceof HttpsError) throw error;
      if (error.code === "auth/email-already-exists") {
        throw new HttpsError("already-exists", "اسم المستخدم مستخدم مسبقاً.");
      }
      throw new HttpsError("internal", "تعذر إنشاء الحساب الإداري.");
    }
  }
);


const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const APP_NOTIFICATION_IMAGE = "https://raw.githubusercontent.com/momenali881-lab/Alshaikha/main/client_app/file_00000000df048210b32f5dc7efa7f5ad.png";

exports.deliverAppNotification = onDocumentCreated("notifications/{notificationId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const notification = snapshot.data() || {};
  const target = String(notification.target || "");
  let profiles = [];
  if (target === "customer" && notification.customerId) {
    const profile = await db.collection("profiles").doc(String(notification.customerId)).get();
    if (profile.exists) profiles = [profile];
  } else if (target === "admin") {
    profiles = (await db.collection("profiles").where("role", "==", "admin").get()).docs;
  } else if (target === "all") {
    profiles = (await db.collection("profiles").where("role", "==", "customer").get()).docs;
  } else return;

  const owners = new Map();
  for (const profile of profiles) {
    const data = profile.data() || {};
    const tokens = Array.isArray(data.fcmTokens) ? [...data.fcmTokens] : [];
    if (data.fcmToken) tokens.push(data.fcmToken);
    for (const token of tokens) {
      if (typeof token === "string" && token.length) owners.set(token, profile.ref);
    }
  }
  const entries = [...owners.entries()];
  if (!entries.length) {
    console.log("No FCM tokens registered for", snapshot.id);
    return;
  }
  const data = {};
  for (const key of ["type","bookingId","customerId","createdBy","conversationId","target","title","body","senderName","senderImageUrl"]) {
    if (notification[key] !== undefined && notification[key] !== null) data[key] = String(notification[key]);
  }
  data.notificationId = snapshot.id;
  for (let start=0; start<entries.length; start+=500) {
    const batch=entries.slice(start,start+500);
    const result=await getMessaging().sendEachForMulticast({
      tokens:batch.map(([token])=>token),
      notification:{title:String(notification.title||"الشيخة"),body:String(notification.body||"لديك إشعار جديد")},
      data,
      android:{priority:"high",notification:{channelId:"alshaikha_notifications",sound:"default"}}
    });
    const cleanup=[];
    result.responses.forEach((response,index)=>{
      if(!response.success && ["messaging/registration-token-not-registered","messaging/invalid-registration-token"].includes(response.error?.code)){
        const [token,owner]=batch[index];
        cleanup.push(owner.update({fcmTokens:FieldValue.arrayRemove(token)}));
      }
    });
    await Promise.all(cleanup);
  }
});
