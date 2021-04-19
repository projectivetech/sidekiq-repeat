# Sidekiq::Repeat

Another recurrent job scheduler for Sidekiq. Clockless.

## Credits

This gem takes the clockless scheduling approach of (and a lot of code from) [Sidekiq::Dejavu](https://github.com/felixbuenemann/sidekiq-dejavu) by Felix Bünemann and adapts it to the in-code configuration style of [Sidetiq](https://github.com/tobiassvn/sidetiq) by Tobias Svensson. Thanks to both for their great gems.

## Usage

### cron-style recurrence notation

```ruby
require 'sidekiq'
require 'sidekiq-repeat'

class TestWorker
  include Sidekiq::Worker
  include Sidekiq::Repeat::Repeatable

  # Every Sunday at 3AM.
  repeat { '0 3 * * 0' }

  def perform
  end
end
```

### Sidetiq/ice_cube-style recurrence notation

Check [the code](lib/sidekiq/repeat/mini_ice_cube.rb) for documentation.

```ruby
[...]
  # Every other hour.
  repeat { hourly(2) }
[...]
```

## Development

```sh
# setup
bundle install

# Run the tests
bundle exec rake test

```

## License

[MIT](LICENSE).
