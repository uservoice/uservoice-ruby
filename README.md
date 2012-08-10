UserVoice gem for API connections
=================================

This gem allows you to easily:
* Generate SSO token for creating SSO users / logging them into UserVoice (http://uservoice.com).
* Do 3-legged and 2-legged UserVoice API calls safely without having to worry about the cryptographic details (unless you want).

Examples
========

Prerequisites:
* Suppose your UserVoice site is at http://uservoice-subdomain.uservoice.com/
* The SSO key of the account is 982c88f2df72572859e8e23423eg87ed
* The account has a following API client (Admin Console -> Settings -> Channels -> API):
    * API key: oQt2BaunWNuainc8BvZpAm
    * API secret: 3yQMSoXBpAwuK3nYHR0wpY6opE341inL9a2HynGF2


SSO-token generation using uservoice gem
----------------------------------------

    sso_token = UserVoice.generate_sso_token('uservoice-subdomain', '982c88f2df72572859e8e23423eg87ed', {
        :guid => 1001,
        :display_name => "John Doe",
        :email => 'john.doe@example.com'
    })

    # Now this URL will log John Doe in:
    puts "https://uservoice_subdomain.uservoice.com/?sso=#{sso_token}"

Making 2-Legged API calls
-------------------------

    oauth = UserVoice::OAuth.new('uservoice-subdomain', 'oQt2BaunWNuainc8BvZpAm', '3yQMSoXBpAwuK3nYHR0wpY6opE341inL9a2HynGF2')

    # In 2-legged calls we are not making request on behalf of any user, so we can start making requests right away

    users_json = oauth.request(:get, "/api/v1/users.json?per_page=3").body
    JSON.parse(users_json)['users'].each do |user_hash|
      puts "User: \"#{user_hash['name']}\", Profile URL: #{user_hash['url']}"
    end