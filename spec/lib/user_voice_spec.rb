require 'spec_helper'

describe UserVoice do
  let(:sso_token) {
    UserVoice.generate_sso_token(config['subdomain_name'], config['sso_key'], {
      :guid => '1000000',
      :display_name => "User Name",
      :email => 'mailaddress@example.com'
    })
  }

  describe UserVoice::Client do
    subject { UserVoice::Client.new(config['subdomain_name'],
                                   config['api_key'],
                                   config['api_secret']) }

    let(:sso_client) { UserVoice::Client.new(config['subdomain_name'],
                                             config['api_key'],
                                             config['api_secret'],
                                            :sso_key => config['sso_key']) }

    it "should get users from the API" do
      users_json = subject.request(:get, "/api/v1/users.json?per_page=3").body
      users = JSON.parse(users_json)['users'].map { |user| user['name'] }
      users.all?.should == true
      users.size.should == 3
    end

    it "should not get current user with 2-legged call" do
      user_json = subject.request(:get, "/api/v1/users/current.json").body
      user = JSON.parse(user_json)
      user['errors']['type'].should == 'unauthorized'
    end

    it "should not get current user without sso key" do
      user_json = subject.request(:get, "/api/v1/users/current.json").body
      expect { subject.login_as('mailaddress@example.com') }.to raise_error(UserVoice::Unauthorized)
    end

    it "should get current user with 3-legged call" do
      subject.login_with_sso_token(sso_token)
      user_json = subject.request(:get, "/api/v1/users/current.json").body
      user = JSON.parse(user_json)
      user['user']['email'].should == 'mailaddress@example.com'
      user['user']['guid'].should == '1000000'
    end

    it "should get current user with email address login" do
      sso_client.login_as('mailaddress@example.com')

      user_json = sso_client.request(:get, "/api/v1/users/current.json").body
      user = JSON.parse(user_json)
      user['user']['email'].should == 'mailaddress@example.com'
      user['user']['guid'].should == 'mailaddress@example.com'
    end

    it "should raise error with invalid email parameter" do
      expect { sso_client.login_as('ma') }.to raise_error(UserVoice::Unauthorized)
      expect { sso_client.login_as(nil) }.to raise_error(UserVoice::Unauthorized)
    end
  end
end