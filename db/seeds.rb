# Local development bootstrap only. Never run against staging/production —
# it creates a known-password platform admin.
raise "db/seeds.rb is for local development only; refusing to run in production" if Rails.env.production?

admin = User.find_or_create_by!(email: "admin@example.com") do |u|
  u.password = "change-me-immediately"
  u.platform_admin = true
end

org = Organization.find_or_create_by!(slug: "acme") do |o|
  o.name = "Acme Inspections"
end

User.find_or_create_by!(email: "org-admin@acme.example.com") do |u|
  u.password = "change-me-immediately"
  u.organization = org
  u.role = "org_admin"
end

mission = Mission.find_or_create_by!(organization: org, name: "Rooftop survey — 123 Main St")
inspection = Inspection.find_or_create_by!(mission: mission, status: "in_progress")
Asset.find_or_create_by!(inspection: inspection, asset_type: "roof", identifier: "roof-north-face")

puts "Seeded platform admin: admin@example.com / change-me-immediately"
puts "Seeded org admin:      org-admin@acme.example.com / change-me-immediately (org: #{org.slug})"
puts "Created by: #{admin.email}"
