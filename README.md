# MachO's Other Tool

`mootool` is an attempt at an open source replacement to the legandary `jtool2` allowing it to continue to progress
with the Apple research community.  Ruby was selected as [Homebrew](https://brew.sh) maintains a good Mach-O parser
that is pure (meaning it needs no dependencies other then a Ruby runtime).

As a secondary goal every command should provide output both in human readable as well as machien readable (YAML)
format making it suitable for use in scripting.

## Installation

Install this utility by running `gem install mootool`

The code can also be used as a library with `gem 'mootool'`

## Usage

* `kc`
  * `list`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/mootool. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Mootool project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/mootool/blob/master/CODE_OF_CONDUCT.md).
