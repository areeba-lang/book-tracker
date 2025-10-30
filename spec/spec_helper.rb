ENV["RACK_ENV"] = "test"

require "rack/test"
require "rspec"
require "database_cleaner/active_record"

require_relative "../config/database"

# Load app and all code
require_relative "../app"

RSpec.configure do |config|
  config.include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  # Clean DB between tests
  DatabaseCleaner.strategy = :transaction

  config.before(:suite) do
    migrations_path = File.join(__dir__, "..", "db", "migrate")
    ActiveRecord::MigrationContext.new(migrations_path, ActiveRecord::SchemaMigration).migrate
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning { example.run }
  end
end


