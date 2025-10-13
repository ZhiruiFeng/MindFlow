# Configuration Setup Guide

## Supabase Authentication Configuration

MindFlow uses **Supabase OAuth with Google** for authentication, providing shared authentication with the ZephyrOS ecosystem.

### Prerequisites

You need access to the ZephyrOS Supabase project. If you don't have credentials yet, contact the project administrator.

### Steps:

1. **Get Supabase Credentials**

   You'll need three pieces of information from your Supabase project:
   - **Supabase URL**: Your Supabase project URL (e.g., `https://xxxxx.supabase.co`)
   - **Supabase Anon Key**: Your project's anonymous key
   - **Redirect URI**: OAuth callback URL (default: `com.mindflow.app:/oauth/callback`)

   To find these in Supabase Dashboard:
   - Go to Project Settings → API
   - Copy the **Project URL** and **anon/public key**

2. **Create Configuration File**
   ```bash
   # From the MindFlow/MindFlow directory
   cp Configuration.plist.template Configuration.plist
   ```

3. **Edit Configuration.plist**

   Open `Configuration.plist` in Xcode or a text editor and replace the placeholder values:

   ```xml
   <key>Supabase</key>
   <dict>
       <key>URL</key>
       <string>https://your-project.supabase.co</string>
       <key>AnonKey</key>
       <string>your-supabase-anon-key-here</string>
       <key>RedirectURI</key>
       <string>com.mindflow.app:/oauth/callback</string>
   </dict>
   ```

4. **Configure Google OAuth in Supabase** (If not already done)

   In the Supabase Dashboard:
   - Go to Authentication → Providers → Google
   - Enable Google authentication
   - Add your Google OAuth Client ID and Secret
   - Add authorized redirect URLs:
     - `https://your-project.supabase.co/auth/v1/callback`
     - `com.mindflow.app:/oauth/callback`

### Security Notes

- ⚠️ **NEVER** commit `Configuration.plist` to version control
- The `.gitignore` file is already configured to exclude this file
- Always use the template file for sharing or documentation
- The Supabase Anon Key is safe to expose in client apps (it's public by design)
- Keep your Supabase Service Role key (if you have one) completely private

### File Structure

```
MindFlow/MindFlow/
├── Configuration.plist.template  ← Template (commit this)
├── Configuration.plist           ← Your actual config (DO NOT commit)
└── Info.plist                    ← URL scheme already configured
```

### Verification

After setup, verify that:

1. **Configuration file exists**
   ```bash
   ls MindFlow/MindFlow/Configuration.plist
   ```

2. **Build the project**
   - The app should build without warnings about missing configuration
   - Check the console for any "⚠️ Warning" messages from ConfigurationManager

3. **Test authentication**
   - Run the app
   - Click "Sign in with Google"
   - You should be redirected to Google's login page
   - After signing in, you should be redirected back to MindFlow
   - Your user info should appear in the Settings tab

### Shared Authentication

MindFlow shares authentication with other ZephyrOS applications:
- Users authenticated in ZephyrOS-Executor can use MindFlow without re-authenticating
- All apps use the same Supabase user database
- User sessions are managed centrally through Supabase

### Troubleshooting

**"No callback URL received"**
- Check that the URL scheme in `Info.plist` matches the `RedirectURI` in `Configuration.plist`
- Ensure the scheme is `com.mindflow.app` (or your custom scheme)

**"Invalid callback"**
- Verify that the redirect URI is added to your Google OAuth client's authorized redirect URIs
- Check that it's also configured in Supabase's Google provider settings

**"Failed to fetch user information"**
- Verify your Supabase URL and Anon Key are correct
- Check that Google authentication is enabled in Supabase Dashboard
