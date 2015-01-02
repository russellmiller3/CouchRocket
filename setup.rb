		require "sinatra"

# The code below will automatically require all the gems listed in our Gemfile,
# so we don't have to manually require gems a la
#
#   require 'data_mapper'
#   require 'dotenv'
#
# See: http://bundler.io/sinatra.html

require "rubygems"
require "bundler/setup"

# Bundler.require(...) requires all gems necessary regardless of
#   environment (:default) in addition to all environment-specific gems.
Bundler.require(:default, Sinatra::Application.environment)

# NOTE:
#   Sinatra::Application.environment is set to the value of ENV['RACK_ENV']
#   if RACK_ENV is set.  Otherwise, it defaults to :development.

# Load the .env file if it exists
if File.exist?(".env")
  Dotenv.load(".env")
end

set(:sessions, true)
set(:session_secret, ENV["SESSION_SECRET"])

# Notify user (and exit) if DATABASE_URL isn't set
unless ENV.key?("DATABASE_URL")
  puts "ENV['DATABASE_URL'] is undefined.  Make sure your .env file is correct."
  exit 1
end

# In development, the DATABASE_URL environment variable should be defined in
#   the '.env' file. In production, Heroku will set this environment variable
#   for you.
DataMapper.setup(:default, ENV["DATABASE_URL"])


# Display DataMapper debugging information in development
if Sinatra::Application.development?
  DataMapper::Logger.new($stdout, :debug)
end

#Twilio Setup
set :twilio_account_sid, ENV['TWILIO_ACCOUNT_SID']
set :twilio_auth_token, ENV['TWILIO_AUTH_TOKEN']
set :twilio_number, ENV['TWILIO_NUMBER']
twilio_client = Twilio::REST::Client.new settings.twilio_account_sid, settings.twilio_auth_token
twilio_number = settings.twilio_number

#MailGun Setup
set :mailgun_public_key, ENV['MAILGUN_PUBLIC_KEY']
set :mailgun_secret_key, ENV['MAILGUN_SECRET_KEY']
set :mail_domain, ENV['MAIL_DOMAIN']
$mg_client = Mailgun::Client.new(settings.mailgun_secret_key)

#Stripe Setup
set :stripe_public_key, ENV['STRIPE_PUBLIC_KEY']
set :stripe_secret_key, ENV['STRIPE_SECRET_KEY']
Stripe.api_key = settings.stripe_secret_key
$stripe_public_key = settings.stripe_public_key

set :partial_template_engine, :erb

configure :development do
  use BetterErrors::Middleware
  BetterErrors.application_root = File.expand_path('..', __FILE__)
end