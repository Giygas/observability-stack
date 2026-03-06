# Cloudflare Access Setup Guide

This guide explains how to secure your observability stack with Cloudflare Access, providing zero-trust authentication for all endpoints.

## Overview

Cloudflare Access acts as a reverse proxy with authentication, allowing you to:

- Protect Grafana, Prometheus, and Loki without VPNs
- Enforce multi-factor authentication (MFA)
- Control access by email, group, or IP
- Generate service tokens for API access (Alloy)
- Monitor all access attempts

## Prerequisites

- Cloudflare account with Zero Trust enabled
- Domain managed by Cloudflare
- Cloudflare Tunnel already configured ([Tunnel Setup Guide](tunnels.md))

## Architecture

```
User/App                             Cloudflare Network                             Observability Stack
                                     ┌────────────────────────────────────────┐
                                     │   Cloudflare Access                    │
                                     │   - Authentication (Email/OTP/SAML)    │
┌─────────────────────────────┐      │   - Service Token Validation           │     ┌───────────────────────┐
│ Browser / Grafana Alloy     │ ───► │   - Access Policies (Email/IP/Group)   │ ──► │ Grafana (3000)        │
│                             │      │   - Logging & Auditing                 │     │ Prometheus (9090)     │
└─────────────────────────────┘      └────────────────────────────────────────┘     │ Loki (3100)           │
                                                                                    └───────────────────────┘
```

## Step 1: Enable Cloudflare Access on Tunnel

If you haven't created a tunnel yet, follow the [Cloudflare Tunnel Setup](tunnels.md#cloudflare-tunnel-recommended) first.

Once your tunnel is running with public hostnames configured:

1. Go to **Cloudflare Zero Trust → Tunnels**
2. Click on your tunnel
3. Navigate to **Public Hostnames**
4. For each hostname (Prometheus, Loki, Grafana), click **Configure**
5. Under **Additional application settings**, click **Add application**
6. Enable **Cloudflare Access**

Your hostnames should now be protected with default "Allow all authenticated users" policy.

## Step 2: Create Access Policies

Access policies control who can access your endpoints.

### Simple Policy: Email Authentication

Go to **Zero Trust → Access → Applications**:

1. Find your protected endpoint (e.g., `grafana-obs.yourdomain.com`)
2. Click **Add a policy**
3. Configure:
   - **Policy name**: `Grafana Users`
   - **Selector**: `Email`
   - **Action**: `Allow`
   - **Value**: `*@yourdomain.com` or `user@example.com`

### Policy with Multi-Factor Authentication

For enhanced security, require MFA:

1. Create policy with selector: `Email`
2. Add **Require action** → **MFA**
3. Users will be prompted for MFA on first login

### IP-Based Policy (Optional)

Restrict access to specific IP ranges:

1. Add new policy with selector: `IP`
2. Value: `1.2.3.4/32` or `192.168.1.0/24`
3. Combine with email policy for layered security

### Group-Based Policy (Recommended)

Use SSO groups for easier management:

1. Go to **Zero Trust → Settings → Authentication**
2. Configure your identity provider (Google, Okta, Azure AD)
3. Create policy with selector: `Group`
4. Value: `obs-admins@yourdomain.com` or SSO group name

## Step 3: Create Service Tokens

Service tokens allow non-browser access (like Grafana Alloy) to bypass interactive authentication.

### Generate Service Token

1. Go to **Zero Trust → Access → Service Auth**
2. Click **Create Service Token**
3. Configure:
   - **Service token name**: `alloy-production`
   - **Tunnel**: Select your tunnel
4. Copy the **Client ID** and **Client Secret**
5. **Important**: Save these immediately—they won't be shown again

### Token Best Practices

- Use one token per environment (dev, staging, production)
- Rotate tokens regularly (every 90 days recommended)
- Revoke old tokens after rotation
- Limit token permissions to specific endpoints if needed

## Step 4: Configure Environment Variables

Add the service token credentials to your observability stack's `.env`:

```bash
# Cloudflare Access credentials (from Step 3)
CF_ACCESS_CLIENT_ID=your_client_id_here
CF_ACCESS_CLIENT_SECRET=your_client_secret_here
```

These credentials will be used by Grafana Alloy to authenticate when sending metrics/logs.

### For Observability Stack Host

Update `.env` in the observability-stack directory:

```bash
# Cloudflare Tunnel token
CLOUDFLARE_TUNNEL_TOKEN=your_tunnel_token

# Cloudflare Access (protects endpoints from browser access)
CF_ACCESS_CLIENT_ID=your_client_id
CF_ACCESS_CLIENT_SECRET=your_client_secret
```

