resource "aws_s3_bucket" "gos_repro_reports" {
  bucket        = "gos-reproducibility-reports"
  provider      = aws
  force_destroy = false

}

resource "aws_s3_bucket_ownership_controls" "gos_repro_reports" {
  bucket = aws_s3_bucket.gos_repro_reports.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "gos_repro_reports" {
  bucket = aws_s3_bucket.gos_repro_reports.id

  block_public_acls  = false
  ignore_public_acls = false
}

resource "aws_s3_bucket_acl" "gos_repro_reports" {
  depends_on = [aws_s3_bucket_ownership_controls.gos_repro_reports]

  bucket = aws_s3_bucket.gos_repro_reports.id
  acl    = "private"
}
