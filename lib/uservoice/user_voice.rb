require "uservoice/version"
require 'uservoice/collection'
require 'uservoice/client'
require 'rubygems'
require 'ezcrypto'
require 'json'
require 'cgi'
require 'base64'
require 'oauth'

module UserVoice
  EMAIL_FORMAT = %r{^([-+.\w][-+.\w!\#\$%&'\*\+\-/=\?\^_`\{\|\}~]*@([-\w]+\.)+[a-zA-Z]{2,32})$}
  DEFAULT_HEADERS = { 'Content-Type'=> 'application/json', 'Accept'=> 'application/json', 'API-Client' => "uservoice-ruby-#{UserVoice::VERSION}" }

  class APIError < RuntimeError
  end
  Unauthorized = Class.new(APIError)
  NotFound = Class.new(APIError)
  ApplicationError = Class.new(APIError)
 
  def self.generate_sso_token(subdomain_key, sso_key, user_hash, valid_for = 5 * 60)
    expiration_key = user_hash['expires'].nil? ? :expires : 'expires'
    user_hash[expiration_key] ||= (Time.now.utc + valid_for).to_s unless valid_for.nil?
    email = (user_hash[:email] || user_hash['email'])

    unless email.to_s.match(EMAIL_FORMAT)
      raise Unauthorized.new("'#{email}' is not a valid email address")
    end

    unless sso_key.to_s.length > 1
      raise Unauthorized.new("Please specify your SSO key")
    end

    key = EzCrypto::Key.with_password(subdomain_key, sso_key)
    encrypted = key.encrypt(user_hash.to_json)
    encoded = Base64.encode64(encrypted).gsub(/\n/,'')

    return CGI.escape(encoded)
  end

  def self.decrypt_sso_token(subdomain_key, sso_key, encoded)
    encrypted = Base64.decode64(CGI.unescape(encoded))
    return JSON.parse(EzCrypto::Key.with_password(subdomain_key, sso_key).decrypt(encrypted))
  end
end
