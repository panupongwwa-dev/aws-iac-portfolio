#!/bin/bash
set -euo pipefail

# Install Splunk Enterprise. Free license (500MB/day) applies automatically
# after the 60-day trial — fine for a low-volume Security Hub findings feed.
cd /opt
curl -fsSL -o splunk.rpm "${splunk_download_url}"
yum install -y ./splunk.rpm

# Seed the admin password so first boot doesn't need an interactive prompt.
mkdir -p /opt/splunk/etc/system/local
cat > /opt/splunk/etc/system/local/user-seed.conf <<EOF
[user_info]
USERNAME = admin
PASSWORD = ${splunk_admin_password}
EOF

chown -R splunk:splunk /opt/splunk

sudo -u splunk /opt/splunk/bin/splunk start --accept-license --no-prompt --answer-yes

# `splunk enable boot-start -systemd-managed 1` does not reliably create a unit on
# Amazon Linux 2023 (confirmed: no unit file ever appears) — write one directly
# instead. Type=oneshot + RemainAfterExit because Splunk's own start script forks
# and manages its daemon itself; wrapping it as Type=forking with a PIDFile fights
# Splunk's stale-PID-file handling after an unclean shutdown (e.g. EC2 stop).
cat > /etc/systemd/system/splunkd.service <<EOF
[Unit]
Description=Splunk Enterprise
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=splunk
Group=splunk
ExecStartPre=-/usr/bin/find /opt/splunk/var/run -name *.pid -delete
ExecStart=/opt/splunk/bin/splunk start --no-prompt --answer-yes
ExecStop=/opt/splunk/bin/splunk stop --no-prompt --answer-yes
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

# Without [Install]/WantedBy, the unit loads as "static" and `systemctl enable`
# silently no-ops (no error, no symlink) — confirmed the hard way: this instance
# stayed dark through every scheduled EC2 stop/start until enabled by hand.
systemctl daemon-reload
systemctl enable splunkd.service

