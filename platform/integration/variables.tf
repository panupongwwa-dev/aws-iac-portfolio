variable "dead_letter_queues" {
  description = "Map of Dead Letter Queues to create"
  type = map(object({
    name                      = string
    fifo                      = optional(bool, false)
    message_retention_seconds = optional(number, 1209600)
    kms_key_id                = optional(string)
    tags                      = optional(map(string), {})
  }))
  default = {}
}

variable "queues" {
  description = "Map of SQS queues to create. Use dlq_key to attach a DLQ defined in dead_letter_queues."
  type = map(object({
    name                        = string
    fifo                        = optional(bool, false)
    content_based_deduplication = optional(bool, false)
    visibility_timeout_seconds  = optional(number, 30)
    message_retention_seconds   = optional(number, 345600)
    max_message_size            = optional(number, 262144)
    delay_seconds               = optional(number, 0)
    receive_wait_time_seconds   = optional(number, 0)
    kms_key_id                  = optional(string)
    dlq_key                     = optional(string)
    max_receive_count           = optional(number, 3)
    tags                        = optional(map(string), {})
  }))
  default = {}
}

variable "topics" {
  description = "Map of SNS topics to create"
  type = map(object({
    name       = string
    fifo       = optional(bool, false)
    kms_key_id = optional(string)
    tags       = optional(map(string), {})
  }))
  default = {}
}

variable "subscriptions" {
  description = "Map of SNS subscriptions. topic_key must match a key in topics. For SQS protocol, set sqs_queue_key to auto-create the queue policy."
  type = map(object({
    topic_key            = string
    protocol             = string
    endpoint             = string
    raw_message_delivery = optional(bool, false)
    filter_policy        = optional(map(list(string)))
    sqs_queue_key        = optional(string)
  }))
  default = {}
}

variable "tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default     = {}
}
