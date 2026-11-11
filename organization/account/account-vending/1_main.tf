# 08-aws-account-vending/1_main.tf
# Creates AWS Accounts and enrolls them into Control Tower v4.0 without Service Catalog

data "aws_caller_identity" "current" {}

# Step 1: Create a new account in Organizations and place it in the specified OU
resource "aws_organizations_account" "this" {
  for_each = var.accounts

  name      = each.value.name
  email     = each.value.email
  role_name = "OrganizationAccountAccessRole"
  parent_id = each.value.ou_id

  tags = merge(
    {
      Name        = each.value.name
      Environment = each.value.environment
      ManagedBy   = "terraform"
    },
    each.value.tags
  )

  lifecycle {
    prevent_destroy = true
    # CT may move the account during enrollment — ignore to avoid false drift
    ignore_changes = [parent_id]
  }
}

# Step 2: Enroll account into Control Tower.
# CT's baseline APIs do NOT accept account targets (verified live:
# "does not support a target AWS Organizations ARN with resource of type
# account"), and `aws controltower enroll-account` never existed. The
# supported programmatic path is ResetEnabledBaseline on the account's OU —
# the API equivalent of the console's "Re-register OU", which baselines any
# unenrolled account inside (existing enrolled accounts are re-applied,
# which is the documented, non-destructive behavior).
# Prerequisites handled by the CALLER: the AWSControlTowerExecution role in
# the target account, and the account's home region opted in.
# Resume-safe: if the OU baseline is already UNDER_CHANGE (e.g. a previous
# run was interrupted), it waits on the running operation instead of firing
# a conflicting reset.
data "aws_organizations_organization" "this" {}

resource "null_resource" "enroll_control_tower" {
  for_each = var.enable_control_tower_enrollment ? var.accounts : {}

  triggers = {
    account_id = aws_organizations_account.this[each.key].id
  }

  provisioner "local-exec" {
    interpreter = ["powershell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = "Stop"
      $ouArn = "arn:aws:organizations::${data.aws_caller_identity.current.account_id}:ou/${data.aws_organizations_organization.this.id}/${each.value.ou_id}"
      Write-Host "Enrolling ${aws_organizations_account.this[each.key].id} by re-registering its OU (${each.value.ou_id})..."
      $eb = aws controltower list-enabled-baselines --region ${var.ct_home_region} --filter "targetIdentifiers=$ouArn" --query 'enabledBaselines[0].[arn,statusSummary.status]' --output text
      $ebArn, $ebStatus = $eb -split "`t"
      if (-not $ebArn -or $ebArn -eq "None") { throw "OU ${each.value.ou_id} has no enabled AWSControlTowerBaseline (OU not registered with CT)" }
      if ($ebStatus -eq "UNDER_CHANGE") {
        Write-Host "OU baseline already UNDER_CHANGE - waiting for the in-flight operation instead of resetting"
      } else {
        $op = aws controltower reset-enabled-baseline --region ${var.ct_home_region} --enabled-baseline-identifier $ebArn --query operationIdentifier --output text
        if (-not $op) { throw "reset-enabled-baseline did not return an operation id" }
        Write-Host "Operation $op started - waiting (typically 15-30 minutes)..."
      }
      $status = "UNDER_CHANGE"
      while ($status -eq "UNDER_CHANGE" -or $status -eq "IN_PROGRESS") {
        Start-Sleep -Seconds 60
        $status = aws controltower list-enabled-baselines --region ${var.ct_home_region} --filter "targetIdentifiers=$ouArn" --query 'enabledBaselines[0].statusSummary.status' --output text
        Write-Host "  OU baseline status: $status"
      }
      if ($status -ne "SUCCEEDED") { throw "Enrollment ended with OU baseline status $status" }
      Write-Host "Enrollment complete for account ${aws_organizations_account.this[each.key].id}"
    EOT
  }

  depends_on = [aws_organizations_account.this]
}

# Step 3: Apply CT Guardrails on OUs (optional)
resource "aws_controltower_control" "this" {
  for_each = {
    for pair in flatten([
      for ou_key, ou_val in var.ou_controls : [
        for control_arn in ou_val.control_arns : {
          key         = "${ou_key}-${control_arn}"
          ou_arn      = ou_val.ou_arn
          control_arn = control_arn
        }
      ]
    ]) : pair.key => pair
  }

  control_identifier = each.value.control_arn
  target_identifier  = each.value.ou_arn

  depends_on = [null_resource.enroll_control_tower]
}
