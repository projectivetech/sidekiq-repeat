module Sidekiq
  module Repeat
    module Repeatable
      module ClassMethods
        def repeat(&block)
          @cronline = MiniIceCube::MainDsl.new.instance_eval(&block).to_s
          @cronline = CronParser.new(@cronline)
        rescue ArgumentError
          fail "repeat '#{@cronline}' in class #{self.name} is not a valid cron line"
        end

        def reschedule
          return unless repeat_configured?
          return if     already_scheduled?

          ts = @cronline.next
          self.perform_at ts.to_f
          Sidekiq.logger.info "Scheduled #{self.name} for #{ts}."
        end

        def repeat_configured?
          !!@cronline
        end

        def already_scheduled?
          @ss ||= Sidekiq::ScheduledSet.new
          @ss.any? { |job| job.klass == self.name }
        end
      end

      class << self
        def repeatables
          @repeatables ||= []
        end

        def reschedule_all
          repeatables.each(&:reschedule)
        end

        def included(klass)
          klass.extend(Sidekiq::Repeat::Repeatable::ClassMethods)
          repeatables << klass
        end
      end
    end
  end
end
