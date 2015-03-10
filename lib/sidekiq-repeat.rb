require 'sidekiq/repeat'

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Repeat::Middleware
  end

  config.on(:startup) do
    Sidekiq::Repeat::Repeatable.reschedule_all
  end
end
