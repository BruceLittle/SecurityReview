class ApplicationJob < ActiveJob::Base
  # Every job below has a bounded, idempotent retry policy — never an
  # unbounded loop that could be used to amplify load against S3, the
  # vendor scanner, or a customer's webhook endpoint.
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError
end
