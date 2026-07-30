# macOS' Other Tooling

`mootool` operates as an experimental system with low friction to extension and experimentation.  This allows reverse
engineering of undocumented Apple formats, such as IMG4 / DER data for yet unknown formats.  It specializes in newer
concepts such as `LocalPolicy`, `FDR` and the SEP / SE.  It pairs perfectly with 
[`apple-knowledge`](https://github.com/hack-different/apple-knowledge) to offload the data vs the code. 

`mootool` is also an attempt at an open source replacement to the legendary `jtool2` allowing it to continue to progress
with the Apple research community. Ruby was selected as [Homebrew](https://brew.sh) maintains a good Mach-O parser
that is pure (meaning it needs no dependencies other than a Ruby runtime).

As a secondary goal every command should provide output both in human-readable and machine-readable (YAML/JSON)
format making it suitable for use in scripting.

## Installation

Install this utility by running `gem install mootool` for the current version on RubyGems.

The code can also be used as a library with `gem 'mootool'`

The development version can be installed with:

```bash
$ bundle install
$ rake install
```

## Usage

* `img4` - IMG4, Payload, Manifest
  * `index` - Indexes known paths where IMG4 files exist and creates an index based on the SHA hashes
  * `print` - Display detailed information about an IMG4 payload, including APTicket, IM4P, LocalPolicy and FDR
* `cert` - Apple Issued Certificates
  * `index` - Creates an index of loose certificates, as well as those in IMG4 payloads
  * `print` - Displays a certificate, its linked resources, and decodes X509 extensions
* `activation` - `MobileActivation`
  * `print` - Shows decoded data from MobileActivation requests such as the issuance of `dcrt`, `scrt`, `sdcrt`, `ucrt`
     `KeyRecoveryAssistant` and more.  Parses both requests and responses from `/System/Volumes/Hardware/MobileActivation`
* `kc` - KernelCollections
    * `list`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can
also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the
version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/mootool. This project is intended
to be a safe, welcoming space for collaboration, and contributors are expected to adhere to
the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Mootool project’s codebases, issue trackers, chat rooms and mailing lists is expected to
follow the [code of conduct](https://github.com/[USERNAME]/mootool/blob/master/CODE_OF_CONDUCT.md).
