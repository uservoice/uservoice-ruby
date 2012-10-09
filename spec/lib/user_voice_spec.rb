require 'spec_helper'

describe UserVoice do

  it "should generate SSO token" do
    token = UserVoice.generate_sso_token(config['subdomain_name'], config['sso_key'], {
      :display_name => "User Name",
      :email => 'mailaddress@example.com'
    })
    encrypted_raw_data = Base64.decode64(CGI.unescape(token))

    key = EzCrypto::Key.with_password(config['subdomain_name'], config['sso_key'])
    key.decrypt(encrypted_raw_data).should match('mailaddress@example.com')
  end
end