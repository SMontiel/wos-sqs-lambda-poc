locals {
  sns_arn = "arn:aws:sns:us-west-1:205399592845:wizelineos-testing-notify-slack-topic"
  threshold = 10
}

resource "aws_sns_topic_subscription" "sns_notify_slack" {
  topic_arn = local.sns_arn
  protocol  = "lambda"
  endpoint  = module.lambda_function.lambda_function_arn
}

module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"
  version = "4.0.2"

  function_name = "wos-poc-processor"
  description   = "Processes SQS messages"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  timeout       = 10

  source_path = "${path.module}/python3.8-app1"

  event_source_mapping = {
    sqs = {
      event_source_arn = aws_sqs_queue.queue.arn
      /*filter_criteria = {
        pattern = jsonencode({
          body = {
            orderQty : [{ numeric : ["<", 10] }]
          }
        })
      }*/
      //function_response_types = ["ReportBatchItemFailures"] // delete
    }
  }

  create_current_version_allowed_triggers = false
  allowed_triggers = {
    AllowExecutionFromSNS = {
      principal  = "sns.amazonaws.com"
      source_arn = local.sns_arn
    }
  }

  attach_policies    = true
  number_of_policies = 1
  policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
  ]

  tags = local.tags
}

resource "aws_sqs_queue" "queue" {
  name = "wos-poc-queue"

  visibility_timeout_seconds = 900

  kms_master_key_id                 = "alias/aws/sqs"
  kms_data_key_reuse_period_seconds = 900

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.deadletter_queue.arn,
    maxReceiveCount     = 1 // number of times to retry before to send to DLQ
  })

  tags = local.tags
}

resource "aws_sqs_queue_policy" "queue" {
  queue_url = aws_sqs_queue.queue.id
  policy    = data.aws_iam_policy_document.queue.json
}

data "aws_iam_policy_document" "queue" {
  statement {
    effect    = "Allow"
    resources = [aws_sqs_queue.queue.arn]
    #resources = ["*"]
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListQueueTags",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
    ]
  }
}

resource "aws_sqs_queue" "deadletter_queue" {
  name = "wos-poc-queue-dead-letter-queue"

  visibility_timeout_seconds = 900

  kms_master_key_id                 = "alias/aws/sqs"
  kms_data_key_reuse_period_seconds = 900

  tags = local.tags
}

resource "aws_sqs_queue_policy" "deadletter_queue" {
  queue_url = aws_sqs_queue.deadletter_queue.id
  policy    = data.aws_iam_policy_document.deadletter_queue.json
}

data "aws_iam_policy_document" "deadletter_queue" {
  statement {
    effect    = "Allow"
    resources = [aws_sqs_queue.deadletter_queue.arn]
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListQueueTags",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
    ]
  }
}

resource "aws_cloudwatch_metric_alarm" "deadletter_alarm" {
  alarm_name          = "${aws_sqs_queue.deadletter_queue.name}-not-empty-alarm"
  alarm_description   = "More than ${local.threshold} items are on the ${aws_sqs_queue.deadletter_queue.name} queue in the last 15 minutes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Average"
  threshold           = local.threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.sns_arn]
  ok_actions          = [local.sns_arn]
  tags                = tomap(local.tags)
  dimensions = {
    "QueueName" = aws_sqs_queue.deadletter_queue.name
  }
}
