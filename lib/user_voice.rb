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
    unless sso_key.to_s.length > 1
      raise Unauthorized.new("Please specify your SSO key")
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
      @consumer = OAuth::Consumer.new(api_key, api_secret, { 
        :site => "#{attrs[:protocol] || 'https'}://#{@subdomain_name}.#{attrs[:uservoice_domain] || 'uservoice.com'}"
      })
      @consumer_token = OAuth::AccessToken.new(@consumer)
      @access_tokens = []
      push_access_token(attrs[:access_token]) if attrs[:access_token]
    end

    def request_token
      @request_token ||= @consumer.get_request_token(:oauth_callback => @callback)
    end

    def authorize_url
      request_token.authorize_url
    end

    def push_access_token(attrs)
      access_token = OAuth::AccessToken.new(@consumer)
      access_token.token = attrs[:oauth_token] || attrs['oauth_token']
      access_token.secret = attrs[:oauth_token_secret] || attrs['oauth_token_secret']
      @access_tokens.push(access_token)
    end

    def to_access_token_hash
      {
       :oauth_token => @access_tokens.last.token,
       :oauth_token_secret => @access_tokens.last.secret
      } if @access_tokens.last
    end


    def pop_access_token
      @access_tokens.pop
    end

    alias logout pop_access_token

    def login_as_owner
      authorize_response = JSON.parse(post('/api/v1/users/login_as_owner.json', {
        'request_token' => request_token.token
      }).body)
      if authorize_response['token']
        push_access_token(authorize_response['token'])
        if block_given?
          yield
          pop_access_token
        end
      else
        raise Unauthorized.new("Could not get Access Token: #{authorize_response}")
      end
    end

    def login_as(email)
      unless email.to_s.match(EMAIL_FORMAT)
        raise Unauthorized.new("'#{email}' is not a valid email address")
      end
      authorize_response = JSON.parse(post('/api/v1/users/login_as.json', {
        'user[email]' => email,
        'request_token' => request_token.token
      }).body)
      if authorize_response['token']
        push_access_token(authorize_response['token'])
        if block_given?
          yield
          pop_access_token
        end
      else
        raise Unauthorized.new("Could not get Access Token: #{authorize_response}")
      end
    end

    def request(*args)
      (@access_tokens.last || @consumer_token).request(*args)
    end

    %w(get post delete put).each do |method|
      define_method(method) do |*args|
        request(method, *args)
      end
    end
  end
end
