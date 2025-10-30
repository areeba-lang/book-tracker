require_relative "../config/database"
require "active_record"

ActiveRecord::Migration.verbose = true

migrations_path = File.expand_path("../db/migrate", __dir__)

if ActiveRecord::Base.connection.respond_to?(:migration_context)
  ActiveRecord::Base.connection.migration_context.migrate
else
  ActiveRecord::MigrationContext.new(migrations_path, ActiveRecord::SchemaMigration).migrate
end

puts "Migrations applied to #{ENV["RACK_ENV"]} (#{ActiveRecord::Base.connection_db_config.database})"


