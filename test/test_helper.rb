ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "ostruct"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Swaps a module or class method for the duration of a block.
    #
    # Minitest 6 dropped its mock library, and every outbound integration in this
    # app is reached through exactly one method — Meta::ConversionsApi.call,
    # Addresses.provider — so this is the whole seam the suite needs. No test ever
    # reaches Meta, Stripe, CJ or a geocoder for real.
    def stubbing(owner, name, replacement)
      original = owner.method(name)
      owner.define_singleton_method(name, replacement)
      yield
    ensure
      owner.define_singleton_method(name, original)
    end

    # Sets environment variables for the duration of a block and puts back exactly
    # what was there, `nil` included.
    def with_env(values)
      previous = values.keys.index_with { |key| ENV[key] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end
  end
end

class ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
end
