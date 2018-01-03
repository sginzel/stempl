# Asket - Analysis SKEleton Template

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/asket`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'stempl'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install asket

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sginzel/asket. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Asket project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/asket/blob/master/CODE_OF_CONDUCT.md).

## Examples
````
NAME <%= name %>
AGE <%= age %>

<%= read 'user_input', "some user input" %>
<%= select_file 'user_file', "select some file" %>

<%= predef %>

<%= nodef %>

<%= read 'user_input', "THIS MUST NOT HAPPEN" %>
````
### Example Config

````
--- # .config.yaml
version: 0.1
collate: 
  - somatic
  - bbbb
  - zzz.txt.erb
variables:
  name: John Smith
  age: 33
form: 
  - # First window
    name: Johny doe
    age: 123
  - # second window
    blubber: select_file
    blabber: select_dir
    testeas: 
    - Hallo
    - Welt
--- # Inline
````

The template engine can also be used for the config file. Although obviously, the variables section is ignored while parsing the config file at this stage.

````
--- #.config.yaml.erb
version: 0.1
collate: 
  - somatic
  - bbbb
  - zzz.txt.erb
variables:
  name: <%= read 'name', 'give a name' %>
  age: 33
form: 
  - # First window
    name: Johny doe
    age: 123
  - # second window
    blubber: select_file
    blabber: select_dir
    testeas: 
    - Hallo
    - Welt
---
````

## Known issues
When using forms the GUI is not always destroyed properly and only closed after the application terminates.