# --- Security Hub -> Splunk ingestion (custom HEC poller, no Splunkbase login needed) ---
/opt/splunk/bin/splunk http-event-collector enable -uri https://localhost:8089 -auth "admin:${splunk_admin_password}"
HEC_TOKEN=$(/opt/splunk/bin/splunk http-event-collector create securityhub -uri https://localhost:8089 -auth "admin:${splunk_admin_password}" | grep -oP 'token=\K[0-9a-f-]+')

cat > /opt/securityhub-poller.sh <<POLLER_EOF
#!/bin/bash
set -euo pipefail

HEC_TOKEN="$HEC_TOKEN"
HEC_URL="https://localhost:8088/services/collector/event"
REGION="${aws_region}"

aws securityhub get-findings --region "\$REGION" --max-results 100 --query 'Findings' --output json | \
python3 -c "
import json, sys, urllib.request, ssl

findings = json.load(sys.stdin)
ctx = ssl._create_unverified_context()
sent = 0
for f in findings:
    event = json.dumps({'sourcetype': 'aws:securityhub', 'event': f}).encode()
    req = urllib.request.Request('\$HEC_URL', data=event, headers={'Authorization': 'Splunk \$HEC_TOKEN'})
    try:
        urllib.request.urlopen(req, context=ctx, timeout=10)
        sent += 1
    except Exception as e:
        print(f'failed to send finding: {e}', file=sys.stderr)
print(f'sent {sent} findings')
"
POLLER_EOF
chmod +x /opt/securityhub-poller.sh

cat > /etc/systemd/system/securityhub-poller.service <<EOF
[Unit]
Description=Poll Security Hub findings into Splunk HEC

[Service]
Type=oneshot
ExecStart=/opt/securityhub-poller.sh
StandardOutput=append:/var/log/securityhub-poller.log
StandardError=append:/var/log/securityhub-poller.log
EOF

cat > /etc/systemd/system/securityhub-poller.timer <<EOF
[Unit]
Description=Run securityhub-poller every 10 minutes

[Timer]
OnBootSec=60
OnUnitActiveSec=10min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now securityhub-poller.timer

# --- Org-wide CloudTrail -> Splunk ingestion ---
# cloudtrail:LookupEvents only returns the CALLING account's own events, even
# from the management account — confirmed against real data (every event had
# recipientAccountId == the management account). The CloudWatch Logs
# destination of the organization trail is the only place that actually
# aggregates every member account's events, hence the cross-account role
# assumption below instead of a local API call.
%{ if cloudtrail_role_arn != "" }
mkdir -p /var/lib
cat > /opt/cloudtrail-poller.sh <<POLLER_EOF
#!/bin/bash
set -euo pipefail

HEC_TOKEN="$HEC_TOKEN"
HEC_URL="https://localhost:8088/services/collector/event"
ROLE_ARN="${cloudtrail_role_arn}"
LOG_GROUP="${cloudtrail_log_group_name}"
REGION="${aws_region}"
STATE_FILE="/var/lib/cloudtrail-poller.lastrun"

CREDS=\$(aws sts assume-role --role-arn "\$ROLE_ARN" --role-session-name cloudtrail-poller --region "\$REGION" --query 'Credentials' --output json)
export AWS_ACCESS_KEY_ID=\$(echo "\$CREDS" | python3 -c "import json,sys; print(json.load(sys.stdin)['AccessKeyId'])")
export AWS_SECRET_ACCESS_KEY=\$(echo "\$CREDS" | python3 -c "import json,sys; print(json.load(sys.stdin)['SecretAccessKey'])")
export AWS_SESSION_TOKEN=\$(echo "\$CREDS" | python3 -c "import json,sys; print(json.load(sys.stdin)['SessionToken'])")

START_TIME=\$(cat "\$STATE_FILE" 2>/dev/null || echo "\$(( \$(date +%s%3N) - 900000 ))")
END_TIME=\$(date +%s%3N)

aws logs filter-log-events --region "\$REGION" --log-group-name "\$LOG_GROUP" \
  --start-time "\$START_TIME" --end-time "\$END_TIME" \
  --query 'events[*].message' --output json | \
python3 -c "
import json, sys, urllib.request, ssl

messages = json.load(sys.stdin)
ctx = ssl._create_unverified_context()
sent = 0
for m in messages:
    event_data = json.loads(m)
    event = json.dumps({'sourcetype': 'aws:cloudtrail', 'event': event_data}).encode()
    req = urllib.request.Request('\$HEC_URL', data=event, headers={'Authorization': 'Splunk \$HEC_TOKEN'})
    try:
        urllib.request.urlopen(req, context=ctx, timeout=10)
        sent += 1
    except Exception as e:
        print(f'failed to send event: {e}', file=sys.stderr)
print(f'sent {sent} cloudtrail events')
"

echo "\$END_TIME" > "\$STATE_FILE"
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
POLLER_EOF
chmod +x /opt/cloudtrail-poller.sh

cat > /etc/systemd/system/cloudtrail-poller.service <<EOF
[Unit]
Description=Poll org-wide CloudTrail into Splunk HEC

[Service]
Type=oneshot
ExecStart=/opt/cloudtrail-poller.sh
StandardOutput=append:/var/log/cloudtrail-poller.log
StandardError=append:/var/log/cloudtrail-poller.log
EOF

cat > /etc/systemd/system/cloudtrail-poller.timer <<EOF
[Unit]
Description=Run cloudtrail-poller every 5 minutes

[Timer]
OnBootSec=90
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now cloudtrail-poller.timer
%{ endif }

# --- Security Hub findings export (EventBridge -> Firehose -> S3) -> Splunk ---
# Complements (doesn't replace) the direct securityhub-poller above: that one
# polls GetFindings with --max-results 100 and no pagination, so it silently
# drops anything past the first 100 changed findings per run, and sees nothing
# while this instance is stopped. This reads whatever Firehose already flushed
# to S3 in the meantime — durable regardless of Splunk's own uptime.
%{ if securityhub_export_bucket_name != "" }
cat > /opt/securityhub-export-poller.sh <<POLLER_EOF
#!/bin/bash
set -euo pipefail

HEC_TOKEN="$HEC_TOKEN"
HEC_URL="https://localhost:8088/services/collector/event"
BUCKET="${securityhub_export_bucket_name}"
STATE_FILE="/var/lib/securityhub-export-poller.processed"
touch "\$STATE_FILE"

for datepart in "\$(date -u -d yesterday +%Y/%m/%d)" "\$(date -u +%Y/%m/%d)"; do
  YEAR=\$(echo "\$datepart" | cut -d/ -f1)
  MONTH=\$(echo "\$datepart" | cut -d/ -f2)
  DAY=\$(echo "\$datepart" | cut -d/ -f3)
  PREFIX="findings/year=\$YEAR/month=\$MONTH/day=\$DAY/"

  aws s3api list-objects-v2 --bucket "\$BUCKET" --prefix "\$PREFIX" \
    --query 'Contents[*].Key' --output text 2>/dev/null | tr '\t' '\n' | while read -r key; do
    [ -z "\$key" ] && continue
    # --output text renders a null query result (empty prefix) as the
    # literal string "None" instead of nothing — confirmed by hitting
    # "download failed: s3://bucket/None ... 404" on a fresh instance.
    [ "\$key" = "None" ] && continue
    grep -qxF "\$key" "\$STATE_FILE" && continue

    aws s3 cp "s3://\$BUCKET/\$key" - | gunzip | python3 -c "
import json, sys, urllib.request, ssl

decoder = json.JSONDecoder()
text = sys.stdin.read().strip()
idx = 0
ctx = ssl._create_unverified_context()
sent = 0
while idx < len(text):
    while idx < len(text) and text[idx] in ' \t\n\r':
        idx += 1
    if idx >= len(text):
        break
    try:
        obj, idx = decoder.raw_decode(text, idx)
    except ValueError:
        break
    event = json.dumps({'sourcetype': 'aws:securityhub:firehose', 'event': obj}).encode()
    req = urllib.request.Request('\$HEC_URL', data=event, headers={'Authorization': 'Splunk \$HEC_TOKEN'})
    try:
        urllib.request.urlopen(req, context=ctx, timeout=10)
        sent += 1
    except Exception as e:
        print(f'failed to send record: {e}', file=sys.stderr)
print(f'sent {sent} records')
"
    echo "processed \$key"
    echo "\$key" >> "\$STATE_FILE"
  done
done
POLLER_EOF
chmod +x /opt/securityhub-export-poller.sh

cat > /etc/systemd/system/securityhub-export-poller.service <<EOF
[Unit]
Description=Pull Firehose-exported Security Hub findings from S3 into Splunk HEC

[Service]
Type=oneshot
ExecStart=/opt/securityhub-export-poller.sh
StandardOutput=append:/var/log/securityhub-export-poller.log
StandardError=append:/var/log/securityhub-export-poller.log
EOF

cat > /etc/systemd/system/securityhub-export-poller.timer <<EOF
[Unit]
Description=Run securityhub-export-poller every 2 minutes

[Timer]
OnBootSec=60
OnUnitActiveSec=2min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now securityhub-export-poller.timer
%{ endif }

# Centralized cross-account CloudWatch Logs (dev/staging Lambda + WAF logs),
# via a CloudWatch Logs Destination -> Firehose -> S3 (see
# security/cloudwatch-logs-central). Firehose's own compression is left
# UNCOMPRESSED, so each S3 object is several CloudWatch Logs subscription
# records concatenated back-to-back, where EACH record is independently
# gzip-compressed (the standard CWL subscription format) with no delimiter
# between records. gzip.decompress() handles concatenated multi-stream gzip
# automatically, and the resulting concatenated JSON text is parsed the same
# way as the Security Hub Firehose export: json.JSONDecoder().raw_decode()
# in a loop, since there's no delimiter between JSON documents either.
%{ if logs_central_bucket_name != "" }
cat > /opt/logs-central-poller.sh <<POLLER_EOF
#!/bin/bash
set -euo pipefail

HEC_TOKEN="$HEC_TOKEN"
HEC_URL="https://localhost:8088/services/collector/event"
BUCKET="${logs_central_bucket_name}"
STATE_FILE="/var/lib/logs-central-poller.processed"
touch "\$STATE_FILE"

for datepart in "\$(date -u -d yesterday +%Y/%m/%d)" "\$(date -u +%Y/%m/%d)"; do
  YEAR=\$(echo "\$datepart" | cut -d/ -f1)
  MONTH=\$(echo "\$datepart" | cut -d/ -f2)
  DAY=\$(echo "\$datepart" | cut -d/ -f3)
  PREFIX="logs/year=\$YEAR/month=\$MONTH/day=\$DAY/"

  aws s3api list-objects-v2 --bucket "\$BUCKET" --prefix "\$PREFIX" \
    --query 'Contents[*].Key' --output text 2>/dev/null | tr '\t' '\n' | while read -r key; do
    [ -z "\$key" ] && continue
    [ "\$key" = "None" ] && continue
    grep -qxF "\$key" "\$STATE_FILE" && continue

    aws s3 cp "s3://\$BUCKET/\$key" - | python3 -c "
import gzip, json, sys, urllib.request, ssl

raw = sys.stdin.buffer.read()
text = gzip.decompress(raw).decode('utf-8', errors='replace')

decoder = json.JSONDecoder()
idx = 0
ctx = ssl._create_unverified_context()
sent = 0
while idx < len(text):
    while idx < len(text) and text[idx] in ' \t\n\r':
        idx += 1
    if idx >= len(text):
        break
    try:
        payload, idx = decoder.raw_decode(text, idx)
    except ValueError:
        break
    if payload.get('messageType') == 'CONTROL_MESSAGE':
        continue
    log_group = payload.get('logGroup', 'unknown')
    owner = payload.get('owner', 'unknown')
    for ev in payload.get('logEvents', []):
        record = {
            'sourcetype': 'aws:cloudwatch:central',
            'event': {'message': ev.get('message'), 'logGroup': log_group, 'owner': owner},
        }
        data = json.dumps(record).encode()
        req = urllib.request.Request('\$HEC_URL', data=data, headers={'Authorization': 'Splunk \$HEC_TOKEN'})
        try:
            urllib.request.urlopen(req, context=ctx, timeout=10)
            sent += 1
        except Exception as e:
            print(f'failed to send event: {e}', file=sys.stderr)
print(f'sent {sent} log events')
"
    echo "processed \$key"
    echo "\$key" >> "\$STATE_FILE"
  done
done
POLLER_EOF
chmod +x /opt/logs-central-poller.sh

cat > /etc/systemd/system/logs-central-poller.service <<EOF
[Unit]
Description=Pull centralized cross-account CloudWatch Logs from S3 into Splunk HEC

[Service]
Type=oneshot
ExecStart=/opt/logs-central-poller.sh
StandardOutput=append:/var/log/logs-central-poller.log
StandardError=append:/var/log/logs-central-poller.log
EOF

cat > /etc/systemd/system/logs-central-poller.timer <<EOF
[Unit]
Description=Run logs-central-poller every 2 minutes

[Timer]
OnBootSec=60
OnUnitActiveSec=2min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now logs-central-poller.timer

# Brute-force login detection. Originally built as a native Splunk saved
# search/alert, but scheduled saved-search dispatch on this instance
# consistently returned scanCount=0 (clean parse, correct time range, no
# errors logged) while the identical search via the plain ad-hoc
# /services/search/jobs endpoint worked correctly every time — root cause
# never identified despite checking file ownership, a full instance reboot,
# license state (still on active trial), and role/index permissions. Worked
# around by driving the same working ad-hoc search from a timer instead of
# relying on Splunk's own scheduler.
cat > /opt/brute-force-poller.sh <<POLLER_EOF
#!/bin/bash
set -euo pipefail

SPLUNK_PASS=\$(aws secretsmanager get-secret-value --secret-id splunk-poc/splunk-admin-password --region ${aws_region} --query SecretString --output text)
export HEC_TOKEN="$HEC_TOKEN"

SEARCH='search sourcetype=aws:cloudwatch:central message="*login_attempt*" message="*\"status\":\"fail\"*" | rex field=message "login_attempt\",\"username\":\"(?<user>[^\"]+)\",\"login_type\":\"(?<login_type>[^\"]+)\",\"status\":\"(?<status>[^\"]+)\",\"ip\":\"(?<ip>[^\"]+)\"" | stats count by ip, user | where count >= 5'

RESP=\$(curl -sk -u "admin:\$SPLUNK_PASS" "https://localhost:8089/services/search/jobs" -d output_mode=json --data-urlencode "search=\$SEARCH" -d earliest_time=-10m -d latest_time=now)
SID=\$(echo "\$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['sid'])")

for i in 1 2 3 4 5 6 7 8 9 10; do
  DONE=\$(curl -sk -u "admin:\$SPLUNK_PASS" -G "https://localhost:8089/services/search/jobs/\$SID" -d output_mode=json | python3 -c "import json,sys; print(json.load(sys.stdin)['entry'][0]['content']['isDone'])")
  [ "\$DONE" = "True" ] && break
  sleep 2
done

curl -sk -u "admin:\$SPLUNK_PASS" -G "https://localhost:8089/services/search/jobs/\$SID/results" -d output_mode=json > /tmp/brute_force_results.json
curl -sk -u "admin:\$SPLUNK_PASS" "https://localhost:8089/services/search/jobs/\$SID" -X DELETE > /dev/null

python3 <<'PYEOF'
import json, datetime, os, urllib.request, ssl

hec_token = os.environ["HEC_TOKEN"]
with open("/tmp/brute_force_results.json") as f:
    d = json.load(f)

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

for r in d.get("results", []):
    msg = f"BRUTE-FORCE ALERT: ip={r['ip']} user={r['user']} fail_count={r['count']} (last 10 min)"
    print(f"[{datetime.datetime.utcnow().isoformat()}] {msg}")
    event = {
        "sourcetype": "brute_force_alert",
        "event": {
            "ip": r["ip"],
            "user": r["user"],
            "fail_count": int(r["count"]),
            "window": "last_10_min",
            "message": msg,
        },
    }
    req = urllib.request.Request(
        "https://localhost:8088/services/collector/event",
        data=json.dumps(event).encode(),
        headers={"Authorization": f"Splunk {hec_token}"},
        method="POST",
    )
    try:
        urllib.request.urlopen(req, context=ctx, timeout=10)
    except Exception as e:
        print(f"HEC send failed: {e}")
PYEOF
POLLER_EOF
chmod +x /opt/brute-force-poller.sh
chown splunk:splunk /opt/brute-force-poller.sh

cat > /etc/systemd/system/brute-force-poller.service <<EOF
[Unit]
Description=Detect brute-force login attempts from centralized logs

[Service]
Type=oneshot
ExecStart=/opt/brute-force-poller.sh
StandardOutput=append:/var/log/brute-force-poller.log
StandardError=append:/var/log/brute-force-poller.log
EOF

cat > /etc/systemd/system/brute-force-poller.timer <<EOF
[Unit]
Description=Run brute-force-poller every 10 minutes

[Timer]
OnBootSec=90
OnUnitActiveSec=10min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now brute-force-poller.timer

# Dashboard so there's a single page to check for brute-force activity,
# instead of writing ad-hoc search queries each time.
cat > /tmp/brute_force_dashboard.xml <<'DASH_EOF'
<dashboard version="1.1">
  <label>Brute-Force Login Alerts</label>
  <row>
    <panel>
      <single>
        <title>Alerts in last 24h</title>
        <search>
          <query>search sourcetype=brute_force_alert | stats count</query>
          <earliest>-24h</earliest>
          <latest>now</latest>
        </search>
        <option name="colorBy">value</option>
        <option name="rangeColors">["0x53a051","0xf8be34","0xdc4e41"]</option>
        <option name="rangeValues">[1,5]</option>
      </single>
    </panel>
  </row>
  <row>
    <panel>
      <table>
        <title>Recent brute-force alerts</title>
        <search>
          <query>search sourcetype=brute_force_alert | table _time, ip, user, fail_count | sort -_time</query>
          <earliest>-24h</earliest>
          <latest>now</latest>
        </search>
      </table>
    </panel>
  </row>
  <row>
    <panel>
      <chart>
        <title>Alerts over time</title>
        <search>
          <query>search sourcetype=brute_force_alert | timechart span=1h count</query>
          <earliest>-24h</earliest>
          <latest>now</latest>
        </search>
        <option name="charting.chart">column</option>
      </chart>
    </panel>
  </row>
</dashboard>
DASH_EOF
curl -sk -u "admin:${splunk_admin_password}" "https://localhost:8089/servicesNS/admin/search/data/ui/views" \
  --data-urlencode "name=brute_force_alerts" \
  --data-urlencode "eai:data@/tmp/brute_force_dashboard.xml"
%{ endif }

# --- TA-aws (Splunk Add-on for AWS) pilot: VPC Flow Logs via native S3 + SQS ---
# Splunk_TA_aws auto-discovers an "EC2 IAM role" account (named after this
# instance's own IAM role) the moment it starts on an EC2 instance with a
# role attached — confirmed live: no manual account/key needed at all, the
# bucket/queue policies in the workload prod account already grant this exact role
# cross-account access. Created via direct REST POST (same pattern as the
# HEC token / dashboard calls above), not the bundled aws_config_cli.py tool
# (that one requires SPLUNK_HOME + real STS-verified keys for the account
# step, neither of which apply here). Wrapped with `set +e` so a failure
# here doesn't abort the rest of user_data.
%{ if ta_aws_package_s3_key != "" }
set +e
{
  aws s3 cp "s3://${app_bundles_bucket_name}/${ta_aws_package_s3_key}" /tmp/ta-aws.spl \
    && /opt/splunk/bin/splunk install app /tmp/ta-aws.spl -auth "admin:${splunk_admin_password}" \
    && chown -R splunk:splunk /opt/splunk/etc/apps/Splunk_TA_aws \
    && curl -sk -u "admin:${splunk_admin_password}" \
      "https://localhost:8089/servicesNS/nobody/Splunk_TA_aws/data/inputs/aws_sqs_based_s3" \
      --data-urlencode "name=vpc_flow_logs_pilot" \
      --data-urlencode "aws_account=${splunk_role_name}" \
      --data-urlencode "sqs_queue_url=${vpc_flow_logs_native_sqs_queue_url}" \
      --data-urlencode "sqs_queue_region=${aws_region}" \
      --data-urlencode "s3_file_decoder=VPCFlowLogs" \
      --data-urlencode "sourcetype=aws:cloudwatchlogs:vpcflow" \
      --data-urlencode "index=default" \
      --data-urlencode "interval=60" \
      --data-urlencode "sqs_batch_size=10" \
      --data-urlencode "using_dlq=0"

  # Lambda CloudWatch metrics, same data Grafana already reads (assumes the
  # same grafana-cloudwatch-reader role in each workload account, which
  # trusts this instance's role).
%{ for t in cloudwatch_metrics_targets }
  curl -sk -u "admin:${splunk_admin_password}" \
    "https://localhost:8089/servicesNS/nobody/Splunk_TA_aws/data/inputs/aws_cloudwatch" \
    --data-urlencode "name=lambda_metrics_${t.env}" \
    --data-urlencode "aws_account=${splunk_role_name}" \
    --data-urlencode "aws_iam_role=${t.role_arn}" \
    --data-urlencode "aws_region=${aws_region}" \
    --data-urlencode 'metric_namespace=["AWS/Lambda"]' \
    --data-urlencode 'metric_names=[".*"]' \
    --data-urlencode 'metric_dimensions=[{"FunctionName":[".*"]}]' \
    --data-urlencode 'statistics=["Average","Sum","Maximum"]' \
    --data-urlencode "period=300" \
    --data-urlencode "query_window_size=12" \
    --data-urlencode "polling_interval=300" \
    --data-urlencode "index=default" \
    --data-urlencode "sourcetype=aws:cloudwatch:lambda:${t.env}"
%{ endfor }
} > /var/log/ta-aws-pilot-setup.log 2>&1
set -e
%{ endif }
