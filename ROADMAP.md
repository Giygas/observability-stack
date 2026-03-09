# Roadmap

## Vision

A zero-config observability stack that starts simple and scales when needed. Local development → remote deployment → high-cardinality workloads — all with the same foundation.

---

## Quick Wins

Documentation and convenience features that deliver immediate value with minimal effort.

### Documentation

- [ ] Mimir integration guide (external deployment)
- [ ] Migration path from Prometheus → Mimir
- [ ] Multi-server deployment documentation
- [ ] Performance benchmarks (10M+ series)

### Developer Tools

- [x] Health check diagnostics
- [x] Configuration validation
- [ ] Automated backup/restore
- [ ] Dashboard import/export utilities

### Dashboard Templates

- [ ] Pre-built dashboard library
- [ ] Go application template (beyond current api-health)
- [ ] System metrics dashboards (node-exporter)
- [ ] Database metrics templates

---

## Medium Effort

Features that add significant capabilities with moderate implementation effort.

### Security

- [ ] OAuth2/OIDC integration for Grafana
- [x] Cloudflare Access setup guide
- [ ] Service-to-service authentication
- [ ] Secrets management patterns

### Alerting

- [ ] Alertmanager configuration guide
- [ ] Pre-built alert rules
- [ ] Notification channel integrations

### Distributed Tracing

- [ ] Tempo integration design
- [ ] OpenTelemetry agent configuration
- [ ] Trace correlation with logs/metrics

### Network Security

- [ ] TLS/mTLS between services
- [ ] Encrypted tunnel configurations
- [ ] VPN setup guides

---

## Major Features

Complex features requiring significant design and implementation effort.

### High Availability

- [ ] High availability patterns
- [ ] Load balancing strategies
- [ ] Disaster recovery guides
- [ ] Multi-region deployment

### Advanced Features

- [ ] Multi-tenancy (team isolation, quotas, RBAC)
- [ ] Kubernetes operator
- [ ] WASM-based metrics processing
- [ ] Grafana Alloy component library

---

## Contributing

Want to influence the roadmap?

- Open a GitHub Issue with the `roadmap` label
- Join discussions on planned features
- Submit RFCs for new ideas
- Participate in RFC reviews

---

## Related Documentation

- [CHANGELOG.md](CHANGELOG.md) - What's been released
- [docs/submodule-updates.md](docs/submodule-updates.md) - Submodule update guide
- [docs/future/](docs/future/) - In-depth exploration of planned features
