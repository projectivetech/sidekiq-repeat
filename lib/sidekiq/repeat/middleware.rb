module Sidekiq
  module Repeat
    class Middleware
      def call(worker, item, queue)
        yield
      ensure
        worker.class.reschedule if worker.class.respond_to?(:reschedule)
      end
    end
  end
end
