require "uservoice/version"
require 'rubygems'
require 'ezcrypto'
require 'json'
require 'cgi'
require 'base64'
require 'oauth'

module UserVoice
  EMAIL_FORMAT = %r{^(\w[-+.\w!\#\$%&'\*\+\-/=\?\^_`\{\|\}~]*@([-\w]*\.)+[a-zA-Z]{2,9})$}

  class Unauthorized < RuntimeError; end
 
  def self.generate_sso_token(subdomain_key, sso_key, user_hash, valid_for = 5 * 60)
    user_hash[:expires] ||= (Time.now.utc + valid_for).to_s unless valid_for.nil?
    unless user_hash[:email].to_s.match(EMAIL_FORMAT)
      raise Unauthorized.new("'#{user_hash[:email]}' is not a valid email address")
    end

    key = EzCrypto::Key.with_password(subdomain_key, sso_key)
    encrypted = key.encrypt(user_hash.to_json)
    encoded = Base64.encode64(encrypted).gsub(/\n/,'')

    return CGI.escape(encoded)
  end

  class Client
    def initialize(subdomain_name, api_key, api_secret, attrs={})
      @subdomain_name = subdomain_name
      @callback = attrs[:callback]
      @sso_key = attrs[:sso_key]
      @consumer = OAuth::Consumer.new(api_key, api_secret, { 
        :site => "https://#{@subdomain_name}.uservoice.com"
      })
      if attrs[:access_token]
        @access_token = OAuth::AccessToken.new(@consumer)
        @access_token.token = attrs[:access_token][:oauth_token]
        @access_token.secret = attrs[:access_token][:oauth_secret]
      end
    end

    def request_token
      @request_token ||= @consumer.get_request_token(:oauth_callback => @callback)
    end

    def authorize_url
      request_token.authorize_url
    end

    def get_access_token(*args)
      @access_token = request_token.get_access_token(*args)
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

    def login_as(email)
      raise Unauthorized.new('SSO key not specified') unless @sso_key
      login_with_sso_token(UserVoice.generate_sso_token(@subdomain_name, @sso_key, {
        :email => email
      }))
    end

    def request(*args)
      (@access_token || @consumer).request(*args)
    end

    %w(get post delete put).each do |method|
      define_method(method) do |*args|
        request(method, *args)
      end
    end
  end
end
