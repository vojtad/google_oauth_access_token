require 'google/api_client/client_secrets'
require 'sinatra'
require 'logger'

enable :sessions

def logger
  settings.logger
end

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

def client_secrets
  settings.client_secrets
end

configure do
  logger = Logger.new(STDOUT)
  logger.level = Logger::DEBUG

  secrets = Google::APIClient::ClientSecrets.load
  authorization = secrets.to_authorization
  authorization.scope = 'https://www.googleapis.com/auth/youtube.upload'

  set :client_secrets, secrets
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
  data = MultiJson.dump({
                            'installed': ({
                                'client_id': user_credentials.client_id,
                                'client_secret': user_credentials.client_secret,
                                'redirect_uris': client_secrets.redirect_uris,
                                'auth_uri': client_secrets.authorization_uri,
                                'token_uri': client_secrets.token_credential_uri,
                                'access_token': user_credentials.access_token,
                                'refresh_token': user_credentials.refresh_token,
                                'id_token': user_credentials.id_token,
                                'expires_in': user_credentials.expires_in,
                                'expires_at': user_credentials.expires_at.to_i,
                                'issued_at': user_credentials.issued_at.to_i
                            }).inject({}) do |accu, (k, v)|
                              # Prunes empty values from JSON output.
                              unless v == nil || (v.respond_to?(:empty?) && v.empty?)
                                accu[k] = v
                              end
                              accu
                            end
                        })

  [200, {'Content-Type' => 'text/plain'}, data]
end
