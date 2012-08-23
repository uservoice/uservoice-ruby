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

  describe UserVoice::Client do
    subject { UserVoice::Client.new(config['subdomain_name'],
                                    config['api_key'],
                                    config['api_secret'],
                                   :uservoice_domain => config['uservoice_domain']) }

    it "should get users from the API" do
      users_json = subject.get("/api/v1/users.json?per_page=3").body
      users = JSON.parse(users_json)['users'].map { |user| user['name'] }
      users.all?.should == true
      users.size.should == 3
    end

    it "should not get current user with 2-legged call" do
      user_json = subject.get("/api/v1/users/current.json").body
      user = JSON.parse(user_json)
      user['errors']['type'].should == 'unauthorized'
    end

    it "should get current user with 2-legged call" do
      subject.login_as('mailaddress@example.com')
      user_json = subject.get("/api/v1/users/current.json").body
      user = JSON.parse(user_json)
      user['user']['email'].should == 'mailaddress@example.com'
    end

    it "should get current user with copied access token" do
      subject.login_as('mailaddress@example.com')

      new_client = UserVoice::Client.new(config['subdomain_name'],
                                    config['api_key'],
                                    config['api_secret'],
                                   :uservoice_domain => config['uservoice_domain'])

      new_client.set_access_token(subject.access_token_hash)

      user_json = new_client.get("/api/v1/users/current.json").body
      user = JSON.parse(user_json)
      user['user']['email'].should == 'mailaddress@example.com'
    end

    it "should login as an owner" do
      pending 'login_as_owner TBD'
      subject.login_as_owner

      user_json = subject.get("/api/v1/users/current.json").body
      user = JSON.parse(user_json)
      user['user']['admin'].should == true
    end

    it "should raise error with invalid email parameter" do
      expect { subject.login_as('ma') }.to raise_error(UserVoice::Unauthorized)
      expect { subject.login_as(nil) }.to raise_error(UserVoice::Unauthorized)
    end
  end
end