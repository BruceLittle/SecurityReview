# Never write these values (or params with these keys, case-insensitively)
# to the Rails log, even in development. See also config.filter_parameters
# in config/application.rb.
Rails.application.config.filter_parameters += %i[
  passw email secret token _key crypt salt certificate
  otp ssn cvv cvc api_token signature access_key_id
  secret_access_key
]
