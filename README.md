UserVoice gem for API connections
=================================

This gem allows you to easily:
* Generate SSO token for creating SSO users / logging them into UserVoice (http://uservoice.com).
* Do 3-legged and 2-legged UserVoice API calls safely without having to worry about the cryptographic details.

Examples
========

Prerequisites:
* Suppose your UserVoice site is at http://uservoice-subdomain.uservoice.com/ and **USERVOICE\_SUBDOMAIN** = uservoice-subdomain
* **SSO\_KEY** = 982c88f2df72572859e8e23423eg87ed (Admin Console -> Settings -> General -> User Authentication)
* The account has a following API client (Admin Console -> Settings -> Channels -> API):
    * **API\_KEY** = oQt2BaunWNuainc8BvZpAm
    * **API\_SECRET** = 3yQMSoXBpAwuK3nYHR0wpY6opE341inL9a2HynGF2


SSO-token generation using uservoice gem
----------------------------------------

SSO-token can be used to create sessions for SSO users. They are capable of synchronizing the user information from one system to another.
Generating the SSO token from SSO key and given uservoice subdomain can be done by calling UserVoice.generate\_sso\_token method like this:

```ruby
require 'uservoice'
sso_token = UserVoice.generate_sso_token(USERVOICE_SUBDOMAIN, SSO_KEY, {
    :guid => 1001,
    :display_name => "John Doe",
    :email => 'john.doe@example.com'
})

# Now this URL will log John Doe in:
puts "https://#{USERVOICE_SUBDOMAIN}.uservoice.com/?sso=#{sso_token}"
```

Making API calls
----------------

With the gem you need to create an instance of UserVoice::Oauth. You get
API_KEY and API_SECRET from an API client which you can create in Admin Console
-> Settings -> Channels -> API.

```ruby
require 'uservoice'
uservoice_client = UserVoice::Client.new(USERVOICE_SUBDOMAIN, API_KEY, API_SECRET)

# Get users of a subdomain (requires trusted client, but no user)
users = uservoice_client.get("/api/v1/users.json?per_page=3")['users']
users.each do |user|
  puts "User: \"#{user['name']}\", Profile URL: #{user['url']}"
end

# Now, let's login as mailaddress@example.com, a regular user
uservoice_client.login_as('mailaddress@example.com')

# Example request #1: Get current user.
user = uservoice_client.get("/api/v1/users/current.json")['user']

puts "User: \"#{user['name']}\", Profile URL: #{user['url']}"

# Login as account owner
uservoice_client.login_as_owner

# Example request #2: Create a new private forum limited to only example.com email domain.
forum = uservoice_client.post("/api/v1/forums.json", :forum => {
  :name => 'Example.com Private Feedback',
  :private => true,
  :allow_by_email_domain => true,
  :allowed_email_domains => [{:domain => 'example.com'}]
})['forum']

puts "Forum '#{forum['name']}' created! URL: #{forum['url']}"
```

Verifying a UserVoice user
--------------------------

If you want to make calls on behalf of a user, but want to make sure he or she
actually owns certain email address in UserVoice, you need to use 3-Legged API
calls. Just pass your user an authorize link to click, so that user may grant
your site permission to access his or her data in UserVoice.

```ruby
require 'uservoice'
CALLBACK_URL = 'http://localhost:3000/' # your site

uservoice_client = UserVoice::Client.new(USERVOICE_SUBDOMAIN, API_KEY, API_SECRET, :callback => CALLBACK_URL)

# At this point you want to print/redirect to uservoice_client.authorize_url in your application.
# Here we just output them as this is a command-line example.
puts "1. Go to #{uservoice_client.authorize_url} and click \"Allow access\"."
puts "2. Then type the oauth_verifier which is passed as a GET parameter to the callback URL:"

# In a web app we would get the oauth_verifier through a redirect from UserVoice (after a redirection back to CALLBACK_URL).
# In this command-line example we just read it from stdin:
uservoice_client.login_verified_user(gets.match('\w*').to_s)

# All done. Now we can read the current user to know user's email address:
user = uservoice_client.get("/api/v1/users/current.json")['user']

puts "User logged in, Name: #{user['name']}, email: #{user['email']}"
```

