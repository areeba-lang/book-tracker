ENV["RACK_ENV"] ||= "development"
require_relative "config/database"  # ensure an AR connection is established
require "active_record"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("db/migrate", __dir__)]
require "sinatra/activerecord/rake"

namespace :db do
  desc "Seed the database"
  task :seed do
    require_relative "db/seeds"
  end
end


