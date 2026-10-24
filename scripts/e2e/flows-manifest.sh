#!/usr/bin/env bash
# Maestro flow lists for P0 E2E (paths relative to apps/mobile).
# Tags: smoke (~15 min critical path), full (complete P0 UI coverage).

set -euo pipefail

E2E_SMOKE_FLOWS=(
  maestro/flows/smoke/auth_sign_in.yaml
  maestro/flows/smoke/shell_navigation.yaml
  maestro/flows/smoke/open_notifications.yaml
  maestro/flows/smoke/home_summary.yaml
  maestro/flows/smoke/offline_banner.yaml
  maestro/flows/smoke/pull_to_refresh_account.yaml
  maestro/flows/smoke/auth_sign_out.yaml
)

E2E_FULL_FLOWS=(
  "${E2E_SMOKE_FLOWS[@]}"
  maestro/flows/features/home_sections.yaml
  maestro/flows/features/baby_switcher.yaml
  maestro/flows/features/gallery_browse.yaml
  maestro/flows/features/gallery_social.yaml
  maestro/flows/features/gallery_upload.yaml
  maestro/flows/features/calendar_create.yaml
  maestro/flows/features/calendar_upcoming.yaml
  maestro/flows/features/calendar_event_cover.yaml
  maestro/flows/features/registry_crud.yaml
  maestro/flows/features/registry_mark_purchased.yaml
  maestro/flows/features/announce_arrival.yaml
  maestro/flows/features/followers_invite.yaml
  maestro/flows/roles/invite_deep_link.yaml
  maestro/flows/features/followers_revoke_remove.yaml
  maestro/flows/features/account_settings.yaml
  maestro/flows/features/settings_help.yaml
  maestro/flows/features/notifications_inbox_read.yaml
  maestro/flows/features/biometric_settings.yaml
  maestro/flows/features/auth_sign_up_verify_gate.yaml
  maestro/flows/features/auth_unverified_gate.yaml
  maestro/flows/roles/follower_permissions.yaml
  maestro/flows/roles/registry_claim_follower.yaml
  maestro/flows/roles/invite_accept_signed_out.yaml
  maestro/flows/roles/invite_wrong_account_switch.yaml
  maestro/flows/roles/invite_login_resume_427.yaml
  maestro/flows/roles/invite_decline.yaml
  maestro/flows/onboarding/onboarding_owner_fresh.yaml
  maestro/flows/onboarding/onboarding_owner_resilience.yaml
  maestro/flows/destructive/account_delete_throwaway.yaml
  maestro/flows/destructive/baby_hard_delete_throwaway.yaml
)

# Named tags for --tag (subset of full).
declare -A E2E_TAG_FLOWS=(
  [invite]="maestro/flows/roles/invite_accept_signed_out.yaml maestro/flows/roles/invite_wrong_account_switch.yaml maestro/flows/roles/invite_login_resume_427.yaml maestro/flows/roles/invite_decline.yaml"
  [auth]="maestro/flows/smoke/auth_sign_in.yaml maestro/flows/smoke/auth_sign_out.yaml maestro/flows/features/auth_sign_up_verify_gate.yaml maestro/flows/features/auth_unverified_gate.yaml"
  [registry]="maestro/flows/features/registry_crud.yaml maestro/flows/features/registry_mark_purchased.yaml maestro/flows/roles/registry_claim_follower.yaml"
  [destructive]="maestro/flows/destructive/account_delete_throwaway.yaml maestro/flows/destructive/baby_hard_delete_throwaway.yaml"
)
