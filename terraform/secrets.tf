resource "random_password" "sql_sa_password" {
  length           = 20
  special          = true
  override_special = "!@#%^_+-"
}
