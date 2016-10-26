module UserVoice
  class Client

    def initialize(*args)
      case args.size
      when 1,2
        if args[1].is_a?(String)
          init_subdomain_and_api_keys(args[0], args[1])
        else
          init_consumer_and_access_token(*args)
        end
      when 3
        if args[2].is_a?(String)
          init_subdomain_and_api_keys(args[0], args[1], args[2])
        else
          init_subdomain_and_api_keys(args[0], args[1], nil, args[2])
        end
      when 4
        init_subdomain_and_api_keys(*args)
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
      raise Unauthorized.new('Call request token first') if @request_token.nil?
      token = @request_token.get_access_token({:oauth_verifier => oauth_verifier}, {}, DEFAULT_HEADERS)
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
      @request_token = @consumer.get_request_token({:oauth_callback => @callback}, {}, DEFAULT_HEADERS)
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

    def curl(method, uri, request_body={}, headers={})
      headers = DEFAULT_HEADERS.merge(headers)

      if headers['Content-Type'] == 'application/json' && request_body.is_a?(Hash)
        request_body = request_body.to_json
      end

      # TODO: Add the oauth token header
      lines = [
        "curl #{@token.consumer.uri}#{uri}",
        *headers.map {|k, v| "-H #{k}: #{v}" }
      ]
      request_body.empty? || lines << "--data '#{request_body}'"
      puts lines.join(" \\\n  ")
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

    def get_collection(uri, opts={})
      UserVoice::Collection.new(self, uri, opts)
    end
  end
end
