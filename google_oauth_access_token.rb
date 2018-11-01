require 'google/api_client/client_secrets'
require 'sinatra'
require 'logger'

enable :sessions

def logger
  settings.logger
end

def client_secrets
  settings.client_secrets
end

def authorization
  settings.authorization
end

configure do
  logger = Logger.new(STDOUT)
  logger.level = Logger::DEBUG

  secrets = Google::APIClient::ClientSecrets.load
  authorization = secrets.to_authorization
  authorization.scope = 'https://www.googleapis.com/auth/youtube'
  authorization.additional_parameters = {'access_type': 'offline'}

  auth_token_initialized = false

  set :client_secrets, secrets
  set :authorization, authorization
  set :logger, logger
  set :auth_token_initialized, auth_token_initialized
end

before do
  if not settings.auth_token_initialized
    auth_token_initialized = true

    authorization.redirect_uri = to('/oauth2callback')
    authorization.update_token!(session)
  end

  if not authorization.access_token and not request.path_info =~ /^\/oauth2/
    redirect to('/oauth2authorize')
  end
end

get '/oauth2authorize' do
  # Request authorization
  redirect authorization.authorization_uri.to_s, 303
end

get '/oauth2callback' do
  authorization.code = params[:code] if params[:code]
  r = authorization.fetch_access_token!

  redirect to('/'), 303
end

get '/' do
  data = MultiJson.dump({
                            'installed': ({
                                'client_id': authorization.client_id,
                                'client_secret': authorization.client_secret,
                                'redirect_uris': client_secrets.redirect_uris,
                                'auth_uri': client_secrets.authorization_uri,
                                'token_uri': client_secrets.token_credential_uri,
                                'access_token': authorization.access_token,
                                'refresh_token': authorization.refresh_token,
                                'id_token': authorization.id_token,
                                'expires_in': authorization.expires_in,
                                'expires_at': authorization.expires_at.to_i,
                                'issued_at': authorization.issued_at.to_i
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
