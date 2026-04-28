# EEA Entra ID sync policy

## Scope

This document describes only the synchronization policy between Microsoft Entra ID and Redmine as implemented by the current plugin.

It does not cover the OAuth authentication flow, plugin configuration, or features that are not directly related to synchronization.

## Synchronization tasks

The plugin exposes the following tasks:

```bash
bundle exec rake entra_id:sync RAILS_ENV=production
bundle exec rake entra_id:sync:users RAILS_ENV=production
bundle exec rake entra_id:sync:groups RAILS_ENV=production
```

`entra_id:sync` runs, in order:

1. user synchronization
2. group synchronization

## Current user sync policy

During `entra_id:sync:users`, the plugin:

1. reads users from the Microsoft Graph `users` endpoint
2. for each Entra ID user, looks for a local Redmine user by:
   - `oid`
   - email
   - login
3. if the user exists in Redmine, updates:
   - `firstname`
   - `lastname`
   - `mail`
   - `oid`
   - `status`
   - `synced_at`
4. if the user does not exist in Redmine, creates it

### User attributes synchronized

The current mapping is:

- `id` -> `oid`
- `mail` or `userPrincipalName` -> `mail`
- `mail` or `userPrincipalName` -> `login` on create only
- `givenName` / `surname` / `displayName` -> `firstname`, `lastname`
- synchronization time -> `synced_at`

### What user sync explicitly does

- updates existing users
- creates new users
- updates `synced_at` on every successful synchronization
- sets `status` to `active` on both create and update
- does not update `login` for existing users

### What user sync does not do

- if a user has been deleted from Entra ID, no action is taken on the Redmine user
- if a user no longer appears in the sync result, the user is not deleted from Redmine
- if a user no longer appears in the sync result, the user is not locked in Redmine
- if a user is disabled in Entra ID, the current plugin does not detect this and does not lock the user in Redmine
- there is no reconciliation for users previously synchronized but now absent from Entra ID
- there is no delta sync for users

### Important effect

For users that are found during `sync:users`, `status` is set to `active`.

This means that a previously synchronized user that is currently `locked` can be reactivated by `sync:users` if it is returned by Entra ID and processed successfully.

## Current group sync policy

During `entra_id:sync:groups`, the plugin:

1. reads groups from the Microsoft Graph `groups` endpoint
2. for each group, reads members from `transitiveMembers`
3. creates or updates the corresponding Redmine group
4. reconciles Redmine group membership against the membership returned by Entra ID

### What group sync explicitly does

- creates new groups in Redmine
- updates existing groups by `oid`
- updates the Redmine group name from Entra ID
- adds users that already exist in Redmine and have a matching `oid`
- removes users that are in the Redmine group but no longer appear in the Entra ID group membership
- removes users without an `oid` from synchronized groups

### What group sync does not do

- if a group has been deleted from Entra ID, no action is taken on the Redmine group
- groups missing from Entra ID are not deleted from Redmine
- groups missing from Entra ID are not archived and are not marked in any way
- group sync does not create missing users; it only adds users that already exist locally and are identified by `oid`
- group sync does not lock or delete users
- there is no delta sync for groups

### Important effect

Removing a user from a synchronized group also remove inherited roles granted through that group in Redmine projects.

## Practical meaning of the current policy

### For users

- synchronization is create/update only for users returned by Entra ID
- synchronization is not complete from a lifecycle management perspective
- a user missing from Entra ID does not trigger cleanup in Redmine

### For groups

- synchronization is create/update only for groups returned by Entra ID
- membership for returned groups is reconciled
- a group missing from Entra ID does not trigger cleanup in Redmine

## What could be added for complete synchronization

Complete synchronization would require additional mechanisms, beyond the current behavior, to detect deleted or disabled objects in Entra ID.

### Recommendations for users

- read the `accountEnabled` property from Microsoft Graph
- lock Redmine users when `accountEnabled = false`
- detect users deleted from Entra ID
- lock or delete Redmine users deleted from Entra ID, depending on operational policy
- use `users/delta` to track additions, updates, and deletions between sync runs
- use `synced_at` or a delta token for controlled reconciliation

### Recommendations for groups

- detect groups deleted from Entra ID
- delete or archive Redmine groups deleted from Entra ID
- use `groups/delta` to track additions, updates, and deletions between sync runs
- define an explicit cleanup strategy for local groups that still have an `oid` but no longer exist in Entra ID

### Policy recommendations

For users, `lock` is generally safer operationally than `delete`.

For groups, `delete` should only be introduced if the impact on memberships and inherited roles is acceptable and fully understood.
