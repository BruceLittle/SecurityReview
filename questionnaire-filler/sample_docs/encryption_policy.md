# Data Encryption Policy

All customer data at rest is encrypted using AES-256. Encryption keys are managed
through a dedicated key management service (KMS) with automatic annual rotation.

Data in transit is encrypted using TLS 1.2 or higher for all external connections.
Internal service-to-service traffic within our production VPC is also encrypted
using mutual TLS.

Database backups are encrypted with the same AES-256 standard and are retained
for 35 days before secure deletion.
