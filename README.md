UserVoice gem for API connections
=================================

This gem allows you to easily:
* Generate SSO token for creating SSO users / logging them into UserVoice (http://uservoice.com).
* Do 3-legged and 2-legged UserVoice API calls safely without having to worry about the cryptographic details (unless you want).

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

    require 'uservoice'
    sso_token = UserVoice.generate_sso_token(USERVOICE_SUBDOMAIN, SSO_KEY, {
        :guid => 1001,
        :display_name => "John Doe",
        :email => 'john.doe@example.com'
    })

    # Now this URL will log John Doe in:
    puts "https://#{USERVOICE_SUBDOMAIN}.uservoice.com/?sso=#{sso_token}"

Making 2-Legged API calls
-------------------------

Managing backups and extracting all the users of a UserVoice subdomain are typical use cases for making 2-legged API calls. With the help
of the gem you just need to create an instance of UserVoice::Oauth (needs an API client, see Admin Console -> Settings -> Channels -> API).
Then just start making requests like the example below demonstrates.

    require 'uservoice'
    uservoice_client = UserVoice::Client.new(USERVOICE_SUBDOMAIN, API_KEY, API_SECRET)

    # Here we don't need to make requests on behalf of any user

    users_json = uservoice_client.get("/api/v1/users.json?per_page=3").body
    JSON.parse(users_json)['users'].each do |user_hash|
      puts "User: \"#{user_hash['name']}\", Profile URL: #{user_hash['url']}"
    end

Making API calls as a user
--------------------------

It is also possible to make calls as any user. Method login\_as constructs SSO token in the background.

    uservoice_client = UserVoice::Client.new(USERVOICE_SUBDOMAIN, API_KEY, API_SECRET)

    # login as mailaddress@example.com, a normal user
    uservoice_client.login_as('mailaddress@example.com')

    # Example request: Get current user.
    response = uservoice_client.get("/api/v1/users/current.json").body
    user_hash = JSON.parse(response)['user']

    # login as account owner
    uservoice_client.login_as_owner

    # Example request: Get current user.
    response = uservoice_client.get("/api/v1/users/current.json").body
    user_hash = JSON.parse(response)['user']

    puts "User logged in, Name: #{user_hash['name']}, Profile URL: #{user_hash['url']}"

Making 3-Legged API calls
-------------------------

If you want to make calls on behalf of a user, you need 3-legged API calls. It basically requires you to pass a link to UserVoice, where
user grants your site permission to access his or her data in his or her account

    CALLBACK_URL = 'http://localhost:3000/'

    uservoice_client = Uservoice::Client.new(USERVOICE_SUBDOMAIN, API_KEY, API_SECRET, :callback => CALLBACK_URL)

    # At this point you want to print/redirect to uservoice_client.authorize_url in your application.
    # Here we just output them as this is a command-line example.
    puts "1. Go to #{uservoice_client.authorize_url} and click \"Allow access\"."
    puts "2. Then type the oauth_verifier which is passed as a GET parameter to the callback URL:"

    # In a web app we would get the oauth_verifier from UserVoice (after a redirection back to CALLBACK_URL).
    # In this command-line example we just read it from stdin:
    uservoice_client.get_access_token(:oauth_verifier => gets.match('\w*').to_s)

    # All done. Now we can, for example, read the current user:
    response = uservoice_client.get("/api/v1/users/current.json").body
    user_hash = JSON.parse(response)['user']

    puts "User logged in, Name: #{user_hash['name']}, Profile URL: #{user_hash['url']}"

