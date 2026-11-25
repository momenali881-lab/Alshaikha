/**
 * Free OneSignal push dispatcher for the Alshaikha Firebase project.
 *
 * Configure Script Properties before running setupAlshaikhaNotifications():
 * FIREBASE_SERVICE_ACCOUNT_JSON
 * ONESIGNAL_CLIENT_REST_API_KEY
 * ONESIGNAL_ADMIN_REST_API_KEY
 * FIREBASE_PROJECT_ID (optional; defaults to "alshaikha")
 *
 * The service-account JSON and REST API keys stay in Script Properties and
 * must never be placed in the mobile apps or committed to this repository.
 */

const ALSHAIKHA_CLIENT_APP_ID = '603a9d8a-365a-4b6f-befd-b213f725c09e';
const ALSHAIKHA_ADMIN_APP_ID = '5ccd4e96-a64c-4565-9ae5-964548bed976';
const ALSHAIKHA_FIRESTORE_COLLECTION = 'notifications';
const ALSHAIKHA_ONESIGNAL_ENDPOINT = 'https://api.onesignal.com/notifications';
const ALSHAIKHA_APP_IMAGE_URL = 'https://raw.githubusercontent.com/momenali881-lab/Alshaikha/main/client_app/file_00000000df048210b32f5dc7efa7f5ad.png';

function setupAlshaikhaNotifications() {
  const properties = PropertiesService.getScriptProperties();
  const required = [
    'FIREBASE_SERVICE_ACCOUNT_JSON',
    'ONESIGNAL_CLIENT_REST_API_KEY',
    'ONESIGNAL_ADMIN_REST_API_KEY'
  ];
  const missing = required.filter(function (key) {
    return !properties.getProperty(key);
  });
  if (missing.length) {
    throw new Error('Missing Script Properties: ' + missing.join(', '));
  }

  ScriptApp.getProjectTriggers().forEach(function (trigger) {
    if (trigger.getHandlerFunction() === 'dispatchAlshaikhaNotifications') {
      ScriptApp.deleteTrigger(trigger);
    }
  });
  ScriptApp.newTrigger('dispatchAlshaikhaNotifications')
    .timeBased()
    .everyMinutes(1)
    .create();
}

function dispatchAlshaikhaNotifications() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(1000)) return;

  try {
    const token = getAlshaikhaAccessToken_();
    const projectId = PropertiesService.getScriptProperties()
      .getProperty('FIREBASE_PROJECT_ID') || 'alshaikha';
    const pending = runAlshaikhaQuery_(token, projectId, {
      from: [{ collectionId: ALSHAIKHA_FIRESTORE_COLLECTION }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'pushStatus' },
          op: 'EQUAL',
          value: { stringValue: 'pending' }
        }
      },
      limit: 100
    });

    pending.forEach(function (row) {
      if (!row.document || !row.document.name) return;
      processAlshaikhaNotification_(token, projectId, row.document);
    });
  } finally {
    lock.releaseLock();
  }
}

