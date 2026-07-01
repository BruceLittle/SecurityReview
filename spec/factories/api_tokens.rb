# ApiToken plaintext values only ever exist transiently (see ApiToken.generate!),
# so specs use the ApiTokenHelper below (spec/support/api_token_helper.rb)
# rather than a FactoryBot factory, to guarantee they exercise the exact
# same generation path production code does.