### For Production App (Alloy)

Update `.env` in your app repository:

```bash
# Remote endpoint URLs
PROMETHEUS_URL=https://prometheus-obs.yourdomain.com/api/v1/write
LOKI_URL=https://loki-obs.yourdomain.com/loki/api/v1/push
GRAFANA_URL=https://grafana-obs.yourdomain.com

# Cloudflare Access credentials (same as obs stack)
CF_ACCESS_CLIENT_ID=your_client_id
CF_ACCESS_CLIENT_SECRET=your_client_secret
```

## Step 5: Configure Alloy for Service Token Auth

Update your `config.remote.alloy` to include Cloudflare Access headers:

```alloy
prometheus.remote_write "obs" {
  endpoint {
    url = env("PROMETHEUS_URL")

    // Cloudflare Access service token headers
    headers = {
      "CF-Access-Client-Id"     = env("CF_ACCESS_CLIENT_ID"),
      "CF-Access-Client-Secret" = env("CF_ACCESS_CLIENT_SECRET"),
    }

    queue_config {
      capacity             = 10000
      max_samples_per_send = 2000
      batch_send_deadline  = "5s"
    }
  }
}

loki.write "obs" {
  endpoint {
    url = env("LOKI_URL")

    // Cloudflare Access service token headers
    headers = {
      "CF-Access-Client-Id"     = env("CF_ACCESS_CLIENT_ID"),
      "CF-Access-Client-Secret" = env("CF_ACCESS_CLIENT_SECRET"),
    }
  }
}
```

## Step 6: Test Access

### Browser Access Test

1. Navigate to `https://grafana-obs.yourdomain.com`
2. You should see Cloudflare Access login page
3. Authenticate with your email (and MFA if configured)
4. After authentication, Grafana should load normally

### API Access Test (Alloy)

On your production server:

```bash
# Start Alloy
docker compose up -d grafana-alloy

# Check logs for successful connection
docker logs grafana-alloy -f

# Should see:
# "Remote write endpoint is healthy"
# "Loki write endpoint is healthy"
```

### curl Test (Verify Service Token Works)

```bash
# Test Prometheus endpoint
curl -H "CF-Access-Client-ID: your_id" \
     -H "CF-Access-Client-Secret: your_secret" \
     https://prometheus-obs.yourdomain.com/api/v1/query?query=up

# Test Loki endpoint
curl -H "CF-Access-Client-ID: your_id" \
     -H "CF-Access-Client-Secret: your_secret" \
     https://loki-obs.yourdomain.com/ready
```

## Step 7: Configure Additional Endpoints

Repeat the process for other services:

### Protect Prometheus UI

1. Go to **Zero Trust → Access → Applications**
2. Click **Add an application**
3. Enter `https://prometheus-obs.yourdomain.com`
4. Create policy (same as Grafana)
5. Copy same service token for Alloy use

### Protect Loki UI

1. Add application for `https://loki-obs.yourdomain.com`
2. Create policy
3. Service token same as Prometheus

## Monitoring Access Logs

Cloudflare Access logs all access attempts for audit trails.

### View Access Logs

1. Go to **Zero Trust → Logs → Access**
2. Filter by:
   - Application (Grafana/Prometheus/Loki)
   - Email (who accessed)
   - Action (Allow/Deny)
   - Time range

### Export Logs

For SIEM integration:

1. Go to **Zero Trust → Settings → R2**
2. Configure log forwarding to your SIEM (Splunk, Datadog, etc.)
3. Set retention period

### Alert on Denied Access

1. Go to **Zero Trust → Access → Applications**
2. Select application
3. Click **Settings** → **Notifications**
4. Configure alerts for denied access attempts

## Troubleshooting

### "Access Denied" Error in Browser

**Symptom**: Cloudflare Access denies access even with correct credentials.

**Solutions**:

- Verify policy matches your email domain
- Check if MFA is required and configured
- Ensure your email is verified in Cloudflare account
- Check browser console for error messages

### Alloy "Unauthorized" Error

**Symptom**: Alloy logs show 401 or 403 errors when sending metrics.

**Solutions**:

- Verify `CF_ACCESS_CLIENT_ID` and `CF_ACCESS_CLIENT_SECRET` are set correctly
- Check service token is not expired (check Zero Trust → Access → Service Auth)
- Ensure service token is associated with correct tunnel
- Test with `curl` command above to isolate issue

### Service Token Not Working

**Symptom**: Service token was working, now suddenly fails.

**Solutions**:

- Check if token was revoked in Cloudflare dashboard
- Verify token is assigned to correct tunnel
- Generate new token and rotate credentials

### Slow Performance

