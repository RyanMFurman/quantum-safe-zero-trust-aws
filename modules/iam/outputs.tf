output "pca_admin_role_arn" {
    value = aws_iam_role.pca_admin.arn 
}

output "pqc_keygen_role_arn" {
  value = aws_iam_role.pqc_keygen.arn
}
