# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- **Health Check Command**: `make health-check` for quick service and endpoint status checks
- **Validation Command**: `make validate` for configuration and environment validation
- **ROADMAP.md**: Comprehensive roadmap of planned features categorized by complexity
- **Submodule Update Guide**: `docs/submodule-updates.md` for parent projects

### Changed
- **Dashboard v2**: Updated `configs/grafana/dashboards/api-health.json` dashboard
  - Fixed threshold values (changed from `0` to `null`)
  - Synced plugin version to Grafana 10.2.4
  - Added transparency to panels for better visual integration
- **Makefile Help Text**: Improved target descriptions for brevity

---

## [1.0.0] - 2026-02-21

### Added
- Initial release of observability-stack
- Grafana 10.2.4, Prometheus v2.48.0, Loki 2.9.10
- Docker Compose orchestration
- Tunnel support: Cloudflare, Tailscale, WireGuard
- Pre-configured Grafana dashboards
- Grafana provisioning
- API Health dashboard template
