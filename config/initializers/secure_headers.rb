SecureHeaders::Configuration.default do |config|
  config.cookies = {
    secure: true,     # never sent over plain HTTP
    httponly: true,   # inaccessible to JS — mitigates session theft via XSS
    samesite: { lax: true }
  }

  config.x_frame_options = "DENY" # the admin console is never framed/embedded
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "0" # deprecated/unreliable in modern browsers; CSP is the real control below
  config.x_download_options = "noopen"
  config.x_permitted_cross_domain_policies = "none"
  config.referrer_policy = %w[strict-origin-when-cross-origin]

  # Values are literal CSP source tokens, quotes included — not a Ruby
  # array of unquoted words, so %w[] (which would strip them) isn't used.
  config.csp = {
    default_src: ["'none'"],
    script_src: ["'self'"],
    style_src: ["'self'"],
    connect_src: ["'self'"],
    img_src: ["'self'"],
    form_action: ["'self'"],
    frame_ancestors: ["'none'"],
    base_uri: ["'self'"],
    object_src: ["'none'"],
    upgrade_insecure_requests: true
  }
end

# The JSON API returns no HTML/JS at all, but is given the same strict
# baseline for defense-in-depth (e.g. a browser preview of an error page).
SecureHeaders::Configuration.override(:api) do |config|
  config.csp = SecureHeaders::OPT_OUT
end
