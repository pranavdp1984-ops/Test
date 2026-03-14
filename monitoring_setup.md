# External Monitoring Setup for Lucee (probe.cfm)

## What probe.cfm returns

### HTTP 200 — OK
```json
{
  "status": "ok",
  "http_code": 200,
  "timestamp": "2024-03-14T10:22:00+00:00",
  "probe_ms": 12,
  "lucee_version": "5.4.6.9",
  "jvm":     { "heap_used_mb": 312, "heap_max_mb": 1024, "heap_pct": 30 },
  "threads": { "count": 45, "deadlocks": 0 },
  "cpu":     { "load_avg": "1.20", "cores": 4 },
  "disk":    { "temp_free_mb": 8420 },
  "reasons": []
}
```

### HTTP 200 — Degraded (early warning)
```json
{ "status": "degraded", "reasons": ["heap:82pct", "threads:320"], ... }
```

### HTTP 503 — Critical (monitoring marks server DOWN)
```json
{ "status": "critical", "reasons": ["deadlock:2 thread(s)", "heap:96pct"], ... }
```

---

## Thresholds

| Metric | Degraded (warning) | Critical (503) |
|---|---|---|
| Heap % | ≥ 80% | ≥ 95% |
| Thread count | > 300 | — |
| CPU load avg | > core count | — |
| Temp disk free | — | < 50 MB |
| Deadlocks | — | any |

---

## UptimeRobot (free, checks every 5 min)

1. Sign up at https://uptimerobot.com
2. Add Monitor → **Keyword Monitor**
3. URL: `https://yoursite.com/probe.cfm`
4. Keyword to exist: `"status":"ok"`
5. Alert contacts: your email / Slack / SMS

> UptimeRobot sees HTTP 503 → marks DOWN → sends alert immediately.

---

## Pingdom (paid, checks every 1 min)

1. Add Check → **HTTP(S)**
2. URL: `https://yoursite.com/probe.cfm`
3. Check for string: `"status":"ok"`
4. Alert when string missing OR status ≠ 200

---

## Zabbix (self-hosted)

Add to your Zabbix host:

```yaml
# zabbix_agentd.conf or via UI
UserParameter=lucee.probe, curl -s -o /tmp/lucee_probe.json -w "%{http_code}" https://yoursite.com/probe.cfm
```

Then create items:
- `lucee.probe` → HTTP code (trigger alert if ≠ 200)
- Use `jsonpath` preprocessing to extract `$.jvm.heap_pct`, `$.threads.deadlocks`, etc.

---

## nginx / HAProxy load balancer health check

### nginx upstream
```nginx
upstream lucee_backend {
    server 127.0.0.1:8888;
    # health check hits probe.cfm every 10s
}

server {
    location /probe.cfm {
        proxy_pass http://lucee_backend;
    }
}
```

### HAProxy
```haproxy
backend lucee
    option httpchk GET /probe.cfm
    http-check expect status 200
    server lucee1 127.0.0.1:8888 check inter 10s fall 2 rise 3
```

---

## Simple shell cron (if no external tool available)

```bash
#!/bin/bash
# /etc/cron.d/lucee_probe  — runs every 2 minutes
PROBE_URL="http://localhost:8888/probe.cfm"
ALERT_EMAIL="admin@yoursite.com"

STATUS=$(curl -s -o /tmp/lucee_probe.json -w "%{http_code}" "$PROBE_URL" 2>/dev/null)

if [ "$STATUS" != "200" ]; then
    echo "Lucee is DOWN or critical. HTTP $STATUS" | \
    mail -s "ALERT: Lucee probe failed" "$ALERT_EMAIL"
fi
```

Save as `/etc/cron.d/lucee_probe`, run `crontab -e` and add:
```
*/2 * * * * /path/to/lucee_probe.sh
```
