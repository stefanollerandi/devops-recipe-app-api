resource "aws_route53_zone" "zone" {
  name = var.dns_zone_name
}

resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = "${lookup(var.subdomain, terraform.workspace)}.${aws_route53_zone.zone.name}"
  type    = "CNAME"
  ttl     = "300"

  records = [aws_lb.api.dns_name]
}

resource "aws_acm_certificate" "cert" {
  domain_name       = aws_route53_record.app.name
  validation_method = "EMAIL"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = toset(aws_acm_certificate.cert.domain_validation_options[*].domain_name)

  allow_overwrite = true
  name            = aws_acm_certificate.cert.domain_validation_options[each.key].resource_record_name
  records         = [aws_acm_certificate.cert.domain_validation_options[each.key].resource_record_value]
  ttl             = 60
  type            = aws_acm_certificate.cert.domain_validation_options[each.key].resource_record_type
  zone_id         = aws_route53_zone.zone.zone_id

  depends_on = [aws_acm_certificate.cert]
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
