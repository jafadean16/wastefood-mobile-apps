const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/* ===========================================================
   1️⃣ SEND NOTIFIKASI MANUAL KE USER
=========================================================== */
exports.sendNotificationToUser = functions.https.onCall(async (data, context) => {
  const { userId, title, body, route, payloadId } = data;

  if (!userId || !title || !body) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "userId, title, and body are required"
    );
  }

  const userDoc = await db.collection("users").doc(userId).get();
  const tokens = userDoc.data()?.fcmTokens || [];

  if (!tokens.length) {
    console.log(`⚠️ User ${userId} tidak punya FCM token`);
    return { success: false, message: "No FCM token" };
  }

  await admin.messaging().sendMulticast({
    tokens,
    notification: { title, body },
    data: {
      type: "manual",
      route: route || "",
      payloadId: payloadId || "",
      userId,
    },
  });

  console.log(`✔️ Notifikasi manual terkirim ke user ${userId}`);
  return { success: true };
});

/* ===========================================================
   2️⃣  SELLER UPDATE STOK → WATCHERS DAPAT NOTIF
=========================================================== */
exports.notifyCustomersOnStockUpdate = functions.firestore
  .document("products/{productId}")
  .onUpdate(async (change, context) => {

    const before = change.before.data();
    const after = change.after.data();

    if (before.stok === after.stok) return null;

    const productId = context.params.productId;
    const namaProduk = after.namaProduk;
    const stokBaru = after.stok;

    const watchersSnap = await db
      .collection("products")
      .doc(productId)
      .collection("watchers")
      .get();

    const tokens = [];

    watchersSnap.forEach(doc => {
      const watcher = doc.data();
      if (watcher.fcmTokens) {
        tokens.push(...watcher.fcmTokens);
      }
    });

    if (!tokens.length) {
      console.log(`⚠️ Tidak ada watchers untuk produk ${productId}`);
      return null;
    }

    await admin.messaging().sendMulticast({
      tokens,
      notification: {
        title: "Stok Produk Diperbarui",
        body: `${namaProduk} kini memiliki stok: ${stokBaru}.`,
      },
      data: {
        type: "stock-update",
        route: "/product-detail",
        productId,
      },
    });

    console.log(`✔️ Notifikasi stok → ${tokens.length} customer`);
    return true;
  });

/* ===========================================================
   3️⃣ CUSTOMER ORDER → SELLER DAPAT NOTIF
=========================================================== */
exports.notifySellerOnNewOrder = functions.firestore
  .document("pesanan/{orderId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();

    const sellerId = data.tokoId;
    const orderId = data.orderId;
    const customerId = data.userId;

    try {
      const sellerDoc = await db.collection("users").doc(sellerId).get();
      const tokens = sellerDoc.data()?.fcmTokens || [];

      if (!tokens.length) {
        console.log(`⚠️ Seller ${sellerId} tidak punya FCM token`);
        return null;
      }

      await admin.messaging().sendMulticast({
        tokens,
        notification: {
          title: "Pesanan Baru Masuk",
          body: `Order ${orderId} dari customer.`,
        },
        data: {
          type: "order-new",
          route: "/store-order-detail",
          orderId,
          customerId,
        },
      });

      console.log(`✔️ Notifikasi order → seller ${sellerId}`);
    } catch (e) {
      console.error(`❌ Gagal kirim notifikasi ke seller ${sellerId}:`, e);
    }

    return true;
  });
