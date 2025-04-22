module Sidekiq
  module Repeat
    module Repeatable
      module ClassMethods
        def repeat(&block)
          @block = block
        end

        def cronline
          return @cronline if @cronline
          return if @block.nil?
          @cronline = MiniIceCube::MainDsl.new.instance_eval(&@block).to_s
          @cronline = CronParser.new(@cronline)

        rescue ArgumentError
          fail "repeat '#{@cronline}' in class #{self.name} is not a valid cron line"
        end

        def reschedule
          # Only if repeat is configured.
          return unless !!cronline

          ts   = cronline.next
          args = [Time.now.to_f, ts.to_f].take(instance_method(:perform).arity)
          nj   = next_scheduled_job

          if nj
            if nj.at > ts
              nj.item['args'] = args
              nj.reschedule ts.to_f
              Sidekiq.logger.info "Re-scheduled #{self.name} for #{ts}."
            end
          else
            jid = self.perform_at ts.to_f, *args
            Sidekiq.logger.info "Scheduled #{self.name} for #{ts} with jid `#{jid.inspect}`."
          end
        end

        def next_scheduled_job
          @ss ||= Sidekiq::ScheduledSet.new
          @ss.find { |job| job.klass == self.name }
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
