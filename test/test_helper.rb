ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module ActionDispatch
  class IntegrationTest
    # Meldet einen Fixture-Benutzer über den echten Login an (alle Fixture-Passwörter: password12345)
    def sign_in_as(user, password: "password12345")
      post user_sessions_path, params: { user: { email_address: user.email_address, password: password } }
    end
  end
end