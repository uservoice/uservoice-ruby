require "uservoice/version"
require 'rubygems'
require 'ezcrypto'
require 'json'
require 'cgi'
require 'base64'
require 'oauth'

module UserVoice
  class Unauthorized < RuntimeError; end
 
  def self.generate_sso_token(subdomain_key, sso_key, user_hash, valid_for = 5 * 60)
    user_hash[:expires] ||= (Time.now.utc + valid_for).to_s unless valid_for.nil?

    key = EzCrypto::Key.with_password(subdomain_key, sso_key)
    encrypted = key.encrypt(user_hash.to_json)
    encoded = Base64.encode64(encrypted).gsub(/\n/,'')

    return CGI.escape(encoded)
  end

  class Client
    def initialize(subdomain_name, api_key, api_secret, attrs={})
      api_url = "https://#{subdomain_name}.uservoice.com"
      @callback = attrs[:callback]
      if attrs[:access_token]
        @access_token = OAuth::AccessToken.new(self)
        @access_token.token = attrs[:access_token][:oauth_token]
        @access_token.secret = attrs[:access_token][:oauth_secret]
      end
      @consumer = OAuth::Consumer.new(api_key, api_secret, :site => api_url)
    end

    def request_token
      @request_token ||= @consumer.get_request_token(:oauth_callback => @callback)
    end

    def login_with_sso_token(sso_token)
      access_token = OAuth::AccessToken.new(@consumer)

      authorize_response = JSON.parse(access_token.post('/api/v1/oauth/authorize.json', {
        :scheme => 'aes_cbc_128',
        :sso => sso_token,
        :request_token => request_token.token
      }).body)
      if authorize_response['token']
        access_token.token = authorize_response['token']['oauth_token']
        access_token.secret = authorize_response['token']['oauth_token_secret']
        @access_token = access_token
      else
        raise Unauthorized.new("Could not get Access Token: #{authorize_response}")
      end
    end
    def request(*args)
      (@access_token || @consumer).request(*args)
    end
  end
end
