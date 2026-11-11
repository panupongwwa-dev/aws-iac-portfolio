resource "aws_organizations_organizational_unit" "this" {
  for_each = var.organizational_units

  name = each.value.name
  parent_id = (
    each.value.parent_key != null
    ? aws_organizations_organizational_unit.this[each.value.parent_key].id
    : each.value.parent_id
  )

  tags = merge(
    { ManagedBy = "terraform" },
    var.default_tags,
    each.value.tags
  )
}
