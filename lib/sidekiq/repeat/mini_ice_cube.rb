module Sidekiq
  module Repeat
    ##
    # This is a mini compatibility layer for the ice_cube syntax. Nothing fancy.
    # It only supports interval-based -ly functions like "hourly(4)" and array
    # list information like .minute_of_hour(0,15,30,45), as these are the ones
    # that we use.
    module MiniIceCube
      module IceCubeDslErrorHandling
        IceCubeSyntaxError = Class.new(StandardError)

        def unsupported(msg)
          fail IceCubeSyntaxError, "Sidekiq::Repeat: Unsupported ice_cube syntax. Please refer to the documentation. (#{msg})"
        end

        def method_missing(meth, *args, &block)
          unsupported("method not found: #{meth}")
        end
      end

      class CronSyntax
        include IceCubeDslErrorHandling

        class << self
          def define_items_method(name, slot)
            define_method(name) do |*args|
              unsupported("invalid arguments for #{name}") unless args.any? && args.all? { |i| i.is_a?(Integer) || i =~ /\d+/ }
              @slots[slot] = args.map(&:to_s).join(',')
              self
            end
          end
        end

        def initialize(*args)
          @slots = args
        end

        def to_s
          @slots.map(&:to_s).join(' ')
        end

        define_items_method(:minute_of_hour, 0)
        define_items_method(:hour_of_day, 1)
        define_items_method(:day_of_month, 2)
      end

      class MainDsl
        include IceCubeDslErrorHandling

        class << self
          def define_interval_method(name, base, *stars_prefix)
            define_method(name) do |*args|
              stars = stars_prefix.dup || []

              if args.any?
                interval = args.first.to_i
                unsupported("invalid interval: #{interval}") unless interval && interval >= 0 && interval <= base

                # Instead of always calculating the next() occurrence as ice_cube does,
                # we can only have fixed run times (as per cron syntax). Hence we calculate
                # the run times based on integer division of interval and time frame, using
                # a random start offset based on the remaining time.
                #
                # NOTE: This effectivly means that after the last run in the time frame the
                #       next run will be scheduled after interval+remainder.
                #
                # Example: minutely(17) will run 3 times per hour. After the last run each
                #          hour the skip will be 17 + 9 = 26 minutes. A random offset in
                #          [0,26) will be applied, so a possible cron line could be '4,21,38'.

                times = []
                nruns = (base / interval).floor
                rnoff = rand(interval + base % interval).floor
                runs  = nruns.times.map { |i| i * interval + rnoff }
                stars << runs.map(&:to_s).join(',')
              end

              stars.fill('*', stars.size..4)
              CronSyntax.new(*stars)
            end
          end
        end

        def weekly(*args)
          unsupported('interval argument unsupported for weekly') unless args.empty?
          CronSyntax.new(0, 3, '*', '*', 0)             # Sundays at 3AM.
        end

        define_interval_method(:minutely, 60)
        define_interval_method(:hourly, 24, 0)          # At first minute of hour.
        define_interval_method(:daily, 31, 0, 3)        # At night, 3AM.
        define_interval_method(:monthly, 12, 0, 3, 0)   # First day of the month, 3AM.
      end
    end
  end
end
