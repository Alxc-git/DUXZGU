require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Local secrets, before any initializer reads ENV. Without this only `bin/dev`
# (Foreman) would see .env, and `bin/rails server` would boot with no Stripe key.
if defined?(Dotenv)
  Dotenv.load(File.expand_path("../.env", __dir__))
end

module ECommerce
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # The shop sells in Quebec: French is the default, English is offered from the
    # header, and anything missing from one falls back to the other rather than
    # showing a raw translation key to a customer.
    config.i18n.available_locales = %i[fr en]
    config.i18n.default_locale = :fr
    config.i18n.fallbacks = { en: :fr, fr: :en }

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
