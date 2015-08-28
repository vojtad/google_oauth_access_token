require 'google/api_client'
require 'google/api_client/client_secrets'
require 'sinatra'
require 'logger'
require 'json'

enable :sessions

def logger; settings.logger end

def calendar; settings.calendar; end

def user_credentials
  # Build a per-request oauth credential based on token stored in session
  # which allows us to use a shared API client.
  @authorization ||= (
    auth = settings.authorization.dup
    auth.redirect_uri = to('/oauth2callback')
    auth.update_token!(session)
    auth
  )
end

configure do
  logger = Logger.new(STDOUT)
  logger.level = Logger::DEBUG

  client = Google::APIClient.new(application_name: 'SlidesLive', application_version: '1.0')
  youtube = client.discovered_api('youtube', 'v3')

  client_secrets = Google::APIClient::ClientSecrets.load
  authorization = client_secrets.to_authorization
  authorization.scope = 'https://www.googleapis.com/auth/youtube.upload'

  set :authorization, authorization
  set :logger, logger
end

before do
  unless user_credentials.access_token || request.path_info =~ /^\/oauth2/
    redirect to('/oauth2authorize')
  end
end

get '/oauth2authorize' do
  # Request authorization
  redirect user_credentials.authorization_uri.to_s, 303
end

get '/oauth2callback' do
  user_credentials.code = params[:code] if params[:code]
  user_credentials.fetch_access_token!
end

get '/' do
  [200, {'Content-Type' => 'text/plain'}, {access_token: user_credentials.access_token, refresh_token: user_credentials.refresh_token, expires_in: user_credentials.expires_in, issued_at: user_credentials.issued_at}.to_json]
end