function processAlshaikhaNotification_(token, projectId, document) {
  const fields = fromAlshaikhaFields_(document.fields || {});
  const notificationId = document.name.split('/').pop();
  const attempts = Number(fields.pushAttempts || 0) + 1;

  try {
    const target = String(fields.target || '');
    let externalIds = [];
    let appId;
    let restKey;

    if (target === 'customer') {
      const customerId = String(fields.customerId || '');
      if (customerId) {
        const profile = getAlshaikhaDocument_(
          token, projectId, 'profiles/' + encodeURIComponent(customerId)
        );
        if (profile) {
          const profileData = fromAlshaikhaFields_(profile.fields || {});
          if (profileData.role === 'customer') externalIds = [customerId];
        }
      }
      appId = ALSHAIKHA_CLIENT_APP_ID;
      restKey = PropertiesService.getScriptProperties()
        .getProperty('ONESIGNAL_CLIENT_REST_API_KEY');
    } else if (target === 'admin') {
      externalIds = queryAlshaikhaProfileIds_(token, projectId, 'admin');
      appId = ALSHAIKHA_ADMIN_APP_ID;
      restKey = PropertiesService.getScriptProperties()
        .getProperty('ONESIGNAL_ADMIN_REST_API_KEY');
    } else if (target === 'all') {
      externalIds = queryAlshaikhaProfileIds_(token, projectId, 'customer');
      appId = ALSHAIKHA_CLIENT_APP_ID;
      restKey = PropertiesService.getScriptProperties()
        .getProperty('ONESIGNAL_CLIENT_REST_API_KEY');
    } else {
      patchAlshaikhaDocument_(token, document.name, {
        pushStatus: { stringValue: 'ignored' },
        pushAttempts: { integerValue: String(attempts) },
        pushError: { stringValue: 'Unsupported notification target' }
      });
      return;
    }

    externalIds = Array.from(new Set(externalIds.filter(Boolean)));
    if (!externalIds.length) {
      patchAlshaikhaDocument_(token, document.name, {
        pushStatus: { stringValue: 'no_recipients' },
        pushAttempts: { integerValue: String(attempts) },
        pushUpdatedAt: { timestampValue: new Date().toISOString() }
      });
      return;
    }
    if (!restKey) throw new Error('OneSignal REST API key is not configured');

    const title = String(fields.title || 'الشيخة');
    const body = String(fields.body || 'لديك إشعار جديد');
    const data = {};
    [
      'type', 'bookingId', 'customerId', 'createdBy',
      'conversationId', 'target', 'id', 'senderName', 'senderImageUrl'
    ].forEach(function (key) {
      if (fields[key] !== undefined && fields[key] !== null) {
        data[key === 'id' ? 'notificationId' : key] = String(fields[key]);
      }
    });

    // OneSignal accepts up to 2,000 external aliases per request.
    const chunks = [];
    for (let i = 0; i < externalIds.length; i += 2000) {
      chunks.push(externalIds.slice(i, i + 2000));
    }

    let delivered = false;
    chunks.forEach(function (ids, index) {
      if (sendAlshaikhaOneSignal_(
        restKey, appId, ids, title, body, data,
        deterministicAlshaikhaUuid_(notificationId + ':' + index), target
      )) delivered = true;
    });

    patchAlshaikhaDocument_(token, document.name, {
      pushStatus: { stringValue: delivered ? 'sent' : 'no_recipients' },
      pushAttempts: { integerValue: String(attempts) },
      pushSentAt: { timestampValue: new Date().toISOString() },
      pushError: { stringValue: '' }
    });
  } catch (error) {
    const message = String(error && error.message ? error.message : error).slice(0, 900);
    // Leave transient errors pending so the next scheduled run can retry.
    patchAlshaikhaDocument_(token, document.name, {
      pushStatus: { stringValue: attempts >= 5 ? 'failed' : 'pending' },
      pushAttempts: { integerValue: String(attempts) },
      pushError: { stringValue: message },
      pushUpdatedAt: { timestampValue: new Date().toISOString() }
    });
    console.error('Notification ' + notificationId + ': ' + message);
  }
}

function sendAlshaikhaOneSignal_(restKey, appId, ids, title, body, data, idempotencyKey, target) {
  const response = UrlFetchApp.fetch(ALSHAIKHA_ONESIGNAL_ENDPOINT, {
    method: 'post',
    contentType: 'application/json',
    headers: { Authorization: 'Key ' + restKey },
    payload: JSON.stringify({
      app_id: appId,
      include_aliases: { external_id: ids },
      target_channel: 'push',
      headings: { ar: title, en: title },
      contents: { ar: body, en: body },
      data: data,
      ...((data.senderImageUrl || target === 'customer') ? { large_icon: data.senderImageUrl || ALSHAIKHA_APP_IMAGE_URL, big_picture: data.senderImageUrl || ALSHAIKHA_APP_IMAGE_URL, ios_attachments: { sender: data.senderImageUrl || ALSHAIKHA_APP_IMAGE_URL } } : {}),
      idempotency_key: idempotencyKey
    }),
    muteHttpExceptions: true
  });

  const code = response.getResponseCode();
  let result = {};
  try {
    result = JSON.parse(response.getContentText() || '{}');
  } catch (_) {}

  if (code < 200 || code >= 300) {
    throw new Error('OneSignal HTTP ' + code + ': ' +
      String(response.getContentText() || '').slice(0, 500));
  }
  // OneSignal can return HTTP 200 with an empty ID when nobody is subscribed.
  return Boolean(result.id);
}

function queryAlshaikhaProfileIds_(token, projectId, role) {
  const rows = runAlshaikhaQuery_(token, projectId, {
    from: [{ collectionId: 'profiles' }],
    where: {
      fieldFilter: {
        field: { fieldPath: 'role' },
        op: 'EQUAL',
        value: { stringValue: role }
      }
    }
  });
  return rows.filter(function (row) {
    return row.document && row.document.name;
  }).map(function (row) {
    return row.document.name.split('/').pop();
  });
}

function runAlshaikhaQuery_(token, projectId, structuredQuery) {
  const url = 'https://firestore.googleapis.com/v1/projects/' +
    encodeURIComponent(projectId) +
    '/databases/(default)/documents:runQuery';
  const response = UrlFetchApp.fetch(url, {
    method: 'post',
    contentType: 'application/json',
    headers: { Authorization: 'Bearer ' + token },
    payload: JSON.stringify({ structuredQuery: structuredQuery }),
    muteHttpExceptions: true
  });
  const code = response.getResponseCode();
  if (code < 200 || code >= 300) {
    throw new Error('Firestore query HTTP ' + code + ': ' +
      String(response.getContentText() || '').slice(0, 500));
  }
  return JSON.parse(response.getContentText() || '[]');
}

