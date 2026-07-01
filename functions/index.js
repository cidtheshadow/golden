/**
 * Golden Care — Firebase Cloud Functions
 *
 * These functions keep private API keys and privileged operations server-side.
 * The Flutter client NEVER holds private/secret keys.
 */

const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

admin.initializeApp();

const MAPS_PLATFORM_API_KEY = defineSecret("MAPS_PLATFORM_API_KEY");
const MAPS_PLACES_GEOCODE_API_KEY = defineSecret("MAPS_PLACES_GEOCODE_API_KEY");
const MAPS_GEOCODING_SERVER_API_KEY = defineSecret("MAPS_GEOCODING_SERVER_API_KEY");
// Define separate secrets for live and test Razorpay credentials.
const RAZORPAY_KEY_ID_LIVE = defineSecret("RAZORPAY_KEY_ID_LIVE");
const RAZORPAY_KEY_SECRET_LIVE = defineSecret("RAZORPAY_KEY_SECRET_LIVE");
const RAZORPAY_KEY_ID_TEST = defineSecret("RAZORPAY_KEY_ID_TEST");
const RAZORPAY_KEY_SECRET_TEST = defineSecret("RAZORPAY_KEY_SECRET_TEST");
const RAZORPAY_WEBHOOK_SECRET = defineSecret("RAZORPAY_WEBHOOK_SECRET");
// Public client-facing keys (stored in Secret Manager but safe to return)
const VAPID_KEY = defineSecret("VAPID_KEY");
const RECAPTCHA_SITE_KEY = defineSecret("RECAPTCHA_SITE_KEY");
const Razorpay = require("razorpay");
const crypto = require("crypto");
const {
  DEFAULT_REFUND_POLICY,
  determineCancellationTransition,
} = require("./lib/refund_logic");

function clampWords(input, maxWords) {
  const words = String(input || "")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (words.length <= maxWords) {
    return words.join(" ");
  }
  return words.slice(0, maxWords).join(" ");
}

function requireSecret(secretParam, message) {
  const value = secretParam.value();
  if (!value) {
    throw new HttpsError("failed-precondition", message);
  }
  return value;
}

// Determine project id at runtime to choose live vs test credentials.
function getProjectId() {
  try {
    if (process.env.GCLOUD_PROJECT) return process.env.GCLOUD_PROJECT;
    if (process.env.GCP_PROJECT) return process.env.GCP_PROJECT;
    if (process.env.FIREBASE_CONFIG) {
      const cfg = JSON.parse(process.env.FIREBASE_CONFIG || '{}');
      if (cfg && cfg.projectId) return cfg.projectId;
    }
  } catch (e) {
    console.warn('getProjectId: failed to parse environment', e);
  }
  return '';
}

function isProductionProject() {
  const pid = getProjectId().toLowerCase();
  // Adjust rules here if your production projectId differs.
  return pid === 'golden-care-d4863' || pid.includes('production') || pid.includes('prod');
}

function detectRuntimeMode(request) {
  // 1) Explicit env override (set during deployment if you want function-wide mode)
  const forced = (process.env.RAZORPAY_FORCE_MODE || '').toLowerCase();
  if (forced === 'live' || forced === 'test') return forced;

  // 2) Inspect caller origin (for web hosting). If origin contains 'test' treat as test mode.
  try {
    const req = request && request.rawRequest ? request.rawRequest : null;
    const headers = req && req.headers ? req.headers : {};
    const origin = (headers.origin || headers.referer || headers.host || '').toLowerCase();
    if (origin) {
      // If origin contains common test identifiers, prefer test mode
      const testIndicators = ['test', 'testing', 'staging', 'localhost', '.dev'];
      for (const t of testIndicators) {
        if (origin.includes(t)) return 'test';
      }
      // Otherwise treat as production/live
      return 'live';
    }
  } catch (e) {
    console.warn('detectRuntimeMode: failed to inspect request headers', e);
  }

  // 3) Fallback to project id heuristic: if project looks like prod, use live else test
  return isProductionProject() ? 'live' : 'test';
}

function getRazorpayCredentials(request) {
  const mode = detectRuntimeMode(request);
  if (mode === 'live') {
    const keyId = RAZORPAY_KEY_ID_LIVE.value();
    const keySecret = RAZORPAY_KEY_SECRET_LIVE.value();
    if (!keyId || !keySecret) {
      throw new HttpsError('failed-precondition', 'Razorpay LIVE credentials not configured for production.');
    }
    return { keyId, keySecret, mode: 'live' };
  }

  const keyId = RAZORPAY_KEY_ID_TEST.value();
  const keySecret = RAZORPAY_KEY_SECRET_TEST.value();
  if (!keyId || !keySecret) {
    throw new HttpsError('failed-precondition', 'Razorpay TEST credentials not configured.');
  }
  return { keyId, keySecret, mode: 'test' };
}

function parseAmountToPaise(value) {
  const num = Number(value || 0);
  if (!Number.isFinite(num) || num <= 0) {
    return 0;
  }
  return Math.round(num * 100);
}

function getLiveServiceAmountPaise(serviceData, booking) {
  if (!serviceData || typeof serviceData !== "object") {
    return 0;
  }

  const bookingDuration = String(booking.duration || "").trim().toLowerCase();
  const options = Array.isArray(serviceData.options) ? serviceData.options : [];
  if (bookingDuration && options.length > 0) {
    const matched = options.find((opt) => {
      const duration = String(opt?.duration || "").trim().toLowerCase();
      return duration && duration === bookingDuration;
    });
    if (matched) {
      return parseAmountToPaise(matched.price);
    }
  }

  return parseAmountToPaise(serviceData.price);
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifications helpers (in-app + push)
// ─────────────────────────────────────────────────────────────────────────────
async function saveNotification(uid, type, title, body, bookingId = null) {
  try {
    const db = admin.firestore();
    const ref = db
      .collection("users")
      .doc(uid)
      .collection("notifications")
      .doc();

    await ref.set({
      id: ref.id,
      type,
      title,
      body,
      bookingId: bookingId || null,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      readAt: null,
      expiresAt: null,
    });
  } catch (error) {
    console.error("[saveNotification] Error:", error);
  }
}

async function sendPushNotification(
  uid,
  title,
  body,
  type,
  bookingId = null,
  data = {}
) {
  try {
    const db = admin.firestore();
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data() || {};
    const token = userData.fcmToken;

    // Always keep in-app notification history, even when push token is absent.
    await saveNotification(uid, type, title, body, bookingId);

    if (!token || typeof token !== "string" || token.length < 10) {
      return;
    }

    const message = {
      token,
      notification: { title, body },
      data: {
        type,
        bookingId: bookingId || "",
        ...Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v)])
        ),
      },
      webpush: {
        notification: {
          title,
          body,
          icon: "/icons/Icon-192.png",
          badge: "/icons/Icon-192.png",
          requireInteraction: false,
        },
        fcmOptions: {
          link: bookingId ? `/booking-details/${bookingId}` : "/",
        },
      },
      android: {
        notification: {
          channelId: "goldencare_default",
          sound: "default",
        },
      },
    };

    await admin.messaging().send(message);
  } catch (error) {
    const code = error?.code || "";
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      try {
        await admin.firestore().collection("users").doc(uid).update({ fcmToken: null });
      } catch (_) {
        // Keep notification flow non-blocking.
      }
    }
    console.error("[sendPushNotification] Error:", error?.message || error);
  }
}

function buildLocationFallback() {
  return {
    address: "Location selected",
    formatted: "",
    components: {},
    street: "",
    subLocality: "",
    locality: "",
    administrativeArea: "",
    subAdministrativeArea: "",
    postalCode: "",
    country: "",
  };
}

function mapAddressComponents(components = []) {
  const mapped = {};
  for (const comp of components) {
    const value = comp.long_name || comp.longText || comp.short_name || comp.shortText || "";
    if (!value) {
      continue;
    }
    for (const type of comp.types || []) {
      if (!mapped[type]) {
        mapped[type] = value;
      }
    }
  }
  return mapped;
}