**Symptom**: Page loads slowly after adding Cloudflare Access.

**Solutions**:

- This is normal—Cloudflare adds ~100-200ms latency for auth checks
- Cloudflare caches policy decisions for 30 minutes after first access
- Consider using Argo Smart Routing for optimization

### MFA Not Prompting

**Symptom**: MFA is configured but not required.

**Solutions**:

- Go to application policy → Edit → Ensure "Require MFA" is enabled
- Check MFA provider settings (Google Authenticator, Okta, etc.)
- Verify MFA is enabled at account level (Zero Trust → Settings → Authentication)

## Security Best Practices

### 1. Always Require Authentication

Never use "Allow all" policy—everyone should authenticate.

### 2. Enable MFA for Admin Access

Require MFA for Grafana admin access and Prometheus endpoints.

### 3. Use Least Privilege

- Create separate policies for read-only users
- Limit service token permissions to specific endpoints
- Revoke unused service tokens

### 4. Rotate Credentials Regularly

- Service tokens: Every 90 days
- Passwords: Every 60 days
- MFA: Re-enroll devices every 180 days

### 5. Monitor Access Logs

- Review logs weekly for suspicious activity
- Set up alerts for denied access from new countries
- Track token usage patterns

### 6. Use Short-Lived Service Tokens

- Generate new tokens for each deployment
- Rotate tokens immediately after security incidents
- Document token rotation in CHANGELOG

### 7. Enable Geo-Blocking (Optional)

Restrict access to specific countries:

1. Go to **Zero Trust → Access → Applications**
2. Select application
3. Click **Settings** → **Rules**
4. Add rule: `Block` → `Geo` → Select countries to block

### 8. Enable Device Posture Checks (Optional)

Require devices to meet security standards:

1. Go to **Zero Trust → Access → Devices**
2. Configure device posture rules (OS version, antivirus, etc.)
3. Add to access policy: `Require` → `Device Posture` → Your rule

## Advanced Configuration

### SSO Integration

Configure SSO with Okta, Azure AD, or Google Workspace:

1. Go to **Zero Trust → Settings → Authentication**
2. Add identity provider
3. Configure SSO settings
4. Update access policies to use SSO groups

### Custom Login Page

Customize Cloudflare Access login page:

1. Go to **Zero Trust → Settings → Custom Pages**
2. Upload company logo
3. Customize colors and branding
4. Add custom messaging

### Session Management

Control user session duration:

1. Go to **Zero Trust → Settings → Authentication**
2. Set **Session duration** (default: 24 hours)
3. Configure **Idle timeout** (default: 8 hours)
4. Enable **Remember this device** for trusted devices

## Cost Considerations

Cloudflare Access pricing (as of 2024):

- **Free Tier**: Up to 50 users, 10 service tokens
- **Paid Plans**: $3/user/month for additional users
- **Teams**: Unlimited users, advanced features

For most small teams, the free tier is sufficient.

## Comparison: Cloudflare Access vs. Alternatives

| Feature               | Cloudflare Access | Basic Auth | VPN               |
| --------------------- | ----------------- | ---------- | ----------------- |
| MFA Support           | ✅ Yes            | ❌ No      | ⚠️ Depends        |
| Zero Trust            | ✅ Yes            | ❌ No      | ❌ No             |
| Scalability           | ✅ Excellent      | ⚠️ Limited | ⚠️ Limited        |
| User Experience       | ✅ SSO browser    | ⚠️ Popups  | ❌ Slow           |
| Logging & Auditing    | ✅ Built-in       | ❌ No      | ⚠️ Requires       |
| Service Token Support | ✅ Yes            | ❌ No      | ❌ No             |
| Cost                  | ✅ Free tier      | ✅ Free    | ⚠️ Infrastructure |

## Migration Guide

### From Basic Auth to Cloudflare Access

1. Remove Basic Auth from Grafana configuration
2. Enable Cloudflare Access on tunnel
3. Create access policies
4. Update users to use Cloudflare Access login
5. Remove Basic Auth credentials from `.env`

### From VPN to Cloudflare Access

1. Keep VPN running temporarily for migration
2. Enable Cloudflare Access on tunnel
3. Create access policies matching VPN user groups
4. Test access through Cloudflare Access
5. Update production apps to use Cloudflare Access headers
6. Gradually migrate users to Cloudflare Access
7. Decommission VPN after migration complete

## Next Steps

- [Tunnel Setup Guide](tunnels.md) - Configure Cloudflare Tunnel
- [Remote Mode Setup](remote-setup.md) - Configure Grafana Alloy with Cloudflare Access
- [Local Mode Setup](local-setup.md) - Local development setup
