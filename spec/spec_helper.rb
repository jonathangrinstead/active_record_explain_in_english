require "active_record"
require "database_cleaner/active_record"
require "active_record_explain_in_english"
require "support/user"
require "support/post"
require "support/category"
require "support/comment"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string   :name
    t.string   :role
    t.boolean  :active
    t.integer  :age
    t.datetime :created_at
    t.datetime :updated_at
  end

  create_table :posts, force: true do |t|
    t.integer :user_id
    t.integer :category_id
    t.string  :title
    t.boolean :published
  end

  create_table :categories, force: true do |t|
    t.string :name
    t.boolean :archived
  end

  create_table :comments, force: true do |t|
    t.integer :user_id
    t.integer :post_id
    t.string  :body
    t.boolean :approved
    t.datetime :created_at
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
