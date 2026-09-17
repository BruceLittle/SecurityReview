/**
 * Shared logging backend for ZeitHawk and AI Tool Finder.
 *
 * Both artifacts open a mailto: link for "Request Security authorization" /
 * "Request Security Approval" / "Request IT review" — that's the real
 * request path and works with zero setup. This web app additionally logs
 * a durable copy of each request to Firestore, so there's a searchable
 * record beyond whatever lands in one inbox.
 *
 * Deployment — see README.md in this folder for the full walkthrough:
 *   1. Associate this Apps Script project with a standard GCP project
 *      (Project Settings -> Google Cloud Platform (GCP) Project) and
 *      enable the Firestore API on it, in Native mode.
 *   2. Set PROJECT_ID below to that GCP project's ID.
 *   3. Deploy -> New deployment -> Web app, execute as "Me",
 *      access "Anyone" (the artifacts call this anonymously).
 *   4. Paste the resulting /exec URL into APPS_SCRIPT_URL in both
 *      tools/zeithawk/index.html and the AI Tool Finder artifact.
 *
 * This endpoint has no auth — "Anyone" access means anyone with the URL
 * can write to it. That's an accepted tradeoff for logging low-sensitivity
 * *requests* (never put secrets in the fields below), not a security
 * boundary. See README.md for the caveats in more detail.
 */

const PROJECT_ID = 'REPLACE_WITH_YOUR_GCP_PROJECT_ID';
const DATABASE_ID = '(default)';
const ALLOWED_COLLECTIONS = ['security_authorization_requests', 'app_review_requests'];
const MAX_LIST_LIMIT = 50;

function doPost(e) {
  try {
    const payload = JSON.parse(e.postData.contents);
    const collection = payload.collection;
    if (ALLOWED_COLLECTIONS.indexOf(collection) === -1) {
      return jsonOutput_({ ok: false, error: 'Unknown collection: ' + collection });
    }
    const doc = {
      tool: String(payload.tool || '').slice(0, 200),
      target: String(payload.target || '').slice(0, 500),
      requester: String(payload.requester || '').slice(0, 200),
      note: String(payload.note || '').slice(0, 2000),
      createdAt: new Date().toISOString(),
    };
    const created = firestoreCreateDocument_(collection, doc);
    return jsonOutput_({ ok: true, id: created.name.split('/').pop() });
  } catch (err) {
    return jsonOutput_({ ok: false, error: String(err) });
  }
}

function doGet(e) {
  const params = (e && e.parameter) || {};
  const collection = params.collection;
  const callback = params.callback;
  let result;

  if (ALLOWED_COLLECTIONS.indexOf(collection) === -1) {
    result = { ok: false, error: 'Unknown collection: ' + collection };
  } else {
    const limit = Math.min(parseInt(params.limit, 10) || 20, MAX_LIST_LIMIT);
    try {
      result = { ok: true, items: firestoreListDocuments_(collection, limit) };
    } catch (err) {
      result = { ok: false, error: String(err) };
    }
  }

  // Apps Script web app responses don't carry CORS headers, so a plain
  // cross-origin fetch() can't read the body. Callers that need to read
  // the result (rather than fire-and-forget a POST) pass ?callback=name
  // and get JSONP back via a <script> tag instead, which isn't subject
  // to CORS.
  if (callback) {
    return ContentService
      .createTextOutput(callback + '(' + JSON.stringify(result) + ')')
      .setMimeType(ContentService.MimeType.JAVASCRIPT);
  }
  return jsonOutput_(result);
}

function jsonOutput_(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function firestoreBaseUrl_() {
  return 'https://firestore.googleapis.com/v1/projects/' + PROJECT_ID
    + '/databases/' + DATABASE_ID + '/documents';
}

function toFirestoreFields_(obj) {
  const fields = {};
  Object.keys(obj).forEach(function (key) {
    const value = obj[key];
    fields[key] = (typeof value === 'number')
      ? { doubleValue: value }
      : { stringValue: String(value) };
  });
  return fields;
}

function fromFirestoreFields_(fields) {
  const obj = {};
  Object.keys(fields || {}).forEach(function (key) {
    const v = fields[key];
    obj[key] = v.stringValue !== undefined ? v.stringValue
      : v.doubleValue !== undefined ? v.doubleValue
      : v.integerValue !== undefined ? Number(v.integerValue)
      : v.timestampValue !== undefined ? v.timestampValue
      : null;
  });
  return obj;
}

function firestoreCreateDocument_(collection, doc) {
  const url = firestoreBaseUrl_() + '/' + collection;
  const res = UrlFetchApp.fetch(url, {
    method: 'post',
    contentType: 'application/json',
    headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken() },
    payload: JSON.stringify({ fields: toFirestoreFields_(doc) }),
    muteHttpExceptions: true,
  });
  if (res.getResponseCode() >= 300) {
    throw new Error('Firestore create failed (' + res.getResponseCode() + '): ' + res.getContentText());
  }
  return JSON.parse(res.getContentText());
}

function firestoreListDocuments_(collection, limit) {
  // createdAt is stored as an ISO-8601 string (fixed-width, UTC), so a
  // plain lexicographic ordering is also chronological — no need for
  // Firestore's timestampValue type or a composite index.
  const url = firestoreBaseUrl_() + '/' + collection
    + '?pageSize=' + encodeURIComponent(limit)
    + '&orderBy=' + encodeURIComponent('createdAt desc');
  const res = UrlFetchApp.fetch(url, {
    method: 'get',
    headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken() },
    muteHttpExceptions: true,
  });
  if (res.getResponseCode() >= 300) {
    // An empty/never-written collection 404s on list — treat that as zero results.
    if (res.getResponseCode() === 404) return [];
    throw new Error('Firestore list failed (' + res.getResponseCode() + '): ' + res.getContentText());
  }
  const body = JSON.parse(res.getContentText());
  return (body.documents || []).map(function (d) {
    const fields = fromFirestoreFields_(d.fields);
    fields.id = d.name.split('/').pop();
    return fields;
  });
}
