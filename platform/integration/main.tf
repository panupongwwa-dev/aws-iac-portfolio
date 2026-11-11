# Dead Letter Queues must be created before main queues that reference them
resource "aws_sqs_queue" "dlq" {
  for_each = var.dead_letter_queues

  name                      = each.value.fifo ? "${each.value.name}.fifo" : each.value.name
  message_retention_seconds = each.value.message_retention_seconds
  kms_master_key_id         = each.value.kms_key_id
  fifo_queue                = each.value.fifo

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_sqs_queue" "this" {
  for_each = var.queues

  name                        = each.value.fifo ? "${each.value.name}.fifo" : each.value.name
  visibility_timeout_seconds  = each.value.visibility_timeout_seconds
  message_retention_seconds   = each.value.message_retention_seconds
  max_message_size            = each.value.max_message_size
  delay_seconds               = each.value.delay_seconds
  receive_wait_time_seconds   = each.value.receive_wait_time_seconds
  fifo_queue                  = each.value.fifo
  content_based_deduplication = each.value.fifo ? each.value.content_based_deduplication : null
  kms_master_key_id           = each.value.kms_key_id

  redrive_policy = each.value.dlq_key != null ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.value.dlq_key].arn
    maxReceiveCount     = each.value.max_receive_count
  }) : null

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_sns_topic" "this" {
  for_each          = var.topics
  name              = each.value.fifo ? "${each.value.name}.fifo" : each.value.name
  fifo_topic        = each.value.fifo
  kms_master_key_id = each.value.kms_key_id
  tags              = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_sns_topic_subscription" "this" {
  for_each = var.subscriptions

  topic_arn            = aws_sns_topic.this[each.value.topic_key].arn
  protocol             = each.value.protocol
  endpoint             = each.value.endpoint
  raw_message_delivery = each.value.raw_message_delivery
  filter_policy        = each.value.filter_policy != null ? jsonencode(each.value.filter_policy) : null
}

# Allow SNS to publish to SQS queues (for SNS → SQS subscriptions)
resource "aws_sqs_queue_policy" "sns_to_sqs" {
  for_each = {
    for k, sub in var.subscriptions : k => sub
    if sub.protocol == "sqs" && sub.sqs_queue_key != null
  }

  queue_url = aws_sqs_queue.this[each.value.sqs_queue_key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSNSPublish"
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.this[each.value.sqs_queue_key].arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_sns_topic.this[each.value.topic_key].arn
        }
      }
    }]
  })
}
