# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

## [1.1.0] - 2026-03-09

### Added
- Health check command for quick service and endpoint status checks
- Validation command for configuration and environment validation
- ROADMAP.md with comprehensive feature planning
- Submodule update guide for parent projects
- Cloudflare Access setup guide with authentication and authorization patterns

### Changed
- Updated API Health dashboard to v2 with corrected thresholds and Grafana 10.2.4 compatibility
- Improved Makefile target descriptions and help text
- Updated tunnel documentation with Cloudflare Access cross-references
- Updated .gitignore for .opencode and agents.md

### Fixed
- Fixed Makefile tunnel startup order to start core stack before tunnels
- Fixed Makefile env-file loading to pass to all docker compose commands
- Fixed Grafana secret permissions in Makefile
- Fixed Makefile port check logic inversion in validate target
- Improved Makefile down and clean targets to stop all tunnels regardless of TUNNEL variable

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

---

[Unreleased]: https://github.com/Giygas/observability-stack/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/Giygas/observability-stack/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Giygas/observability-stack/releases/tag/v1.0.0
