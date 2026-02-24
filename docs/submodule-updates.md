# Submodule Update Guide

This guide helps you keep your project updated when using observability-stack as a submodule.

---

## Baseline Status (v1.0.0)

**Current release:** v1.0.0
**Release date:** [Current date]

### What's Included

- Grafana 10.2.4
- Prometheus v2.48.0
- Loki 2.9.10
- Docker Compose configuration
- Tunnel support (Cloudflare, Tailscale, WireGuard)
- Pre-configured dashboards
- Grafana provisioning

---

## What Changed in Each Version

### v1.0.0 (Baseline)

**Breaking Changes:** None
**Recommended Updates:** None
**Optional Updates:** None

**What to do:**
```bash
make obs-update
```

---

## Quick Reference: Update Checklist

When a new version is released:

- [ ] Run `make obs-update`
- [ ] Check CHANGELOG.md in observability/
- [ ] Check if breaking changes exist
- [ ] Update `.env.example` if new variables were added
- [ ] (Optional) Add new convenience commands to Makefile
- [ ] Restart stack: `make obs-down && make obs-up`

---

## Determining if Updates Are Required

| Change Type | Action Required |
|-------------|----------------|
| Documentation only | ✅ Skip (just run `make obs-update`) |
| New Make targets | ⚠️ Optional (add delegates for convenience) |
| New environment variables | 🟠 Recommended (update `.env.example`) |
| New services | 🟠 Recommended (update docs) |
| Breaking changes | 🔴 Critical (must update) |
| New ports | 🟠 Recommended (update docs) |
| Network changes | 🔴 Critical (verify compatibility) |

---

## Best Practices

1. **Keep submodule updated**: Run `make obs-update` regularly
2. **Check CHANGELOG**: Always review changes before updating
3. **Test updates**: Update in a staging environment first
4. **Version pinning**: Pin to specific commits for production stability
5. **Documentation**: Keep your project docs synced with observability-stack

---

## Version Pinning (For Production)

To pin to a specific version:

```bash
# Update to specific commit
cd observability
git checkout <commit-hash>

# Lock submodule version
cd ..
git add observability
git commit -m "Pin observability-stack to <commit-hash>"
```

This prevents automatic updates from breaking your production setup.

---

## Common Patterns

### Adding New Make Delegates

When observability-stack adds new Make targets, you can delegate them from your project:

```makefile
# In your project's Makefile
OBS_DIR := observability

obs-health-check: ## Run observability health check
	@$(MAKE) -C $(OBS_DIR) health-check

obs-validate: ## Validate observability configuration
	@$(MAKE) -C $(OBS_DIR) validate

obs-backup: ## Backup observability data
	@$(MAKE) -C $(OBS_DIR) backup

obs-restore: ## Restore observability data
	@$(MAKE) -C $(OBS_DIR) restore
```

### Updating Environment Variables

When new environment variables are added, update your `.env.example`:

```bash
# Check what's new in observability/.env.example
diff .env.example observability/.env.example

# Add new variables to your .env.example
cp observability/.env.example .env.example
# Customize for your project
```

---

## Troubleshooting

### Submodule Not Updating

```bash
# Error: No changes despite running update
# Solution: Force update
cd observability
git fetch origin
git checkout main
git pull origin main
cd ..
git add observability
git commit -m "Update observability-stack to latest"
```

### Breaking Changes Detected

1. **Stop the stack:**
   ```bash
   make obs-down
   ```

2. **Review breaking changes in CHANGELOG**

3. **Update configuration as needed**

4. **Restart the stack:**
   ```bash
   make obs-up
   ```

5. **Verify everything works:**
   ```bash
   make obs-health-check
   ```
