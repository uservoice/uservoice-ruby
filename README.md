UserVoice gem for API connections
=================================

This gem allows you to easily:
* Generate SSO token for creating SSO users / logging them into UserVoice (http://uservoice.com).
* Do 3-legged and 2-legged UserVoice API calls safely without having to worry about the cryptographic details (unless you want).

Examples
========

Prerequisites:
* Suppose your UserVoice site is at http://uservoice-subdomain.uservoice.com/
* **SSO\_KEY** = 982c88f2df72572859e8e23423eg87ed (Admin Console -> Settings -> General -> User Authentication)
* The account has a following API client (Admin Console -> Settings -> Channels -> API):
    * **API\_KEY** = oQt2BaunWNuainc8BvZpAm
    * **API\_SECRET** = 3yQMSoXBpAwuK3nYHR0wpY6opE341inL9a2HynGF2


SSO-token generation using uservoice gem
----------------------------------------

SSO-token can be used to create sessions for SSO users. They are capable of synchronizing the user information from one system to another.
Generating the SSO token from SSO key and given uservoice subdomain can be done by calling UserVoice.generate\_sso\_token method like this:

    sso_token = UserVoice.generate_sso_token('uservoice-subdomain', SSO_KEY, {
        :guid => 1001,
        :display_name => "John Doe",
        :email => 'john.doe@example.com'
    })

    # Now this URL will log John Doe in:
    puts "https://uservoice_subdomain.uservoice.com/?sso=#{sso_token}"

Making 2-Legged API calls
-------------------------

Managing backups and extracting all the users of a UserVoice subdomain are typical use cases for making 2-legged API calls. With the help
of the gem you just need to create an instance of UserVoice::Oauth (needs an API client, see Admin Console -> Settings -> Channels -> API).
Then just start making requests like the example below demonstrates.

    oauth = UserVoice::OAuth.new('uservoice-subdomain', API_KEY, API_SECRET)

    # In 2-legged calls we are not making request on behalf of any user, so we can start making requests right away

    users_json = oauth.request(:get, "/api/v1/users.json?per_page=3").body
    JSON.parse(users_json)['users'].each do |user_hash|
      puts "User: \"#{user_hash['name']}\", Profile URL: #{user_hash['url']}"
    end

Making 3-Legged API calls
-------------------------

If you want to make calls on behalf of a user, you need 3-legged API calls. It basically requires you to pass a link to UserVoice, where
user grants your site permission to access his or her data in his or her account

    CALLBACK_URL = 'http://localhost:3000/'

    oauth = Uservoice::OAuth.new('uservoice-subdomain', API_KEY, API_SECRET)

    # You need to get a request token from UserVoice like this. Specify the :oauth_callback
    request_token = oauth.get_request_token(:oauth_callback => CALLBACK_URL)

    # At this point you want to print/redirect to request_token.authorize_url in your application.
    # Here we just output them as this is a command-line example.
    puts "1. Go to #{request_token.authorize_url} and click \"Allow access\"."
    puts "2. Then type the oauth_verifier which is passed as a GET parameter to the callback URL:"

    # In a web app we would get the oauth_verifier from UserVoice (after a redirection back to CALLBACK_URL).
    # In this command-line example we just read it from stdin:
    access_token = request_token.get_access_token(:oauth_verifier => gets.match('\w*').to_s)

    # All done. Now we can, for example, read the current user:
    response = access_token.get("/api/v1/users/current.json").body
    user_hash = JSON.parse(response)['user']

    puts "User logged in, Name: #{user_hash['name']}, Profile URL: #{user_hash['url']}"