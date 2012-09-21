require "uservoice/version"
require 'rubygems'
require 'ezcrypto'
require 'json'
require 'cgi'
require 'base64'
require 'oauth'

module UserVoice
  EMAIL_FORMAT = %r{^(\w[-+.\w!\#\$%&'\*\+\-/=\?\^_`\{\|\}~]*@([-\w]*\.)+[a-zA-Z]{2,9})$}
  DEFAULT_HEADERS = { 'Content-Type'=> 'application/json', 'Accept'=> 'application/json' }

  class APIError < RuntimeError
  end
  Unauthorized = Class.new(APIError)
  NotFound = Class.new(APIError)
  ApplicationError = Class.new(APIError)
 
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

    def initialize(*args)
      case args.size
      when 3,4
        init_subdomain_and_api_keys(*args)
      when 1,2
        init_consumer_and_access_token(*args)
      end
    end

    def init_subdomain_and_api_keys(subdomain_name, api_key, api_secret, attrs={})
      consumer = OAuth::Consumer.new(api_key, api_secret, { 
        :site => "#{attrs[:protocol] || 'https'}://#{subdomain_name}.#{attrs[:uservoice_domain] || 'uservoice.com'}"
      })
      init_consumer_and_access_token(consumer, attrs)
    end

    def init_consumer_and_access_token(consumer, attrs={})
      @consumer = consumer
      @token = OAuth::AccessToken.new(@consumer, attrs[:oauth_token] || '', attrs[:oauth_token_secret] || '')
      @response_format = attrs[:response_format] || :hash
      @callback = attrs[:callback]
    end

    def authorize_url
      request_token.authorize_url
    end

    def login_with_verifier(oauth_verifier)
      token = @request_token.get_access_token(:oauth_verifier => oauth_verifier)
      Client.new(@consumer, :oauth_token => token.token, :oauth_token_secret => token.secret)
    end

    def login_with_access_token(oauth_token, oauth_token_secret, &block)
      token = Client.new(@consumer, :oauth_token => oauth_token, :oauth_token_secret => oauth_token_secret)
      if block_given?
        yield token
      else
        return token
      end
    end

    def token
      @token.token
    end

    def secret
      @token.secret
    end

    def request_token
      @request_token = @consumer.get_request_token(:oauth_callback => @callback)
    end

    def login_as_owner(&block)
      token = post('/api/v1/users/login_as_owner.json', {
        'request_token' => request_token.token
      })['token']
      if token
        login_with_access_token(token['oauth_token'], token['oauth_token_secret'], &block)
      else
        raise Unauthorized.new("Could not get Access Token")
      end
    end

    def login_as(email, &block)
      unless email.to_s.match(EMAIL_FORMAT)
        raise Unauthorized.new("'#{email}' is not a valid email address")
      end
      token = post('/api/v1/users/login_as.json', {
        :user => { :email => email },
        :request_token => request_token.token
      })['token']

      if token
        login_with_access_token(token['oauth_token'], token['oauth_token_secret'], &block)
      else
        raise Unauthorized.new("Could not get Access Token")
      end
    end

    def request(method, uri, request_body={}, headers={})
      headers = DEFAULT_HEADERS.merge(headers)

      if headers['Content-Type'] == 'application/json' && request_body.is_a?(Hash)
        request_body = request_body.to_json
      end

      response = case method.to_sym
                 when :post, :put
                   @token.request(method, uri, request_body, headers)
                 when :head, :delete, :get
                   @token.request(method, uri, headers)
                 else
                   raise RuntimeError.new("Invalid HTTP method #{method}")
                 end

      return case @response_format.to_s
             when 'raw'
               response
             else
               attrs = JSON.parse(response.body)
               if attrs && attrs['errors']
                 case attrs['errors']['type']
                 when 'unauthorized'
                   raise Unauthorized.new(attrs)
                 when 'record_not_found'
                   raise NotFound.new(attrs)
                 when 'application_error'
                   raise ApplicationError.new(attrs)
                 else
                   raise APIError.new(attrs)
                 end
               end
               attrs
             end
    end

    %w(get post delete put).each do |method|
      define_method(method) do |*args|
        request(method, *args)
      end
    end
  end
end