function buildGeocodePayload(result, components) {
  const primaryLine = components.street_number && components.route
    ? `${components.street_number} ${components.route}`
    : components.route || components.premise || components.subpremise || null;
  const addressParts = [
    primaryLine,
    components.premise && components.premise !== primaryLine
      ? components.premise
      : null,
    components.subpremise && components.subpremise !== primaryLine
      ? components.subpremise
      : null,
    components.neighborhood || null,
    components.sublocality_level_2 || null,
    components.sublocality_level_1 || components.sublocality || null,
    components.locality || null,
    components.administrative_area_level_2 || null,
  ]
    .filter(Boolean)
    .map((part) => part.trim())
    .filter((part) => part.length > 0 && !part.endsWith(":"));

  const seen = new Set();
  const uniqueParts = addressParts.filter((part) => {
    const key = part.toLowerCase().trim();
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });

  return {
    address: uniqueParts.length > 0
      ? uniqueParts.join(", ")
      : (result.formatted_address || "Location selected"),
    formatted: result.formatted_address || "",
    components,
    street: primaryLine || "",
    subLocality: components.sublocality_level_1 ||
      components.sublocality ||
      components.neighborhood ||
      "",
    locality: components.locality || "",
    administrativeArea: components.administrative_area_level_1 || "",
    subAdministrativeArea: components.administrative_area_level_2 || "",
    postalCode: components.postal_code || "",
    country: components.country || "",
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. geocodeAddress — Reverse-geocode lat/lng WITHOUT exposing the Maps key
// ─────────────────────────────────────────────────────────────────────────────
exports.geocodeAddress = onCall(
  {
    enforceAppCheck: false,
    cors: true,
    secrets: [MAPS_GEOCODING_SERVER_API_KEY],
  },
  async (request) => {
    const latitude = request.data?.latitude ?? request.data?.lat;
    const longitude = request.data?.longitude ?? request.data?.lng;
    if (
      typeof latitude !== "number" ||
      typeof longitude !== "number" ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Valid latitude (-90..90) and longitude (-180..180) are required."
      );
    }

    const apiKey = requireSecret(
      MAPS_GEOCODING_SERVER_API_KEY,
      "Geocoding service is not configured."
    );

    const url =
      `https://maps.googleapis.com/maps/api/geocode/json` +
      `?latlng=${latitude},${longitude}` +
      `&key=${apiKey}` +
      `&language=en` +
      `&result_type=street_address|premise|subpremise|` +
      `sublocality_level_1|sublocality|locality`;

    try {
      const response = await fetch(url);
      const data = await response.json();

      if (data.status !== "OK" || !data.results || data.results.length === 0) {
        console.error(
          "[geocode] API error:",
          data.status,
          data.error_message || ""
        );
        return buildLocationFallback();
      }

      const preferredTypes = [
        "street_address",
        "premise",
        "subpremise",
        "route",
        "sublocality_level_2",
        "sublocality_level_1",
        "sublocality",
        "locality",
      ];

      let bestResult = data.results[0];
      for (const type of preferredTypes) {
        const match = data.results.find((item) => item.types?.includes(type));
        if (match) {
          bestResult = match;
          break;
        }
      }

      const components = mapAddressComponents(bestResult.address_components || []);
      const payload = buildGeocodePayload(bestResult, components);
      console.log("[geocode] Result:", payload.address);
      return payload;
    } catch (err) {
      console.error("Geocoding API error:", err);
      throw new HttpsError("internal", "Geocoding request failed.");
    }
  }
);

// Public config callable: returns only public, non-secret values the client needs.
// This callable intentionally does NOT return any secret values (like Razorpay key secrets
// or server-side Maps keys). It only returns publishable/public identifiers (maps platform
// key, recaptcha site key, vapid key, razorpay publishable key id for the detected mode).
exports.getPublicConfig = onCall(
  {
    enforceAppCheck: false,
    cors: true,
    // Only declare the public-facing secrets / key-ids we will read here.
    secrets: [MAPS_PLATFORM_API_KEY, RECAPTCHA_SITE_KEY, VAPID_KEY, RAZORPAY_KEY_ID_LIVE, RAZORPAY_KEY_ID_TEST],
  },
  async (request) => {
    try {
      // Detect runtime mode (live/test) for selecting publishable Razorpay key id
      const mode = detectRuntimeMode(request);

      const mapsKey = MAPS_PLATFORM_API_KEY.value() || '';
      const recaptcha = RECAPTCHA_SITE_KEY.value() || '';
      const vapid = VAPID_KEY.value() || '';

      let razorpayKeyId = '';
      if (mode === 'live') {
        razorpayKeyId = RAZORPAY_KEY_ID_LIVE.value() || '';
      } else {
        razorpayKeyId = RAZORPAY_KEY_ID_TEST.value() || '';
      }

      // Only return publishable identifiers. Do NOT include any secret values.
      return {
        mapsPlatformKey: mapsKey,
        recaptchaSiteKey: recaptcha,
        vapidKey: vapid,
        razorpayKeyId,
        mode,
      };
    } catch (err) {
      console.error('[getPublicConfig] error:', err);
      throw new HttpsError('internal', 'Failed to read public config');
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// placeSearch — Google Places Autocomplete without exposing API key
// ─────────────────────────────────────────────────────────────────────────────
exports.placeSearch = onCall(
  {
    enforceAppCheck: false,
    cors: true,
    secrets: [MAPS_PLACES_GEOCODE_API_KEY],
  },
  async (request) => {
    const input = String(request.data?.input || "").trim();
    if (input.length < 2) {
      throw new HttpsError("invalid-argument", "input must be at least 2 characters");
    }

    const apiKey = requireSecret(
      MAPS_PLACES_GEOCODE_API_KEY,
      "Places search service is not configured."
    );

    const sessionToken = String(request.data?.sessionToken || "").trim();
    const rawLatitude = request.data?.latitude;
    const rawLongitude = request.data?.longitude;
    const latitude = Number(rawLatitude);
    const longitude = Number(rawLongitude);
    const latitudeProvided = rawLatitude !== undefined && rawLatitude !== null;
    const longitudeProvided = rawLongitude !== undefined && rawLongitude !== null;
    if ((latitudeProvided && !Number.isFinite(latitude)) || (longitudeProvided && !Number.isFinite(longitude))) {
      throw new HttpsError("invalid-argument", "latitude/longitude must be valid numbers");
    }
    const hasBiasPoint =
      Number.isFinite(latitude) &&
      Number.isFinite(longitude) &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

    const payload = {
      input,
      languageCode: "en",
      regionCode: "IN",
      includeQueryPredictions: false,
      ...(sessionToken ? { sessionToken } : {}),
      ...(hasBiasPoint
        ? {
          locationBias: {
            circle: {
              center: {
                latitude,
                longitude,
              },
              radius: 50000,
            },
          },
        }
        : {}),
    };

    try {
      const response = await fetch(
        "https://places.googleapis.com/v1/places:autocomplete",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": apiKey,
            "X-Goog-FieldMask": [
              "suggestions.placePrediction.placeId",
              "suggestions.placePrediction.text.text",
              "suggestions.placePrediction.structuredFormat.mainText.text",
              "suggestions.placePrediction.structuredFormat.secondaryText.text",
            ].join(","),
          },
          body: JSON.stringify(payload),
        }
      );
      const data = await response.json();

      if (!response.ok) {
        const upstreamMessage = data?.error?.message || "Unknown Places API error";
        // Keep full upstream reason in server logs for diagnostics.
        console.error("Maps API Error:", data || upstreamMessage);
        if (response.status >= 400 && response.status < 500) {
          throw new HttpsError("internal", "Place search failed", {
            status: response.status,
            upstream: upstreamMessage,
          });
        }
        throw new HttpsError("internal", "Place search failed", {
          status: response.status,
          upstream: upstreamMessage,
        });
      }

      const predictions = (data.suggestions || [])
        .map((item) => item.placePrediction)
        .filter(Boolean)
        .slice(0, 7)
        .map((item) => ({
          placeId: item.placeId || "",
          description: item.text?.text || "",
          mainText: item.structuredFormat?.mainText?.text || "",
          secondaryText: item.structuredFormat?.secondaryText?.text || "",
        }))
        .filter((item) => item.placeId.length > 0);

      return { predictions };
    } catch (error) {
      console.error("Maps API Error:", error?.response?.data || error?.message || error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError("internal", "Place search failed");
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// resolvePlaceLocation — resolve place_id to coordinates + formatted address
// ─────────────────────────────────────────────────────────────────────────────
exports.resolvePlaceLocation = onCall(
  {
    enforceAppCheck: false,
    cors: true,
    secrets: [MAPS_GEOCODING_SERVER_API_KEY],
  },
  async (request) => {
    const rawPlaceId = String(request.data?.placeId || "").trim();
    if (!rawPlaceId) {
      throw new HttpsError("invalid-argument", "placeId is required");
    }
    const placeId = rawPlaceId.startsWith("places/")
      ? rawPlaceId.substring("places/".length)
      : rawPlaceId;
    const placeResource = `places/${placeId}`;

    const apiKey = requireSecret(
      MAPS_GEOCODING_SERVER_API_KEY,
      "Place resolver service is not configured."
    );

    const sessionToken = String(request.data?.sessionToken || "").trim();
    const url =
      `https://places.googleapis.com/v1/${placeResource}` +
      `?languageCode=en&regionCode=IN` +
      (sessionToken ? `&sessionToken=${encodeURIComponent(sessionToken)}` : "");

    try {
      const response = await fetch(url, {
        method: "GET",
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": apiKey,
          "X-Goog-FieldMask": "id,displayName.text,formattedAddress,location,addressComponents",
        },
      });
      const data = await response.json();

      if (!response.ok || !data) {
        const upstreamMessage = data?.error?.message || "Unknown Places API error";
        console.error("Maps API Error:", data || upstreamMessage);
        throw new HttpsError("internal", "Place details lookup failed", {
          status: response.status,
          upstream: upstreamMessage,
        });
      }

      const result = data;
      const location = result.location;
      if (!location || typeof location.latitude !== "number" || typeof location.longitude !== "number") {
        throw new HttpsError("internal", "Place details missing coordinates");
      }

      const components = mapAddressComponents(result.addressComponents || []);
      const payload = buildGeocodePayload(
        {
          formatted_address: result.formattedAddress || "",
        },
        components
      );

      return {
        placeId: result.id || placeId,
        name: result.displayName?.text || "",
        latitude: location.latitude,
        longitude: location.longitude,
        formattedAddress: result.formattedAddress || payload.formatted || payload.address,
        address: payload.address,
        components: payload.components,
      };
    } catch (error) {
      console.error("Maps API Error:", error?.response?.data || error?.message || error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError("internal", "Place details lookup failed");
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 2. checkWhitelistStatus — Check if an email is whitelisted WITHOUT exposing
//    the full whitelisted_partners collection to the client.
// ─────────────────────────────────────────────────────────────────────────────
exports.checkWhitelistStatus = onCall(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request) => {
    const { email } = request.data;

    if (!email || typeof email !== "string") {
      throw new HttpsError("invalid-argument", "A valid email is required.");
    }

    const normalizedEmail = email.trim().toLowerCase();
    const doc = await admin
      .firestore()
      .collection("whitelisted_partners")
      .doc(normalizedEmail)
      .get();
    const data = doc.exists ? (doc.data() || {}) : null;
    const isActive = data?.isActive;
    const isEnabled = data?.isEnabled;

    const isWhitelisted = doc.exists && (
      isActive === true ||
      isEnabled === true ||
      (typeof isActive !== "boolean" && typeof isEnabled !== "boolean")
    );

    return { isWhitelisted };
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 3. createNotification — Only the server may create notifications, preventing
//    any authenticated user from spamming another user's notification feed.
// ─────────────────────────────────────────────────────────────────────────────
exports.createNotification = onCall(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const { targetUserId, title, body, type, targetId, collection } = request.data;

    if (!targetUserId || !title || !body) {
      throw new HttpsError(
        "invalid-argument",
        "targetUserId, title, and body are required."
      );
    }

    const allowedCollections = ["users", "servicePersonnel"];
    const col = allowedCollections.includes(collection) ? collection : "users";

    // Verify the caller is allowed to send this notification:
    // - The caller is the booking owner or assigned caregiver
    // - OR the caller is an admin
    const callerUid = request.auth.uid;
    const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
    const callerRole = callerDoc.exists ? callerDoc.data().role : null;

    // Allow: admins can send to anyone; users can only send notifications
    // related to bookings they own or are assigned to.
    if (callerRole !== "admin") {
      if (!targetId || typeof targetId !== "string") {
        throw new HttpsError(
          "permission-denied",
          "Non-admin notifications must reference a booking."
        );
      }

      const bookingDoc = await admin.firestore().collection("bookings").doc(targetId).get();
      if (!bookingDoc.exists) {
        throw new HttpsError(
          "not-found",
          "Booking not found for notification target."
        );
      }

      const booking = bookingDoc.data() || {};
      if (booking.userId !== callerUid && booking.servicePersonnelId !== callerUid) {
        throw new HttpsError(
          "permission-denied",
          "You are not authorized to send this notification."
        );
      }
    }

    const docRef = admin
      .firestore()
      .collection(col)
      .doc(targetUserId)
      .collection("notifications")
      .doc();

    await docRef.set({
      id: docRef.id,
      userId: targetUserId,
      title,
      body,
      type: type || "system",
      targetId: targetId || null,
      isRead: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, notificationId: docRef.id };
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// markNotificationRead — mark one notification read and set expiry (+7 days)
// ─────────────────────────────────────────────────────────────────────────────
exports.markNotificationRead = onCall(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const notificationId = request.data?.notificationId;
    if (!notificationId || typeof notificationId !== "string") {
      throw new HttpsError("invalid-argument", "notificationId required");
    }

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    await admin
      .firestore()
      .collection("users")
      .doc(request.auth.uid)
      .collection("notifications")
      .doc(notificationId)
      .update({
        isRead: true,
        readAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      });

    return { success: true };
  }
);

// Backwards-compatible batched mark-read callable.
// Accepts either `notificationId` (string) or `notificationIds` (array of strings),
// and optional `collection` ('users' | 'servicePersonnel'). Uses admin SDK to
// perform server-side writes so Firestore rules do not block the operation.
exports.markNotificationsRead = onCall(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const rawIds = request.data?.notificationIds || (request.data?.notificationId ? [request.data.notificationId] : []);
    if (!Array.isArray(rawIds) || rawIds.length === 0) {
      throw new HttpsError("invalid-argument", "notificationIds required");
    }

    const collection = request.data?.collection === 'servicePersonnel' ? 'servicePersonnel' : 'users';
    const uid = request.auth.uid;
    const db = admin.firestore();

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    try {
      const chunkSize = 200;
      for (let i = 0; i < rawIds.length; i += chunkSize) {
        const chunk = rawIds.slice(i, i + chunkSize);
        const batch = db.batch();
        for (const id of chunk) {
          if (!id || typeof id !== 'string') continue;
          const ref = db.collection(collection).doc(uid).collection('notifications').doc(id);
          batch.set(ref, {
            isRead: true,
            readAt: admin.firestore.FieldValue.serverTimestamp(),
            expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
          }, { merge: true });
        }
        await batch.commit();
      }
      return { success: true, updated: rawIds.length };
    } catch (err) {
      console.error('[markNotificationsRead] Error:', err);
      throw new HttpsError('internal', 'Failed to mark notifications read');
    }
  }
);
/**
 * Payment Handler Functions for Razorpay Integration
 * These functions are exported and used by the main index.js
 */

// ─────────────────────────────────────────────────────────────────────────────
// 1. createRazorpayOrder — Create a Razorpay order for payment
// ─────────────────────────────────────────────────────────────────────────────
exports.createRazorpayOrder = onCall(
  {
    // Web App Check attestation can intermittently fail and block payments.
    // Keep auth enforcement via request.auth and booking ownership checks.
    enforceAppCheck: false,
    cors: true,
    secrets: [
      RAZORPAY_KEY_ID_LIVE,
      RAZORPAY_KEY_SECRET_LIVE,
      RAZORPAY_KEY_ID_TEST,
      RAZORPAY_KEY_SECRET_TEST,
    ],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const data = request.data || {};
    const { bookingId } = data;
    // Server decides mode by origin/project; ignore unauthorised client requests.
    let keyMode = String(data.keyMode || "").toLowerCase();
    const detectedMode = detectRuntimeMode(request);
    const isAdmin = !!(request.auth && request.auth.token && request.auth.token.admin);
    if (keyMode && keyMode !== detectedMode) {
      if (isAdmin) {
        console.warn(`[createRazorpayOrder] Admin requested keyMode='${keyMode}' overriding detected='${detectedMode}'`);
      } else {
        console.warn(`[createRazorpayOrder] Ignoring client keyMode='${keyMode}' and using detected='${detectedMode}'`);
        keyMode = detectedMode;
      }
    }
    if (!keyMode) keyMode = detectedMode;

    if (!bookingId || typeof bookingId !== "string") {
      throw new HttpsError("invalid-argument", "Invalid bookingId.");
    }

    try {
      const db = admin.firestore();
      const bookingRef = db.collection("bookings").doc(bookingId);
      const bookingDoc = await bookingRef.get();

      if (!bookingDoc.exists) {
        throw new HttpsError("not-found", "Booking not found.");
      }

      const booking = bookingDoc.data() || {};
      if (booking.userId !== request.auth.uid) {
        throw new HttpsError("permission-denied", "This booking is not yours.");
      }

      if (booking.paymentStatus === "paid") {
        throw new HttpsError(
          "failed-precondition",
          "Booking has already been paid for."
        );
      }

      if (!booking.serviceId || typeof booking.serviceId !== "string") {
        throw new HttpsError("failed-precondition", "Booking is missing a valid service reference.");
      }

      const serviceDoc = await db.collection("services").doc(booking.serviceId).get();
      if (!serviceDoc.exists) {
        throw new HttpsError("failed-precondition", "Service no longer exists for this booking.");
      }

      const liveAmountPaise = getLiveServiceAmountPaise(serviceDoc.data() || {}, booking);
      if (liveAmountPaise <= 0) {
        throw new HttpsError("failed-precondition", "Unable to resolve live service pricing.");
      }

      const bookingAmountPaise = parseAmountToPaise(booking.price || booking.amount);
      if (bookingAmountPaise !== liveAmountPaise) {
        await bookingRef.set(
          {
            price: liveAmountPaise / 100,
            amount: liveAmountPaise / 100,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        throw new HttpsError(
          "failed-precondition",
          "PRICE_CHANGED",
          {
            code: "PRICE_CHANGED",
            latestAmount: liveAmountPaise / 100,
            previousAmount: bookingAmountPaise / 100,
          }
        );
      }

      const creds = getRazorpayCredentials(request);
      const keyId = creds.keyId;
      const keySecret = creds.keySecret;

      if (keyMode === "live" && keyId.startsWith("rzp_test_")) {
        throw new HttpsError(
          "failed-precondition",
          "Razorpay server is configured in test mode. Please set live payment secrets."
        );
      }

      if (keyMode === "test" && keyId.startsWith("rzp_live_")) {
        throw new HttpsError(
          "failed-precondition",
          "Razorpay server is configured in live mode for a testing build."
        );
      }

      // Idempotency guard: reuse recent pending/created order for this booking.
      const pendingWindowMs = 15 * 60 * 1000;
      const nowMs = Date.now();
      const reusableQuery = await db
        .collection("transactions")
        .where("bookingId", "==", bookingId)
        .limit(20)
        .get();

      const reusableTx = reusableQuery.docs.find((doc) => {
        const tx = doc.data() || {};
        const status = String(tx.status || "").toLowerCase();
        const paymentStatus = String(tx.paymentStatus || "").toLowerCase();
        const createdAt = tx.createdAt && typeof tx.createdAt.toDate === "function"
          ? tx.createdAt.toDate().getTime()
          : 0;
        const isPending = ["created", "pending", "payment_initiated"].includes(status) ||
          ["pending", "pending_payment", "initiated"].includes(paymentStatus);
        const isFresh = createdAt > 0 && (nowMs - createdAt) <= pendingWindowMs;
        const txAmount = Number(tx.amount || 0);
        return isPending && isFresh && !!tx.providerOrderId && txAmount === liveAmountPaise;
      });

      if (reusableTx) {
        const tx = reusableTx.data() || {};
        await db.runTransaction(async (t) => {
          const bookingSnap = await t.get(bookingRef);
          if (!bookingSnap.exists) {
            throw new HttpsError("not-found", "Booking not found.");
          }
          t.update(bookingRef, {
            transactionId: reusableTx.id,
            paymentStatus: "pending_payment",
            status: "pending_payment",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        return {
          orderId: tx.providerOrderId,
          transactionId: reusableTx.id,
          amount: tx.amount || liveAmountPaise,
          currency: tx.currency || "INR",
          keyId,
          reused: true,
        };
      }

      const razorpay = new Razorpay({
        key_id: keyId,
        key_secret: keySecret,
      });

      const orderAmount = liveAmountPaise;
      const orderData = await razorpay.orders.create({
        amount: orderAmount,
        currency: "INR",
        receipt: bookingId,
        notes: {
          bookingId,
          userId: request.auth.uid,
        },
      });

      const transactionRef = db.collection("transactions").doc();
      const platformFeeInPaise = Math.round(orderAmount * 0.02);
      let returnExisting = null;

      await db.runTransaction(async (t) => {
        const freshBookingSnap = await t.get(bookingRef);
        if (!freshBookingSnap.exists) {
          throw new HttpsError("not-found", "Booking not found.");
        }

        const freshBooking = freshBookingSnap.data() || {};
        if (freshBooking.userId !== request.auth.uid) {
          throw new HttpsError("permission-denied", "This booking is not yours.");
        }
        if (freshBooking.paymentStatus === "paid") {
          throw new HttpsError(
            "failed-precondition",
            "Booking has already been paid for."
          );
        }

        const activeTransactionId = freshBooking.transactionId;
        if (activeTransactionId) {
          const activeRef = db.collection("transactions").doc(activeTransactionId);
          const activeSnap = await t.get(activeRef);
          if (activeSnap.exists) {
            const activeTx = activeSnap.data() || {};
            const activeStatus = String(activeTx.status || "").toLowerCase();
            const activePaymentStatus = String(activeTx.paymentStatus || "").toLowerCase();
            const activeCreatedAt = activeTx.createdAt && typeof activeTx.createdAt.toDate === "function"
              ? activeTx.createdAt.toDate().getTime()
              : 0;
            const isActivePending = ["created", "pending", "payment_initiated"].includes(activeStatus) ||
              ["pending", "pending_payment", "initiated"].includes(activePaymentStatus);
            const isActiveFresh = activeCreatedAt > 0 && (Date.now() - activeCreatedAt) <= pendingWindowMs;
            if (isActivePending && isActiveFresh && activeTx.providerOrderId) {
              returnExisting = {
                orderId: activeTx.providerOrderId,
                transactionId: activeRef.id,
                amount: activeTx.amount || orderAmount,
                currency: activeTx.currency || "INR",
                keyId,
                reused: true,
              };
              t.update(bookingRef, {
                paymentStatus: "pending_payment",
                status: "pending_payment",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              return;
            }
          }
        }

        t.set(transactionRef, {
          transactionId: transactionRef.id,
          referenceType: "booking",
          referenceId: bookingId,
          bookingId,
          userId: request.auth.uid,
          servicePersonnelId: freshBooking.servicePersonnelId || null,
          amount: orderAmount,
          amountDisplay: orderAmount / 100,
          currency: "INR",
          status: "payment_initiated",
          paymentStatus: "pending_payment",
          provider: "razorpay",
          providerOrderId: orderData.id,
          providerPaymentId: null,
          providerSignature: null,
          platformFee: platformFeeInPaise,
          platformFeeDisplay: platformFeeInPaise / 100,
          platformFeePercent: 2,
          metadata: {
            serviceId: freshBooking.serviceId || "",
            serviceName: freshBooking.serviceName || freshBooking.serviceType || "",
            bookingDate: freshBooking.date || null,
            duration: freshBooking.duration || "",
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        t.update(bookingRef, {
          transactionId: transactionRef.id,
          paymentStatus: "pending_payment",
          status: "pending_payment",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      if (returnExisting) {
        return returnExisting;
      }

      return {
        orderId: orderData.id,
        transactionId: transactionRef.id,
        amount: orderAmount,
        currency: "INR",
        keyId,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error("createRazorpayOrder error:", err);
      throw new HttpsError("internal", "Failed to create order.");
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 2. verifyRazorpayPayment — Verify payment signature and update booking
// ─────────────────────────────────────────────────────────────────────────────
exports.verifyRazorpayPayment = onCall(
  {
    // Keep consistent with createRazorpayOrder for reliable web payments.
    enforceAppCheck: false,
    cors: true,
    secrets: [
      RAZORPAY_KEY_ID_LIVE,
      RAZORPAY_KEY_SECRET_LIVE,
      RAZORPAY_KEY_ID_TEST,
      RAZORPAY_KEY_SECRET_TEST,
    ],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const { transactionId, orderId, paymentId, signature } = request.data;

    if (!transactionId || !orderId || !paymentId || !signature) {
      throw new HttpsError(
        "invalid-argument",
        "transactionId, orderId, paymentId, and signature are required."
      );
    }

    try {
      const db = admin.firestore();
      const creds = getRazorpayCredentials(request);
      const keySecret = creds.keySecret;

      const transactionRef = db.collection("transactions").doc(transactionId);

      // Verify signature using HMAC-SHA256.
      const body = `${orderId}|${paymentId}`;
      const expectedSignature = crypto
        .createHmac("sha256", keySecret)
        .update(body)
        .digest("hex");
      const signatureMatches = safeCompareHex(expectedSignature, signature);

      let paymentMethod = "unknown";
      if (signatureMatches) {
        try {
          const keyId = creds.keyId;
          const razorpay = new Razorpay({
            key_id: keyId,
            key_secret: keySecret,
          });
          const paymentDetails = await razorpay.payments.fetch(paymentId);
          paymentMethod = paymentDetails.method || "unknown";
        } catch (e) {
          console.log("[verifyPayment] Could not fetch method:", e);
        }
      }

      const result = {
        bookingId: null,
        familyUid: null,
        caregiverUid: null,
        alreadyCaptured: false,
        invalidSignature: false,
      };

      await db.runTransaction(async (t) => {
        const transactionSnap = await t.get(transactionRef);
        if (!transactionSnap.exists) {
          throw new HttpsError("not-found", "Transaction not found.");
        }

        const transaction = transactionSnap.data() || {};
        if (transaction.userId !== request.auth.uid) {
          throw new HttpsError(
            "permission-denied",
            "This transaction is not yours."
          );
        }

        if (transaction.providerOrderId !== orderId) {
          throw new HttpsError(
            "invalid-argument",
            "Order ID does not match the transaction."
          );
        }

        const bookingId = transaction.referenceId || transaction.bookingId;
        if (!bookingId) {
          throw new HttpsError("not-found", "Booking not found.");
        }

        const bookingRef = db.collection("bookings").doc(bookingId);
        const bookingSnap = await t.get(bookingRef);
        if (!bookingSnap.exists) {
          throw new HttpsError("not-found", "Booking not found.");
        }

        const booking = bookingSnap.data() || {};
        result.bookingId = bookingId;
        result.familyUid = booking.userId || transaction.userId || null;
        result.caregiverUid =
          booking.servicePersonnelId || booking.caregiverId || transaction.servicePersonnelId || null;

        const alreadyPaid =
          transaction.status === "captured" ||
          transaction.paymentStatus === "captured" ||
          booking.paymentStatus === "paid";

        if (alreadyPaid) {
          result.alreadyCaptured = true;
          return;
        }

        if (!signatureMatches) {
          t.update(transactionRef, {
            status: "failed",
            paymentStatus: "failed",
            providerPaymentId: paymentId,
            providerSignature: signature,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          t.update(bookingRef, {
            paymentStatus: "failed",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          result.invalidSignature = true;
          return;
        }

        t.update(transactionRef, {
          status: "captured",
          paymentStatus: "captured",
          providerPaymentId: paymentId,
          providerSignature: signature,
          paymentMethod,
          capturedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        t.update(bookingRef, {
          paymentId,
          paymentStatus: "paid",
          transactionId,
          status: "confirmed",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      if (result.invalidSignature) {
        throw new HttpsError(
          "failed-precondition",
          "Invalid payment signature."
        );
      }

      if (!result.alreadyCaptured) {
        const bookingTitle = "Booking confirmed";
        const bookingBody = "Your Golden Care booking has been confirmed.";

        if (result.familyUid) {
          await sendPushNotification(
            result.familyUid,
            bookingTitle,
            bookingBody,
            "booking_confirmed",
            result.bookingId
          );
        }
        if (result.caregiverUid) {
          await sendPushNotification(
            result.caregiverUid,
            bookingTitle,
            "A booking has been assigned and confirmed.",
            "booking_confirmed",
            result.bookingId
          );
        }
      }

      return {
        success: true,
        bookingId: result.bookingId,
        transactionId,
        alreadyCaptured: result.alreadyCaptured,
        message: result.alreadyCaptured
          ? "Payment already captured."
          : "Payment verified successfully. Booking confirmed.",
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error("verifyRazorpayPayment error:", err);
      throw new HttpsError("internal", "Payment verification failed");
    }
  }
);

function extractRefundFailureReason(error) {
  return String(
    error?.error?.description ||
    error?.error?.reason ||
    error?.message ||
    "refund_failed"
  );
}

function isInsufficientRefundBalanceReason(reason) {
  const normalized = String(reason || "").toLowerCase();
  return (
    normalized.includes("enough balance") ||
    normalized.includes("insufficient balance") ||
    normalized.includes("add funds")
  );
}

function buildRefundRetryTimestamp(minutes = 30) {
  return admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + minutes * 60 * 1000)
  );
}

async function processBookingCancellationWithRefund({
  request,
  bookingId,
  actorUid,
  isAdmin = false,
  cancelledBy = "user",
  refundReason = "user_cancellation",
  familyCancellationMessage = "Your booking was cancelled successfully.",
  caregiverCancellationMessage = "A scheduled booking was cancelled by the family.",
}) {
  const db = admin.firestore();
  const bookingRef = db.collection("bookings").doc(bookingId);
  const staging = {
    requiresGatewayRefund: false,
    providerPaymentId: null,
    transactionId: null,
    totalPaidPaise: 0,
    refundAmountPaise: 0,
    cancellationFeePaise: 0,
    platformFeePaise: 0,
    refundPercent: 0,
    isFullRefund: false,
    familyUid: null,
    caregiverUid: null,
    alreadyRefunded: false,
    alreadyCancelled: false,
    transactionMissing: false,
    refundFailed: false,
    refundFailReason: null,
    refundRetryPending: false,
  };

  await db.runTransaction(async (t) => {
    const bookingSnap = await t.get(bookingRef);
    if (!bookingSnap.exists) {
      throw new HttpsError("not-found", "Booking not found");
    }

    const booking = bookingSnap.data() || {};
    if (!isAdmin && booking.userId !== actorUid) {
      throw new HttpsError(
        "permission-denied",
        "Booking does not belong to this user"
      );
    }

    staging.familyUid = booking.userId || actorUid;
    staging.caregiverUid = booking.servicePersonnelId || booking.caregiverId || null;
    staging.transactionId = booking.transactionId || null;

    let txRef = null;
    let txSnap = null;
    let tx = null;
    if (staging.transactionId) {
      txRef = db.collection("transactions").doc(staging.transactionId);
      txSnap = await t.get(txRef);
      if (txSnap.exists) {
        tx = txSnap.data() || {};
      }
    }

    const transition = determineCancellationTransition({
      booking,
      transaction: tx,
      transactionExists: !!(txSnap && txSnap.exists),
      policy: DEFAULT_REFUND_POLICY,
    });

    switch (transition.scenario) {
      case "already_cancelled": {
        staging.alreadyCancelled = true;
        return;
      }
      case "no_transaction": {
        t.update(bookingRef, {
          status: "cancelled",
          paymentStatus: "not_charged",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancelledBy,
          refundAmount: 0,
          refundAmountDisplay: 0,
          refundReason,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }
      case "transaction_missing": {
        staging.transactionMissing = true;
        staging.refundFailed = true;
        staging.refundFailReason = "transaction_missing";
        if (staging.transactionId) {
          console.log(`[cancelBooking] transaction ${staging.transactionId} missing for booking ${bookingId}`);
        }
        t.update(bookingRef, {
          status: "cancelled",
          paymentStatus: "refund_failed",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancelledBy,
          refundReason,
          refundFailReason: "transaction_missing",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }
      case "already_refunded": {
        staging.alreadyRefunded = true;
        t.update(bookingRef, {
          status: "cancelled",
          paymentStatus: "refunded",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancelledBy,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }
      case "provider_payment_id_missing": {
        staging.refundFailed = true;
        staging.refundFailReason = "provider_payment_id_missing";
        if (txRef) {
          t.update(txRef, {
            status: "refund_failed",
            paymentStatus: "refund_failed",
            refundFailReason: "provider_payment_id_missing",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        t.update(bookingRef, {
          status: "cancelled",
          paymentStatus: "refund_failed",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancelledBy,
          refundReason,
          refundFailReason: "provider_payment_id_missing",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }
      case "refund_amount_zero":
      case "gateway_refund_required": {
        staging.requiresGatewayRefund = transition.scenario === "gateway_refund_required";
        staging.providerPaymentId = transition.providerPaymentId || null;
        staging.totalPaidPaise = transition.totalPaidPaise || 0;
        staging.refundAmountPaise = transition.refundAmountPaise || 0;
        staging.cancellationFeePaise = transition.cancellationFeePaise || 0;
        staging.platformFeePaise = transition.platformFeePaise || 0;
        staging.refundPercent = transition.refundPercent || 0;
        staging.isFullRefund = !!transition.isFullRefund;
        if (!staging.requiresGatewayRefund) {
          staging.refundFailed = true;
          staging.refundFailReason = "refund_amount_zero";
        }

        if (txRef && tx) {
          console.log(`[cancelBooking] Found transaction ${staging.transactionId} status=${tx.status} paymentStatus=${tx.paymentStatus} providerPaymentId=${tx.providerPaymentId}`);
        }
        console.log(`[cancelBooking] Refund decision: requiresGatewayRefund=${staging.requiresGatewayRefund} providerPaymentId=${staging.providerPaymentId} refundAmountPaise=${staging.refundAmountPaise}`);

        if (txRef) {
          t.update(txRef, {
            status: staging.requiresGatewayRefund ? "refund_processing" : "refund_failed",
            paymentStatus: staging.requiresGatewayRefund ? "refund_processing" : "refund_failed",
            refundReason,
            refundAmount: staging.refundAmountPaise,
            refundAmountDisplay: parseFloat((staging.refundAmountPaise / 100).toFixed(2)),
            cancellationFee: staging.cancellationFeePaise,
            cancellationFeeDisplay: parseFloat((staging.cancellationFeePaise / 100).toFixed(2)),
            platformFee: staging.platformFeePaise,
            platformFeeDisplay: parseFloat((staging.platformFeePaise / 100).toFixed(2)),
            refundPercent: staging.refundPercent,
            refundRetryPending: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            ...(staging.requiresGatewayRefund
              ? {}
              : { refundFailReason: "refund_amount_zero" }),
          });
        }

        t.update(bookingRef, {
          status: "cancelled",
          paymentStatus: staging.requiresGatewayRefund ? "refund_initiated" : "refund_failed",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancelledBy,
          refundAmount: staging.refundAmountPaise,
          refundAmountDisplay: parseFloat((staging.refundAmountPaise / 100).toFixed(2)),
          refundReason,
          refundRetryPending: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          ...(staging.requiresGatewayRefund
            ? {}
            : { refundFailReason: "refund_amount_zero" }),
        });
        return;
      }
      default:
        throw new HttpsError("internal", "Unknown cancellation transition.");
    }
  });

  let refundId = null;

  if (
    staging.requiresGatewayRefund &&
    staging.providerPaymentId &&
    staging.transactionId
  ) {
    try {
      const creds = getRazorpayCredentials(request);
      const razorpay = new Razorpay({
        key_id: creds.keyId,
        key_secret: creds.keySecret,
      });

      const refundNotes = {
        reason: refundReason,
        bookingId,
        refundPercent: String(staging.refundPercent),
        fullRefund: String(staging.isFullRefund),
        cancellationFee: String(staging.cancellationFeePaise),
        platformFee: String(staging.platformFeePaise),
        cancelledBy,
      };

      const initiateRefund = async (speed) => {
        const refund = await razorpay.payments.refund(staging.providerPaymentId, {
          amount: staging.refundAmountPaise,
          speed,
          notes: {
            ...refundNotes,
            speed,
          },
        });
        return refund;
      };

      const txRef = db.collection("transactions").doc(staging.transactionId);

      const markRefundInitiated = async (refund, speed) => {
        refundId = refund.id;
        staging.refundFailed = false;
        staging.refundRetryPending = false;
        staging.refundFailReason = null;
        console.log(
          `[cancelBooking] Refund initiated refundId=${refundId} speed=${speed} for payment ${staging.providerPaymentId}`
        );

        await db.runTransaction(async (t) => {
          const bookingSnap = await t.get(bookingRef);
          const txSnap = await t.get(txRef);
          if (!bookingSnap.exists || !txSnap.exists) {
            return;
          }

          t.update(txRef, {
            status: "refund_initiated",
            paymentStatus: "refund_initiated",
            refundId,
            refundGatewayStatus: refund.status || "created",
            refundInitiatedAt: admin.firestore.FieldValue.serverTimestamp(),
            refundRetryPending: false,
            refundFailReason: admin.firestore.FieldValue.delete(),
            refundNextRetryAt: admin.firestore.FieldValue.delete(),
            refundLastAttemptSpeed: speed,
            refundLastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          t.update(bookingRef, {
            status: "cancelled",
            paymentStatus: "refund_initiated",
            refundId,
            refundInitiatedAt: admin.firestore.FieldValue.serverTimestamp(),
            refundRetryPending: false,
            refundFailReason: admin.firestore.FieldValue.delete(),
            refundNextRetryAt: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
      };

      const markRefundFailed = async (reason, retryPending) => {
        const retryAt = retryPending ? buildRefundRetryTimestamp(30) : null;
        staging.refundFailed = true;
        staging.refundFailReason = reason;
        staging.refundRetryPending = retryPending;

        await db.runTransaction(async (t) => {
          const bookingSnap = await t.get(bookingRef);
          const txSnap = await t.get(txRef);
          if (!bookingSnap.exists || !txSnap.exists) {
            return;
          }

          t.update(txRef, {
            status: "refund_failed",
            paymentStatus: "refund_failed",
            refundFailReason: reason,
            refundRetryPending: retryPending,
            refundLastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
            refundRetryCount: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            ...(retryPending
              ? { refundNextRetryAt: retryAt }
              : { refundNextRetryAt: admin.firestore.FieldValue.delete() }),
          });

          t.update(bookingRef, {
            status: "cancelled",
            paymentStatus: "refund_failed",
            refundFailReason: reason,
            refundRetryPending: retryPending,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            ...(retryPending
              ? { refundNextRetryAt: retryAt }
              : { refundNextRetryAt: admin.firestore.FieldValue.delete() }),
          });
        });
      };

      try {
        const refund = await initiateRefund("optimum");
        await markRefundInitiated(refund, "optimum");
      } catch (optimumError) {
        const optimumReason = extractRefundFailureReason(optimumError);
        console.error("[cancelBooking] Razorpay refund failed (optimum):", optimumError);

        if (isInsufficientRefundBalanceReason(optimumReason)) {
          try {
            const fallbackRefund = await initiateRefund("normal");
            await markRefundInitiated(fallbackRefund, "normal");
          } catch (fallbackError) {
            const fallbackReason = extractRefundFailureReason(fallbackError);
            console.error("[cancelBooking] Razorpay refund failed (normal fallback):", fallbackError);
            await markRefundFailed(
              fallbackReason,
              isInsufficientRefundBalanceReason(fallbackReason)
            );
            refundId = "FAILED";
          }
        } else {
          await markRefundFailed(optimumReason, false);
          refundId = "FAILED";
        }
      }
    } catch (razorpayError) {
      const reason = extractRefundFailureReason(razorpayError);
      console.error("[cancelBooking] Razorpay refund failed:", razorpayError);
      staging.refundFailed = true;
      staging.refundFailReason = reason;

      if (staging.transactionId) {
        const txRef = db.collection("transactions").doc(staging.transactionId);
        await db.runTransaction(async (t) => {
          const bookingSnap = await t.get(bookingRef);
          const txSnap = await t.get(txRef);
          if (!bookingSnap.exists || !txSnap.exists) {
            return;
          }

          t.update(txRef, {
            status: "refund_failed",
            paymentStatus: "refund_failed",
            refundFailReason: reason,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          t.update(bookingRef, {
            status: "cancelled",
            paymentStatus: "refund_failed",
            refundFailReason: reason,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
      }
      refundId = "FAILED";
    }
  }

  if (!staging.alreadyCancelled) {
    if (staging.familyUid) {
      await sendPushNotification(
        staging.familyUid,
        "Booking cancelled",
        familyCancellationMessage,
        "booking_cancelled",
        bookingId
      );
    }
    if (staging.caregiverUid) {
      await sendPushNotification(
        staging.caregiverUid,
        "Booking cancelled",
        caregiverCancellationMessage,
        "booking_cancelled",
        bookingId
      );
    }
  }

  const cancelledBySuffix = cancelledBy === "admin" ? " by admin" : "";
  const defaultMessage = `Booking cancelled${cancelledBySuffix}.`;

  return {
    success: true,
    bookingId,
    refundAmount: parseFloat((staging.refundAmountPaise / 100).toFixed(2)),
    refundPercent: staging.refundPercent,
    refundId,
    alreadyCancelled: staging.alreadyCancelled,
    refundFailed: staging.refundFailed,
    refundFailReason: staging.refundFailReason,
    refundRetryPending: staging.refundRetryPending,
    message: staging.alreadyCancelled
      ? "Booking already cancelled."
      : staging.refundRetryPending
        ? `${defaultMessage} Refund could not be initiated${staging.refundFailReason ? ` (${staging.refundFailReason})` : ""}. It is queued and will be retried automatically once balance is available.`
        : staging.refundFailed
          ? `${defaultMessage} Refund could not be initiated${staging.refundFailReason ? ` (${staging.refundFailReason})` : ""}.`
          : staging.refundAmountPaise > 0
            ? `${defaultMessage} INR ${(staging.refundAmountPaise / 100).toFixed(2)} refund (${staging.refundPercent}%) initiated.`
            : defaultMessage,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. cancelBooking — Cancel booking with policy-based refund
// ─────────────────────────────────────────────────────────────────────────────
exports.cancelBooking = onCall(
  {
    // Keep consistent with payment callables to avoid web App Check false negatives.
    enforceAppCheck: false,
    cors: true,
    secrets: [
      RAZORPAY_KEY_ID_LIVE,
      RAZORPAY_KEY_SECRET_LIVE,
      RAZORPAY_KEY_ID_TEST,
      RAZORPAY_KEY_SECRET_TEST,
    ],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const { bookingId } = request.data || {};
    if (!bookingId || typeof bookingId !== "string") {
      throw new HttpsError("invalid-argument", "bookingId required");
    }

    try {
      return await processBookingCancellationWithRefund({
        request,
        bookingId,
        actorUid: request.auth.uid,
        isAdmin: false,
        cancelledBy: "user",
        refundReason: "user_cancellation",
        familyCancellationMessage: "Your booking was cancelled successfully.",
        caregiverCancellationMessage: "A scheduled booking was cancelled by the family.",
      });
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error("[cancelBooking] Error:", err);
      throw new HttpsError("internal", err.message || "Cancellation failed");
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 4. razorpayWebhook — HTTPS endpoint for Razorpay payment notifications
// ─────────────────────────────────────────────────────────────────────────────
exports.razorpayWebhook = onRequest(
  { enforceAppCheck: false, cors: true, secrets: [RAZORPAY_WEBHOOK_SECRET] },
  async (req, res) => {
    try {
      const db = admin.firestore();
      const webhookSecret = RAZORPAY_WEBHOOK_SECRET.value();

      if (!webhookSecret) {
        console.error("Webhook secret not configured");
        return res.status(500).json({ error: "Webhook not configured" });
      }

      if (!req.rawBody || req.rawBody.length === 0) {
        console.warn("Webhook raw body missing");
        return res.status(400).json({ error: "Invalid payload" });
      }

      // Verify webhook signature strictly against raw request bytes
      const shasum = crypto.createHmac("sha256", webhookSecret);
      shasum.update(req.rawBody);
      const digest = shasum.digest("hex");

      const headerSigRaw = req.get("x-razorpay-signature") || req.headers["x-razorpay-signature"];
      const headerSig = Array.isArray(headerSigRaw) ? headerSigRaw.join("") : String(headerSigRaw || "");
      if (!safeCompareHex(digest, headerSig)) {
        console.warn("Invalid webhook signature");
        return res.status(403).json({ error: "Invalid signature" });
      }

      const event = req.body.event;
      const paymentEntity = req.body.payload?.payment?.entity || null;
      const refundEntity = req.body.payload?.refund?.entity || null;
      const payload = paymentEntity || refundEntity || {};

      async function getTransactionByOrderId(providerOrderId) {
        const query = await db
          .collection("transactions")
          .where("providerOrderId", "==", providerOrderId)
          .limit(1)
          .get();

        if (query.empty) {
          return null;
        }

        return query.docs[0];
      }

      async function getTransactionByPaymentId(providerPaymentId) {
        const query = await db
          .collection("transactions")
          .where("providerPaymentId", "==", providerPaymentId)
          .limit(1)
          .get();

        if (query.empty) {
          return null;
        }

        return query.docs[0];
      }

      if (event === "payment.authorized" || event === "payment.captured") {
        const transactionDoc = await getTransactionByOrderId(payload.order_id);
        if (!transactionDoc) {
          console.warn(`No transaction found for order ${payload.order_id}`);
          return res.status(200).json({ status: "ignored" });
        }

        await db.runTransaction(async (t) => {
          const txSnap = await t.get(transactionDoc.ref);
          if (!txSnap.exists) {
            return;
          }

          const transaction = txSnap.data() || {};
          if (
            transaction.status === "captured" ||
            transaction.paymentStatus === "captured"
          ) {
            return;
          }

          const bookingId =
            transaction.referenceType === "booking" ? transaction.referenceId : null;
          let bookingRef = null;
          let bookingSnap = null;
          if (bookingId) {
            bookingRef = db.collection("bookings").doc(bookingId);
            bookingSnap = await t.get(bookingRef);
          }

          t.update(transactionDoc.ref, {
            status: "captured",
            paymentStatus: "captured",
            providerPaymentId: payload.id,
            webhookVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          if (bookingSnap && bookingSnap.exists) {
            t.update(bookingRef, {
              paymentId: payload.id,
              paymentStatus: "paid",
              status: "confirmed",
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        });

        console.log(
          `Payment captured: ${payload.id} for order ${payload.order_id}`
        );
      } else if (event === "payment.failed") {
        const transactionDoc = await getTransactionByOrderId(payload.order_id);
        if (!transactionDoc) {
          console.warn(`No transaction found for failed order ${payload.order_id}`);
          return res.status(200).json({ status: "ignored" });
        }

        await db.runTransaction(async (t) => {
          const txSnap = await t.get(transactionDoc.ref);
          if (!txSnap.exists) {
            return;
          }

          const tx = txSnap.data() || {};
          if (tx.status === "captured" || tx.paymentStatus === "captured") {
            return;
          }

          // Read any related booking first (reads before writes)
          const bookingId = tx.referenceId || tx.bookingId;
          let bookingRef = null;
          let bookingSnap = null;
          if (bookingId) {
            bookingRef = db.collection("bookings").doc(bookingId);
            bookingSnap = await t.get(bookingRef);
          }

          // Now perform writes
          t.update(transactionDoc.ref, {
            status: "failed",
            paymentStatus: "failed",
            failureReason: payload.error_description || payload.reason || "Payment declined",
            webhookVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          if (bookingSnap && bookingSnap.exists) {
            t.update(bookingRef, {
              paymentStatus: "failed",
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        });

        console.log(`Payment failed for order ${payload.order_id}`);
      } else if (event === "refund.processed" || event === "refund.speed_changed") {
        const paymentId = refundEntity?.payment_id;
        const refundId = refundEntity?.id;
        const refundAmount = refundEntity?.amount;

        if (paymentId) {
          const txDoc = await getTransactionByPaymentId(paymentId);

          if (txDoc) {
            await db.runTransaction(async (t) => {
              const txSnap = await t.get(txDoc.ref);
              if (!txSnap.exists) {
                return;
              }

              const tx = txSnap.data() || {};
              if (tx.status === "refunded" && tx.paymentStatus === "refunded") {
                return;
              }

              const bookingId = tx.referenceId || tx.bookingId;
              let bookingRef = null;
              let bookingSnap = null;
              if (bookingId) {
                bookingRef = db.collection("bookings").doc(bookingId);
                bookingSnap = await t.get(bookingRef);
              }

              t.update(txDoc.ref, {
                status: "refunded",
                paymentStatus: "refunded",
                refundId,
                refundAmount,
                refundAmountDisplay: parseFloat((Number(refundAmount || 0) / 100).toFixed(2)),
                refundProcessedAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              if (bookingSnap && bookingSnap.exists) {
                t.update(bookingRef, {
                  paymentStatus: "refunded",
                  refundProcessedAt: admin.firestore.FieldValue.serverTimestamp(),
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
              }
            });
          }
        }
      } else if (event === "refund.failed") {
        const paymentId = refundEntity?.payment_id;
        if (paymentId) {
          const txDoc = await getTransactionByPaymentId(paymentId);

          if (txDoc) {
            await db.runTransaction(async (t) => {
              const txSnap = await t.get(txDoc.ref);
              if (!txSnap.exists) {
                return;
              }

              const tx = txSnap.data() || {};
              const bookingId = tx.referenceId || tx.bookingId;
              let bookingRef = null;
              let bookingSnap = null;
              if (bookingId) {
                bookingRef = db.collection("bookings").doc(bookingId);
                bookingSnap = await t.get(bookingRef);
              }

              t.update(txDoc.ref, {
                status: "refund_failed",
                paymentStatus: "refund_failed",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              if (bookingSnap && bookingSnap.exists) {
                t.update(bookingRef, {
                  paymentStatus: "refund_failed",
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
              }
            });
          }
        }
      }

      res.status(200).json({ status: "ok" });
    } catch (err) {
      console.error("Webhook error:", err);
      res.status(500).json({ error: "Webhook processing failed" });
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 5. cleanupExpiredPayments — Expire pending-payment bookings after 15 minutes
// ─────────────────────────────────────────────────────────────────────────────
exports.cleanupExpiredPayments = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Asia/Kolkata",
    region: "us-central1",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const cutoff = new admin.firestore.Timestamp(
      now.seconds - (15 * 60),
      now.nanoseconds
    );

    console.log(
      "[cleanupExpiredPayments] Running at:",
      now.toDate().toISOString()
    );
    console.log(
      "[cleanupExpiredPayments] Cutoff:",
      cutoff.toDate().toISOString()
    );

    try {
      // To avoid requiring a composite index on (status, createdAt) which
      // can cause the query to fail silently in some deployments, fetch
      // pending_payment bookings and perform the cutoff filter in code.
      const snap = await admin
        .firestore()
        .collection("bookings")
        .where("status", "==", "pending_payment")
        .get();

      if (snap.empty) {
        console.log("[cleanupExpiredPayments] No pending_payment bookings found");
        return;
      }

      const cutoffMs = Date.now() - 15 * 60 * 1000; // 15 minutes
      const expiredDocs = snap.docs.filter((doc) => {
        const data = doc.data() || {};
        const created = data.createdAt;
        if (!created) return false;
        const createdMs = typeof created.toDate === "function" ? created.toDate().getTime() : (typeof created === 'number' ? created : 0);
        return createdMs > 0 && createdMs < cutoffMs;
      });

      if (expiredDocs.length === 0) {
        console.log("[cleanupExpiredPayments] No expired bookings found after filtering");
        return;
      }

      console.log(`[cleanupExpiredPayments] Found ${expiredDocs.length} expired bookings`);

      const batchSize = 500;
      for (let i = 0; i < expiredDocs.length; i += batchSize) {
        const chunk = expiredDocs.slice(i, i + batchSize);
        for (const bookingDoc of chunk) {
          await admin.firestore().runTransaction(async (t) => {
            const freshBookingSnap = await t.get(bookingDoc.ref);
            if (!freshBookingSnap.exists) return;
            const booking = freshBookingSnap.data() || {};
            if (booking.status !== "pending_payment") return;

            // Read any related transaction first (all reads must happen before writes)
            let txRef = null;
            let txSnap = null;
            if (booking.transactionId) {
              txRef = admin.firestore().collection("transactions").doc(booking.transactionId);
              txSnap = await t.get(txRef);
            }

            // Now perform writes — all reads completed above
            t.update(bookingDoc.ref, {
              status: "expired",
              paymentStatus: "expired",
              expiredAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              expiryReason: "payment_timeout_15min",
            });

            if (txSnap && txSnap.exists) {
              const tx = txSnap.data() || {};
              if (tx.status !== "captured" && tx.paymentStatus !== "captured") {
                t.update(txRef, {
                  status: "cancelled",
                  paymentStatus: "cancelled",
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                  cancellationReason: "payment_timeout_15min",
                });
              }
            }
          });

          console.log(`[cleanupExpiredPayments] Expiring booking: ${bookingDoc.id}`);
        }

        console.log(`[cleanupExpiredPayments] Batch ${Math.floor(i / batchSize) + 1} committed`);
      }

      console.log(`[cleanupExpiredPayments] Done. Expired ${expiredDocs.length} bookings`);
    } catch (error) {
      console.error("[cleanupExpiredPayments] Error:", error);
      throw error;
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 6. retryQueuedRefunds — Retry refund failures queued due balance issues
// ─────────────────────────────────────────────────────────────────────────────
exports.retryQueuedRefunds = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "Asia/Kolkata",
    region: "us-central1",
    secrets: [
      RAZORPAY_KEY_ID_LIVE,
      RAZORPAY_KEY_SECRET_LIVE,
      RAZORPAY_KEY_ID_TEST,
      RAZORPAY_KEY_SECRET_TEST,
    ],
  },
  async () => {
    const db = admin.firestore();
    const now = new Date();
    const nowMs = now.getTime();

    console.log("[retryQueuedRefunds] Running at:", now.toISOString());

    const retrySnap = await db
      .collection("transactions")
      .where("refundRetryPending", "==", true)
      .limit(200)
      .get();

    if (retrySnap.empty) {
      console.log("[retryQueuedRefunds] No queued refunds found");
      return;
    }

    const creds = getRazorpayCredentials();
    const razorpay = new Razorpay({
      key_id: creds.keyId,
      key_secret: creds.keySecret,
    });

    let retriedSuccess = 0;
    let retriedQueued = 0;
    let retriedFinalFailed = 0;

    for (const txDoc of retrySnap.docs) {
      const tx = txDoc.data() || {};
      const paymentStatus = String(tx.paymentStatus || tx.status || "").toLowerCase();
      const retryAt = tx.refundNextRetryAt;
      const retryAtMs =
        retryAt && typeof retryAt.toDate === "function" ? retryAt.toDate().getTime() : 0;

      if (
        paymentStatus === "refunded" ||
        paymentStatus === "refund_initiated" ||
        paymentStatus === "refund_processing"
      ) {
        await txDoc.ref.update({
          refundRetryPending: false,
          refundNextRetryAt: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        continue;
      }

      if (retryAtMs > 0 && retryAtMs > nowMs) {
        continue;
      }

      const paymentId = tx.providerPaymentId || tx.paymentId || null;
      const amountPaise = Number(tx.refundAmount || 0);
      const bookingId = tx.referenceId || tx.bookingId || null;

      if (!paymentId || !Number.isFinite(amountPaise) || amountPaise <= 0) {
        await txDoc.ref.update({
          status: "refund_failed",
          paymentStatus: "refund_failed",
          refundFailReason: "retry_payload_invalid",
          refundRetryPending: false,
          refundNextRetryAt: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        if (bookingId) {
          const bookingRef = db.collection("bookings").doc(bookingId);
          await bookingRef.update({
            paymentStatus: "refund_failed",
            refundFailReason: "retry_payload_invalid",
            refundRetryPending: false,
            refundNextRetryAt: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }).catch(() => { });
        }
        retriedFinalFailed += 1;
        continue;
      }

      try {
        const refund = await razorpay.payments.refund(paymentId, {
          amount: Math.round(amountPaise),
          speed: "normal",
          notes: {
            reason: "queued_retry",
            bookingId: bookingId || "",
            retryCount: String(Number(tx.refundRetryCount || 0) + 1),
          },
        });

        await db.runTransaction(async (t) => {
          const txSnap = await t.get(txDoc.ref);
          if (!txSnap.exists) {
            return;
          }

          let bookingRef = null;
          let bookingSnap = null;
          if (bookingId) {
            bookingRef = db.collection("bookings").doc(bookingId);
            bookingSnap = await t.get(bookingRef);
          }

          t.update(txDoc.ref, {
            status: "refund_initiated",
            paymentStatus: "refund_initiated",
            refundId: refund.id,
            refundGatewayStatus: refund.status || "created",
            refundRetryPending: false,
            refundFailReason: admin.firestore.FieldValue.delete(),
            refundNextRetryAt: admin.firestore.FieldValue.delete(),
            refundRetryCount: admin.firestore.FieldValue.increment(1),
            refundInitiatedAt: admin.firestore.FieldValue.serverTimestamp(),
            refundLastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
            refundLastAttemptSpeed: "normal",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          if (bookingSnap && bookingSnap.exists) {
            t.update(bookingRef, {
              paymentStatus: "refund_initiated",
              refundId: refund.id,
              refundRetryPending: false,
              refundFailReason: admin.firestore.FieldValue.delete(),
              refundNextRetryAt: admin.firestore.FieldValue.delete(),
              refundInitiatedAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        });

        retriedSuccess += 1;
      } catch (retryError) {
        const reason = extractRefundFailureReason(retryError);
        const keepQueued = isInsufficientRefundBalanceReason(reason);
        const nextRetryAt = keepQueued ? buildRefundRetryTimestamp(30) : null;

        await db.runTransaction(async (t) => {
          const txSnap = await t.get(txDoc.ref);
          if (!txSnap.exists) {
            return;
          }

          let bookingRef = null;
          let bookingSnap = null;
          if (bookingId) {
            bookingRef = db.collection("bookings").doc(bookingId);
            bookingSnap = await t.get(bookingRef);
          }

          t.update(txDoc.ref, {
            status: "refund_failed",
            paymentStatus: "refund_failed",
            refundFailReason: reason,
            refundRetryPending: keepQueued,
            refundRetryCount: admin.firestore.FieldValue.increment(1),
            refundLastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            ...(keepQueued
              ? { refundNextRetryAt: nextRetryAt }
              : { refundNextRetryAt: admin.firestore.FieldValue.delete() }),
          });

          if (bookingSnap && bookingSnap.exists) {
            t.update(bookingRef, {
              paymentStatus: "refund_failed",
              refundFailReason: reason,
              refundRetryPending: keepQueued,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              ...(keepQueued
                ? { refundNextRetryAt: nextRetryAt }
                : { refundNextRetryAt: admin.firestore.FieldValue.delete() }),
            });
          }
        });

        if (keepQueued) {
          retriedQueued += 1;
        } else {
          retriedFinalFailed += 1;
        }
      }
    }

    console.log(
      `[retryQueuedRefunds] done success=${retriedSuccess} queued=${retriedQueued} finalFailed=${retriedFinalFailed}`
    );
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 7. detectCaregiverNoShow — Mark no-show and refund fully after 30 min grace
// ─────────────────────────────────────────────────────────────────────────────
exports.detectCaregiverNoShow = onSchedule(
  {
    schedule: "every 10 minutes",
    timeZone: "Asia/Kolkata",
    region: "us-central1",
    secrets: [
      RAZORPAY_KEY_ID_LIVE,
      RAZORPAY_KEY_SECRET_LIVE,
      RAZORPAY_KEY_ID_TEST,
      RAZORPAY_KEY_SECRET_TEST,
    ],
  },
  async () => {
    const db = admin.firestore();
    const now = new Date();
    const cutoff = new Date(now.getTime() - (30 * 60 * 1000));

    console.log("[detectCaregiverNoShow] Checking at:", now.toISOString());
    console.log("[detectCaregiverNoShow] Cutoff:", cutoff.toISOString());

    try {
      const suspectSnap = await db
        .collection("bookings")
        .where("status", "==", "confirmed")
        .where("isVerifiedComplete", "==", false)
        .where("date", "<=", admin.firestore.Timestamp.fromDate(now))
        .get();

      if (suspectSnap.empty) {
        console.log("[detectCaregiverNoShow] No suspect bookings");
        return;
      }

      console.log(`[detectCaregiverNoShow] Checking ${suspectSnap.size} bookings`);

      // Select appropriate Razorpay credentials for this runtime (live/test)
      const creds = getRazorpayCredentials();
      const keyId = creds.keyId;
      const keySecret = creds.keySecret;

      const razorpay = new Razorpay({
        key_id: keyId,
        key_secret: keySecret,
      });

      for (const bookingDoc of suspectSnap.docs) {
        const booking = bookingDoc.data();

        try {
          let bookingDateTime = null;
          const dateField = booking.date;
          const startTimeField = booking.startTime;
          const timeField = booking.startTimeString || booking.time;

          if (startTimeField?.toDate) {
            bookingDateTime = startTimeField.toDate();
          } else if (startTimeField instanceof Date) {
            bookingDateTime = startTimeField;
          } else if (typeof startTimeField === "string") {
            const parsed = new Date(startTimeField);
            if (!Number.isNaN(parsed.getTime())) {
              bookingDateTime = parsed;
            }
          }

          if (!bookingDateTime && dateField && timeField) {
            let dateObj;
            if (dateField?.toDate) {
              dateObj = dateField.toDate();
            } else if (typeof dateField === "string") {
              dateObj = new Date(dateField);
            }

            if (dateObj && !Number.isNaN(dateObj.getTime())) {
              const timeStr = String(timeField).trim();
              const timeMatch = timeStr.match(/(\d{1,2}):(\d{2})\s*(AM|PM)?/i);
              if (timeMatch) {
                let hours = parseInt(timeMatch[1], 10);
                const mins = parseInt(timeMatch[2], 10);
                const meridiem = (timeMatch[3] || "").toUpperCase();

                if (meridiem === "PM" && hours !== 12) hours += 12;
                if (meridiem === "AM" && hours === 12) hours = 0;

                bookingDateTime = new Date(dateObj);
                bookingDateTime.setHours(hours, mins, 0, 0);
              }
            }
          }

          if (!bookingDateTime) continue;

          const noShowTime = new Date(bookingDateTime.getTime() + (30 * 60 * 1000));
          if (now < noShowTime) continue;

          console.log(`[detectCaregiverNoShow] No-show detected: ${bookingDoc.id}`);

          let refundId = null;
          let refundAmountPaise = 0;
          const transactionId = booking.transactionId;

          if (transactionId && booking.paymentStatus === "paid") {
            const txRef = db.collection("transactions").doc(transactionId);
            const txSnap = await txRef.get();

            if (txSnap.exists) {
              const tx = txSnap.data();
              const totalPaid = Number(tx.amount || 0);
              refundAmountPaise = totalPaid;

              try {
                const refund = await razorpay.payments.refund(tx.providerPaymentId, {
                  amount: totalPaid,
                  speed: "optimum",
                  notes: {
                    reason: "caregiver_noshow",
                    bookingId: bookingDoc.id,
                  },
                });

                refundId = refund.id;

                await txRef.update({
                  status: "refund_initiated",
                  paymentStatus: "refund_initiated",
                  refundId: refund.id,
                  refundAmount: totalPaid,
                  refundAmountDisplay: parseFloat((totalPaid / 100).toFixed(2)),
                  cancellationFee: 0,
                  cancellationFeeDisplay: 0,
                  platformFee: 0,
                  platformFeeDisplay: 0,
                  refundReason: "caregiver_noshow",
                  refundInitiatedAt: admin.firestore.FieldValue.serverTimestamp(),
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
              } catch (e) {
                console.error("[detectCaregiverNoShow] Refund failed:", e);
                await txRef.update({
                  status: "refund_failed",
                  paymentStatus: "refund_failed",
                  refundFailReason: e.message || "refund_failed",
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                refundId = "FAILED";
              }
            }
          }

          await bookingDoc.ref.update({
            status: "caregiver_noshow",
            paymentStatus: refundAmountPaise > 0 ? "refund_initiated" : booking.paymentStatus,
            noShowDetectedAt: admin.firestore.FieldValue.serverTimestamp(),
            refundId,
            refundAmount: refundAmountPaise,
            refundAmountDisplay: parseFloat((refundAmountPaise / 100).toFixed(2)),
            refundReason: "caregiver_noshow",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          if (booking.userId) {
            await sendPushNotification(
              booking.userId,
              "Caregiver no-show reported",
              "Your booking was flagged as caregiver no-show and is being handled.",
              "noshow_reported",
              bookingDoc.id
            );
          }

          console.log(`[detectCaregiverNoShow] Processed: ${bookingDoc.id}, refundId: ${refundId}`);
        } catch (bookingError) {
          console.error(`[detectCaregiverNoShow] Error for ${bookingDoc.id}:`, bookingError);
        }
      }
    } catch (error) {
      console.error("[detectCaregiverNoShow] Fatal:", error);
      throw error;
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// cleanupExpiredNotifications — remove read notifications after expiry
// ─────────────────────────────────────────────────────────────────────────────
exports.cleanupExpiredNotifications = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "Asia/Kolkata",
    region: "us-central1",
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const usersSnap = await db.collection("users").select().get();

    let totalDeleted = 0;
    for (const userDoc of usersSnap.docs) {
      const expiredSnap = await db
        .collection("users")
        .doc(userDoc.id)
        .collection("notifications")
        .where("expiresAt", "<=", now)
        .get();

      if (expiredSnap.empty) continue;

      const batch = db.batch();
      for (const doc of expiredSnap.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();
      totalDeleted += expiredSnap.size;
    }

    console.log(`[cleanupExpiredNotifications] Deleted ${totalDeleted} docs`);
    return null;
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// OTP helpers
// ─────────────────────────────────────────────────────────────────────────────
function generateOtpCode() {
  return String(crypto.randomInt(100000, 1000000));
}

function hashOtp(otp, bookingId, userId, salt) {
  const key = `${String(bookingId || "").trim()}:${String(userId || "").trim()}:${String(salt || "").trim()}`;
  return crypto.createHmac("sha256", key).update(String(otp || "").trim()).digest("hex");
}

function safeEqualHash(left, right) {
  const leftBuf = Buffer.from(String(left || ""));
  const rightBuf = Buffer.from(String(right || ""));
  if (leftBuf.length !== rightBuf.length || leftBuf.length === 0) {
    return false;
  }
  return crypto.timingSafeEqual(leftBuf, rightBuf);
}

function safeCompareHex(a, b) {
  try {
    if (!a || !b) return false;
    const ab = Buffer.from(String(a || ""), 'hex');
    const bb = Buffer.from(String(b || ""), 'hex');
    if (ab.length !== bb.length || ab.length === 0) return false;
    return crypto.timingSafeEqual(ab, bb);
  } catch (e) {
    return false;
  }
}

function toTimestampMillis(value) {
  if (!value) {
    return 0;
  }
  if (typeof value.toDate === "function") {
    const date = value.toDate();
    return Number.isFinite(date?.getTime?.()) ? date.getTime() : 0;
  }
  if (value instanceof Date) {
    return Number.isFinite(value.getTime()) ? value.getTime() : 0;
  }
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : 0;
  }
  return 0;
}

const OTP_MAX_ATTEMPTS = 5;
const OTP_TTL_MS = 10 * 60 * 1000;
const OTP_GENERATE_COOLDOWN_MS = 30 * 1000;
const OTP_VERIFY_ATTEMPT_COOLDOWN_MS = 1500;

const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

function toIstDateKey(value) {
  const date = value && typeof value.toDate === "function" ? value.toDate() : value;
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
    return null;
  }

  const istDate = new Date(date.getTime() + IST_OFFSET_MS);
  return `${istDate.getUTCFullYear()}-${String(istDate.getUTCMonth() + 1).padStart(2, "0")}-${String(istDate.getUTCDate()).padStart(2, "0")}`;
}

function isBookingDateTodayIst(bookingDateTs) {
  const bookingDateKey = toIstDateKey(bookingDateTs);
  const todayDateKey = toIstDateKey(new Date());
  return Boolean(bookingDateKey && todayDateKey && bookingDateKey === todayDateKey);
}

// ─────────────────────────────────────────────────────────────────────────────
// generateStartOtp — booking owner generates start OTP on booking day
// ─────────────────────────────────────────────────────────────────────────────
exports.generateStartOtp = onCall(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
      }

      const bookingId = request.data?.bookingId;
      if (!bookingId || typeof bookingId !== "string") {
        throw new HttpsError("invalid-argument", "bookingId required");
      }

      const db = admin.firestore();
      const bookingRef = db.collection("bookings").doc(bookingId);
      const bookingSnap = await bookingRef.get();

      if (!bookingSnap.exists) {
        throw new HttpsError("not-found", "Booking not found");
      }

      const booking = bookingSnap.data();
      if (!booking) {
        throw new HttpsError("not-found", "Booking not found");
      }

      if (booking.userId !== request.auth.uid) {
        throw new HttpsError(
          "permission-denied",
          "Only booking owner can generate start OTP"
        );
      }

      if (!isBookingDateTodayIst(booking.date)) {
        throw new HttpsError(
          "failed-precondition",
          "Start OTP is available on booking day only"
        );
      }

      if (booking.status !== "confirmed" && booking.status !== "upcoming") {
        throw new HttpsError(
          "failed-precondition",
          "Booking must be confirmed to generate start OTP"
        );
      }

      const nowMs = Date.now();
      const lastGeneratedMs = toTimestampMillis(booking.startOtpGeneratedAt);
      const generateCooldownRemainingMs = OTP_GENERATE_COOLDOWN_MS - (nowMs - lastGeneratedMs);
      if (lastGeneratedMs > 0 && generateCooldownRemainingMs > 0) {
        throw new HttpsError(
          "resource-exhausted",
          `Please wait ${Math.ceil(generateCooldownRemainingMs / 1000)} seconds before regenerating OTP.`
        );
      }

      const otp = generateOtpCode();
      const otpSalt = crypto.randomBytes(16).toString("hex");
      const otpHash = hashOtp(otp, bookingId, booking.userId, otpSalt);
      const expiresAt = new Date(nowMs + OTP_TTL_MS);

      await bookingRef.update({
        startOtpHash: otpHash,
        startOtpSalt: otpSalt,
        startOtpExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        startOtpAttempts: 0,
        startOtpLastAttemptAt: null,
        startOtpGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        otp,
        expiresAt: expiresAt.toISOString(),
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError("internal", error?.message || "Failed to generate start OTP");
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// verifyStartOtp — assigned caregiver verifies start OTP and starts service
// ─────────────────────────────────────────────────────────────────────────────
exports.verifyStartOtp = onCall(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
      }

      const bookingId = request.data?.bookingId;
      const otp = request.data?.otp;
      if (!bookingId || typeof bookingId !== "string" || !otp || typeof otp !== "string") {
        throw new HttpsError("invalid-argument", "bookingId and otp required");
      }

      const db = admin.firestore();
      const bookingRef = db.collection("bookings").doc(bookingId);
      let bookingUserId = "";
      let bookingCaregiverId = "";

      await db.runTransaction(async (transaction) => {
        const bookingSnap = await transaction.get(bookingRef);
        if (!bookingSnap.exists) {
          throw new HttpsError("not-found", "Booking not found");
        }

        const booking = bookingSnap.data() || {};
        bookingUserId = String(booking.userId || "").trim();
        bookingCaregiverId = String(booking.servicePersonnelId || "").trim();

        if (bookingCaregiverId !== request.auth.uid) {
          throw new HttpsError("permission-denied", "Only assigned caregiver can verify start OTP");
        }

        if (booking.status !== "confirmed" && booking.status !== "upcoming") {
          throw new HttpsError("failed-precondition", "Booking must be confirmed to verify start OTP");
        }

        const attempts = Number(booking.startOtpAttempts || 0);
        if (attempts >= OTP_MAX_ATTEMPTS) {
          throw new HttpsError("resource-exhausted", "Maximum attempts reached");
        }

        const nowMs = Date.now();
        const lastAttemptMs = toTimestampMillis(booking.startOtpLastAttemptAt);
        const verifyCooldownRemainingMs =
          OTP_VERIFY_ATTEMPT_COOLDOWN_MS - (nowMs - lastAttemptMs);
        if (lastAttemptMs > 0 && verifyCooldownRemainingMs > 0) {
          throw new HttpsError(
            "resource-exhausted",
            `Please wait ${Math.ceil(verifyCooldownRemainingMs / 1000)} seconds before retrying OTP.`
          );
        }

        const expiresAt = booking.startOtpExpiresAt;
        if (!expiresAt || typeof expiresAt.toDate !== "function" || expiresAt.toDate().getTime() < nowMs) {
          throw new HttpsError("deadline-exceeded", "OTP expired. Ask family to regenerate.");
        }

        const otpSalt = String(booking.startOtpSalt || "").trim();
        const storedHash = String(booking.startOtpHash || "").trim();
        if (!otpSalt || !storedHash || !bookingUserId) {
          throw new HttpsError("failed-precondition", "Start OTP not available. Ask family to regenerate.");
        }

        const inputHash = hashOtp(otp.trim(), bookingId, bookingUserId, otpSalt);
        if (!safeEqualHash(inputHash, storedHash)) {
          transaction.update(bookingRef, {
            startOtpAttempts: admin.firestore.FieldValue.increment(1),
            startOtpLastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          throw new HttpsError("invalid-argument", "Incorrect OTP");
        }

        transaction.update(bookingRef, {
          status: "in_progress",
          isVerifiedStart: true,
          startOtpHash: null,
          startOtpSalt: null,
          startOtpExpiresAt: null,
          startOtpAttempts: 0,
          startOtpLastAttemptAt: null,
          startOtpGeneratedAt: null,
          serviceStartedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      if (bookingUserId) {
        await sendPushNotification(
          bookingUserId,
          "Service Started",
          "Your caregiver verified the start OTP and started the service.",
          "service_started",
          bookingId
        );
      }

      if (bookingCaregiverId) {
        await sendPushNotification(
          bookingCaregiverId,
          "Service Started",
          "Start OTP verified. Service is now in progress.",
          "service_started",
          bookingId
        );
      }

      return { success: true };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError("internal", error?.message || "Failed to verify start OTP");
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// generateCompletionOtp — booking owner generates completion OTP
// ─────────────────────────────────────────────────────────────────────────────
exports.generateCompletionOtp = onCall(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
      }

      const bookingId = request.data?.bookingId;
      if (!bookingId || typeof bookingId !== "string") {
        throw new HttpsError("invalid-argument", "bookingId required");
      }

      const db = admin.firestore();
      const bookingRef = db.collection("bookings").doc(bookingId);
      const bookingSnap = await bookingRef.get();

      if (!bookingSnap.exists) {
        throw new HttpsError("not-found", "Booking not found");
      }

      const booking = bookingSnap.data();
      if (!booking) {
        throw new HttpsError("not-found", "Booking not found");
      }

      if (booking.userId !== request.auth.uid) {
        throw new HttpsError("permission-denied", "Only booking owner can generate completion OTP");
      }

      if (booking.status !== "in_progress" && booking.status !== "completion_requested") {
        throw new HttpsError("failed-precondition", "Service must be in progress");
      }

      const nowMs = Date.now();
      const lastGeneratedMs = toTimestampMillis(booking.completionOtpGeneratedAt);
      const generateCooldownRemainingMs = OTP_GENERATE_COOLDOWN_MS - (nowMs - lastGeneratedMs);
      if (lastGeneratedMs > 0 && generateCooldownRemainingMs > 0) {
        throw new HttpsError(
          "resource-exhausted",
          `Please wait ${Math.ceil(generateCooldownRemainingMs / 1000)} seconds before regenerating OTP.`
        );
      }

      const otp = generateOtpCode();
      const otpSalt = crypto.randomBytes(16).toString("hex");
      const otpHash = hashOtp(otp, bookingId, booking.userId, otpSalt);
      const expiresAt = new Date(nowMs + OTP_TTL_MS);

      await bookingRef.update({
        completionOtpHash: otpHash,
        completionOtpSalt: otpSalt,
        completionOtpExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        completionOtpAttempts: 0,
        completionOtpLastAttemptAt: null,
        completionOtpGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "completion_requested",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (booking.userId) {
        await sendPushNotification(
          booking.userId,
          "Service Completion Requested",
          "Completion OTP generated. Share it with your caregiver when service ends.",
          "completion_requested",
          bookingId
        );
      }

      if (booking.servicePersonnelId) {
        await sendPushNotification(
          booking.servicePersonnelId,
          "Completion OTP Ready",
          "Family generated completion OTP. Ask them for the code to complete service.",
          "completion_requested",
          bookingId
        );
      }

      return {
        success: true,
        otp,
        expiresAt: expiresAt.toISOString(),
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError("internal", error?.message || "Failed to generate completion OTP");
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// verifyCompletionOtp — assigned caregiver verifies completion OTP and completes job
// ─────────────────────────────────────────────────────────────────────────────
exports.verifyCompletionOtp = onCall(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
      }

      const bookingId = request.data?.bookingId;
      const otp = request.data?.otp;
      if (!bookingId || typeof bookingId !== "string" || !otp || typeof otp !== "string") {
        throw new HttpsError("invalid-argument", "bookingId and otp required");
      }

      const db = admin.firestore();
      const bookingRef = db.collection("bookings").doc(bookingId);
      let bookingUserId = "";
      let bookingCaregiverId = "";

      await db.runTransaction(async (transaction) => {
        const bookingSnap = await transaction.get(bookingRef);
        if (!bookingSnap.exists) {
          throw new HttpsError("not-found", "Booking not found");
        }

        const booking = bookingSnap.data() || {};
        bookingUserId = String(booking.userId || "").trim();
        bookingCaregiverId = String(booking.servicePersonnelId || "").trim();

        if (bookingCaregiverId !== request.auth.uid) {
          throw new HttpsError("permission-denied", "Only assigned caregiver can verify completion OTP");
        }

        if (booking.status !== "in_progress" && booking.status !== "completion_requested") {
          throw new HttpsError("failed-precondition", "Service must be in progress");
        }

        const attempts = Number(booking.completionOtpAttempts || 0);
        if (attempts >= OTP_MAX_ATTEMPTS) {
          throw new HttpsError("resource-exhausted", "Maximum attempts reached");
        }

        const nowMs = Date.now();
        const lastAttemptMs = toTimestampMillis(booking.completionOtpLastAttemptAt);
        const verifyCooldownRemainingMs =
          OTP_VERIFY_ATTEMPT_COOLDOWN_MS - (nowMs - lastAttemptMs);
        if (lastAttemptMs > 0 && verifyCooldownRemainingMs > 0) {
          throw new HttpsError(
            "resource-exhausted",
            `Please wait ${Math.ceil(verifyCooldownRemainingMs / 1000)} seconds before retrying OTP.`
          );
        }

        const expiresAt = booking.completionOtpExpiresAt;
        if (!expiresAt || typeof expiresAt.toDate !== "function" || expiresAt.toDate().getTime() < nowMs) {
          throw new HttpsError("deadline-exceeded", "OTP expired");
        }

        const otpSalt = String(booking.completionOtpSalt || "").trim();
        const storedHash = String(booking.completionOtpHash || "").trim();
        if (!otpSalt || !storedHash || !bookingUserId) {
          throw new HttpsError("failed-precondition", "Completion OTP not available. Ask family to regenerate.");
        }

        const inputHash = hashOtp(otp.trim(), bookingId, bookingUserId, otpSalt);
        if (!safeEqualHash(inputHash, storedHash)) {
          transaction.update(bookingRef, {
            completionOtpAttempts: admin.firestore.FieldValue.increment(1),
            completionOtpLastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          throw new HttpsError("invalid-argument", "Incorrect OTP");
        }

        transaction.update(bookingRef, {
          status: "completed",
          isVerifiedComplete: true,
          completionOtpHash: null,
          completionOtpSalt: null,
          completionOtpExpiresAt: null,
          completionOtpAttempts: 0,
          completionOtpLastAttemptAt: null,
          completionOtpGeneratedAt: null,
          serviceCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      if (bookingCaregiverId) {
        await db.collection("servicePersonnel").doc(bookingCaregiverId).set(
          {
            visitsCompleted: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      await Promise.all([
        bookingUserId
          ? sendPushNotification(
            bookingUserId,
            "Service Completed",
            "Your care session is complete.",
            "service_completed",
            bookingId
          )
          : Promise.resolve(),
        bookingCaregiverId
          ? sendPushNotification(
            bookingCaregiverId,
            "Session Completed",
            "Session marked complete.",
            "service_completed",
            bookingId
          )
          : Promise.resolve(),
      ]);

      return { success: true };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError("internal", error?.message || "Failed to verify completion OTP");
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// submitBookingReview — booking owner submits caregiver review
// ─────────────────────────────────────────────────────────────────────────────
exports.submitBookingReview = onCall(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
      }

      const bookingId = request.data?.bookingId;
      const ratingRaw = request.data?.rating;
      const commentRaw = request.data?.comment;

      if (!bookingId || typeof bookingId !== "string") {
        throw new HttpsError("invalid-argument", "bookingId required");
      }

      const rating = Number(ratingRaw);
      if (!Number.isFinite(rating) || rating < 1 || rating > 5) {
        throw new HttpsError("invalid-argument", "rating must be between 1 and 5");
      }

      const comment = clampWords(commentRaw, 25);

      const db = admin.firestore();
      const bookingRef = db.collection("bookings").doc(bookingId);
      const bookingSnap = await bookingRef.get();

      if (!bookingSnap.exists) {
        throw new HttpsError("not-found", "Booking not found");
      }

      const booking = bookingSnap.data() || {};
      if (booking.userId !== request.auth.uid) {
        throw new HttpsError("permission-denied", "Only booking owner can submit review");
      }

      if (booking.status !== "completed") {
        throw new HttpsError("failed-precondition", "Review can be submitted after completion");
      }

      const personnelId = booking.servicePersonnelId;
      if (!personnelId || typeof personnelId !== "string") {
        throw new HttpsError("failed-precondition", "No caregiver linked to booking");
      }

      const personnelRef = db.collection("servicePersonnel").doc(personnelId);
      const personnelSnap = await personnelRef.get();
      if (!personnelSnap.exists) {
        throw new HttpsError("not-found", "Caregiver profile not found");
      }

      const personnel = personnelSnap.data() || {};
      const existingReviewsRaw = Array.isArray(personnel.reviews) ? personnel.reviews : [];
      const existingReviews = existingReviewsRaw.filter((r) => r && typeof r === "object");

      let reviewerName = booking.userName || "User";
      if (request.auth.uid) {
        const userSnap = await db.collection("users").doc(request.auth.uid).get();
        if (userSnap.exists) {
          const userData = userSnap.data() || {};
          if (typeof userData.name === "string" && userData.name.trim()) {
            reviewerName = userData.name.trim();
          }
        }
      }

      const existingIndex = existingReviews.findIndex(
        (r) => r.bookingId === bookingId && r.userId === request.auth.uid
      );

      const existingCreatedAt =
        existingIndex >= 0 && existingReviews[existingIndex]?.createdAt
          ? existingReviews[existingIndex].createdAt
          : admin.firestore.Timestamp.now();

      const review = {
        rating,
        comment,
        userId: request.auth.uid,
        userName: reviewerName,
        bookingId,
        createdAt: existingCreatedAt,
        updatedAt: admin.firestore.Timestamp.now(),
      };

      const nextReviews =
        existingIndex >= 0
          ? existingReviews.map((r, idx) => (idx === existingIndex ? review : r))
          : [...existingReviews, review];

      const ratingSum = nextReviews.reduce(
        (sum, r) => sum + Number(r.rating || 0),
        0
      );
      const nextAverage = nextReviews.length > 0 ? ratingSum / nextReviews.length : 0;

      await personnelRef.update({
        reviews: nextReviews,
        rating: Number(nextAverage.toFixed(2)),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, updated: existingIndex >= 0 };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError("internal", error?.message || "Failed to submit review");
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// assignRandomCaregiver — choose an available caregiver for a booking
// ─────────────────────────────────────────────────────────────────────────────
exports.assignRandomCaregiver = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const bookingId = request.data?.bookingId;
    if (!bookingId || typeof bookingId !== "string") {
      throw new HttpsError("invalid-argument", "bookingId required");
    }

    const db = admin.firestore();
    const bookingRef = db.collection("bookings").doc(bookingId);
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) {
      throw new HttpsError("not-found", "Booking not found");
    }

    const booking = bookingSnap.data() || {};
    if (booking.userId !== request.auth.uid && !(await isAdminUser(request.auth.uid))) {
      throw new HttpsError("permission-denied", "Not authorized for this booking");
    }

    if (booking.servicePersonnelId) {
      return { success: true, caregiverId: booking.servicePersonnelId, alreadyAssigned: true };
    }

    const caregiversSnap = await db
      .collection("servicePersonnel")
      .where("isActive", "==", true)
      .limit(200)
      .get();

    const caregiverIds = caregiversSnap.docs.map((doc) => doc.id);
    const userRefs = caregiverIds.map((id) => db.collection("users").doc(id));
    const userSnaps = userRefs.length > 0 ? await db.getAll(...userRefs) : [];
    const userMap = new Map();
    for (const snap of userSnaps) {
      if (snap.exists) {
        userMap.set(snap.id, snap.data() || {});
      }
    }

    const bookingDateTs = booking.date;
    const bookingDate = bookingDateTs?.toDate ? bookingDateTs.toDate() : null;
    const bookingDateStr = bookingDate
      ? `${bookingDate.getUTCFullYear()}-${String(bookingDate.getUTCMonth() + 1).padStart(2, "0")}-${String(bookingDate.getUTCDate()).padStart(2, "0")}`
      : null;

    const nowIst = new Date(Date.now() + (5.5 * 60 * 60 * 1000));
    const todayIstStr = `${nowIst.getUTCFullYear()}-${String(nowIst.getUTCMonth() + 1).padStart(2, "0")}-${String(nowIst.getUTCDate()).padStart(2, "0")}`;

    const candidates = caregiversSnap.docs
      .map((doc) => {
        const personnel = doc.data() || {};
        const user = userMap.get(doc.id) || {};

        const unavailableDates = Array.isArray(personnel.unavailableDates)
          ? personnel.unavailableDates
          : (Array.isArray(user.unavailableDates) ? user.unavailableDates : []);

        const unavailableWeekdays = Array.isArray(personnel.unavailableWeekdays)
          ? personnel.unavailableWeekdays
          : (Array.isArray(user.unavailableWeekdays) ? user.unavailableWeekdays : []);

        const overrideDate = typeof personnel.isAvailableOverrideDate === "string"
          ? personnel.isAvailableOverrideDate
          : (typeof user.isAvailableOverrideDate === "string" ? user.isAvailableOverrideDate : null);

        const isAvailable = typeof personnel.isAvailable === "boolean"
          ? personnel.isAvailable
          : (typeof user.isAvailable === "boolean" ? user.isAvailable : true);

        const isProfileComplete = Boolean(String(personnel.name || "").trim()) &&
          Boolean(String(personnel.phone || "").trim()) &&
          Boolean(String(personnel.city || "").trim()) &&
          Boolean(String(personnel.state || "").trim()) &&
          Array.isArray(personnel.specialties) &&
          personnel.specialties.length > 0;

        return {
          ...personnel,
          id: doc.id,
          _user: user,
          unavailableDates,
          unavailableWeekdays,
          isAvailableOverrideDate: overrideDate,
          isAvailable,
          isProfileComplete,
        };
      })
      .filter((cg) => {
        if (!cg.isActive || !cg.isAvailable || !cg.isProfileComplete) {
          return false;
        }

        const overrideDate = cg.isAvailableOverrideDate;
        const isHardUnavailable = cg.isAvailable === false && !overrideDate;
        const isTemporarilyUnavailableToday =
          cg.isAvailable === false && overrideDate === todayIstStr;

        if (isHardUnavailable) return false;
        if (isTemporarilyUnavailableToday && bookingDateStr === todayIstStr) {
          return false;
        }
        const unavailableDates = cg.unavailableDates;
        const unavailableWeekdays = cg.unavailableWeekdays;
        const weekday = bookingDate ? bookingDate.getUTCDay() : null;

        if (bookingDateStr && unavailableDates.includes(bookingDateStr)) return false;
        if (weekday !== null && unavailableWeekdays.includes(weekday)) return false;
        return true;
      });

    if (candidates.length === 0) {
      throw new HttpsError("failed-precondition", "No available caregivers");
    }

    const randomIndex = Math.floor(Math.random() * candidates.length);
    const selected = candidates[randomIndex];

    await bookingRef.update({
      servicePersonnelId: selected.id,
      servicePersonnelName: selected.name || selected._user?.name || "",
      caregiverName: selected.name || selected._user?.name || "",
      assignedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (selected.id) {
      await sendPushNotification(
        selected.id,
        "New Booking Assigned",
        "You have been assigned a new booking.",
        "booking_assigned",
        bookingId
      );
    }

    return {
      success: true,
      caregiverId: selected.id,
      caregiverName: selected.name || selected._user?.name || "",
    };
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// getAvailableCaregivers — list available caregivers for selected date
// ─────────────────────────────────────────────────────────────────────────────
exports.getAvailableCaregivers = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const dateStr = String(request.data?.date || "").trim();
    if (!dateStr || !/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
      throw new HttpsError("invalid-argument", "date must be YYYY-MM-DD");
    }

    const selectedDate = new Date(`${dateStr}T00:00:00.000Z`);
    if (Number.isNaN(selectedDate.getTime())) {
      throw new HttpsError("invalid-argument", "Invalid date");
    }
    const weekday = selectedDate.getUTCDay();

    const db = admin.firestore();
    const caregiversSnap = await db
      .collection("servicePersonnel")
      .where("isActive", "==", true)
      .where("isAvailable", "==", true)
      .limit(300)
      .get();

    const caregiverIds = caregiversSnap.docs.map((doc) => doc.id);
    const userRefs = caregiverIds.map((id) => db.collection("users").doc(id));
    const userSnaps = userRefs.length > 0 ? await db.getAll(...userRefs) : [];
    const userMap = new Map();
    for (const snap of userSnaps) {
      if (snap.exists) {
        userMap.set(snap.id, snap.data() || {});
      }
    }

    const caregivers = caregiversSnap.docs
      .map((doc) => {
        const personnel = doc.data() || {};
        const user = userMap.get(doc.id) || {};

        const unavailableDates = Array.isArray(personnel.unavailableDates)
          ? personnel.unavailableDates
          : (Array.isArray(user.unavailableDates) ? user.unavailableDates : []);

        const unavailableWeekdays = Array.isArray(personnel.unavailableWeekdays)
          ? personnel.unavailableWeekdays
          : (Array.isArray(user.unavailableWeekdays) ? user.unavailableWeekdays : []);

        const isProfileComplete = Boolean(String(personnel.name || "").trim()) &&
          Boolean(String(personnel.phone || "").trim()) &&
          Boolean(String(personnel.city || "").trim()) &&
          Boolean(String(personnel.state || "").trim()) &&
          Array.isArray(personnel.specialties) &&
          personnel.specialties.length > 0;

        return {
          ...personnel,
          id: doc.id,
          _user: user,
          unavailableDates,
          unavailableWeekdays,
          isProfileComplete,
        };
      })
      .filter((cg) => {
        if (!cg.isProfileComplete) {
          return false;
        }

        return !cg.unavailableDates.includes(dateStr) &&
          !cg.unavailableWeekdays.includes(weekday);
      })
      .map((cg) => ({
        id: cg.id,
        name: cg.name || cg._user?.name || "",
        rating: Number(cg.rating || 0),
        photoUrl: cg.imageUrl || cg.profileImage || cg._user?.profileImage || null,
        experience: cg.experience || cg.experienceYears || null,
      }));

    return { success: true, caregivers };
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// updateBookingProgress — caregiver updates booking state
// ─────────────────────────────────────────────────────────────────────────────
exports.updateBookingProgress = onCall(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const bookingId = request.data?.bookingId;
    const action = String(request.data?.action || "").trim();
    if (!bookingId || typeof bookingId !== "string" || !action) {
      throw new HttpsError("invalid-argument", "bookingId and action required");
    }

    const transitions = {
      start: { from: ["confirmed", "upcoming"], to: "in_progress" },
      request_completion: { from: ["in_progress"], to: "completion_requested" },
    };

    const transition = transitions[action];
    if (!transition) {
      throw new HttpsError("invalid-argument", "Invalid action");
    }

    const db = admin.firestore();
    const bookingRef = db.collection("bookings").doc(bookingId);
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) {
      throw new HttpsError("not-found", "Booking not found");
    }

    const booking = bookingSnap.data() || {};
    if (booking.servicePersonnelId !== request.auth.uid) {
      throw new HttpsError("permission-denied", "Only assigned caregiver can update progress");
    }
    if (!transition.from.includes(booking.status)) {
      throw new HttpsError("failed-precondition", `Booking must be ${transition.from.join(" or ")}`);
    }

    const patch = {
      status: transition.to,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (action === "start") {
      patch.serviceStartedAt = admin.firestore.FieldValue.serverTimestamp();
    }

    await bookingRef.update(patch);

    if (booking.userId) {
      await sendPushNotification(
        booking.userId,
        action === "start" ? "Service Started" : "Service Completion Requested",
        action === "start"
          ? "Your caregiver marked the session as started."
          : "Your caregiver requested service completion verification.",
        action === "start" ? "service_started" : "completion_requested",
        bookingId
      );
    }

    return { success: true, status: transition.to };
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// reportCaregiverNoShow — booking owner reports caregiver no-show
// ─────────────────────────────────────────────────────────────────────────────
exports.reportCaregiverNoShow = onCall(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const bookingId = request.data?.bookingId;
    if (!bookingId || typeof bookingId !== "string") {
      throw new HttpsError("invalid-argument", "bookingId required");
    }

    const db = admin.firestore();
    const bookingRef = db.collection("bookings").doc(bookingId);
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) {
      throw new HttpsError("not-found", "Booking not found");
    }

    const booking = bookingSnap.data() || {};
    if (booking.userId !== request.auth.uid) {
      throw new HttpsError("permission-denied", "Only booking owner can report no-show");
    }

    if (booking.status !== "confirmed" && booking.status !== "upcoming") {
      throw new HttpsError("failed-precondition", "Booking must be confirmed");
    }

    const dateTs = booking.date;
    const bookingDate = dateTs?.toDate ? dateTs.toDate() : null;
    if (!bookingDate) {
      throw new HttpsError("failed-precondition", "Booking date missing");
    }

    const graceEnd = new Date(bookingDate.getTime() + (25 * 60 * 1000));
    if (new Date() < graceEnd) {
      throw new HttpsError("failed-precondition", "Please wait 25 minutes from booking start time");
    }

    await bookingRef.update({
      status: "caregiver_noshow",
      cancelledBy: "system_noshow",
      paymentStatus: booking.paymentStatus === "paid" ? "refund_pending" : booking.paymentStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      noShowReportedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await sendPushNotification(
      booking.userId,
      "No-show Reported",
      "Your booking has been marked as caregiver no-show.",
      "noshow_reported",
      bookingId
    );

    return { success: true };
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// deleteUserAccount — self-service account deletion with active booking guard
// ─────────────────────────────────────────────────────────────────────────────
exports.deleteUserAccount = onCall(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const uid = request.auth.uid;
    const authTimeSeconds = Number(request.auth.token?.auth_time || 0);
    const nowSeconds = Math.floor(Date.now() / 1000);
    const maxAuthAgeSeconds = 10 * 60;
    if (!authTimeSeconds || (nowSeconds - authTimeSeconds) > maxAuthAgeSeconds) {
      throw new HttpsError(
        "failed-precondition",
        "Please re-authenticate before deleting your account"
      );
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const personnelRef = db.collection("servicePersonnel").doc(uid);

    const activeStatuses = ["confirmed", "upcoming", "in_progress", "completion_requested"];
    const [userSnap, personnelSnap, bookingsAsUser, bookingsAsCaregiver] = await Promise.all([
      userRef.get(),
      personnelRef.get(),
      db
        .collection("bookings")
        .where("userId", "==", uid)
        .where("status", "in", activeStatuses)
        .limit(1)
        .get(),
      db
        .collection("bookings")
        .where("servicePersonnelId", "==", uid)
        .where("status", "in", activeStatuses)
        .limit(1)
        .get(),
    ]);

    const role = String(userSnap.data()?.role || "").trim().toLowerCase();
    if (role === "admin") {
      throw new HttpsError("permission-denied", "Admin accounts cannot be deleted with this endpoint");
    }

    if (!bookingsAsUser.empty || !bookingsAsCaregiver.empty) {
      throw new HttpsError("failed-precondition", "Cannot delete account with active bookings");
    }

    const nowTs = admin.firestore.FieldValue.serverTimestamp();
    const anonymizedEmail = `deleted_${uid}@anon.local`;
    const batch = db.batch();

    batch.set(
      userRef,
      {
        name: "Deleted User",
        email: anonymizedEmail,
        phone: null,
        fcmToken: null,
        profileImage: null,
        emergencyContacts: [],
        address: "",
        street: "",
        city: "",
        state: "",
        pincode: "",
        latitude: null,
        longitude: null,
        isActive: false,
        role: "deleted",
        deletedAt: nowTs,
        updatedAt: nowTs,
      },
      { merge: true }
    );

    if (personnelSnap.exists) {
      batch.set(
        personnelRef,
        {
          name: "Deleted User",
          email: anonymizedEmail,
          phone: null,
          imageUrl: "",
          isActive: false,
          isAvailable: false,
          isOnline: false,
          deletedAt: nowTs,
          updatedAt: nowTs,
        },
        { merge: true }
      );
    }

    await batch.commit();

    try {
      await admin
        .storage()
        .bucket()
        .file(`profile_images/${uid}.jpg`)
        .delete({ ignoreNotFound: true });
    } catch (e) {
      console.warn("[deleteUserAccount] storage cleanup skipped:", e?.message || e);
    }

    try {
      await admin.auth().deleteUser(uid);
    } catch (e) {
      if (e?.code !== "auth/user-not-found") {
        console.error("[deleteUserAccount] auth delete failed:", e?.message || e);
        throw new HttpsError("internal", "Failed to complete account deletion");
      }
    }

    return {
      success: true,
      deletedAt: new Date().toISOString(),
    };
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// changeCaregiver — booking owner requests caregiver replacement
// ─────────────────────────────────────────────────────────────────────────────
exports.changeCaregiver = onCall(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const bookingId = request.data?.bookingId;
    const newCaregiverId = request.data?.newCaregiverId;
    const reason = String(request.data?.reason || "").trim();

    if (!bookingId || typeof bookingId !== "string" || !newCaregiverId || typeof newCaregiverId !== "string") {
      throw new HttpsError("invalid-argument", "bookingId and newCaregiverId required");
    }

    const db = admin.firestore();
    const bookingRef = db.collection("bookings").doc(bookingId);
    const newCaregiverRef = db.collection("users").doc(newCaregiverId);

    const [bookingSnap, newCgSnap, newPersonnelSnap] = await Promise.all([
      bookingRef.get(),
      newCaregiverRef.get(),
      db.collection("servicePersonnel").doc(newCaregiverId).get(),
    ]);
    if (!bookingSnap.exists) {
      throw new HttpsError("not-found", "Booking not found");
    }
    if (!newCgSnap.exists || newCgSnap.data()?.role !== "caregiver") {
      throw new HttpsError("not-found", "New caregiver not found");
    }

    const booking = bookingSnap.data() || {};
    if (booking.userId !== request.auth.uid) {
      throw new HttpsError("permission-denied", "Only booking owner can change caregiver");
    }
    if (booking.status !== "confirmed" && booking.status !== "upcoming") {
      throw new HttpsError("failed-precondition", "Booking must be confirmed");
    }

    const bookingDate = booking.date?.toDate ? booking.date.toDate() : null;
    if (!bookingDate) {
      throw new HttpsError("failed-precondition", "Booking date missing");
    }
    const hoursUntil = (bookingDate.getTime() - Date.now()) / (1000 * 60 * 60);
    if (hoursUntil < 6) {
      throw new HttpsError("failed-precondition", "Cannot change caregiver less than 6 hours before booking");
    }

    if (booking.servicePersonnelId === newCaregiverId) {
      throw new HttpsError("failed-precondition", "New caregiver is same as current caregiver");
    }

    if (Number(booking.caregiverChangeCount || 0) >= 1) {
      throw new HttpsError("failed-precondition", "Only one caregiver change is allowed");
    }

    const oldCaregiverId = booking.servicePersonnelId || null;
    const newCg = newCgSnap.data() || {};
    const newPersonnel = newPersonnelSnap.data() || {};
    const caregiverName = String(newPersonnel.name || newCg.name || "").trim();

    await bookingRef.update({
      servicePersonnelId: newCaregiverId,
      caregiverId: newCaregiverId,
      servicePersonnelName: caregiverName,
      caregiverName: caregiverName,
      previousCaregiverId: oldCaregiverId,
      caregiverChangeCount: admin.firestore.FieldValue.increment(1),
      caregiverChangeReason: reason || null,
      caregiverChangedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const notifications = [
      sendPushNotification(
        booking.userId,
        "Caregiver Updated",
        "Your booking caregiver has been changed successfully.",
        "caregiver_changed",
        bookingId
      ),
      sendPushNotification(
        newCaregiverId,
        "New Booking Assigned",
        "A booking has been assigned to you.",
        "booking_assigned",
        bookingId
      ),
    ];

    if (oldCaregiverId) {
      notifications.push(
        sendPushNotification(
          oldCaregiverId,
          "Booking Reassigned",
          "One of your bookings has been reassigned.",
          "booking_reassigned",
          bookingId
        )
      );
    }

    await Promise.all(notifications);

    return { success: true };
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// resetDailyAvailability — reset caregiver day override at IST midnight
// ─────────────────────────────────────────────────────────────────────────────
exports.resetDailyAvailability = onSchedule(
  {
    schedule: "30 18 * * *",
    timeZone: "UTC",
    region: "us-central1",
  },
  async () => {
    const db = admin.firestore();
    const nowIst = new Date(Date.now() + (5.5 * 60 * 60 * 1000));
    const todayStr = `${nowIst.getUTCFullYear()}-${String(nowIst.getUTCMonth() + 1).padStart(2, "0")}-${String(nowIst.getUTCDate()).padStart(2, "0")}`;

    const snap = await db
      .collection("servicePersonnel")
      .where("isAvailableOverrideDate", "==", todayStr)
      .get();

    if (snap.empty) {
      return null;
    }

    const chunkSize = 200;
    for (let i = 0; i < snap.docs.length; i += chunkSize) {
      const batch = db.batch();
      const chunk = snap.docs.slice(i, i + chunkSize);

      for (const doc of chunk) {
        batch.update(doc.ref, {
          isAvailable: true,
          isAvailableOverrideDate: null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        batch.set(
          db.collection("users").doc(doc.id),
          {
            isAvailable: true,
            isAvailableOverrideDate: null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      await batch.commit();
    }

    console.log(`[resetDailyAvailability] Reset ${snap.size} caregivers`);
    return null;
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// cleanupPastUnavailableDates — remove dates older than today
// ─────────────────────────────────────────────────────────────────────────────
exports.cleanupPastUnavailableDates = onSchedule(
  {
    schedule: "30 18 * * *",
    timeZone: "UTC",
    region: "us-central1",
  },
  async () => {
    const db = admin.firestore();
    const nowIst = new Date(Date.now() + (5.5 * 60 * 60 * 1000));
    const todayStr = `${nowIst.getUTCFullYear()}-${String(nowIst.getUTCMonth() + 1).padStart(2, "0")}-${String(nowIst.getUTCDate()).padStart(2, "0")}`;

    const caregiversSnap = await db
      .collection("servicePersonnel")
      .where("unavailableDates", "!=", null)
      .limit(500)
      .get();

    let cleaned = 0;
    for (const caregiver of caregiversSnap.docs) {
      const dates = Array.isArray(caregiver.data().unavailableDates)
        ? caregiver.data().unavailableDates
        : [];

      const futureOnly = dates.filter((d) => typeof d === "string" && d >= todayStr);
      if (futureOnly.length !== dates.length) {
        await Promise.all([
          caregiver.ref.update({
            unavailableDates: futureOnly,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }),
          db.collection("users").doc(caregiver.id).set(
            {
              unavailableDates: futureOnly,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          ),
        ]);
        cleaned += 1;
      }
    }

    console.log(`[cleanupPastUnavailableDates] Cleaned ${cleaned} caregivers`);
    return null;
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Admin panel callable APIs
// ─────────────────────────────────────────────────────────────────────────────
async function assertAdmin(request) {
  const context = await getAdminContext(request);
  return context.email;
}

exports.assertAdmin = assertAdmin;

const ROOT_ADMIN_EMAIL = "admin@goldencares.in";

function normalizeAdminType(value) {
  const normalized = String(value || "").trim().toLowerCase();
  if (normalized === "primary" || normalized === "secondary") {
    return normalized;
  }
  return null;
}

function requiresAdminPasswordReset(adminData, authToken) {
  const fromDoc = adminData?.mustChangePassword === true;
  const fromClaim = authToken?.passwordResetRequired === true;
  return fromDoc || fromClaim;
}

function toAdminContext(email, adminData) {
  const normalizedEmail = normalizeEmail(email);
  const normalizedType = normalizeAdminType(adminData?.adminType);
  const isRoot = normalizedEmail === ROOT_ADMIN_EMAIL;
  const adminType = isRoot ? "primary" : (normalizedType || "secondary");
  const isPrimary = adminType === "primary";

  return {
    email: normalizedEmail,
    adminType,
    isPrimary,
    isSecondary: !isPrimary,
    isRoot,
    mustChangePassword: adminData?.mustChangePassword === true,
    uid: normalizeId(adminData?.uid),
    canManageAdmins: isPrimary,
    canDeleteAccounts: isPrimary,
    canEditTransactions: false,
  };
}

async function getAdminContext(request, options = {}) {
  const allowPasswordResetRequired = options.allowPasswordResetRequired === true;
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login required");
  }

  const email = String(request.auth.token?.email || "").trim().toLowerCase();
  if (!email) {
    throw new HttpsError("permission-denied", "No email on auth token");
  }

  const db = admin.firestore();
  const directDoc = await db.collection("admin_role_users").doc(email).get();
  const encodedEmail = encodeURIComponent(email);
  const encodedDoc = encodedEmail === email
    ? directDoc
    : await db.collection("admin_role_users").doc(encodedEmail).get();

  const adminData = directDoc.exists ? directDoc.data() : encodedDoc.data();
  if (!adminData || adminData.isActive !== true) {
    throw new HttpsError("permission-denied", "Not an admin user");
  }

  if (
    !allowPasswordResetRequired &&
    requiresAdminPasswordReset(adminData, request.auth.token)
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Password update required before accessing admin actions"
    );
  }

  return toAdminContext(email, adminData);
}

async function assertPrimaryAdmin(request) {
  const ctx = await getAdminContext(request);
  if (!ctx.isPrimary) {
    throw new HttpsError(
      "permission-denied",
      "Only primary admins can perform this action"
    );
  }
  return ctx;
}

function validateAdminPassword(value) {
  const password = String(value || "");
  if (password.length < 12 || password.length > 128) {
    throw new HttpsError(
      "invalid-argument",
      "Password must be between 12 and 128 characters"
    );
  }
  if (!/[A-Z]/.test(password)) {
    throw new HttpsError(
      "invalid-argument",
      "Password must include at least one uppercase letter"
    );
  }
  if (!/[a-z]/.test(password)) {
    throw new HttpsError(
      "invalid-argument",
      "Password must include at least one lowercase letter"
    );
  }
  if (!/[0-9]/.test(password)) {
    throw new HttpsError(
      "invalid-argument",
      "Password must include at least one number"
    );
  }
  if (!/[!@#$%^&*()_+\-=[\]{};':"\\|,.<>/?]/.test(password)) {
    throw new HttpsError(
      "invalid-argument",
      "Password must include at least one special character"
    );
  }
  return password;
}

function normalizeAuditObject(value) {
  if (value === undefined) {
    return null;
  }
  if (value === null) {
    return null;
  }
  if (Array.isArray(value)) {
    return value.map((item) => normalizeAuditObject(item));
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (value && typeof value === "object") {
    if (typeof value.toDate === "function") {
      try {
        return value.toDate().toISOString();
      } catch (_) {
        return String(value);
      }
    }

    const output = {};
    for (const [key, child] of Object.entries(value)) {
      if (child === undefined) {
        continue;
      }
      output[key] = normalizeAuditObject(child);
    }
    return output;
  }
  return value;
}

function createAuditRecord({
  request,
  adminContext,
  actionCategory,
  targetEntityId,
  targetEntityType,
  previousState,
  newState,
}) {
  return {
    adminUid: String(request.auth?.uid || adminContext?.uid || "").trim(),
    adminEmail: String(adminContext?.email || request.auth?.token?.email || "")
      .trim()
      .toLowerCase(),
    actionCategory: String(actionCategory || "UNKNOWN").trim().toUpperCase(),
    targetEntityId: String(targetEntityId || "").trim(),
    targetEntityType: String(targetEntityType || "unknown").trim().toLowerCase(),
    previousState: normalizeAuditObject(previousState),
    newState: normalizeAuditObject(newState),
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function stripAuditInternalFields(entity) {
  const value = { ...(entity || {}) };
  delete value.updatedAt;
  delete value.createdAt;
  delete value.deletedAt;
  delete value.adminMutatedAt;
  return value;
}

async function writeAdminAuditLog({
  request,
  adminContext,
  actionCategory,
  targetEntityId,
  targetEntityType,
  previousState,
  newState,
}) {
  const db = admin.firestore();
  const auditRef = db.collection("admin_audit_logs").doc();
  await auditRef.set(
    createAuditRecord({
      request,
      adminContext,
      actionCategory,
      targetEntityId,
      targetEntityType,
      previousState,
      newState,
    })
  );
}

function normalizeId(value) {
  return String(value || "").trim();
}

function normalizeEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function generateTemporaryPassword(length = 14) {
  const upper = "ABCDEFGHJKLMNPQRSTUVWXYZ";
  const lower = "abcdefghijkmnopqrstuvwxyz";
  const digits = "23456789";
  const symbols = "!@#$%^*_-";
  const all = `${upper}${lower}${digits}${symbols}`;

  const pick = (charset) => {
    const idx = crypto.randomInt(0, charset.length);
    return charset[idx];
  };

  const targetLength = Math.max(12, Number(length) || 14);
  const chars = [
    pick(upper),
    pick(lower),
    pick(digits),
    pick(symbols),
  ];

  while (chars.length < targetLength) {
    chars.push(pick(all));
  }

  for (let i = chars.length - 1; i > 0; i -= 1) {
    const j = crypto.randomInt(0, i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }

  return chars.join("");
}

function sanitizeEntityType(value) {
  return String(value || "").trim().toLowerCase();
}

function safeImageExtension(contentType) {
  const normalized = String(contentType || "").trim().toLowerCase();
  if (normalized === "image/png") {
    return "png";
  }
  if (normalized === "image/webp") {
    return "webp";
  }
  if (normalized === "image/gif") {
    return "gif";
  }
  return "jpg";
}

function toMillis(value) {
  if (!value) {
    return 0;
  }
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : 0;
  }
  if (value?.toMillis && typeof value.toMillis === "function") {
    const millis = value.toMillis();
    return Number.isFinite(millis) ? millis : 0;
  }
  if (value?.toDate && typeof value.toDate === "function") {
    const date = value.toDate();
    return Number.isFinite(date?.getTime?.()) ? date.getTime() : 0;
  }
  const parsed = new Date(value);
  return Number.isFinite(parsed.getTime()) ? parsed.getTime() : 0;
}

function sortByTimelineDesc(left, right) {
  const leftMillis = Math.max(
    toMillis(left.createdAt),
    toMillis(left.updatedAt),
    toMillis(left.timestamp)
  );
  const rightMillis = Math.max(
    toMillis(right.createdAt),
    toMillis(right.updatedAt),
    toMillis(right.timestamp)
  );
  return rightMillis - leftMillis;
}

function toFiniteNumber(value) {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value === "string" && value.trim() === "") {
    return null;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function parseDurationHours(value) {
  const numeric = toFiniteNumber(value);
  if (numeric !== null) {
    return numeric > 0 ? numeric : null;
  }

  const text = String(value || "").trim();
  if (!text) {
    return null;
  }
  const match = text.match(/(\d+(?:\.\d+)?)/);
  if (!match) {
    return null;
  }
  const hours = Number(match[1]);
  return Number.isFinite(hours) && hours > 0 ? hours : null;
}

function inferAmountRupees(rawAmount, tx, bookingPrice) {
  const hasProviderOrderId = Boolean(normalizeId(tx.providerOrderId));
  const hasLegacyOrderId = Boolean(normalizeId(tx.orderId));

  if (hasProviderOrderId) {
    return rawAmount / 100;
  }
  if (!hasProviderOrderId && hasLegacyOrderId) {
    return rawAmount;
  }

  if (bookingPrice !== null && bookingPrice > 0) {
    const rupeesDistance = Math.abs(rawAmount - bookingPrice);
    const paiseDistance = Math.abs(rawAmount / 100 - bookingPrice);
    return paiseDistance < rupeesDistance ? rawAmount / 100 : rawAmount;
  }

  return rawAmount > 10000 ? rawAmount / 100 : rawAmount;
}

function inferFeeRupees(rawFee, tx, resolvedAmount) {
  const hasProviderOrderId = Boolean(normalizeId(tx.providerOrderId));
  const hasLegacyOrderId = Boolean(normalizeId(tx.orderId));

  if (hasProviderOrderId) {
    return rawFee / 100;
  }
  if (!hasProviderOrderId && hasLegacyOrderId) {
    return rawFee;
  }

  if (resolvedAmount > 0) {
    const expected = resolvedAmount * 0.02;
    const rupeesDistance = Math.abs(rawFee - expected);
    const paiseDistance = Math.abs(rawFee / 100 - expected);
    return paiseDistance < rupeesDistance ? rawFee / 100 : rawFee;
  }

  return rawFee > 10000 ? rawFee / 100 : rawFee;
}

function getTransactionBookingId(tx) {
  return normalizeId(tx.bookingId || tx.referenceId);
}

function normalizeTransactionForAdmin(id, transaction, booking = null) {
  const tx = transaction || {};

  const bookingPrice =
    toFiniteNumber(booking?.price) ??
    toFiniteNumber(booking?.amount) ??
    toFiniteNumber(booking?.totalAmount);

  const amountDisplay = toFiniteNumber(tx.amountDisplay);
  const rawAmount =
    toFiniteNumber(tx.amount) ??
    toFiniteNumber(tx.totalAmount) ??
    toFiniteNumber(tx.bookingAmount) ??
    toFiniteNumber(tx.paidAmount);

  let displayAmount = 0;
  if (amountDisplay !== null && (amountDisplay > 0 || rawAmount === null || rawAmount <= 0)) {
    displayAmount = amountDisplay;
  } else if (rawAmount !== null && rawAmount > 0) {
    displayAmount = inferAmountRupees(rawAmount, tx, bookingPrice);
  }

  const feeDisplay = toFiniteNumber(tx.platformFeeDisplay);
  const rawFee =
    toFiniteNumber(tx.platformFee) ??
    toFiniteNumber(tx.fee) ??
    toFiniteNumber(tx.serviceFee);
  let displayPlatformFee = 0;
  if (feeDisplay !== null && (feeDisplay > 0 || rawFee === null || rawFee <= 0)) {
    displayPlatformFee = feeDisplay;
  } else if (rawFee !== null && rawFee > 0) {
    displayPlatformFee = inferFeeRupees(rawFee, tx, displayAmount);
  }

  const durationHours =
    parseDurationHours(tx.durationHours) ??
    parseDurationHours(tx.serviceDurationHours) ??
    parseDurationHours(tx.hours) ??
    parseDurationHours(tx.serviceHours) ??
    parseDurationHours(tx?.metadata?.durationHours) ??
    parseDurationHours(tx?.metadata?.duration) ??
    parseDurationHours(tx.duration) ??
    parseDurationHours(booking?.durationHours) ??
    parseDurationHours(booking?.duration);

  const bookingServiceName = String(
    booking?.serviceName || booking?.serviceTitle || booking?.service || ""
  ).trim();
  const txServiceName = String(
    tx.serviceName || tx.serviceTitle || tx.service || ""
  ).trim();
  const serviceName = txServiceName || bookingServiceName;

  const txUserId = normalizeId(tx.userId || tx.familyId);
  const bookingUserId = normalizeId(booking?.userId || booking?.familyId);
  const resolvedUserId = txUserId || bookingUserId;

  const txPersonnelId = normalizeId(
    tx.servicePersonnelId || tx.caregiverId || tx.partnerId
  );
  const bookingPersonnelId = normalizeId(
    booking?.servicePersonnelId || booking?.caregiverId || booking?.partnerId
  );
  const resolvedPersonnelId = txPersonnelId || bookingPersonnelId;

  return {
    id,
    ...tx,
    bookingId: normalizeId(tx.bookingId || tx.referenceId),
    userId: resolvedUserId,
    servicePersonnelId: resolvedPersonnelId,
    serviceName,
    displayAmount,
    displayPlatformFee,
    displayDurationHours: durationHours,
  };
}

async function buildBookingMapForTransactions(db, transactions) {
  const bookingIds = [];
  for (const tx of transactions) {
    const bookingId = getTransactionBookingId(tx);
    if (bookingId) {
      bookingIds.push(bookingId);
    }
  }

  const uniqueIds = [...new Set(bookingIds)];
  if (uniqueIds.length === 0) {
    return new Map();
  }

  const bookingRefs = uniqueIds.map((id) => db.collection("bookings").doc(id));
  const bookingSnaps = await db.getAll(...bookingRefs);

  const map = new Map();
  for (const snap of bookingSnaps) {
    if (snap.exists) {
      map.set(snap.id, snap.data() || {});
    }
  }
  return map;
}

async function notifyUserChange(userId, title, body, type = "admin_update") {
  if (!userId) {
    return;
  }
  await sendPushNotification(userId, title, body, type, null);
}

exports.adminGetStats = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    await assertAdmin(request);
    const db = admin.firestore();

    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const todayTimestamp = admin.firestore.Timestamp.fromDate(todayStart);

    const [
      totalBookings,
      todayBookings,
      activeBookings,
      completedBookings,
      familyUsers,
      caregivers,
      activeCaregivers,
      pendingCaregivers,
    ] = await Promise.all([
      db.collection("bookings").count().get(),
      db.collection("bookings").where("createdAt", ">=", todayTimestamp).count().get(),
      db
        .collection("bookings")
        .where("status", "in", ["confirmed", "in_progress", "completion_requested"])
        .count()
        .get(),
      db.collection("bookings").where("status", "==", "completed").count().get(),
      db.collection("users").where("role", "==", "family").count().get(),
      db.collection("users").where("role", "==", "caregiver").count().get(),
      db
        .collection("users")
        .where("role", "==", "caregiver")
        .where("isAvailable", "==", true)
        .count()
        .get(),
      db
        .collection("users")
        .where("role", "==", "caregiver")
        .where("isApproved", "==", false)
        .count()
        .get(),
    ]);

    const capturedTransactions = await db
      .collection("transactions")
      .where("status", "==", "captured")
      .get();

    let totalRevenue = 0;
    let todayRevenue = 0;
    let platformFees = 0;

    for (const doc of capturedTransactions.docs) {
      const tx = doc.data() || {};
      const normalized = normalizeTransactionForAdmin(doc.id, tx);
      const amount = Number(normalized.displayAmount || 0);
      const fee = Number(normalized.displayPlatformFee || 0);
      totalRevenue += amount;
      platformFees += fee;

      const createdAt = tx.createdAt?.toDate ? tx.createdAt.toDate() : null;
      if (createdAt && createdAt >= todayStart) {
        todayRevenue += amount;
      }
    }

    return {
      bookings: {
        total: totalBookings.data().count,
        today: todayBookings.data().count,
        active: activeBookings.data().count,
        completed: completedBookings.data().count,
      },
      users: {
        families: familyUsers.data().count,
        caregivers: caregivers.data().count,
        activeCaregivers: activeCaregivers.data().count,
        pendingApproval: pendingCaregivers.data().count,
      },
      revenue: {
        total: totalRevenue,
        today: todayRevenue,
        platformFees,
      },
    };
  }
);

exports.adminListUsers = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    await assertAdmin(request);
    const data = request.data || {};
    const userId = normalizeId(data.userId);
    const role = typeof data.role === "string" && data.role.trim() ? data.role.trim() : null;
    const limit = Math.max(1, Math.min(Number(data.limit || 20), 100));
    const startAfterId = typeof data.startAfter === "string" ? data.startAfter : null;

    const db = admin.firestore();

    if (userId) {
      const userSnap = await db.collection("users").doc(userId).get();
      if (!userSnap.exists) {
        return { users: [], lastId: null, hasMore: false };
      }
      const value = userSnap.data() || {};
      if (role && String(value.role || "") !== role) {
        return { users: [], lastId: null, hasMore: false };
      }
      delete value.fcmToken;
      return {
        users: [{ ...value, id: userSnap.id }],
        lastId: null,
        hasMore: false,
      };
    }

    let query = db.collection("users").limit(limit);
    if (role) {
      query = db
        .collection("users")
        .where("role", "==", role)
        .limit(limit);
    }

    if (startAfterId) {
      const cursor = await db.collection("users").doc(startAfterId).get();
      if (cursor.exists) {
        query = query.startAfter(cursor);
      }
    }

    const snap = await query.get();
    const users = snap.docs.map((doc) => {
      const value = doc.data() || {};
      delete value.fcmToken;
      return { ...value, id: doc.id };
    }).sort(sortByTimelineDesc);

    return {
      users,
      lastId: snap.docs.length === limit ? snap.docs[snap.docs.length - 1].id : null,
      hasMore: snap.docs.length === limit,
    };
  }
);

exports.adminUpdateUser = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await getAdminContext(request);
    const data = request.data || {};
    const userId = String(data.userId || "").trim();
    const updates = data.updates || {};
    if (!userId) {
      throw new HttpsError("invalid-argument", "userId required");
    }

    const allowed = [
      "isAvailable",
      "isApproved",
      "name",
      "isActive",
      "email",
      "phone",
      "rating",
      "experienceYears",
      "city",
      "state",
      "address",
      "profileImage",
    ];
    const filtered = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    for (const key of allowed) {
      if (Object.prototype.hasOwnProperty.call(updates, key)) {
        filtered[key] = updates[key];
      }
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(userId);
    let changedKeys = [];

    await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new HttpsError("not-found", "User not found");
      }

      const before = userSnap.data() || {};
      tx.update(userRef, filtered);

      const mergedAfter = {
        ...before,
        ...stripAuditInternalFields(filtered),
      };

      changedKeys = Object.keys(filtered).filter((key) => key !== "updatedAt");
      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext,
          actionCategory: "USER_UPDATE",
          targetEntityId: userId,
          targetEntityType: "users",
          previousState: stripAuditInternalFields(before),
          newState: stripAuditInternalFields(mergedAfter),
        })
      );
    });

    if (changedKeys.length > 0) {
      await notifyUserChange(
        userId,
        "Profile Updated",
        `Admin updated your profile fields: ${changedKeys.join(", ")}`,
        "profile_updated"
      );
    }

    if (Object.prototype.hasOwnProperty.call(filtered, "isApproved")) {
      await notifyUserChange(
        userId,
        filtered.isApproved ? "Verification Approved" : "Verification Updated",
        filtered.isApproved
          ? "Your verification has been approved by admin."
          : "Your verification status has been updated by admin.",
        "verification_update"
      );
    }

    return { success: true };
  }
);

exports.adminUpsertUser = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await getAdminContext(request);
    const userId = normalizeId(request.data?.userId);
    const payload = request.data?.data || {};

    if (!userId) {
      throw new HttpsError("invalid-argument", "userId required");
    }

    const allowed = [
      "name",
      "email",
      "phone",
      "role",
      "isActive",
      "isAvailable",
      "isApproved",
      "city",
      "state",
      "address",
      "rating",
      "experienceYears",
    ];

    const filtered = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    for (const key of allowed) {
      if (Object.prototype.hasOwnProperty.call(payload, key)) {
        filtered[key] = payload[key];
      }
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(userId);
    await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      const before = userSnap.exists ? (userSnap.data() || {}) : null;
      tx.set(userRef, filtered, { merge: true });

      const after = {
        ...(before || {}),
        ...stripAuditInternalFields(filtered),
      };
      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext,
          actionCategory: "USER_UPSERT",
          targetEntityId: userId,
          targetEntityType: "users",
          previousState: stripAuditInternalFields(before),
          newState: stripAuditInternalFields(after),
        })
      );
    });

    await notifyUserChange(
      userId,
      "Profile Updated",
      "Your profile was created or updated by admin.",
      "profile_updated"
    );

    return { success: true };
  }
);

exports.adminDeleteUser = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await assertPrimaryAdmin(request);
    const userId = String(request.data?.userId || "").trim();
    if (!userId) {
      throw new HttpsError("invalid-argument", "userId required");
    }

    const db = admin.firestore();
    const activeStatuses = ["confirmed", "in_progress", "completion_requested"];
    const [asFamily, asCaregiver] = await Promise.all([
      db
        .collection("bookings")
        .where("userId", "==", userId)
        .where("status", "in", activeStatuses)
        .limit(1)
        .get(),
      db
        .collection("bookings")
        .where("servicePersonnelId", "==", userId)
        .where("status", "in", activeStatuses)
        .limit(1)
        .get(),
    ]);

    if (!asFamily.empty || !asCaregiver.empty) {
      throw new HttpsError("failed-precondition", "User has active bookings");
    }

    const userRef = db.collection("users").doc(userId);
    await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      const before = userSnap.exists ? (userSnap.data() || {}) : null;
      const anonymized = {
        name: "Deleted User",
        email: `deleted_${userId}@anon.local`,
        phone: null,
        fcmToken: null,
        isActive: false,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      tx.set(userRef, anonymized, { merge: true });
      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext,
          actionCategory: "USER_DELETE",
          targetEntityId: userId,
          targetEntityType: "users",
          previousState: stripAuditInternalFields(before),
          newState: {
            ...stripAuditInternalFields(before),
            name: "Deleted User",
            email: `deleted_${userId}@anon.local`,
            phone: null,
            fcmToken: null,
            isActive: false,
          },
        })
      );
    });

    try {
      await admin.auth().deleteUser(userId);
    } catch (_) {
      // Ignore auth delete failures for already-removed users.
    }

    return { success: true };
  }
);

exports.adminListBookings = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    await assertAdmin(request);
    const data = request.data || {};
    const bookingId = normalizeId(data.bookingId);
    const userId = normalizeId(data.userId);
    const servicePersonnelId = normalizeId(data.servicePersonnelId);
    const status = typeof data.status === "string" && data.status.trim() ? data.status.trim() : null;
    const limit = Math.max(1, Math.min(Number(data.limit || 20), 100));
    const startAfterId = typeof data.startAfter === "string" ? data.startAfter : null;

    const db = admin.firestore();

    if (bookingId) {
      const bookingSnap = await db.collection("bookings").doc(bookingId).get();
      if (!bookingSnap.exists) {
        return { bookings: [], lastId: null, hasMore: false };
      }
      const booking = { ...(bookingSnap.data() || {}), id: bookingSnap.id };
      if (status && String(booking.status || "") !== status) {
        return { bookings: [], lastId: null, hasMore: false };
      }
      if (userId && String(booking.userId || "") !== userId) {
        return { bookings: [], lastId: null, hasMore: false };
      }
      const assignedId = String(booking.servicePersonnelId || booking.caregiverId || "");
      if (servicePersonnelId && assignedId !== servicePersonnelId) {
        return { bookings: [], lastId: null, hasMore: false };
      }
      return {
        bookings: [booking],
        lastId: null,
        hasMore: false,
      };
    }

    let query = db.collection("bookings").limit(limit);
    if (status) {
      query = db
        .collection("bookings")
        .where("status", "==", status)
        .limit(limit);
    }

    if (userId) {
      query = db
        .collection("bookings")
        .where("userId", "==", userId)
        .limit(limit);
      if (status) {
        query = db
          .collection("bookings")
          .where("userId", "==", userId)
          .where("status", "==", status)
          .limit(limit);
      }
    }

    if (servicePersonnelId) {
      query = db
        .collection("bookings")
        .where("servicePersonnelId", "==", servicePersonnelId)
        .limit(limit);
      if (status) {
        query = db
          .collection("bookings")
          .where("servicePersonnelId", "==", servicePersonnelId)
          .where("status", "==", status)
          .limit(limit);
      }
    }

    if (startAfterId) {
      const cursor = await db.collection("bookings").doc(startAfterId).get();
      if (cursor.exists) {
        query = query.startAfter(cursor);
      }
    }

    const snap = await query.get();
    return {
      bookings: snap.docs
        .map((doc) => ({ ...doc.data(), id: doc.id }))
        .sort(sortByTimelineDesc),
      lastId: snap.docs.length === limit ? snap.docs[snap.docs.length - 1].id : null,
      hasMore: snap.docs.length === limit,
    };
  }
);

exports.adminUpdateBooking = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await getAdminContext(request);
    const adminEmail = adminContext.email;
    const data = request.data || {};
    const bookingId = normalizeId(data.bookingId);
    const updates = data.updates || {};

    if (!bookingId) {
      throw new HttpsError("invalid-argument", "bookingId required");
    }

    const allowed = [
      "status",
      "servicePersonnelId",
      "caregiverId",
      "servicePersonnelName",
      "caregiverName",
      "price",
      "totalAmount",
      "adminNote",
      "notes",
      "date",
      "startTime",
      "endTime",
    ];

    const validStatuses = [
      "pending_payment",
      "confirmed",
      "in_progress",
      "completion_requested",
      "completed",
      "cancelled",
      "expired",
    ];

    const db = admin.firestore();
    const bookingRef = db.collection("bookings").doc(bookingId);
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) {
      throw new HttpsError("not-found", "Booking not found");
    }

    const booking = bookingSnap.data() || {};
    const filtered = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      adminMutatedBy: adminEmail,
      adminMutatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    for (const key of allowed) {
      if (Object.prototype.hasOwnProperty.call(updates, key)) {
        filtered[key] = updates[key];
      }
    }

    if (Object.prototype.hasOwnProperty.call(filtered, "status") &&
      !validStatuses.includes(String(filtered.status))) {
      throw new HttpsError("invalid-argument", "Invalid booking status");
    }

    const previousCaregiverId = String(
      booking.servicePersonnelId || booking.caregiverId || ""
    );
    const requestedCaregiverId = normalizeId(filtered.servicePersonnelId || filtered.caregiverId);

    if (requestedCaregiverId) {
      const [caregiverUserDoc, caregiverPersonnelDoc] = await Promise.all([
        db.collection("users").doc(requestedCaregiverId).get(),
        db.collection("servicePersonnel").doc(requestedCaregiverId).get(),
      ]);

      if (!caregiverUserDoc.exists && !caregiverPersonnelDoc.exists) {
        throw new HttpsError("not-found", "Assigned caregiver not found");
      }

      const caregiverData = caregiverPersonnelDoc.data() || caregiverUserDoc.data() || {};
      const resolvedName = String(caregiverData.name || "").trim();

      filtered.servicePersonnelId = requestedCaregiverId;
      filtered.caregiverId = requestedCaregiverId;
      filtered.servicePersonnelName = resolvedName || filtered.servicePersonnelName || "";
      filtered.caregiverName = resolvedName || filtered.caregiverName || "";
    }

    await db.runTransaction(async (tx) => {
      const currentSnap = await tx.get(bookingRef);
      const before = currentSnap.exists ? (currentSnap.data() || {}) : {};
      tx.update(bookingRef, filtered);

      const after = {
        ...before,
        ...stripAuditInternalFields(filtered),
      };

      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext,
          actionCategory: "BOOKING_UPDATE",
          targetEntityId: bookingId,
          targetEntityType: "bookings",
          previousState: stripAuditInternalFields(before),
          newState: stripAuditInternalFields(after),
        })
      );
    });

    const changedFields = Object.keys(filtered).filter(
      (key) => !["updatedAt", "adminMutatedBy", "adminMutatedAt"].includes(key)
    );

    if (booking.userId) {
      await sendPushNotification(
        booking.userId,
        "Booking Updated",
        `Admin updated your booking (${changedFields.join(", ") || "details"}).`,
        "booking_updated",
        bookingId
      );
    }

    const nextCaregiverId = requestedCaregiverId || previousCaregiverId;
    if (nextCaregiverId) {
      await sendPushNotification(
        nextCaregiverId,
        "Booking Updated",
        "An admin updated a booking assigned to you.",
        "booking_updated",
        bookingId
      );
    }

    if (
      requestedCaregiverId &&
      previousCaregiverId &&
      requestedCaregiverId !== previousCaregiverId
    ) {
      await sendPushNotification(
        previousCaregiverId,
        "Booking Reassigned",
        "A booking has been reassigned to another caregiver by admin.",
        "booking_reassigned",
        bookingId
      );
    }

    return { success: true };
  }
);

exports.adminReassignCaregiver = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await getAdminContext(request);
    const adminEmail = adminContext.email;
    const data = request.data || {};
    const bookingId = String(data.bookingId || "").trim();
    const newCaregiverId = String(data.newCaregiverId || "").trim();
    const reason = String(data.reason || "").trim();

    if (!bookingId || !newCaregiverId) {
      throw new HttpsError("invalid-argument", "bookingId and newCaregiverId required");
    }

    const db = admin.firestore();
    const [bookingSnap, caregiverUserSnap, caregiverPersonnelSnap] = await Promise.all([
      db.collection("bookings").doc(bookingId).get(),
      db.collection("users").doc(newCaregiverId).get(),
      db.collection("servicePersonnel").doc(newCaregiverId).get(),
    ]);

    if (!bookingSnap.exists) {
      throw new HttpsError("not-found", "Booking not found");
    }
    if (!caregiverUserSnap.exists && !caregiverPersonnelSnap.exists) {
      throw new HttpsError("not-found", "Caregiver not found");
    }

    const booking = bookingSnap.data() || {};
    const caregiver = caregiverPersonnelSnap.data() || caregiverUserSnap.data() || {};
    const caregiverName = String(caregiver.name || "").trim();

    const bookingRef = db.collection("bookings").doc(bookingId);
    await db.runTransaction(async (tx) => {
      const currentSnap = await tx.get(bookingRef);
      const before = currentSnap.exists ? (currentSnap.data() || {}) : {};
      const mutation = {
        servicePersonnelId: newCaregiverId,
        caregiverId: newCaregiverId,
        servicePersonnelName: caregiverName,
        caregiverName: caregiverName,
        adminReassigned: true,
        adminReassignReason: reason,
        adminMutatedBy: adminEmail,
        adminMutatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      tx.update(bookingRef, mutation);

      const after = {
        ...before,
        ...stripAuditInternalFields(mutation),
      };

      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext,
          actionCategory: "BOOKING_REASSIGN",
          targetEntityId: bookingId,
          targetEntityType: "bookings",
          previousState: stripAuditInternalFields(before),
          newState: stripAuditInternalFields(after),
        })
      );
    });

    await Promise.all([
      booking.userId
        ? sendPushNotification(
          booking.userId,
          "Caregiver Updated",
          "Your caregiver has been updated.",
          "caregiver_changed",
          bookingId
        )
        : Promise.resolve(),
      sendPushNotification(
        newCaregiverId,
        "New Booking",
        "You have been assigned a booking.",
        "booking_assigned",
        bookingId
      ),
    ]);

    return { success: true };
  }
);

exports.adminCancelBooking = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await getAdminContext(request);
    const adminEmail = adminContext.email;
    const data = request.data || {};
    const bookingId = String(data.bookingId || "").trim();
    const reason = String(data.reason || "").trim();
    const issueRefund = data.issueRefund !== false;

    if (!bookingId) {
      throw new HttpsError("invalid-argument", "bookingId required");
    }
    if (!issueRefund) {
      throw new HttpsError(
        "failed-precondition",
        "Admin cancellation requires issueRefund=true."
      );
    }

    const db = admin.firestore();
    const bookingRef = db.collection("bookings").doc(bookingId);
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) {
      throw new HttpsError("not-found", "Booking not found");
    }

    const booking = bookingSnap.data() || {};
    if (["completed", "cancelled", "expired"].includes(booking.status)) {
      throw new HttpsError("failed-precondition", "Cannot cancel this booking");
    }

    const before = booking;

    const cancelResult = await processBookingCancellationWithRefund({
      request,
      bookingId,
      actorUid: request.auth.uid,
      isAdmin: true,
      cancelledBy: "admin",
      refundReason: reason || "admin_cancellation",
      familyCancellationMessage: "Your booking was cancelled by admin.",
      caregiverCancellationMessage: "An assigned booking has been cancelled by admin.",
    });

    await bookingRef.set(
      {
        cancellationReason: reason || "admin_cancellation",
        adminMutatedBy: adminEmail,
        adminMutatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    const updatedSnap = await bookingRef.get();
    const after = updatedSnap.exists ? (updatedSnap.data() || {}) : before;

    await db.collection("admin_audit_logs").doc().set(
      createAuditRecord({
        request,
        adminContext,
        actionCategory: "BOOKING_CANCEL",
        targetEntityId: bookingId,
        targetEntityType: "bookings",
        previousState: stripAuditInternalFields(before),
        newState: stripAuditInternalFields(after),
      })
    );

    return {
      ...cancelResult,
      issueRefund,
    };
  }
);

exports.adminGetPricing = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    await assertAdmin(request);

    const normalizeServiceForAdmin = (id, service) => {
      const value = service || {};
      const options = Array.isArray(value.options) ? value.options : [];
      const primaryOption = options.find((item) => item && typeof item === "object") || null;

      const resolvedName = String(
        value.name || value.title || value.serviceName || ""
      ).trim() || `Service ${id}`;

      const resolvedPrice =
        toFiniteNumber(value.price) ??
        toFiniteNumber(value.amount) ??
        toFiniteNumber(primaryOption?.price) ??
        0;

      const resolvedDurationHours =
        parseDurationHours(value.durationHours) ??
        parseDurationHours(value.duration) ??
        parseDurationHours(primaryOption?.durationHours) ??
        parseDurationHours(primaryOption?.duration) ??
        0;

      const numericIdOrder = toFiniteNumber(id);
      const resolvedOrder =
        toFiniteNumber(value.order) ??
        (numericIdOrder !== null && numericIdOrder >= 0 ? numericIdOrder : 999);
      const resolvedIsActive = typeof value.isActive === "boolean"
        ? value.isActive
        : (typeof value.isPopular === "boolean" ? value.isPopular : true);

      const resolvedMaxQuantity =
        toFiniteNumber(value.maxQuantity) ??
        toFiniteNumber(primaryOption?.maxQuantity);

      return {
        ...value,
        id,
        name: resolvedName,
        serviceName: resolvedName,
        title: String(value.title || resolvedName),
        category: String(value.category || value.type || "-").trim() || "-",
        description: String(value.description || ""),
        price: resolvedPrice,
        durationHours: resolvedDurationHours,
        order: Number.isFinite(resolvedOrder) ? resolvedOrder : 999,
        isActive: resolvedIsActive,
        maxQuantity: resolvedMaxQuantity ?? null,
      };
    };

    const snap = await admin.firestore().collection("services").get();
    const services = snap.docs
      .map((doc) => normalizeServiceForAdmin(doc.id, doc.data() || {}))
      .sort((left, right) => Number(left.order || 999) - Number(right.order || 999));
    return {
      services,
    };
  }
);

exports.adminUpdatePricing = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await getAdminContext(request);
    const data = request.data || {};
    const serviceId = String(data.serviceId || "").trim();
    const updates = data.updates || {};

    if (!serviceId) {
      throw new HttpsError("invalid-argument", "serviceId required");
    }

    const allowed = [
      "price",
      "name",
      "title",
      "isActive",
      "isPopular",
      "durationHours",
      "category",
      "description",
      "order",
      "maxQuantity",
      "options",
      "includedItems",
      "imageUrl",
    ];
    const filtered = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    for (const key of allowed) {
      if (Object.prototype.hasOwnProperty.call(updates, key)) {
        filtered[key] = updates[key];
      }
    }

    // Maintain compatibility while migrating clients from isPopular to isActive.
    if (Object.prototype.hasOwnProperty.call(filtered, "isActive") &&
      !Object.prototype.hasOwnProperty.call(filtered, "isPopular")) {
      filtered.isPopular = filtered.isActive;
    }
    if (Object.prototype.hasOwnProperty.call(filtered, "isPopular") &&
      !Object.prototype.hasOwnProperty.call(filtered, "isActive")) {
      filtered.isActive = filtered.isPopular;
    }

    const db = admin.firestore();
    const serviceRef = db.collection("services").doc(serviceId);
    await db.runTransaction(async (tx) => {
      const serviceSnap = await tx.get(serviceRef);
      if (!serviceSnap.exists) {
        throw new HttpsError("not-found", "Service not found");
      }

      const before = serviceSnap.data() || {};
      tx.update(serviceRef, filtered);
      const after = {
        ...before,
        ...stripAuditInternalFields(filtered),
      };
      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext,
          actionCategory: "SERVICE_UPDATE",
          targetEntityId: serviceId,
          targetEntityType: "services",
          previousState: stripAuditInternalFields(before),
          newState: stripAuditInternalFields(after),
        })
      );
    });
    return { success: true };
  }
);

exports.adminCreateService = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await getAdminContext(request);
    const service = request.data?.service || {};
    const name = String(service.name || "").trim();
    const options = Array.isArray(service.options)
      ? service.options.filter((item) => item && typeof item === "object")
      : [];

    const normalizedOptions = [];
    for (const option of options) {
      const optionPrice = toFiniteNumber(option.price);
      const optionDurationHours =
        parseDurationHours(option.durationHours) ??
        parseDurationHours(option.duration);
      if (optionPrice === null || optionPrice <= 0) {
        continue;
      }
      if (optionDurationHours === null || optionDurationHours <= 0) {
        continue;
      }

      const durationText = String(
        option.duration || `${optionDurationHours} hours`
      ).trim();

      normalizedOptions.push({
        ...option,
        duration: durationText,
        durationHours: optionDurationHours,
        price: optionPrice,
      });
    }

    const explicitPrice = toFiniteNumber(service.price);
    const explicitDurationHours = parseDurationHours(service.durationHours);
    const optionPrices = normalizedOptions.map((item) => Number(item.price));
    const optionDurations = normalizedOptions.map((item) => Number(item.durationHours));

    const priceCandidates = [];
    if (explicitPrice !== null && explicitPrice > 0) {
      priceCandidates.push(explicitPrice);
    }
    priceCandidates.push(...optionPrices.filter((value) => Number.isFinite(value) && value > 0));

    const durationCandidates = [];
    if (explicitDurationHours !== null && explicitDurationHours > 0) {
      durationCandidates.push(explicitDurationHours);
    }
    durationCandidates.push(
      ...optionDurations.filter((value) => Number.isFinite(value) && value > 0)
    );

    const price = priceCandidates.length > 0 ? Math.min(...priceCandidates) : NaN;
    const durationHours = durationCandidates.length > 0 ? Math.min(...durationCandidates) : 1;

    if (!name || !Number.isFinite(price) || price <= 0) {
      throw new HttpsError(
        "invalid-argument",
        "Service name and positive price are required"
      );
    }

    const db = admin.firestore();
    const docRef = db.collection("services").doc();
    const payload = {
      id: docRef.id,
      name,
      price,
      durationHours: Number.isFinite(durationHours) && durationHours > 0
        ? durationHours
        : 1,
      isActive: service.isActive !== false,
      isPopular: service.isPopular === true || service.isActive !== false,
      category: String(service.category || "general"),
      description: String(service.description || ""),
      order: Number(service.order || 999),
      maxQuantity: toFiniteNumber(service.maxQuantity),
      options: normalizedOptions.length > 0 ? normalizedOptions : [
        {
          duration: `${durationHours} hours`,
          durationHours,
          price,
        },
      ],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const batch = db.batch();
    batch.set(docRef, payload);
    const auditRef = db.collection("admin_audit_logs").doc();
    batch.set(
      auditRef,
      createAuditRecord({
        request,
        adminContext,
        actionCategory: "SERVICE_CREATE",
        targetEntityId: docRef.id,
        targetEntityType: "services",
        previousState: null,
        newState: stripAuditInternalFields({ ...payload }),
      })
    );
    await batch.commit();

    return { success: true, serviceId: docRef.id };
  }
);

exports.adminDeleteService = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await getAdminContext(request);
    const serviceId = normalizeId(request.data?.serviceId);
    if (!serviceId) {
      throw new HttpsError("invalid-argument", "serviceId required");
    }
    const db = admin.firestore();
    const serviceRef = db.collection("services").doc(serviceId);
    await db.runTransaction(async (tx) => {
      const serviceSnap = await tx.get(serviceRef);
      if (!serviceSnap.exists) {
        throw new HttpsError("not-found", "Service not found");
      }

      const before = serviceSnap.data() || {};
      tx.delete(serviceRef);
      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext,
          actionCategory: "SERVICE_DELETE",
          targetEntityId: serviceId,
          targetEntityType: "services",
          previousState: stripAuditInternalFields(before),
          newState: null,
        })
      );
    });
    return { success: true };
  }
);

exports.adminUpdatePlatformFee = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await getAdminContext(request);
    const feePercent = Number(request.data?.feePercent);
    if (!Number.isFinite(feePercent) || feePercent < 0 || feePercent > 50) {
      throw new HttpsError("invalid-argument", "Fee must be a number between 0 and 50");
    }

    const db = admin.firestore();
    const pricingRef = db.collection("config").doc("pricing");
    await db.runTransaction(async (tx) => {
      const pricingSnap = await tx.get(pricingRef);
      const before = pricingSnap.exists ? (pricingSnap.data() || {}) : null;
      const mutation = {
        platformFeePercent: feePercent,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      tx.set(pricingRef, mutation, { merge: true });
      const after = {
        ...(before || {}),
        platformFeePercent: feePercent,
      };
      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext,
          actionCategory: "CONFIG_UPDATE",
          targetEntityId: "pricing",
          targetEntityType: "config",
          previousState: stripAuditInternalFields(before),
          newState: stripAuditInternalFields(after),
        })
      );
    });
    return { success: true };
  }
);

exports.adminUploadEntityImage = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await getAdminContext(request);

    const entityType = sanitizeEntityType(request.data?.entityType);
    const entityId = normalizeId(request.data?.entityId);
    const contentType = String(request.data?.contentType || "").trim().toLowerCase();
    const dataBase64 = String(request.data?.dataBase64 || "").trim();
    const fileNameHint = normalizeId(request.data?.fileName);

    if (!entityId || !dataBase64) {
      throw new HttpsError(
        "invalid-argument",
        "entityId and dataBase64 are required"
      );
    }
    if (!contentType.startsWith("image/")) {
      throw new HttpsError("invalid-argument", "Only image uploads are allowed");
    }

    let collection = "";
    let imageField = "";
    let storagePrefix = "";
    if (entityType === "caregiver") {
      collection = "users";
      imageField = "profileImage";
      storagePrefix = "caregivers";
    } else if (entityType === "service_personnel") {
      collection = "servicePersonnel";
      imageField = "profileImage";
      storagePrefix = "personnel";
    } else if (entityType === "service") {
      collection = "services";
      imageField = "imageUrl";
      storagePrefix = "services";
    } else {
      throw new HttpsError("invalid-argument", "Unsupported entityType");
    }

    const bytes = Buffer.from(dataBase64, "base64");
    if (!bytes.length || bytes.length > 8 * 1024 * 1024) {
      throw new HttpsError(
        "invalid-argument",
        "Image size must be between 1 byte and 8 MB"
      );
    }

    const targetRef = admin.firestore().collection(collection).doc(entityId);
    const targetSnap = await targetRef.get();
    if (!targetSnap.exists) {
      throw new HttpsError("not-found", "Target document not found");
    }

    const extension = safeImageExtension(contentType);
    const sanitizedHint = fileNameHint
      ? fileNameHint.replace(/[^a-zA-Z0-9._-]/g, "_")
      : "upload";
    const path = `admin_uploads/${storagePrefix}/${entityId}/${Date.now()}_${sanitizedHint}.${extension}`;

    const bucket = admin.storage().bucket();
    const file = bucket.file(path);
    await file.save(bytes, {
      metadata: {
        contentType,
        cacheControl: "public,max-age=3600",
      },
      resumable: false,
    });

    const [downloadUrl] = await file.getSignedUrl({
      action: "read",
      expires: "03-01-2500",
    });

    const db = admin.firestore();
    await db.runTransaction(async (tx) => {
      const targetCurrentSnap = await tx.get(targetRef);
      const before = targetCurrentSnap.exists ? (targetCurrentSnap.data() || {}) : {};
      tx.set(
        targetRef,
        {
          [imageField]: downloadUrl,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      const after = {
        ...before,
        [imageField]: downloadUrl,
      };

      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext,
          actionCategory: "MEDIA_UPDATE",
          targetEntityId: entityId,
          targetEntityType: collection,
          previousState: stripAuditInternalFields(before),
          newState: stripAuditInternalFields(after),
        })
      );
    });

    return {
      success: true,
      path,
      downloadUrl,
      field: imageField,
    };
  }
);

exports.adminListTransactions = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    await assertAdmin(request);
    const data = request.data || {};
    const transactionId = normalizeId(data.transactionId);
    const bookingId = normalizeId(data.bookingId);
    const userId = normalizeId(data.userId);
    const servicePersonnelId = normalizeId(data.servicePersonnelId);
    const limit = Math.max(1, Math.min(Number(data.limit || 20), 100));
    const startAfterId = typeof data.startAfter === "string" ? data.startAfter : null;

    const db = admin.firestore();

    if (transactionId) {
      const txSnap = await db.collection("transactions").doc(transactionId).get();
      if (!txSnap.exists) {
        return { transactions: [], lastId: null, hasMore: false };
      }
      const txRaw = txSnap.data() || {};
      const bookingIdForTx = getTransactionBookingId(txRaw);
      let booking = null;
      if (bookingIdForTx) {
        const bookingSnap = await db.collection("bookings").doc(bookingIdForTx).get();
        booking = bookingSnap.exists ? bookingSnap.data() : null;
      }
      const tx = normalizeTransactionForAdmin(txSnap.id, txRaw, booking);
      const txBookingId = normalizeId(tx.bookingId || tx.referenceId);
      const txUserId = normalizeId(tx.userId);
      const txPersonnelId = normalizeId(tx.servicePersonnelId);
      if (bookingId && txBookingId !== bookingId) {
        return { transactions: [], lastId: null, hasMore: false };
      }
      if (userId && txUserId !== userId) {
        return { transactions: [], lastId: null, hasMore: false };
      }
      if (servicePersonnelId && txPersonnelId !== servicePersonnelId) {
        return { transactions: [], lastId: null, hasMore: false };
      }
      return {
        transactions: [tx],
        lastId: null,
        hasMore: false,
      };
    }

    let query = db.collection("transactions").limit(limit);
    if (userId) {
      query = db
        .collection("transactions")
        .where("userId", "==", userId)
        .limit(limit);
    }
    if (servicePersonnelId) {
      query = db
        .collection("transactions")
        .where("servicePersonnelId", "==", servicePersonnelId)
        .limit(limit);
    }
    if (startAfterId) {
      const cursor = await db.collection("transactions").doc(startAfterId).get();
      if (cursor.exists) {
        query = query.startAfter(cursor);
      }
    }

    const snap = await query.get();
    let rawTransactions = snap.docs
      .map((doc) => ({ id: doc.id, ...(doc.data() || {}) }));

    // bookingId may be stored as bookingId OR referenceId depending on legacy flow.
    if (bookingId) {
      rawTransactions = rawTransactions.filter((tx) => {
        const txBookingId = normalizeId(tx.bookingId || tx.referenceId);
        return txBookingId === bookingId;
      });
    }

    if (userId) {
      rawTransactions = rawTransactions.filter(
        (tx) => normalizeId(tx.userId || tx.familyId) === userId
      );
    }

    if (servicePersonnelId) {
      rawTransactions = rawTransactions.filter(
        (tx) =>
          normalizeId(tx.servicePersonnelId || tx.caregiverId || tx.partnerId) ===
          servicePersonnelId
      );
    }

    const bookingMap = await buildBookingMapForTransactions(db, rawTransactions);

    return {
      transactions: rawTransactions
        .map((tx) => {
          const bookingIdForTx = getTransactionBookingId(tx);
          const booking = bookingIdForTx ? (bookingMap.get(bookingIdForTx) || null) : null;
          return normalizeTransactionForAdmin(tx.id, tx, booking);
        })
        .sort(sortByTimelineDesc),
      lastId: snap.docs.length === limit ? snap.docs[snap.docs.length - 1].id : null,
      hasMore: snap.docs.length === limit,
    };
  }
);

exports.adminUpdateTransaction = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    await assertAdmin(request);
    throw new HttpsError(
      "permission-denied",
      "Transactions are immutable from the admin panel"
    );
  }
);

exports.adminListServicePersonnel = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    await assertAdmin(request);
    const data = request.data || {};
    const limit = Math.max(1, Math.min(Number(data.limit || 50), 200));
    const startAfterId = typeof data.startAfter === "string" ? data.startAfter : null;

    let query = admin
      .firestore()
      .collection("servicePersonnel")
      .limit(limit);

    if (startAfterId) {
      const cursor = await admin.firestore().collection("servicePersonnel").doc(startAfterId).get();
      if (cursor.exists) {
        query = query.startAfter(cursor);
      }
    }

    const snap = await query.get();
    return {
      personnel: snap.docs
        .map((doc) => ({ ...doc.data(), id: doc.id }))
        .sort(sortByTimelineDesc),
      lastId: snap.docs.length === limit ? snap.docs[snap.docs.length - 1].id : null,
      hasMore: snap.docs.length === limit,
    };
  }
);

exports.adminUpdateServicePersonnel = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await getAdminContext(request);
    const personnelId = normalizeId(request.data?.personnelId);
    const updates = request.data?.updates || {};

    if (!personnelId) {
      throw new HttpsError("invalid-argument", "personnelId required");
    }

    const allowed = [
      "name",
      "phone",
      "isAvailable",
      "isApproved",
      "rating",
      "city",
      "state",
      "address",
      "serviceIds",
      "partnerId",
      "isActive",
      "profileImage",
      "visitsCompleted",
      "experienceYears",
    ];
    const primaryOnlyFields = ["visitsCompleted", "experienceYears"];

    const requestedPrimaryOnly = primaryOnlyFields.filter((key) =>
      Object.prototype.hasOwnProperty.call(updates, key)
    );
    if (requestedPrimaryOnly.length > 0 && !adminContext.isPrimary) {
      throw new HttpsError(
        "permission-denied",
        "Only primary admins can update visits completed and experience years"
      );
    }

    const filtered = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    for (const key of allowed) {
      if (Object.prototype.hasOwnProperty.call(updates, key)) {
        filtered[key] = updates[key];
      }
    }

    if (Object.prototype.hasOwnProperty.call(filtered, "visitsCompleted")) {
      const visits = Number(filtered.visitsCompleted);
      if (!Number.isFinite(visits) || visits < 0) {
        throw new HttpsError(
          "invalid-argument",
          "visitsCompleted must be a non-negative number"
        );
      }
      filtered.visitsCompleted = Math.floor(visits);
    }

    if (Object.prototype.hasOwnProperty.call(filtered, "experienceYears")) {
      const years = Number(filtered.experienceYears);
      if (!Number.isFinite(years) || years < 0) {
        throw new HttpsError(
          "invalid-argument",
          "experienceYears must be a non-negative number"
        );
      }
      filtered.experienceYears = Number(years.toFixed(1));
    }

    const db = admin.firestore();
    const personnelRef = db.collection("servicePersonnel").doc(personnelId);
    await db.runTransaction(async (tx) => {
      const personnelSnap = await tx.get(personnelRef);
      if (!personnelSnap.exists) {
        throw new HttpsError("not-found", "Service personnel not found");
      }

      const before = personnelSnap.data() || {};
      tx.set(personnelRef, filtered, { merge: true });
      const after = {
        ...before,
        ...stripAuditInternalFields(filtered),
      };
      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext,
          actionCategory: "PERSONNEL_UPDATE",
          targetEntityId: personnelId,
          targetEntityType: "servicepersonnel",
          previousState: stripAuditInternalFields(before),
          newState: stripAuditInternalFields(after),
        })
      );
    });

    await notifyUserChange(
      personnelId,
      "Profile Updated",
      "Your service personnel profile was updated by admin.",
      "profile_updated"
    );

    return { success: true };
  }
);

exports.adminDeleteServicePersonnel = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await assertPrimaryAdmin(request);
    const personnelId = normalizeId(request.data?.personnelId);
    if (!personnelId) {
      throw new HttpsError("invalid-argument", "personnelId required");
    }

    const db = admin.firestore();
    const personnelRef = db.collection("servicePersonnel").doc(personnelId);
    await db.runTransaction(async (tx) => {
      const personnelSnap = await tx.get(personnelRef);
      if (!personnelSnap.exists) {
        throw new HttpsError("not-found", "Service personnel not found");
      }

      const before = personnelSnap.data() || {};
      const mutation = {
        isActive: false,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      tx.set(personnelRef, mutation, { merge: true });
      const after = {
        ...before,
        isActive: false,
      };

      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext,
          actionCategory: "PERSONNEL_DELETE",
          targetEntityId: personnelId,
          targetEntityType: "servicepersonnel",
          previousState: stripAuditInternalFields(before),
          newState: stripAuditInternalFields(after),
        })
      );
    });

    await notifyUserChange(
      personnelId,
      "Account Deactivated",
      "Your service personnel account has been deactivated by admin.",
      "account_status"
    );

    return { success: true };
  }
);

exports.adminListPartners = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    await assertAdmin(request);
    const data = request.data || {};
    const limit = Math.max(1, Math.min(Number(data.limit || 100), 300));
    const startAfterId = typeof data.startAfter === "string" ? data.startAfter : null;

    let query = admin.firestore().collection("whitelisted_partners").limit(limit);
    if (startAfterId) {
      const cursor = await admin.firestore().collection("whitelisted_partners").doc(startAfterId).get();
      if (cursor.exists) {
        query = query.startAfter(cursor);
      }
    }

    const snap = await query.get();
    return {
      partners: snap.docs.map((doc) => ({ ...doc.data(), id: doc.id })),
      lastId: snap.docs.length === limit ? snap.docs[snap.docs.length - 1].id : null,
      hasMore: snap.docs.length === limit,
    };
  }
);

exports.adminUpsertPartner = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await getAdminContext(request);
    const adminEmail = adminContext.email;
    const email = normalizeEmail(request.data?.email);
    const isActive = request.data?.isActive !== false;

    if (!email) {
      throw new HttpsError("invalid-argument", "email required");
    }

    const db = admin.firestore();
    const partnerRef = db.collection("whitelisted_partners").doc(email);
    await db.runTransaction(async (tx) => {
      const partnerSnap = await tx.get(partnerRef);
      const before = partnerSnap.exists ? (partnerSnap.data() || {}) : null;
      const mutation = {
        email,
        isActive,
        isEnabled: isActive,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: adminEmail,
      };
      tx.set(partnerRef, mutation, { merge: true });
      const after = {
        ...(before || {}),
        email,
        isActive,
        isEnabled: isActive,
        updatedBy: adminEmail,
      };

      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext,
          actionCategory: "PARTNER_UPSERT",
          targetEntityId: email,
          targetEntityType: "whitelisted_partners",
          previousState: stripAuditInternalFields(before),
          newState: stripAuditInternalFields(after),
        })
      );
    });

    return { success: true };
  }
);

exports.adminDeletePartner = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await getAdminContext(request);
    const email = normalizeEmail(request.data?.email);
    if (!email) {
      throw new HttpsError("invalid-argument", "email required");
    }
    const db = admin.firestore();
    const partnerRef = db.collection("whitelisted_partners").doc(email);
    await db.runTransaction(async (tx) => {
      const partnerSnap = await tx.get(partnerRef);
      if (!partnerSnap.exists) {
        throw new HttpsError("not-found", "Partner not found");
      }
      const before = partnerSnap.data() || {};
      tx.delete(partnerRef);

      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext,
          actionCategory: "PARTNER_DELETE",
          targetEntityId: email,
          targetEntityType: "whitelisted_partners",
          previousState: stripAuditInternalFields(before),
          newState: null,
        })
      );
    });
    return { success: true };
  }
);

exports.adminBroadcastNotification = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await getAdminContext(request);
    const data = request.data || {};
    const title = String(data.title || "").trim();
    const body = String(data.body || "").trim();
    const targetRole = typeof data.targetRole === "string" ? data.targetRole.trim() : "";

    if (!title || !body) {
      throw new HttpsError("invalid-argument", "title and body required");
    }

    const db = admin.firestore();
    let query = db.collection("users").select("role");
    if (targetRole) {
      query = db.collection("users").where("role", "==", targetRole).select("role");
    }

    const snap = await query.get();
    let sent = 0;
    let failed = 0;
    for (const doc of snap.docs) {
      try {
        await saveNotification(doc.id, "admin_broadcast", title, body, null);
        sent += 1;
      } catch (_) {
        failed += 1;
      }
    }

    await writeAdminAuditLog({
      request,
      adminContext,
      actionCategory: "NOTIFICATION_BROADCAST",
      targetEntityId: targetRole || "all_users",
      targetEntityType: "notifications",
      previousState: null,
      newState: {
        title,
        body,
        targetRole: targetRole || null,
        sent,
        failed,
      },
    });

    return { sent, failed };
  }
);

exports.adminApproveCaregiver = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const adminContext = await getAdminContext(request);
    const caregiverId = String(request.data?.caregiverId || "").trim();
    const approved = Boolean(request.data?.approved);
    if (!caregiverId) {
      throw new HttpsError("invalid-argument", "caregiverId required");
    }
    const db = admin.firestore();
    const caregiverRef = db.collection("users").doc(caregiverId);
    await db.runTransaction(async (tx) => {
      const caregiverSnap = await tx.get(caregiverRef);
      if (!caregiverSnap.exists) {
        throw new HttpsError("not-found", "Caregiver not found");
      }

      const before = caregiverSnap.data() || {};
      tx.update(caregiverRef, {
        isApproved: approved,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      const after = {
        ...before,
        isApproved: approved,
      };

      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext,
          actionCategory: "CAREGIVER_APPROVAL",
          targetEntityId: caregiverId,
          targetEntityType: "users",
          previousState: stripAuditInternalFields(before),
          newState: stripAuditInternalFields(after),
        })
      );
    });

    await sendPushNotification(
      caregiverId,
      approved ? "Application Approved" : "Application Update",
      approved ? "Your profile has been approved." : "Please contact support.",
      "account_status",
      null
    );

    return { success: true };
  }
);

exports.adminAddAdmin = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const caller = await assertPrimaryAdmin(request);
    const email = String(request.data?.email || "").trim().toLowerCase();
    if (!email) {
      throw new HttpsError("invalid-argument", "email required");
    }

    if (email === ROOT_ADMIN_EMAIL) {
      throw new HttpsError(
        "failed-precondition",
        "Root admin role is managed automatically"
      );
    }

    const db = admin.firestore();
    const adminRoleRef = db.collection("admin_role_users").doc(email);
    await db.runTransaction(async (tx) => {
      const targetSnap = await tx.get(adminRoleRef);
      const before = targetSnap.exists ? (targetSnap.data() || {}) : null;
      const mutation = {
        email,
        adminType: "secondary",
        isRoot: false,
        isActive: true,
        addedBy: caller.email,
        addedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      tx.set(adminRoleRef, mutation, { merge: true });

      const after = {
        ...(before || {}),
        email,
        adminType: "secondary",
        isRoot: false,
        isActive: true,
        addedBy: caller.email,
      };

      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext: caller,
          actionCategory: "ROLE_CHANGE",
          targetEntityId: email,
          targetEntityType: "admin_role_users",
          previousState: stripAuditInternalFields(before),
          newState: stripAuditInternalFields(after),
        })
      );
    });

    return { success: true };
  }
);

exports.adminRemoveAdmin = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const caller = await assertPrimaryAdmin(request);
    const email = String(request.data?.email || "").trim().toLowerCase();
    if (!email) {
      throw new HttpsError("invalid-argument", "email required");
    }
    if (email === caller.email) {
      throw new HttpsError("failed-precondition", "Cannot remove yourself");
    }
    if (email === ROOT_ADMIN_EMAIL) {
      throw new HttpsError("failed-precondition", "Root admin cannot be removed");
    }

    const db = admin.firestore();
    const adminRoleRef = db.collection("admin_role_users").doc(email);
    const targetSnap = await adminRoleRef.get();
    const targetData = targetSnap.data() || {};
    const targetContext = toAdminContext(email, targetData);
    if (targetContext.isPrimary && !caller.isRoot) {
      throw new HttpsError(
        "permission-denied",
        "Only root admin can remove another primary admin"
      );
    }

    await db.runTransaction(async (tx) => {
      const currentSnap = await tx.get(adminRoleRef);
      const before = currentSnap.exists ? (currentSnap.data() || {}) : null;
      tx.set(
        adminRoleRef,
        {
          isActive: false,
          adminType: targetContext.adminType,
          isRoot: targetContext.isRoot,
          removedAt: admin.firestore.FieldValue.serverTimestamp(),
          removedBy: caller.email,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      const after = {
        ...(before || {}),
        isActive: false,
        adminType: targetContext.adminType,
        isRoot: targetContext.isRoot,
        removedBy: caller.email,
      };

      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext: caller,
          actionCategory: "ROLE_CHANGE",
          targetEntityId: email,
          targetEntityType: "admin_role_users",
          previousState: stripAuditInternalFields(before),
          newState: stripAuditInternalFields(after),
        })
      );
    });

    return { success: true };
  }
);

exports.adminListAdmins = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const caller = await getAdminContext(request);
    const limit = Math.max(
      1,
      Math.min(Number(request.data?.limit || 100), 300)
    );

    const snap = await admin
      .firestore()
      .collection("admin_role_users")
      .where("isActive", "==", true)
      .limit(limit)
      .get();

    const admins = await Promise.all(
      snap.docs.map(async (doc) => {
        const value = doc.data() || {};
        const email = String(value.email || doc.id || "").trim().toLowerCase();
        let uid = "";
        try {
          const user = await admin.auth().getUserByEmail(email);
          uid = user.uid;
        } catch (_) {
          // Keep listing non-auth entries so admins can audit stale records.
        }
        return {
          id: doc.id,
          email,
          uid,
          isActive: value.isActive === true,
          mustChangePassword: value.mustChangePassword === true,
          adminType: toAdminContext(email, value).adminType,
          isPrimary: toAdminContext(email, value).isPrimary,
          isRoot: toAdminContext(email, value).isRoot,
          canBeRemoved: email !== ROOT_ADMIN_EMAIL,
          addedBy: value.addedBy || "",
          addedAt: value.addedAt || null,
          updatedAt: value.updatedAt || null,
        };
      })
    );

    admins.sort(sortByTimelineDesc);
    return {
      admins,
      caller,
      rootAdminEmail: ROOT_ADMIN_EMAIL,
    };
  }
);

exports.adminGetAdminAuthz = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const caller = await getAdminContext(request, {
      allowPasswordResetRequired: true,
    });
    const claimRequiresPasswordReset = request.auth?.token?.passwordResetRequired === true;
    const requiresPasswordChange = caller.mustChangePassword || claimRequiresPasswordReset;
    return {
      email: caller.email,
      adminType: caller.adminType,
      isPrimary: caller.isPrimary,
      isSecondary: caller.isSecondary,
      isRoot: caller.isRoot,
      requiresPasswordChange,
      rootAdminEmail: ROOT_ADMIN_EMAIL,
      permissions: {
        canManageAdmins: caller.canManageAdmins,
        canDeleteAccounts: caller.canDeleteAccounts,
        canEditTransactions: false,
      },
    };
  }
);

exports.adminListAuditLogs = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    await assertPrimaryAdmin(request);

    const limit = Math.max(1, Math.min(Number(request.data?.limit || 100), 300));
    const startAfterId = normalizeId(request.data?.startAfterId);
    const db = admin.firestore();

    let query = db
      .collection("admin_audit_logs")
      .orderBy("timestamp", "desc")
      .limit(limit);

    if (startAfterId) {
      const cursor = await db.collection("admin_audit_logs").doc(startAfterId).get();
      if (cursor.exists) {
        query = query.startAfter(cursor);
      }
    }

    const snap = await query.get();
    return {
      logs: snap.docs.map((doc) => ({ ...doc.data(), id: doc.id })),
      lastId: snap.docs.length === limit ? snap.docs[snap.docs.length - 1].id : null,
      hasMore: snap.docs.length === limit,
    };
  }
);

exports.grantAdminRole = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const caller = await assertPrimaryAdmin(request);

    const requestedEmail = normalizeEmail(request.data?.email);
    const requestedUid = normalizeId(request.data?.uid);
    const requestedAdminType = normalizeAdminType(request.data?.adminType) || "secondary";

    if (!requestedEmail && !requestedUid) {
      throw new HttpsError("invalid-argument", "Provide target email or uid");
    }

    let userRecord;
    let generatedPassword = null;
    try {
      userRecord = requestedUid
        ? await admin.auth().getUser(requestedUid)
        : await admin.auth().getUserByEmail(requestedEmail);
    } catch (error) {
      const authCode = String(error?.code || "");
      const userNotFound = authCode === "auth/user-not-found";
      if (!userNotFound) {
        throw new HttpsError("internal", "Failed to resolve target auth user");
      }

      if (requestedUid) {
        throw new HttpsError("not-found", "Target auth user not found");
      }
      if (!requestedEmail) {
        throw new HttpsError(
          "invalid-argument",
          "Email is required when creating a new administrator login"
        );
      }

      generatedPassword = generateTemporaryPassword();
      try {
        userRecord = await admin.auth().createUser({
          email: requestedEmail,
          password: generatedPassword,
          disabled: false,
          emailVerified: true,
        });
      } catch (createError) {
        throw new HttpsError(
          "internal",
          `Failed to create administrator login: ${createError?.message || "unknown error"}`
        );
      }
    }

    const targetUid = userRecord.uid;
    const targetEmail = normalizeEmail(userRecord.email || requestedEmail);

    if (!targetEmail) {
      throw new HttpsError(
        "failed-precondition",
        "Target user must have a valid email"
      );
    }

    if (targetEmail === ROOT_ADMIN_EMAIL && requestedAdminType !== "primary") {
      throw new HttpsError(
        "failed-precondition",
        "Root admin must always stay primary"
      );
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(targetUid);
    const adminRoleRef = db.collection("admin_role_users").doc(targetEmail);
    const resolvedAdminType = targetEmail === ROOT_ADMIN_EMAIL ? "primary" : requestedAdminType;
    const mustChangePassword = Boolean(generatedPassword);
    await db.runTransaction(async (tx) => {
      const [userSnap, roleSnap] = await Promise.all([
        tx.get(userRef),
        tx.get(adminRoleRef),
      ]);

      const previousUser = userSnap.exists ? (userSnap.data() || {}) : null;
      const previousRole = roleSnap.exists ? (roleSnap.data() || {}) : null;

      tx.set(
        userRef,
        {
          role: "admin",
          isActive: true,
          email: targetEmail,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      tx.set(
        adminRoleRef,
        {
          email: targetEmail,
          uid: targetUid,
          adminType: resolvedAdminType,
          isRoot: targetEmail === ROOT_ADMIN_EMAIL,
          isActive: true,
          mustChangePassword,
          addedBy: caller.email,
          addedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext: caller,
          actionCategory: "ROLE_CHANGE",
          targetEntityId: targetUid,
          targetEntityType: "users",
          previousState: {
            user: stripAuditInternalFields(previousUser),
            roleEntry: stripAuditInternalFields(previousRole),
          },
          newState: {
            user: {
              ...(previousUser || {}),
              role: "admin",
              isActive: true,
              email: targetEmail,
            },
            roleEntry: {
              ...(previousRole || {}),
              email: targetEmail,
              uid: targetUid,
              adminType: resolvedAdminType,
              isRoot: targetEmail === ROOT_ADMIN_EMAIL,
              isActive: true,
              mustChangePassword,
              addedBy: caller.email,
            },
          },
        })
      );
    });

    const existingClaims = userRecord.customClaims || {};
    await admin.auth().setCustomUserClaims(targetUid, {
      ...existingClaims,
      admin: true,
      role: "admin",
      passwordResetRequired: mustChangePassword,
    });

    return {
      success: true,
      uid: targetUid,
      email: targetEmail,
      adminType: resolvedAdminType,
      passwordGenerated: Boolean(generatedPassword),
      temporaryPassword: generatedPassword,
    };
  }
);

exports.adminSetInitialPassword = onCall(
  {
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    const caller = await getAdminContext(request, {
      allowPasswordResetRequired: true,
    });

    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const newPassword = validateAdminPassword(request.data?.newPassword);
    const shouldBeRequired = caller.mustChangePassword ||
      request.auth.token?.passwordResetRequired === true;

    if (!shouldBeRequired) {
      return {
        success: true,
        updated: false,
        message: "Initial password update is not required",
      };
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(request.auth.uid);
    const adminRoleRef = db.collection("admin_role_users").doc(caller.email);

    await admin.auth().updateUser(request.auth.uid, {
      password: newPassword,
    });

    const existingClaims = request.auth.token || {};
    await admin.auth().setCustomUserClaims(request.auth.uid, {
      ...existingClaims,
      admin: true,
      role: "admin",
      passwordResetRequired: false,
    });

    await db.runTransaction(async (tx) => {
      const [userSnap, roleSnap] = await Promise.all([
        tx.get(userRef),
        tx.get(adminRoleRef),
      ]);

      const previousUser = userSnap.exists ? (userSnap.data() || {}) : null;
      const previousRole = roleSnap.exists ? (roleSnap.data() || {}) : null;

      tx.set(
        userRef,
        {
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      tx.set(
        adminRoleRef,
        {
          mustChangePassword: false,
          passwordUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      const auditRef = db.collection("admin_audit_logs").doc();
      tx.set(
        auditRef,
        createAuditRecord({
          request,
          adminContext: caller,
          actionCategory: "SECURITY_PASSWORD_UPDATE",
          targetEntityId: request.auth.uid,
          targetEntityType: "users",
          previousState: {
            user: stripAuditInternalFields(previousUser),
            roleEntry: stripAuditInternalFields(previousRole),
          },
          newState: {
            user: {
              ...(previousUser || {}),
            },
            roleEntry: {
              ...(previousRole || {}),
              mustChangePassword: false,
            },
          },
        })
      );
    });

    return {
      success: true,
      updated: true,
      message: "Password updated successfully",
    };
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Helper: Check if user is admin
// ─────────────────────────────────────────────────────────────────────────────
async function isAdminUser(uid) {
  const authUser = await admin.auth().getUser(uid);
  if (authUser.customClaims?.admin === true) {
    return true;
  }

  const email = String(authUser.email || "").trim().toLowerCase();
  if (!email) {
    return false;
  }

  const adminDoc = await admin.firestore().collection("admin_role_users").doc(email).get();
  return adminDoc.exists && adminDoc.data()?.isActive === true;
}

module.exports.isAdminUser = isAdminUser;
