#!/usr/bin/env ruby
# Fill TestFlight "Test Information" (en-US + vi descriptions, feedback email, URLs) and the beta review contact.
# Usage: bundle exec ruby scripts/asc/testflight_info.rb <asc_app_id>
# Credentials and contact details come from ./.env (ASC_*, APP_REVIEW_*); nothing secret is printed.
require "base64"
require "faraday"
require "json"
require "spaceship"

app_id = ARGV[0] or abort "usage: #{$PROGRAM_NAME} <asc_app_id>"
root = File.expand_path("../..", __dir__)
env = File.read(File.join(root, ".env")).scan(/^([A-Z][A-Z0-9_]*)=(.*)$/).to_h.transform_values { |v| v.delete('"') }
token = Spaceship::ConnectAPI::Token.create(
  key_id: env.fetch("ASC_KEY_ID"), issuer_id: env.fetch("ASC_ISSUER_ID"),
  key: Base64.decode64(env.fetch("ASC_KEY_CONTENT_BASE64"))
)

API = "https://api.appstoreconnect.apple.com"
conn = Faraday.new(API)
def call(conn, token, verb, path, body = nil)
  res = conn.run_request(verb, path, body && JSON.generate(body), "Authorization" => "Bearer #{token.text}", "Content-Type" => "application/json")
  [res.status, res.body.to_s.empty? ? {} : JSON.parse(res.body)]
end

site = "https://apps-site-six.vercel.app/apps/roll36"
texts = {
  "en-US" => "ROLL 36 is an analog film camera: you shoot a finite roll of 36 frames, frames stay hidden until you develop the roll and wait. Test the viewfinder, the Darkroom (developing takes about an hour), the film Library and importing a photo.",
  "vi" => "ROLL 36 là máy ảnh film analog: mỗi cuộn chỉ có 36 tấm, ảnh bị giấu cho đến khi bạn tráng cuộn và chờ. Hãy thử viewfinder, Darkroom (tráng mất khoảng một giờ), thư viện film và nhập ảnh."
}

_, existing = call(conn, token, :get, "/v1/apps/#{app_id}/betaAppLocalizations?limit=50")
by_locale = (existing["data"] || []).to_h { |l| [l.dig("attributes", "locale"), l["id"]] }
texts.each do |locale, description|
  attrs = { locale: locale, description: description, feedbackEmail: env.fetch("APP_REVIEW_EMAIL"),
            marketingUrl: site, privacyPolicyUrl: "#{site}/privacy" }
  if by_locale[locale]
    status, = call(conn, token, :patch, "/v1/betaAppLocalizations/#{by_locale[locale]}",
                   { data: { type: "betaAppLocalizations", id: by_locale[locale], attributes: attrs.reject { |k, _| k == :locale } } })
  else
    status, = call(conn, token, :post, "/v1/betaAppLocalizations",
                   { data: { type: "betaAppLocalizations", attributes: attrs,
                             relationships: { app: { data: { type: "apps", id: app_id } } } } })
  end
  puts "#{locale}: #{status}"
end

_, detail = call(conn, token, :get, "/v1/apps/#{app_id}/betaAppReviewDetail")
detail_id = detail.dig("data", "id")
status, = call(conn, token, :patch, "/v1/betaAppReviewDetails/#{detail_id}", {
  data: { type: "betaAppReviewDetails", id: detail_id, attributes: {
    contactFirstName: env.fetch("APP_REVIEW_FIRST_NAME"), contactLastName: env.fetch("APP_REVIEW_LAST_NAME"),
    contactPhone: env.fetch("APP_REVIEW_PHONE"), contactEmail: env.fetch("APP_REVIEW_EMAIL"),
    demoAccountRequired: false, notes: "No login required. Developing a roll takes about 60 minutes by design."
  } }
})
puts "review detail: #{status}"
