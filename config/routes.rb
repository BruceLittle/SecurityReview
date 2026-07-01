require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  # Unauthenticated liveness probe only — no app/DB state is exposed.
  get "/healthz", to: proc { [200, {}, ["ok"]] }

  devise_for :users, skip: [:registrations] # admin/org users are provisioned by an admin, not self-registered

  # defaults: { format: :json } — this surface is JSON-only regardless of
  # the request's Accept header; it never falls back to rendering an HTML
  # error page (avoids content-type inconsistency on error responses).
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      # Customer-facing JSON API, authenticated via X-API-Token (see
      # Api::V1::BaseController / ApiTokenAuthenticatable). Every resource
      # below is scoped to the organization the token belongs to.
      resources :missions, only: %i[index show] do
        resources :inspections, only: %i[index show]
      end
      resources :inspections, only: [:show]
      resources :assets, only: [:show] do
        # Requests a short-lived presigned PUT URL and creates the pending
        # Attachment row; the client uploads bytes straight to S3, never
        # through this app's request/response cycle.
        resources :attachments, only: [:create]
      end
      resources :attachments, only: [:show] do
        member do
          get :download # generates a short-lived S3 presigned URL, never a direct redirect to S3
        end
      end

      # Inbound webhook from the third-party scanning/processing vendor.
      # Verified via HMAC signature, not org-token auth (see WebhooksController).
      post "webhooks/scan_results", to: "webhooks#scan_results"
    end
  end

  # Internal administrative console. Session-authenticated only (Devise),
  # never reachable via X-API-Token, and gated by Admin::BaseController's
  # require_admin! before_action. Not intended for customer/client use.
  namespace :admin do
    resources :organizations, only: %i[index show]
    resources :users, only: %i[index show new create edit update destroy]
    resources :api_tokens, only: %i[index new create destroy]
    resources :audit_logs, only: %i[index show]

    root to: "organizations#index"
  end

  authenticate :user, ->(u) { u.platform_admin? } do
    mount Sidekiq::Web => "/admin/sidekiq"
  end

  root to: redirect("/admin")
end
