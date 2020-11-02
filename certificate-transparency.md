---
title: Provose and Certificate Transparency
nav_exclude: true

---
# Provose and Certificate Transparency

If you are going to use Provose, there are a few things you should know about Certificate Transparency.

# What is Certificate Transparency?

[Certificate Transparency](https://www.certificate-transparency.org/) is an Internet security standard at protecting the chain of trust for digital certificates used on the Internet. Digital certificates are used to prevent communications on the Internet from eavesdropping or tampering in-transit. These certificates are issued by organizations called Certificate Authorities (CAs), who must be trusted to issue certificates that contain accurate information.

Malicious actors, such as individual hackers or national governments, often target Certificate Authorities with the goal of issuing fraudulent certificates that can be used to impersonate a website. When they succeed, it is very difficult to detect and revoke these fraudulent certificates. Certificate Transparency aims to make detecting fraudulent certificates by creating a public log to record certificates issued by publicly trusted Certificate Authorities.

# How does Provose interact with Certificate Transparency?

Provose creates multiple certificates--for securing communciations both within private networks and across the Internet. All of these certificates are published to Certificate Transparency.

Every time you create a Provose module with the `module` keyword, Provose creates a new Virtual Private Cloud (VPC) and an Amazon Certificate Manager (ACM) certificate to protect communications within the VPC. In order for this certificate to automatically be trusted by web browsers like Google Chrome, Amazon publishes the certificate's metadata to the Certificate Transparency log. It is possible to disable this publishing, but then web browsers would throw an error when visiting a webpage secured by this certificate.

This means that if your `internal_root_domain` is set to `"example-internal.com"` and your `internal_subdomain` is set to `"myproject"`, then anybody in the world can see that Amazon issued a wildcard certificate for `"*.myproject.example-internal.com"`. Provose provisions an internal HTTPS Application Load Balancer (ALB) that uses this wildcard certificate. If you have an Elasticsearch instance located at `"elasticsearch.myproject.example-internal.com"`, Provose will serve traffic from the already-created wildcard certificate, so Certificate Transparency will not log the *full* DNS name of these services.

However, if you use Provose to deploy containers serving HTTP requests--whether they come from within the VPC or from the public Internet--then Provose will provision another ACM certificate with the exact DNS name for your service--**not** a wildcard certificate. This means that if you deployed a container that serves traffic at `"container.example-internal.com"` or `"container.example.com"`, Amazon will log the full DNS name to the public Certificate Transparency logs. In the future, Provose might reissue this certificate as a wildcard of `"*.example.com"` in an effort to leak less information to Certificate Transparency. However, this will only benefit DNS names that were created *after* this change was made. Additionally, it is only possible to protect only one subdomain level with a wildcard certificate. If you are serving traffic at `"long.dns.name.example.com"`, the wildcard certificate logged to Certificate Transparency would be `"*.dns.name.example.com"`.

And remember--the Certificate Transparency log is *forever*. If Provose issues a certificate, and the certificate later expires or is deleted, the Certificate Transparency log will still have recorded the certificate's existence. Do not issue certificates with DNS names that are embarrassing, must be kept secret, or reveal information about your infrastructure that you do not want to give away.

# How can I check the Certificate Transparency logs for my certificates?

Certificate Transparency logs are public, and there are various online tools like [crt.sh](https://crt.sh/). You can enter the various root domain names that you own, and it will return any certificates containing that root domain name--including certificates you may have generated with software other than Provose.

# Will Provose add a feature that would disable logging to Certificate Transparency?

No. It is still possible to use certificates to keep your infrastructure secure without having the certificates' metadata published to the rest of the world, but it is far less confusing for Provose to log every certificate it creates.
