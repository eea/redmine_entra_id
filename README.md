# Redmine EntraID Plugin

A Redmine plugin that enables Microsoft EntraID (formerly Azure Active Directory) authentication and user synchronization for your Redmine installation.

## What is Microsoft EntraID?

Microsoft EntraID is Microsoft's cloud-based identity and access management service that helps employees sign in and access resources. It's the evolution of Azure Active Directory and provides:

- Single Sign-On (SSO)
- Centralized User Management
- Enhanced Security
- OAuth 2.0 Integration

## Plugin features

- **OAuth 2.0 Authentication**: Secure login using Microsoft EntraID credentials with
  automatic user creation
- **User Synchronization**: One-way sync of EntraId users to Redmine
- **Group Synchronization**: One-way sync of EntraID groups and memberships to Redmine
- **Exclusive Mode**: Option to disable local Redmine authentication entirely

## Requirements

- Redmine 5.x and 6.0
- Ruby 3.1 or newer
- Microsoft EntraID tenant with application registration

## Installation

1. **Clone the plugin into your Redmine plugins directory:**

   ```bash
   cd /path/to/redmine
   git clone https://github.com/eea/redmine_entra_id.git plugins/entra_id
   ```

2. **Install plugin dependencies:**

   ```bash
   bundle install
   ```

3. **Run the plugin migrations from the Redmine root directory:**

   ```bash
   bundle exec rake redmine:plugins:migrate RAILS_ENV=production
   ```

4. **Restart your Redmine application server**

## Microsoft Entra ID Setup

These steps need to be completed in the EntraID admin console.

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com)
2. Navigate to **Entra ID** > **App registrations**
3. Click **New registration**
4. Configure:
   - **Name**: Redmine
   - **Supported account types**: Accounts in this organizational directory only
   - **Redirect URI**: `https://your-redmine-domain.com/entra_id/callback`
5. Go to **API permissions**
6. Add the following **Microsoft Graph** permissions:
   - **User.Read** (Delegated) - for user authentication
   - **User.Read.All** (Application) - for user synchronization
   - **Group.Read.All** (Application) - for group synchronization
7. Click **Grant admin consent** to apply the permissions
8. Go to **Certificates & secrets**
9. Click **New client secret**
10. Add a description and set expiration
11. **Copy the secret value** (you won't be able to see it again)

From your app registration overview page, copy:

- **Application (client) ID**
- **Directory (tenant) ID**
- **Client secret** (from previous step)

## Plugin Configuration

1. **Navigate to Redmine Administration**

   - Go to **Administration** > **Plugins**
   - Find "Entra ID" and click **Configure**

2. **Configure the plugin:**

   The plugin uses environment variables for the Entra credentials:

   ```bash
   # Set the following environment variables
   export ENTRA_ID_CLIENT_ID="12345678-1234-1234-1234-123456789012"
   export ENTRA_ID_CLIENT_SECRET="your-client-secret-here"
   export ENTRA_ID_TENANT_ID="87654321-4321-4321-4321-210987654321"
   ```

   **Plugin Settings** (via Administration > Plugins > Configure):

   | Setting       | Description                          | Default |
   | ------------- | ------------------------------------ | ------- |
   | **Enabled**   | Enable/disable the plugin            | `false` |
   | **Exclusive** | Disable local Redmine authentication | `false` |

3. **Save the configuration**

## Usage

### User Authentication

Once configured, users will see a "Sign in with EntraId" option on the Redmine login page. The authentication flow:

1. User clicks "Log in with Microsoft EntraId"
2. Redirected to Microsoft login page
3. User enters corporate credentials
4. Microsoft redirects back to Redmine with authorization code
5. Plugin exchanges code for user information
6. User is logged into Redmine (account created if needed)

### User and Group Synchronization

The plugin provides rake tasks for synchronizing users and groups:

```bash
# Sync both users and groups
bundle exec rake entra_id:sync RAILS_ENV=production

# Sync only users
bundle exec rake entra_id:sync:users RAILS_ENV=production

# Sync only groups
bundle exec rake entra_id:sync:groups RAILS_ENV=production
```

**User Synchronization**:

- Fetches all users from Microsoft Graph API
- Creates/updates local Redmine users
- Maps Entra ID attributes to Redmine fields:
  - `userPrincipalName` → login/email
  - `givenName` → firstname
  - `surname` → lastname
  - `id` (OID) → stored for future synchronization
- Updates `synced_at` timestamp

**Group Synchronization**:

- Fetches groups from Microsoft Graph API
- Creates/updates Redmine groups based on EntraID groups
- Syncs group memberships automatically
- Removes Redmine groups that no longer exist in EntraID

### Exclusive Mode

When **Exclusive** mode is enabled:

- Local Redmine authentication is disabled
- Only Entra ID users can log in
- Registration and password reset forms are hidden
- Useful for corporate environments requiring centralized authentication

## Database Changes

The plugin adds the following fields to the `users` table:

- `oid` (string): Microsoft Entra ID Object ID (unique identifier)
- `synced_at` (datetime): Last synchronization timestamp

## Update scripts

- `bin/rails entra_id:reset_logins`
- `bin/rails entra_id:reset_auth_sources`

## Troubleshooting

### Common Issues

**"Invalid redirect URI" error:**

- Ensure the redirect URI in Azure matches exactly: `https://your-domain.com/entra_id/callback`
- Check for trailing slashes and protocol (http vs https)

**"Insufficient privileges" error:**

- Verify application permissions are configured correctly
- Ensure admin consent has been granted for your organization

**"Invalid client" error:**

- Double-check Client ID and Tenant ID values
- Ensure Client Secret hasn't expired

## Contributing

### Local setup

Clone the Redmine repository:

```bash
gh repo clone redmine/redmine
```

Clone the plugin in the Redmine plugins folder in the `plugins/entra_id` folder of the Redmine installation:

```bash
gh repo clone eea/redmine_entra_id redmine/plugins/entra_id
```

Create a database configuration for Redmine. Below is a sample configuration for MySQL 8 or newer:

```yaml
default: &default
  adapter: mysql2
  host: 127.0.0.1
  username: root
  encoding: utf8mb4
  variables:
    # Recommended `transaction_isolation` for MySQL to avoid concurrency issues is
    # `READ-COMMITTED`.
    # In case of MySQL lower than 8, the variable name is `tx_isolation`.
    # See https://www.redmine.org/projects/redmine/wiki/MySQL_configuration
    transaction_isolation: "READ-COMMITTED"

development:
  <<: *default
  database: redmine_development

test:
  <<: *default
  database: redmine_test

production:
  <<: *default
  database: redmine_production
```

Setup the database:

```bash
bin/rails db:prepare
```

Load the default Redmine data:

```bash
bin/rails redmine:load_default_data REDMINE_LANG=en
```

Run the plugin migrations:

```bash
bin/rails redmine:plugins:migrate NAME=entra_id
```
