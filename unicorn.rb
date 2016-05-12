# config/unicorn.rb
worker_processes ENV['APP_SERVER_WORKERS'].nil? ? 2 : Integer(ENV['APP_SERVER_WORKERS'])
preload_app true
# change backlog from standard 1024 to 200, listen to HEROKU's port environment variable
# change it without deploy with heroku config:set UNICORN_BACKLOG=16
listen ENV['PORT'], :backlog => Integer(ENV['UNICORN_BACKLOG'] || 200)

# allow pry to work in development
# must start the server with RAILS_ENV=development
# see http://stackoverflow.com/questions/25435408/unicorn-pry-in-rails
timeout ENV['RAILS_ENV'] == 'development' ? 10_000 : 30

before_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
    Process.kill 'QUIT', Process.pid
  end

  defined?(ActiveRecord::Base) and ActiveRecord::Base.connection.disconnect!
end

after_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to sent QUIT'
  end

  defined?(ActiveRecord::Base) and ActiveRecord::Base.establish_connection

  Sidekiq.configure_client do |config|
    config.redis = { url: REDIS_URL, namespace: "#{REDIS_NAMESPACE}_#{Rails.env}" }

    config.client_middleware do |chain|
      chain.add Sidekiq::Status::ClientMiddleware
    end
  end

  # We're using this pdf_package initializer to add methods to the template
  # models (Evaluation, ConsentForm) that are used in the pdf package views.
  # These don't carry over when Unicorn forks, so we re-require here.
  require Rails.root.join('config/initializers/pdf_package_model_mixins')
end

