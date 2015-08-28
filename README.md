Tool to get Google OAuth 2 Access Token. Save your client secrets to client_secrets.json file and update authorization.scope in the source file as needed.

Run with `ruby google_oauth_access_token.rb` and then go to http://localhost:4567/ in your browser.

You can save the output to the environment variable, e.g. CLIENT_SECRETS and use it like this:
```
client = Google::APIClient.new(application_name: 'SlidesLive', application_version: '1.0')

credentials = Google::APIClient::ClientSecrets.new(MultiJson.load(ENV['CLIENT_SECRETS']))
authorization = credentials.to_authorization
authorization.scope = 'https://www.googleapis.com/auth/youtube.upload'

authorization.fetch_access_token!

client.authorization = authorization
```
