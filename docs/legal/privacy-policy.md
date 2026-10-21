# Privacy Policy (draft)

> **Draft — requires review by {{COMPANY_OR_DEVELOPER_NAME}} and qualified legal counsel before publication.**  
> Replace all `{{PLACEHOLDER}}` values. Grounded in the repository data inventory: `docs/legal/data-inventory.md`.

**Effective date:** {{EFFECTIVE_DATE}}  
**Operator:** {{COMPANY_OR_DEVELOPER_NAME}} (“we”, “us”)  
**Contact:** {{CONTACT_EMAIL}}  
**Website / app links domain:** {{DOMAIN}}

---

## 1. Overview

La Nonna (“the app”) helps families share a baby’s journey—photos, calendar, registry, announcements, and invitations—with a trusted circle. This policy describes personal information we process when you use the Android app (`com.lanonna.lanonna`) and our backend services.

The app is intended for **adults** (parents and family). It stores information **about babies and children** that you choose to add. We do not offer separate child accounts.

---

## 2. Information we collect

### 2.1 Information you provide

- **Account:** email address, password (handled by Firebase Authentication), optional display name, avatar, phone, birth date, country, and postal code.
- **Baby profiles:** name (optional), gender, due date or birth date, photos, registry shipping address (if you add it), and related content you create (calendar events, registry items, comments, name suggestions, birth announcement details).
- **Invitations:** email addresses of people you invite and optional relationship labels.
- **Communications preferences:** notification and digest settings you select in the app.

### 2.2 Information collected automatically

- **Identifiers:** Firebase user ID; device push token (FCM) when you enable notifications.
- **Usage signals:** throttled “last seen” timestamp on our servers to keep your session current.
- **Security:** Firebase App Check signals to help protect our API from abuse.
- **Crash diagnostics:** if enabled for your build, Firebase Crashlytics may receive crash logs and an opaque user identifier (your Firebase UID) to help us fix defects.

We do **not** use a separate in-app analytics SDK for behavioral advertising. Calendar and registry “AI Suggestions” are generated from **catalogs bundled with the app**, not by sending your content to a third-party generative AI service.

### 2.3 Photos and device permissions

If you add photos, the app may ask for **camera** and/or **photo library** access (platform-dependent). Images are processed on your device before upload (including removal of most camera metadata). Photos are stored on our cloud storage and linked to your baby profile.

On Android, you may be prompted to allow **notifications**. **Biometric** hardware may be used for optional app unlock or biometric sign-in; biometric templates stay on your device—we store only cryptographic public keys needed for sign-in.

---

## 3. How we use information

We use personal information to:

- Create and secure your account and authenticate requests.
- Operate family sharing (memberships, followers, invites, gallery, calendar, registry, announcements).
- Send **push notifications** and in-app notifications you enable.
- Send **invitation emails** to addresses you provide (via our email provider).
- Generate **baby data exports** when a baby owner requests them.
- Maintain, secure, and improve the service (including crash reporting).
- Comply with law and enforce our terms.

We use **Mailjet** to deliver invitation emails. We use **Google Cloud** (including Cloud SQL, Cloud Run, Cloud Storage, Pub/Sub) and **Firebase** (Authentication, App Check, Cloud Messaging, Crashlytics) to run the service.

---

## 4. Legal bases (where applicable)

If you are in the European Economic Area or United Kingdom, we rely on one or more of: **contract** (providing the app), **legitimate interests** (security, abuse prevention, product improvement), and **consent** where required (for example optional notifications or biometric features). **Owner/lawyer review:** confirm bases and whether baby-related data needs additional consent or documentation.

---

## 5. Sharing

We do not sell your personal information. We share data only:

- With **family members** you authorize (owners and followers on a baby profile), according to app permissions.
- With **service providers** that process data on our instructions (Google/Firebase, Mailjet), subject to appropriate safeguards.
- When required by law or to protect rights, safety, and security.

Invite links may open pages hosted at `{{DOMAIN}}` (Firebase Hosting) before opening the app.

---

## 6. International transfers

Our infrastructure may process data in countries where Google Cloud and our providers operate. **Owner/lawyer review:** document transfer mechanisms (e.g. Standard Contractual Clauses) for your users’ regions.

---

## 7. Retention

We keep information while your account is active and as needed to provide the service. Specific behaviors documented in our systems include:

- Expired pending invitations are marked expired by a scheduled job.
- Object storage may apply bucket lifecycle rules (for example cleaning incomplete uploads and old object versions where enabled).
- When you **delete your account**, we tombstone your profile (`email` and avatar removed, display name set to “Deleted user”), remove your Firebase login, end memberships, delete certain participation data (such as RSVPs and reactions), revoke pending invites, soft-delete baby profiles you solely own, revoke biometric credentials, and **enqueue removal of your media in cloud storage**. That async cleanup deletes your user avatar, your baby data export files, all photos and thumbnails for babies you solely own (including baby avatars), and photos you uploaded on shared babies; it does **not** delete text you left on shared babies (comments, name suggestions, registry claims), which may still show under “Deleted user.” Sole-owned baby records may remain in our database in soft-deleted form after files are removed. A background job retries stuck cleanups (including a periodic sweep). **Owner/lawyer review:** disclose typical timing and what SQL rows are retained.

Export files are stored temporarily for download as part of the export feature.

---

## 8. Your choices and rights

Depending on where you live, you may have rights to access, correct, delete, restrict, or port your data, and to object to certain processing. Contact **{{CONTACT_EMAIL}}** to exercise rights. We may need to verify your identity.

### 8.1 In-app controls

- **Edit profile:** Account settings → profile fields.
- **Notifications:** Account / notification settings.
- **Leave a baby circle:** Membership controls (when you are not the sole owner).
- **Delete a baby profile:** Available to the sole owner via the baby profile deletion flow.

### 8.2 Account deletion

1. Open **Account**.
2. Tap **Delete account** and review the preview (including baby profiles that will be removed if you are the only owner).
3. Confirm, then complete re-authentication if prompted (email password or Google).
4. We process deletion on our servers and sign you out.

If deletion fails after re-authentication, contact **{{CONTACT_EMAIL}}**.

### 8.3 Data export (baby owners)

1. Open **Account** → **Export baby data** (owners only).
2. Tap to request an export and wait until status is ready.
3. Open the download link to retrieve a JSON archive (and linked media URLs as provided in the export).

Exports intentionally omit other members’ email addresses and Firebase identifiers; see `docs/legal/data-inventory.md`.

---

## 9. Children

The app is not directed at children under 13 (or the minimum age in your country) to use as account holders. Parents and guardians provide information about babies and children. **Owner/lawyer review:** COPPA, GDPR child-data, and store “target audience” settings.

---

## 10. Security

We use industry-standard measures including encrypted transport (HTTPS), access controls, hashed invite tokens, and Firebase/App Check protections. No method is 100% secure.

---

## 11. Changes

We may update this policy. We will post the new version at `https://{{DOMAIN}}/legal/privacy` (or in-app legal screens) and update the effective date. Material changes may require additional notice where law requires.

---

## 12. Contact

Questions or requests: **{{CONTACT_EMAIL}}**  
**{{COMPANY_OR_DEVELOPER_NAME}}**  
**Governing law / venue:** {{JURISDICTION}} (**Owner/lawyer review**)
