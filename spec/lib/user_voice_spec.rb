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
                                   :uservoice_domain => config['uservoice_domain'],
                                   :protocol => config['protocol']) }

    it "should get user names from the API" do
      users = subject.get("/api/v1/users.json?per_page=3")
      user_names = users['users'].map { |user| user['name'] }
      user_names.all?.should == true
      user_names.size.should == 3
    end

    it "should not get current user with 2-legged call" do
      user = subject.get("/api/v1/users/current.json")
      user['errors']['type'].should == 'unauthorized'
    end

    it "should not be able to create KB article as nobody" do
      result = subject.post("/api/v1/articles.json", :article => {
        :title => 'good morning'
      })
      result['errors']['type'].should == 'unauthorized'
    end

    it "should be able to create and delete a forum as the owner" do
      subject.login_as_owner
      forum = subject.post("/api/v1/forums.json", :forum => {
        :name => 'Test forum from RSpec',
        'private' => true,
        'allow_by_email_domain' => true,
        'allowed_email_domains' => [{'domain' => 'raimo.rspec.example.com'}]
      })['forum']

      forum['id'].should be_a(Integer)

      deleted_forum = subject.delete("/api/v1/forums/#{forum['id']}.json")['forum']
      deleted_forum['id'].should == forum['id']
    end

    it "should get current user with 2-legged call" do
      subject.login_as('mailaddress@example.com')
      user = subject.get("/api/v1/users/current.json")
      user['user']['email'].should == 'mailaddress@example.com'
    end

    it "should get current user with copied access token" do
      subject.login_as('mailaddress@example.com')

      new_client = UserVoice::Client.new(config['subdomain_name'],
                                         config['api_key'],
                                         config['api_secret'],
                                        :uservoice_domain => config['uservoice_domain'],
                                        :protocol => config['protocol'])

      new_client.access_token_attributes = subject.access_token_attributes

      user = new_client.get("/api/v1/users/current.json")
      user['user']['email'].should == 'mailaddress@example.com'
    end

    it "should login as an owner" do
      subject.login_as_owner

      owner = subject.get("/api/v1/users/current.json")['user']
      owner['roles']['owner'].should == true
    end

    it "should not be able to delete when not deleting behalf of anyone" do
      result = subject.delete("/api/v1/users/#{234}.json")
      result['errors']['message'].should match(/user required/i)
    end

    it "should not be able to delete owner" do
      subject.login_as_owner

      owner = subject.get("/api/v1/users/current.json")['user']

      result = subject.delete("/api/v1/users/#{owner['id']}.json")
      result['errors']['message'].should match(/Cannot delete admins/i)
    end

    it "should not be able to delete any user as random user" do
      subject.login_as('somebodythere@example.com')
      regular_user = subject.get("/api/v1/users/current.json")['user']

      subject.login_as('somerandomdude@example.com')
      subject.delete("/api/v1/users/#{regular_user['id']}.json")['errors']['message'].should match(/cannot delete/i)
    end

    it "should be able to delete himself" do
      subject.login_as('somebodythere@example.com')
      me = subject.get("/api/v1/users/current.json")['user']

      subject.delete("/api/v1/users/#{me['id']}.json")['user']['id'].should == me['id']

      subject.get("/api/v1/users/current.json")['errors']['type'].should == 'record_not_found'
    end

    it "should be able to delete random user and login as him after that" do
      subject.login_as('somebodythere@example.com')
      regular_user = subject.get("/api/v1/users/current.json")['user']

      subject.login_as_owner
      subject.delete("/api/v1/users/#{regular_user['id']}.json")['user']['id'].should == regular_user['id']
      subject.get("/api/v1/users/#{regular_user['id']}.json")['errors']['type'].should == 'record_not_found'

      subject.login_as('somebodythere@example.com')
      subject.get("/api/v1/users/current.json")['user']['id'].should == regular_user['id']
    end

    it "should raise error with invalid email parameter" do
      expect { subject.login_as('ma') }.to raise_error(UserVoice::Unauthorized)
      expect { subject.login_as(nil) }.to raise_error(UserVoice::Unauthorized)
    end
  end
end