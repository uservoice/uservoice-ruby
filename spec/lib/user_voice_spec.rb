require 'spec_helper'

describe UserVoice do

  context 'having an SSO token for User Name' do
    let(:user_attributes) do
      { :display_name => "User Name", :email => 'mailaddress@example.com' }
    end

    it "should generate SSO token" do
      token = UserVoice.generate_sso_token(config['subdomain_name'], config['sso_key'], user_attributes)
      encrypted_raw_data = Base64.decode64(CGI.unescape(token))
      key = EzCrypto::Key.with_password(config['subdomain_name'], config['sso_key'])
      key.decrypt(encrypted_raw_data).should match('mailaddress@example.com')
    end

    it "should decrypt SSO token" do
      token = UserVoice.generate_sso_token(config['subdomain_name'], config['sso_key'], user_attributes)
      UserVoice.decrypt_sso_token(config['subdomain_name'], config['sso_key'], token)['display_name'].should match('User Name')
    end
  end
end