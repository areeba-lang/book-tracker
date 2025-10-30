require "active_record"
require "logger"
require "dotenv/load"

ENV["RACK_ENV"] ||= "development"

DB_PATH = File.expand_path("../db/#{ENV["RACK_ENV"]}.sqlite3", __dir__)

ActiveRecord::Base.logger = Logger.new($stdout)

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: DB_PATH
)


