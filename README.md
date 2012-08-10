Uservoice gem for API connections
=================================


SSO-token generation using uservoice gem
----------------------------------------

Suppose your UserVoice site is at http://uservoice-subdomain.uservoice.com/ and your SSO key is hGsD7y7GhSksuoIh:

    sso_token = Uservoice.generate_sso_token('uservoice-subdomain', 'hGsD7y7GhSksuoIh', {
        :guid => 1001,
        :display_name => "John Doe",
        :email => 'john.doe@example.com'
    })

    # Now this URL will log John Doe in:
    puts "https://uservoice_subdomain.uservoice.com/?sso=#{sso_token}"