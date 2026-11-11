variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "grafana-poc"
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro (1GB RAM) installed grafana-server fine but the instance went completely unresponsive afterward (SSM agent stopped answering, port 3000 never came up, despite EC2 status checks still passing) — console output showed zram/swap getting disabled at boot (\"system has too much memory (916MB), limit is 800MB, ignoring\"), so there's no swap at all on a 1GB box, making it a likely OOM candidate once Grafana actually starts loading. t3.small (2GB RAM) matches what security/splunk-poc already runs reliably."
  type        = string
  default     = "t3.small"
}

variable "availability_zone" {
  description = "AZ to launch in (e.g. \"ap-southeast-7b\"). null = first AZ Terraform finds, which may hit InsufficientInstanceCapacity on a constrained AZ — set explicitly if that happens (see security/splunk-poc for the same issue)."
  type        = string
  default     = null
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the Grafana UI (port 3000). Required — do not default to 0.0.0.0/0."
  type        = list(string)
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size (GB) — the AL2023 AMI's own snapshot is 30GB, so this can't go below that"
  type        = number
  default     = 30
}

variable "grafana_download_url" {
  description = "Direct download URL for the Grafana OSS RPM (from rpm.grafana.com's own Packages/ path, not the dl.grafana.com release artifact, which bundles something far larger). Verify with `curl -I <url>` before applying — a dead link fails silently inside user_data."
  type        = string
  default     = "https://rpm.grafana.com/Packages/grafana-12.1.0-1.x86_64.rpm"
}

variable "cross_account_metrics_role_arns" {
  description = "ARNs of cross-account roles this instance may assume to read CloudWatch metrics in other accounts (e.g. a workload dev account). Each one becomes a separate Grafana CloudWatch data source. Empty = only this account's own metrics are readable."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
