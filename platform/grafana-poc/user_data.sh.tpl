#!/bin/bash
set -euo pipefail

# Direct RPM download + rpm -ivh, NOT "yum install grafana" via a configured
# repo. The repo-based install reliably hung on TWO separate boots (t3.nano
# and t3.micro) at the exact same point right after the package finished
# downloading — confirmed via EC2 console output showing zero new lines for
# 30+ minutes both times, and every SSM command stuck "Pending" the whole
# time, which together point at DNF's own transaction/dependency-solver step,
# not CPU/network. rpm -ivh installs the file directly with no solver
# involved. Grafana's own runtime deps are just glibc/systemd, already on
# AL2023, so --nodeps is a safety net rather than something actually needed.
curl -fsSL -o /tmp/grafana.rpm "${grafana_download_url}"
timeout 300 rpm -ivh --nodeps /tmp/grafana.rpm

mkdir -p /etc/grafana/provisioning/datasources

# Same-account CloudWatch (this instance's own role) plus one data source per
# cross-account role — each one assumes a role via the instance's own
# credentials, so no static keys anywhere.
cat > /etc/grafana/provisioning/datasources/cloudwatch.yaml <<EOF
apiVersion: 1
datasources:
  - name: CloudWatch
    type: cloudwatch
    access: proxy
    isDefault: true
    jsonData:
      authType: default
      defaultRegion: ${aws_region}
%{ for ds in cross_account_datasources ~}
  - name: CloudWatch-${ds.account_id}
    type: cloudwatch
    access: proxy
    jsonData:
      authType: default
      assumeRoleArn: ${ds.arn}
      defaultRegion: ${aws_region}
%{ endfor ~}
EOF

# Seed the admin password so first login doesn't need the interactive
# "change admin/admin" prompt — same idea as Splunk's user-seed.conf.
cat >> /etc/grafana/grafana.ini <<EOF

[security]
admin_password = ${grafana_admin_password}
EOF

systemctl daemon-reload
systemctl enable --now grafana-server
