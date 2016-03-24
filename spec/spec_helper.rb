ENV['RAILS_ENV'] = 'test'
if ENV['TRAVIS'] && !(defined?(RUBY_ENGINE) && RUBY_ENGINE == 'rbx')
  require 'codeclimate-test-reporter'
  CodeClimate::TestReporter.start
end

require File.expand_path('../dummy/config/environment', __FILE__)

# Re-create the test database and run the migrations
db = ENV.fetch('DB', 'sqlite3')
system({ 'DB' => db }, 'script/create-db-users') unless ENV['TRAVIS']
ActiveRecord::Tasks::DatabaseTasks.drop_current
ActiveRecord::Tasks::DatabaseTasks.create_current
ActiveRecord::Migrator.migrate(['db/migrate/', File.join(Rails.root, 'db/migrate/')])

require File.expand_path('../../spec/support/features/page_object/authentication', __FILE__)
require 'rspec/rails'
require 'capybara/rspec'
require 'factory_girl_rails'
require 'shoulda-matchers'
require 'database_cleaner'
require 'test_after_commit'
require 'chronic'
require 'fileutils'

Dir[Rails.root.join('../../spec/support/**/*.rb')].each { |f| require f }

counter = -1

FileUtils.mkdir('log') unless File.directory?('log')
ActiveRecord::SchemaMigration.logger = ActiveRecord::Base.logger =
  Logger.new(File.open("log/test.#{db}.log", 'w'))

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.fixture_path = "#{::Rails.root}/../../spec/fixtures"
  config.use_transactional_fixtures = true
  config.include FactoryGirl::Syntax::Methods

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
    TestAfterCommit.enabled = true
    Q.queue_config.inline = true
  end

  config.after(:suite) do
    counter = 0
  end

  config.before(:each) do
    DatabaseCleaner.start
    Time.zone = 'UTC'
    Chronic.time_class = Time.zone
    Thredded.queue_backend = :threaded_in_memory_queue
  end

  config.after(:each) do
    DatabaseCleaner.clean
    counter += 1
    if counter > 9
      GC.enable
      GC.start
      GC.disable
      counter = 0
    end
  end

  ThreadedInMemoryQueue.logger.level = Logger::ERROR
end
