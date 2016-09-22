require 'spec_helper'
describe UserVoice::Client do
  subject { UserVoice::Client.new(config['subdomain_name'],
                                  config['api_key'],
                                  config['api_secret'],
                                 :uservoice_domain => config['uservoice_domain'],
                                 :protocol => config['protocol']) }
  let(:external_scope) { 'external_system_name' }

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

  it 'should be able to attach file in ticket' do
    user = subject.login_as('my@example.com')

    @ticket = user.post('/api/v1/tickets', :ticket => {
      :subject => 'A new ticket has arrived in your console',
      :message => 'My msg',
      :attachments => [{
        :content_type => 'image/png',
        :name => 'testi.png',
        :data => 'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/'+
                  '9hAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJl'+
                  'YWR5ccllPAAAAH5JREFUeNpi/P//PwMlgImBQsCCzG'+
                  'FkZETmGgPxTDT16UAXn0URAXkBhrGASCA+A8SbsakH'+
                  'YUJeUIfSB8gNA2MofZYcA6SAWJISA2C23wLiz+QYYE'+
                  '/IdmJdcIAcA9SAmJcSFxgToxmfAQ7kGqAGTXkwF6RB'+
                  'UyNOwDjguREgwAAEES2zre7f8gAAAABJRU5ErkJggg=='
      }]
    })['ticket']

    subject.get("/api/v1/tickets/#{@ticket['id']}")['ticket']['state'].should == 'open'
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

  it "should be able to create KB article as an owner" do
    owner = subject.login_as_owner
    result = owner.post("/api/v1/articles.json", :article => {
      :question => 'What is up?',
      :answer_html => 'Nothing much'
    })
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

  it "should update the email of the current user" do
    user = subject.login_as('mailaddress@example.com') do |token|
      token.put("/api/v1/users/current", :user => {
        :email => 'mailaddress123@example.com'
      })
      token.get("/api/v1/users/current")['user']
    end

    user_with_new_email = subject.login_as('mailaddress123@example.com')
    id = user_with_new_email.get("/api/v1/users/current")['user']['id']
    id.should == user['id']
    user_with_new_email.delete("/api/v1/users/#{id}")['user']
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

  it "should not be able to delete user without login" do
    regular_user = subject.login_as('somebodythere@example.com').get("/api/v1/users/current.json")['user']

    lambda {
      subject.delete("/api/v1/users/#{regular_user['id']}.json")
    }.should raise_error(UserVoice::Unauthorized)
  end

  it 'should get all suggestions using a collection enumerator' do
    subject.should_receive(:get).once.and_return({
      "response_data"=>{"page"=>1, "per_page"=>10, "total_records"=>1, "filter"=>"all", "sort"=>"votes"},
      "suggestions"=>[ {
            "url"=>"http://uservoice-subdomain.uservoice.com/forums/1-a/suggestions/1-i",
            "id"=>1,
            "state"=>"published",
            "title"=>"a",
            "text"=>"b",
            "formatted_text"=>"b",
            "forum"=>{"id"=>"1", "name"=>"General"}
          }
      ]})
    suggestions = subject.get_collection("/api/v1/suggestions.json")
    count = 0
    suggestions.each do |suggestion|
      count += 1
    end
    count.should == suggestions.size
    count.should == 1
  end

  it "should get an error when trying to query suggestions with an unexistant manual action" do
    lambda {
      subject.login_as_owner do |owner_token|
        owner_token.get("/api/v1/suggestions.json?filter=with_external_id&external_scope=#{external_scope}&manual_action=#{external_scope}")['suggestions']
      end
    }.should raise_error(UserVoice::NotFound)
  end

  it "should identify a suggestion" do
    owner_token = subject.login_as_owner

    suggestions = owner_token.get("/api/v1/suggestions.json?filter=without_external_id&external_scope=#{external_scope}&per_page=1")['suggestions']
    identifications = suggestions.map {|s| { :id => s['id'], :external_id => s['id'].to_i*10, :url => 'http://url.example.com' } }

    ids = owner_token.put("/api/v1/suggestions/identify.json",
                          :upsert => true,
                          :external_scope => external_scope,
                          :identifications => identifications)['identifications']['ids']
    ids.should == identifications.map { |s| s[:id] }.sort
  end

  it "should be able to delete itself" do
    owner = subject.login_as_owner
    user_count_1st = owner.get_collection("/api/v1/users.json").size
    my_token = subject.login_as('somenewthere@example.com')

    user_count_1st.should == owner.get_collection("/api/v1/users.json").size - 1

    # whoami
    my_id = my_token.get("/api/v1/users/current.json")['user']['id']

    # Delete myself!
    my_token.delete("/api/v1/users/#{my_id}.json")['user']['id'].should == my_id
    user_count_1st.should == owner.get_collection("/api/v1/users.json").size
  end

  it 'should throw 404 if user not found' do
    lambda {
      subject.login_as_owner.get("/api/v1/users/2345871235")
    }.should raise_error(UserVoice::NotFound)
  end

  it "should/be able to delete random user and login as him after that" do
    somebody = subject.login_as('somebodythere@example.com')
    owner = subject.login_as_owner
    user_count = owner.get_collection("/api/v1/users.json").size

    # somebody is still there...
    regular_user = somebody.get("/api/v1/users/current.json")['user']
    regular_user['email'].should == 'somebodythere@example.com'

    # delete somebody!
    owner.delete("/api/v1/users/#{regular_user['id']}.json")['user']['id'].should == regular_user['id']

    # not found anymore!
    user_count.should == owner.get_collection("/api/v1/users.json").size + 1

    # this recreates somebody
    somebody = subject.login_as('somebodythere@example.com')
    somebody.get("/api/v1/users/current.json")['user']['email'].should == regular_user['email']
  end

  it "should raise error with invalid email parameter" do
    expect { subject.login_as('ma') }.to raise_error(UserVoice::Unauthorized)
    expect { subject.login_as(nil) }.to raise_error(UserVoice::Unauthorized)
  end

  it "should allow users with .technology email addresses to be valid" do
    expect('somebody@example.technology').to match(UserVoice::EMAIL_FORMAT)
  end
end
