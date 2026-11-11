variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "splunk-poc"
}

variable "instance_type" {
  description = "EC2 instance type (Splunk's own minimum recommendation is much higher — t3.small/medium is workable for a low-volume learning setup, not production)"
  type        = string
  default     = "t3.small"
}

variable "availability_zone" {
  description = "AZ to launch in (e.g. \"ap-southeast-7b\"). null = first AZ Terraform finds, which may hit InsufficientInstanceCapacity on a constrained AZ — set explicitly if that happens."
  type        = string
  default     = null
}

variable "use_spot" {
  description = "Launch as a spot instance. Set false to fall back to on-demand if spot capacity/fulfillment is unreliable in this region."
  type        = bool
  default     = false
}

variable "spot_max_price" {
  description = "Max hourly price (USD) to bid for the spot instance. null = cap at current on-demand price (AWS default). Only used when use_spot = true."
  type        = string
  default     = null
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the Splunk Web UI (port 8000). Required — do not default to 0.0.0.0/0."
  type        = list(string)
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size (GB). Not preserved across spot interruption — this is a learning/POC box, not durable storage."
  type        = number
  default     = 30
}

variable "splunk_download_url" {
  description = "Direct download URL for the Splunk Enterprise RPM. Splunk's download links change per release — verify with `curl -I <url>` before applying; an old/dead link fails silently inside user_data (curl 404 -> script exits, instance comes up with no Splunk listening)."
  type        = string
  default     = "https://download.splunk.com/products/splunk/releases/10.4.0/linux/splunk-10.4.0-f798d4d49089.x86_64.rpm"
}

variable "cross_account_assume_role_arns" {
  description = "ARNs of cross-account roles this instance is allowed to assume (e.g. a CloudTrail-reader role in the management account). Empty = none."
  type        = list(string)
  default     = []
}

variable "cloudtrail_role_arn" {
  description = "ARN of the cross-account role to assume for reading the org-wide CloudTrail log group in the management account. Empty string = CloudTrail polling disabled."
  type        = string
  default     = ""
}

variable "cloudtrail_log_group_name" {
  description = "Name of the org-wide CloudTrail CloudWatch Logs log group, read via cloudtrail_role_arn. Required if cloudtrail_role_arn is set."
  type        = string
  default     = ""
}

variable "securityhub_export_bucket_name" {
  description = "S3 bucket where security/securityhub-firehose-export lands Security Hub findings (same account, no cross-account role needed). Empty string = polling that bucket disabled."
  type        = string
  default     = ""
}

variable "logs_central_bucket_name" {
  description = "S3 bucket where security/cloudwatch-logs-central lands centralized cross-account CloudWatch Logs (same account, no cross-account role needed). Empty string = polling that bucket disabled."
  type        = string
  default     = ""
}

variable "logs_central_sqs_queue_arn" {
  description = "SQS queue ARN that receives S3 ObjectCreated notifications for the logs_central bucket (security/cloudwatch-logs-central's sqs_queue_arn output) — for TA-aws's SQS-based S3 input. Empty string = not granted."
  type        = string
  default     = ""
}

# ---- TA-aws (Splunk Add-on for AWS) pilot: cross-account VPC Flow Logs in
# native S3 format, published by a workload prod account. ------------------

variable "ta_aws_package_s3_key" {
  description = "Key (within app_bundles bucket) of the uploaded TA-aws .spl file. Empty string = TA-aws not installed."
  type        = string
  default     = ""
}

variable "vpc_flow_logs_native_bucket_name" {
  description = "S3 bucket (cross-account, in the workload prod account) holding native-format VPC Flow Logs for the TA-aws pilot. Empty string = pilot disabled."
  type        = string
  default     = ""
}

variable "vpc_flow_logs_native_sqs_queue_arn" {
  description = "SQS queue ARN (cross-account, in the workload prod account) — the queue's own policy isn't sufficient for cross-account access; this role also needs its own identity policy naming the resource. Empty string = pilot disabled."
  type        = string
  default     = ""
}

variable "vpc_flow_logs_native_sqs_queue_url" {
  description = "SQS queue URL (cross-account, in the workload prod account) notifying of new objects in the pilot bucket. Empty string = pilot disabled."
  type        = string
  default     = ""
}

variable "cloudwatch_metrics_targets" {
  description = "Cross-account grafana-cloudwatch-reader roles for TA-aws's CloudWatch input to assume — same Lambda metrics Grafana already reads, one entry per workload environment."
  type = list(object({
    env      = string
    role_arn = string
  }))
  default = []
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
