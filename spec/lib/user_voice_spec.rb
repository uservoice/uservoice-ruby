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

  describe OAuth do
    subject { UserVoice::OAuth.new(config['subdomain_name'], 
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
  end
end