function getAlshaikhaDocument_(token, projectId, relativePath) {
  const url = 'https://firestore.googleapis.com/v1/projects/' +
    encodeURIComponent(projectId) +
    '/databases/(default)/documents/' + relativePath;
  const response = UrlFetchApp.fetch(url, {
    method: 'get',
    headers: { Authorization: 'Bearer ' + token },
    muteHttpExceptions: true
  });
  if (response.getResponseCode() === 404) return null;
  const code = response.getResponseCode();
  if (code < 200 || code >= 300) {
    throw new Error('Firestore read HTTP ' + code + ': ' +
      String(response.getContentText() || '').slice(0, 500));
  }
  return JSON.parse(response.getContentText() || '{}');
}

function patchAlshaikhaDocument_(token, documentName, fields) {
  const masks = Object.keys(fields).map(function (key) {
    return 'updateMask.fieldPaths=' + encodeURIComponent(key);
  }).join('&');
  const url = 'https://firestore.googleapis.com/v1/' +
    documentName + '?' + masks;
  const response = UrlFetchApp.fetch(url, {
    method: 'patch',
    contentType: 'application/json',
    headers: { Authorization: 'Bearer ' + token },
    payload: JSON.stringify({ fields: fields }),
    muteHttpExceptions: true
  });
  const code = response.getResponseCode();
  if (code < 200 || code >= 300) {
    throw new Error('Firestore update HTTP ' + code + ': ' +
      String(response.getContentText() || '').slice(0, 500));
  }
}

function getAlshaikhaAccessToken_() {
  const raw = PropertiesService.getScriptProperties()
    .getProperty('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (!raw) throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is missing');
  const credentials = JSON.parse(raw);
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlAlshaikha_(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = base64UrlAlshaikha_(JSON.stringify({
    iss: credentials.client_email,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600
  }));
  const unsigned = header + '.' + claim;
  const signature = Utilities.computeRsaSha256Signature(
    unsigned, credentials.private_key
  );
  const assertion = unsigned + '.' + base64UrlAlshaikha_(signature);
  const response = UrlFetchApp.fetch('https://oauth2.googleapis.com/token', {
    method: 'post',
    payload: {
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: assertion
    },
    muteHttpExceptions: true
  });
  const code = response.getResponseCode();
  const result = JSON.parse(response.getContentText() || '{}');
  if (code < 200 || code >= 300 || !result.access_token) {
    throw new Error('Google token exchange failed: ' +
      String(response.getContentText() || '').slice(0, 500));
  }
  return result.access_token;
}

function base64UrlAlshaikha_(value) {
  const bytes = typeof value === 'string'
    ? Utilities.newBlob(value).getBytes()
    : value;
  return Utilities.base64EncodeWebSafe(bytes).replace(/=+$/g, '');
}

function deterministicAlshaikhaUuid_(seed) {
  const bytes = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256, seed, Utilities.Charset.UTF_8
  ).slice(0, 16).map(function (value) { return value & 255; });
  bytes[6] = (bytes[6] & 15) | 80;
  bytes[8] = (bytes[8] & 63) | 128;
  const hex = bytes.map(function (value) {
    return value.toString(16).padStart(2, '0');
  }).join('');
  return hex.slice(0, 8) + '-' + hex.slice(8, 12) + '-' +
    hex.slice(12, 16) + '-' + hex.slice(16, 20) + '-' + hex.slice(20);
}

function fromAlshaikhaFields_(fields) {
  const result = {};
  Object.keys(fields || {}).forEach(function (key) {
    result[key] = fromAlshaikhaValue_(fields[key]);
  });
  return result;
}

function fromAlshaikhaValue_(value) {
  if (!value) return null;
  if (Object.prototype.hasOwnProperty.call(value, 'stringValue')) return value.stringValue;
  if (Object.prototype.hasOwnProperty.call(value, 'integerValue')) return Number(value.integerValue);
  if (Object.prototype.hasOwnProperty.call(value, 'doubleValue')) return Number(value.doubleValue);
  if (Object.prototype.hasOwnProperty.call(value, 'booleanValue')) return value.booleanValue;
  if (Object.prototype.hasOwnProperty.call(value, 'timestampValue')) return value.timestampValue;
  if (Object.prototype.hasOwnProperty.call(value, 'nullValue')) return null;
  if (value.mapValue) return fromAlshaikhaFields_(value.mapValue.fields || {});
  if (value.arrayValue) return (value.arrayValue.values || []).map(fromAlshaikhaValue_);
  return null;
}
