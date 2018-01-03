# STEMPL - Skeleton TEMPLate
stempl is a simple tool to create the same files and folder structure (skeleton) from a template directory. 
Each .erb file in the template is parsed using the ERB template engine, which allows customization of the skeleton if neccessary.
This is useful if you need to repeatedly create similar skeleton with dynmaic content, such as project names or parameters.  

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'stempl', :git => 'git://github.com/sginzel/stempl.git'
```

And then execute:

    $ bundle

Or build and install it yourself as:

    $ git clone git://github.com/sginzel/stempl && cd stempl && bundle install && gem build stempl && gem install -g stempl

## Usage
````
stempl [options] --varname \'var value\' names
    -r, --repository  Template location (local or remote git, default: ~/.stempl)
    -t, --target      Target directory for skeletons, default: .
    -f, --force       force overwrite (default: false)
    -v, --verbose     enable verbose mode
    -q, --quiet       suppress output (quiet mode)
    -d, --dry-run     dry-run - do not create any files or directories, just print the actions
    --names           Name of skeleton
    --version         print the version
    -h, --help
````
Please not that names of stempl templates must not contain spaces.

### Example usage
```` 
# Clone a simple demultiplex workflow to a new subfolder in the current directory
stempl -d -t demultiplex_today \
       -r https://github.com/sginzel/stempl-examples.git \
       demultiplex
````
This will download the repository using `git clone` to a temporary directory and use the demultiplex template.
Please make sure that `git` is available on your system. 
  

## Create a new Stempl
To create a new stempl template you can either create one at ~/.stempl or have `stempl` create one for you
````
# For production remove -d and -v option (verbosive dry-run)
stempl -d -v -t target new_stempl
[INFO] ~/.stempl/ew_stempl does not exist.
[INFO] Do you want to create a new stempl at ~/.stempl/ew_stempl?(Y/n)
Y
Create stempl ~/.stempl/new_stempl
[MKDIR-stempl] ~/.stempl/new_stempl
[DEFAULT_CONF] ~/.stempl/new_stempl/.config.yaml
---
name: new_stempl
version: 0.01
collate: []
variables: []
dialog: []
[END OF DEFAULT_CONF]
````

Each file or folder that is created in the new_stempl directory will now be copied to the target location when `stempl -t target new_stempl` is called.

The configuration of a stempl will be copied to the target location with the name .stempl_config.yaml. 
If the target is used again predefined dynamic values can be used from the that config. 

## Dynamic templates
Every file and folder is simply copied from the template to the target directory. 
The only exception are .erb files, which are parsed with the ERB template engine to customize the templates. 

If user input is required use `cli_read` and `cli_select_file` to read values from the command prompt. 
While parsing the template undefined variables are detected and a `cli_read` command prompt will query a values from the user. 
This is repeated until no undefinded variables are found.

### .config.yaml

````
--- # .config.yaml
name: 
version: 0.1
collate: 
  - file_zzz
  - file_aaa
  - file_cca
variables:
  name: John Smith
  age: 33
dialog: 
  - # Dialog #1
    name: Johny doe
    age: 123
  - # Dialog #2
    favorite_file: select_file
    favorite_directory: select_dir
    favorite_food: 
    - Pizza
    - Salad
--- 
````

- *name* - name of the stempl. 
- *version* - version (for future use)
- *collate* - Order in which files should be processed. This can be important when defining one which is used in multiple files. 
 Any file not present in the collate field is appended to the collation and sorted alphabetically. 
- *variables* - A lookup for predefined variables.
- *dialog* - An array of hashes that are used to build the dialogs. 

The template engine can also be used for the config file. 
Although obviously, the variables section is ignored while parsing the config file at this stage.

````
--- # .config.yaml
name: 
version: 0.1
collate: 
  - file_zzz
  - file_aaa
  - file_cca
variables:
  name: <%= cli_read('person_name', 'give a default name')%>
  age: 33
dialog: 
  - # Dialog #1
    name: <%= person_name %>
    age: 123
  - # Dialog #2
    favorite_file: select_file
    favorite_directory: select_dir
    favorite_food: 
    - Pizza
    - Salad
--- 
````

If you want to use a more familiar syntax you can also do this
````
<%=
{
    'name' => 'Some Name'
    'version' => 0.1,
    'collate' => %w( file_zzz file_aaa file_cca ), 
    'variables' => {
        'name' => cli_read('person_name', 'give a default name')
        'age' => 33
    },
    'dialog' => [
     { 'name' => person_name, 'age' => 123 },
     { 'favorite_file' => select_file, 'favorite_folder' => select_dir, 'favorite_food' => %w(Pizza Salad)}
    ]
}.to_yaml %>
````

Variables can also be pre defined in the .config.yaml
````
variables:
  name: John Smith
  age: 33
````

or passed on as parameters 

`stempl -t target new_stempl --name \'Johny Smith\' --age 33`

Of course you will run into trouble if your variable names correspond to an option recognized by stempl. 
Please use \\' to quote strings with spaces from a command line.  

### Dialogs
Dialogs are displayed using GTK3 and the input types are determined by the default values provided in the .config.yaml.
 Each entry in the dialog-field is opened as a new dialog window. 
````
dialog: 
  - # First dialog window
    name: John Doe
    age: 32
  - # Second dialog window
    favorite_file: select_file
    favorite_folder: select_dir
    favorite_food: 
    - Pizza
    - Salad
````
Strings and Numbers will result in text boxes, select_file and select_dir will provide file and folder selections, if the default value is an array a combobox will be displayed.  

#### Known issues
When using dialogs the GUI is not always destroyed properly and only closes after the application terminates.

## Examples
### Home directory skeleton
This simple skeleton reads the standard .bashrc and appends a customized history size.
The welcome message is customized if the user is an admin. 
````
# .bashrc.erb
<%= File.open('/etc/skel/.bashrc', 'r').read %>

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=<%= cli_read 'histsize', 'How many records should be in the history? ' %>
HISTFILESIZE=<%= cli_read 'histfilesize', 'How big should the history file be? ' %>

echo '###########################################'
echo 'Welcome <%= username %> to your new account'
echo '<%= (is_admin == "true")?("YOU ARE ADMIN"):("") %> '
echo '###########################################'

````

````
---- # .config.yaml.erb
name: homeskeleton
version: 0.1
collate: 
  - .bashrc
variables:
dialog: 
  - 
    username:  
    histsize: <%= cli_read 'histsize', 'Tell me the histsize on the console please' %>
    histfilesize: <%= (histsize).to_i*2 %>
    is_admin: 
      - Yes
      - No
---
````

#### Notes
YAML was designed as a readable format and does this job well. 
Unfortunately this means that 'yes' and 'no' are converted into true/fals when the .yaml file is parsed.
That is why line #10 in .bashrc.erb does not check `is_admin == 'Yes'`. 

All values which are read over the console or dialog are stored as strings/text. 
Keep this in mind if you want to work with numbers (e.g. line #11 of .config.yaml.erb)



## Development
In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/asket`. To experiment with that code, run `bin/console` for an interactive prompt.

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sginzel/asket. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Asket project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/asket/blob/master/CODE_OF_CONDUCT.md).
