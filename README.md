# Redmine EntraID Plugin

A Redmine plugin that enables Microsoft EntraID (formerly Azure Active Directory) authentication and user synchronization for your Redmine installation.

## What is Microsoft EntraID?

Microsoft EntraID is Microsoft's cloud-based identity and access management service that helps employees sign in and access resources. It's the evolution of Azure Active Directory and provides:

- Single Sign-On (SSO)
- Centralized User Management
- Enhanced Security
- OAuth 2.0 Integration

## Plugin features

- **OAuth 2.0 Authentication**: Secure login using Microsoft EntraID credentials
- **User Synchronization**: Automatically sync users from Microsoft Graph API
- **Exclusive Mode**: Option to disable local Redmine authentication entirely
- **User Mapping**: Maps EntraID user attributes to Redmine user fields
- **Automatic User Creation**: Creates Redmine users on first login if they don't exist

## Requirements

- Redmine 4.0+ (tested with Redmine 5.x)
- Ruby 2.7+
- Microsoft EntraID tenant with application registration
- Network access to Microsoft Graph API endpoints

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

### 1. Register an Application

1. Sign in to the [Azure portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** > **App registrations**
3. Click **New registration**
4. Configure:
   - **Name**: Redmine
   - **Supported account types**: Accounts in this organizational directory only
   - **Redirect URI**: `https://your-redmine-domain.com/entra_id/callback`

### 2. Configure Application Permissions

In your app registration:

1. Go to **API permissions**
2. Add the following **Microsoft Graph** permissions:
   - **User.Read** (Delegated) - for user authentication
   - **User.Read.All** (Application) - for user synchronization
3. Click **Grant admin consent** to apply the permissions

### 3. Generate Client Secret

1. Go to **Certificates & secrets**
2. Click **New client secret**
3. Add a description and set expiration
4. **Copy the secret value** (you won't be able to see it again)

### 4. Note Your Configuration Values

From your app registration overview page, copy:
- **Application (client) ID**
- **Directory (tenant) ID**
- **Client secret** (from previous step)

## Plugin Configuration

1. **Navigate to Redmine Administration**
   - Go to **Administration** > **Plugins**
   - Find "Entra ID" and click **Configure**

2. **Configure the following settings:**

   | Setting | Description | Example |
   |---------|-------------|---------|
   | **Enabled** | Enable/disable the plugin | `true` |
   | **Exclusive** | Disable local Redmine authentication | `false` |
   | **Client ID** | Application ID from Azure | `12345678-1234-1234-1234-123456789012` |
   | **Client Secret** | Secret value from Azure | `your-client-secret-here` |
   | **Tenant ID** | Directory ID from Azure | `87654321-4321-4321-4321-210987654321` |

3. **Save the configuration**

## Usage

### User Authentication

Once configured, users will see a "Sign in with EntraId" option on the Redmine login page. The authentication flow:

1. User clicks "Sign in with EntraId"
2. Redirected to Microsoft login page
3. User enters corporate credentials
4. Microsoft redirects back to Redmine with authorization code
5. Plugin exchanges code for user information
6. User is logged into Redmine (account created if needed)

### User Synchronization

The plugin can synchronize users from your Entra ID directory:

```bash
# From Redmine root directory
bundle exec rake entra_id:sync_users RAILS_ENV=production
```

This task:
- Fetches all users from Microsoft Graph API
- Creates/updates local Redmine users
- Maps Entra ID attributes to Redmine fields:
  - `userPrincipalName` → login/email
  - `givenName` → firstname
  - `surname` → lastname
  - `id` (OID) → stored for future synchronization

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


## Development

### Running Tests

```bash
# From Redmine root directory
bundle exec rake test:plugins NAME=entra_id RAILS_ENV=test
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

## Security Considerations

- **Client Secret Protection**: The client secret is stored encrypted in the database
- **HTTPS Required**: OAuth flows require HTTPS in production
- **Token Validation**: All tokens are validated against Microsoft's public keys
- **State Parameter**: CSRF protection using OAuth state parameter

## License

This plugin is released under the [MIT License](LICENSE).

## Support

For issues and questions:
- GitHub Issues: https://github.com/eea/redmine_entra_id/issues
- Documentation: https://github.com/eea/redmine_entra_id

## Version History

- **0.0.1**: Initial release with basic OAuth authentication and user sync
