# Google Play store listing (draft)

Grounded in `docs/legal/data-inventory.md`. Replace placeholders before submission.

---

## App identity

| Field | Value |
|-------|--------|
| **App name** | La Nonna |
| **Package name** | `com.lanonna.lanonna` |
| **Default language** | English (United States) — adjust as needed |

---

## Short description (≤ 80 characters)

```
Share your baby's journey with family—photos, calendar, registry & invites.
```

**Character count:** 72

---

## Full description (≤ 4000 characters)

```
La Nonna is a calm, private space for expecting and new parents to share their baby's journey with the people they trust.

CREATE YOUR CIRCLE
• Set up a baby profile and invite partners, grandparents, and friends as owners or followers.
• Everyone stays in sync with one shared home for your growing family.

PHOTOS & MEMORIES
• Upload photos from your camera or library to a shared gallery.
• Comment, react, and tag moments that matter.

PLAN TOGETHER
• Shared calendar for appointments, milestones, and visits.
• Optional event suggestions by stage (built into the app—no chatbot required).

REGISTRY & GIFTS
• Build a gift registry and track what's been claimed.
• Add a shipping address for gifts when you're ready.

FUN & ANNOUNCEMENTS
• Name suggestions, predictions, and birth announcement keepsakes you can share.

STAY IN THE LOOP
• Push notifications for activity you care about (you control preferences in settings).
• Email invitations when you invite someone new.

YOUR DATA, YOUR CHOICE
• Edit your profile anytime.
• Baby owners can export a JSON copy of baby data from Account settings.
• Delete your account from Account settings when you no longer want the service.

La Nonna is designed for adults managing family content. You choose what to share and whom to invite.

Questions or support: {{CONTACT_EMAIL}}
Privacy policy: https://{{DOMAIN}}/legal/privacy
```

**Character count:** ~1,450 (well under 4,000)

---

## Category suggestion

| Primary | **Parenting** |
| Secondary (optional) | **Lifestyle** |

Rationale: core flows are baby profile, family invites, registry, and parenting milestones.

---

## Content rating (IARC questionnaire notes)

Use Google Play’s questionnaire; align answers with actual app behavior:

| Topic | Suggested answer direction | Evidence |
|-------|---------------------------|----------|
| **Violence, sexuality, language, controlled substances** | None / No | Family productivity app; no such content in product code paths |
| **User-generated content** | **Yes** — shared photos, comments, calendar text, registry links | Gallery, comments, events (`007_gallery_calendar_social.sql`) |
| **User communication** | **Yes** — comments, invites, notifications | Social tables; Mailjet invites |
| **Location** | **No precise location collection** observed | Event `location` is free-text user input, not GPS |
| **Personal info** | **Yes** — account email, profile, baby data, photos | Data inventory §2 |
| **Digital purchases** | **No** in-app store observed | Registry tracks gifts; no Play Billing in repo |
| **Target audience** | **Adults** (not designed for children as users) | Onboarding/terms; **Owner/lawyer review** for child-content rules |

Expect a **Everyone** or **Teen** rating depending on how Google scores user-generated sharing; verify in Play Console.

---

## Data safety form (draft answers)

Complete the form in Play Console; this table is a worksheet derived from the inventory.

| Data type (Play taxonomy) | Collected | Shared | Required? | Purpose | Encrypted in transit | Deletion |
|---------------------------|-----------|--------|-----------|---------|----------------------|----------|
| **Email address** | Yes | With service providers (Firebase, Mailjet) | Yes (account) | Account management, invites | Yes (HTTPS) | Account deletion in app; contact {{CONTACT_EMAIL}} |
| **Name** | Yes | With family circle on shared babies | Optional (display name) | App functionality | Yes | Account deletion / profile edit |
| **User IDs** | Yes (Firebase UID) | With Google/Firebase | Yes | Account management, security | Yes | Account deletion |
| **Photos** | Yes | With invited family on a baby profile | Optional | App functionality | Yes | Delete in app where supported; **account deletion** removes your uploads (including on shared babies) and all media for babies you solely own via **async cloud storage cleanup** |
| **Other user-generated content** | Yes (comments, events, registry text) | With family circle | Optional | App functionality | Yes | Edit/delete in app where supported; **account deletion** may leave comments/suggestions/registry text on shared babies attributed to “Deleted user” |
| **Device or other IDs** | Yes (FCM token) | With Google (FCM) | Optional (notifications) | Push notifications | Yes | Disable notifications; account deletion |
| **Crash logs** | Yes (Crashlytics) | With Google | Optional (build-dependent) | Analytics / stability | Yes | Firebase/Google controls; see policy |
| **Phone number** | Optional | Not sold; stored on profile | Optional | App functionality | Yes | Profile edit / account deletion |
| **Other info** (baby birth dates, registry address, etc.) | Yes | With family circle | Optional | App functionality | Yes | Profile/baby edit; export; deletion flows |

**Additional Play Console declarations:**

| Question | Draft answer |
|----------|----------------|
| Data encrypted in transit? | **Yes** (HTTPS/TLS for API and uploads) |
| Users can request data deletion? | **Yes** — in-app account deletion (SQL tombstone + Firebase removal + **async** deletion of avatars, exports, and applicable photos/thumbnails in cloud storage); baby data export for owners; contact {{CONTACT_EMAIL}} |
| Data collection optional where applicable? | **Partially** — account requires email; many profile/baby fields optional |
| Committed to Play Families Policy? | **Owner decision** — app stores child-related content created by adults |

---

## Store assets (not in repo)

Track in `launch-checklist.md`: icon, feature graphic, phone screenshots, data safety submission, content rating certificate.
