# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "rails", github: "rails/rails"
  gem "mysql2"
end

require "active_record"
require "minitest/autorun"
require "logger"

# This connection will do for database-independent bug reports.
ActiveRecord::Base.establish_connection(
  adapter:  "mysql2",
  username: "root",
  password: "root",
  port:     3307,
  host:     "127.0.0.1"
)
ActiveRecord::Base.logger = Logger.new(STDOUT)

runner = Class.new do
  DB_NAME = "dumper_issue"

  def drop_db
    execute("DROP DATABASE IF EXISTS #{DB_NAME}")
  end

  def create_db
    execute("CREATE DATABASE IF NOT EXISTS #{DB_NAME}")
  end

  def use_db
    execute("USE #{DB_NAME}")
  end

  def create_table
    ActiveRecord::Migration.create_table(:posts) do |t|
      t.json :metadata
    end

    execute <<-SQL
  ALTER TABLE posts ADD COLUMN `author` VARCHAR(32)
  GENERATED ALWAYS AS (json_unquote(json_extract(`metadata`, "$.author")))
SQL
  end

  def dump_schema
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, schema_file)
    schema_file.close
  end

  def load_schema
    load schema_file
  end

  protected

  def execute(sql)
    ActiveRecord::Base.connection.execute(sql)
  end

  def schema_file
    @schema_file ||= File.new("#{__dir__}/schema.rb", 'w:utf-8')
  end
end.new

runner.drop_db
runner.create_db
runner.use_db

runner.create_table
runner.dump_schema

runner.drop_db
runner.create_db
runner.use_db

runner.load_schema
