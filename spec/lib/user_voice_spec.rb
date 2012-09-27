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

    it "should not get current user without logged in user" do
      lambda do
        user = subject.get("/api/v1/users/current.json")
      end.should raise_error(UserVoice::Unauthorized)
    end

    it "should be able to get access token as owner" do
      subject.login_as_owner do |owner|
        owner.get("/api/v1/users/current.json")['user']['roles']['owner'].should == true

        owner.login_as('regular@example.com') do |regular|
          owner.get("/api/v1/users/current.json")['user']['roles']['owner'].should == true
          @user = regular.get("/api/v1/users/current.json")['user']
          @user['roles']['owner'].should == false
        end

        owner.get("/api/v1/users/current.json")['user']['roles']['owner'].should == true
      end
      # ensure blocks got run
      @user['email'].should == 'regular@example.com'
    end

    it "should not be able to create KB article as nobody" do
      lambda do
        result = subject.post("/api/v1/articles.json", :article => {
          :title => 'good morning'
        })
      end.should raise_error(UserVoice::Unauthorized)
    end

    it "should be able to create and delete a forum as the owner" do
      owner = subject.login_as_owner
      forum = owner.post("/api/v1/forums.json", :forum => {
        :name => 'Test forum from RSpec',
        'private' => true,
        'allow_by_email_domain' => true,
        'allowed_email_domains' => [{'domain' => 'raimo.rspec.example.com'}]
      })['forum']

      forum['id'].should be_a(Integer)

      deleted_forum = owner.delete("/api/v1/forums/#{forum['id']}.json")['forum']
      deleted_forum['id'].should == forum['id']
    end

    it "should get current user with 2-legged call" do
      user = subject.login_as('mailaddress@example.com') do |token|
        token.get("/api/v1/users/current.json")['user']
      end

      user['email'].should == 'mailaddress@example.com'
    end

    it "should get current user with copied access token" do
      original_token = subject.login_as('mailaddress@example.com')

      client = UserVoice::Client.new(config['subdomain_name'],
                                   config['api_key'],
                                   config['api_secret'],
                                  :uservoice_domain => config['uservoice_domain'],
                                  :protocol => config['protocol'],
                                  :oauth_token => original_token.token,
                                  :oauth_token_secret => original_token.secret)
      # Also this works but creates an extra object:
      # client = client.login_with_access_token(original_token.token, original_token.secret)

      user = client.get("/api/v1/users/current.json")['user']

      user['email'].should == 'mailaddress@example.com'
    end

    it "should login as an owner" do
      me = subject.login_as_owner

      owner = me.get("/api/v1/users/current.json")['user']
      owner['roles']['owner'].should == true
    end

    it "should not be able to delete when not deleting on behalf of anyone" do
      lambda {
        result = subject.delete("/api/v1/users/#{234}.json")
      }.should raise_error(UserVoice::Unauthorized, /user required/i)
    end

    it "should not be able to delete owner" do
      owner_access_token = subject.login_as_owner

      owner = owner_access_token.get("/api/v1/users/current.json")['user']

      lambda {
        result = owner_access_token.delete("/api/v1/users/#{owner['id']}.json")
      }.should raise_error(UserVoice::Unauthorized, /last owner/i)
    end

    it "should not be able to delete user without login" do
      regular_user = subject.login_as('somebodythere@example.com').get("/api/v1/users/current.json")['user']

      lambda {
        subject.delete("/api/v1/users/#{regular_user['id']}.json")
      }.should raise_error(UserVoice::Unauthorized)
    end

    it "should be able to identify suggestions and sign the PUT request which contains an array" do
      owner_token = subject.login_as_owner
      external_scope = 'sillyness'
      suggestions = owner_token.get("/api/v1/suggestions.json?filter=without_external_id&external_scope=#{external_scope}")['suggestions']

      identifications = suggestions.map {|s| { :id => s['id'], :external_id => s['id'].to_i*10 } }

      ids = owner_token.put("/api/v1/suggestions/identify.json",
                          :external_scope => external_scope,
                          :identifications => identifications)['identifications']['ids']
      ids.should == identifications.map { |s| s[:id] }.sort
    end

    it "should be able to delete itself" do
      my_token = subject.login_as('somebodythere@example.com')

      # whoami
      my_id = my_token.get("/api/v1/users/current.json")['user']['id']

      # Delete myself!
      my_token.delete("/api/v1/users/#{my_id}.json")['user']['id'].should == my_id

      # I don't exist anymore
      lambda {
        my_token.get("/api/v1/users/current.json")
      }.should raise_error(UserVoice::NotFound)
    end

    it "should/be able to delete random user and login as him after that" do
      somebody = subject.login_as('somebodythere@example.com')
      owner = subject.login_as_owner

      # somebody is still there...
      regular_user = somebody.get("/api/v1/users/current.json")['user']
      regular_user['email'].should == 'somebodythere@example.com'

      # delete somebody!
      owner.delete("/api/v1/users/#{regular_user['id']}.json")['user']['id'].should == regular_user['id']

      # not found anymore!
      lambda {
        somebody.get("/api/v1/users/current.json")['errors']['type']
      }.should raise_error(UserVoice::NotFound)

      # this recreates somebody
      somebody = subject.login_as('somebodythere@example.com')
      somebody.get("/api/v1/users/current.json")['user']['id'].should_not == regular_user['id']
    end

    it "should raise error with invalid email parameter" do
      expect { subject.login_as('ma') }.to raise_error(UserVoice::Unauthorized)
      expect { subject.login_as(nil) }.to raise_error(UserVoice::Unauthorized)
    end
  end
end