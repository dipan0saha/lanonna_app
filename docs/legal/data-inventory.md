# Data inventory (engineering summary)

This document summarizes categories of user data stored by La Nonna and what **Delete account** (FR-SET-005) does to each. For implementation detail see [account-deletion-storage-cleanup.md](../engineering/rca/account-deletion-storage-cleanup.md) and [account-deletion-user-data-audit.md](../engineering/rca/account-deletion-user-data-audit.md).

| Data category | Storage | On account delete |
|---------------|---------|-------------------|
| Account profile (email, name, avatar URL) | `app_users` | Tombstoned: PII removed; placeholder display name for attribution on shared content |
| In-app notification inbox | `notifications` (recipient `firebase_uid`) | **Removed** |
| Push device registration | `device_tokens` | **Removed** |
| Biometric sign-in public keys | `biometric_credentials` | **Removed** |
| Photos / avatars / exports (binary) | GCS + SQL pointers | SQL removed per product rules; GCS purged **asynchronously** via `storage_cleanup_jobs` |
| Sole-owned baby profile and all baby-scoped SQL | `baby_profiles` + dependents | **Hard-deleted** |
| Comments, suggestions, registry claims on co-owned babies | various `*_firebase_uid` author columns | Retained; author shown as deleted member |
| RSVPs, votes, loves, squishes | presence tables | **Removed** globally for the user |
