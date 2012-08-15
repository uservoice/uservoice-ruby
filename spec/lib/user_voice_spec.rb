require 'spec_helper'

describe UserVoice do
  subject { UserVoice }

  describe 'generate_sso_token' do

    it "should generate token from user attributes" do
      subject.generate_sso_token('uservoice', 'asdfadsgasdg', {
        :guid => 1234,
        :display_name => 'Test Name'
      })
    end
  end

  describe UserVoice::Client do
    subject { UserVoice::Client.new(config['subdomain_name'],
                                   config['api_key'],
                                   config['api_secret']) }

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

    it "should get current user with 3-legged call" do
      sso_token = UserVoice.generate_sso_token(config['subdomain_name'], config['sso_key'], {
        :guid => '1000000',
        :display_name => "User Name",
        :email => 'mailaddress@example.com'
      })
      subject.login_with_sso_token(sso_token)
      user_json = subject.request(:get, "/api/v1/users/current.json").body
      user = JSON.parse(user_json)
      user['user']['email'].should == 'mailaddress@example.com'
      user['user']['guid'].should == '1000000'
    end
  end
end