# STEMPL - *S*keleton *TEMPL*ate
stempl is a simple tool to create the same files and folder structure (skeleton) from a template directory. 
Each .erb file in the template is parsed using the ERB template engine, which allows customization of the skeleton if neccessary.
This is useful if you need to repeatedly create similar skeletons with minor differences in content.  

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'stempl', :git => 'git://github.com/sginzel/stempl.git'
```

And then execute:

    $ bundle

Or build and install it yourself as:

    $ git clone git://github.com/sginzel/stempl && cd stempl && bundle install && gem build stempl && gem install -g stempl

stempl was developed and tested with ruby 2.3.3, but anything >2.0 should work without guarantees.   

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

### Template commands
- <% ... %> - execute code that is inside <% %> brackets.  
- <%= ... %> - execute code and add the last return value to the skeleton. Nesting is not possible. 
- *cli_read (varname, prompt)* - query a value through the command line (alias: `read`).
- *cli_select_file (varname, prompt)* - select a file through the command line (alias: `select_file`).
- *dialog ({varname: "default value", ...})* - Opens a GUI dialog to prompt for user input. 
- *dialog (["varname1", "varname2", ...]})* - `dialog()` can also handle arrays and defaults to text input. 
- *repository* - the template repository location.
- *target_dir* - the location of the skeleton to generate.
- *source* - template file location.
- *target* - skeleton file location. Is `nil` when the file is included in `nocopy` section of the config file.

### Configuration
 Add a YAML file named `.config.yaml` to the template directory to configure the parsing process. 

````
--- # .config.yaml
name: 'Some Name'
version: 0.1
collate: 
  - file_zzz
  - file_aaa
  - file_cca
exclude: 
  - bbb.*
nocopy: 
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
- *exclude* - Files to be excluded from the template
- *nocopy* - These files are only passed through the template engine, but the result is not copied to the skeleton. 
These files require the .erb extension and can be used to execute code while processing a template. 
- *variables* - A lookup for predefined variables. Can also be given on the command line `stempl some_stempl --name \'John Doe\' --age 33`.
Of course you will run into trouble if your variable names correspond to an option recognized by stempl. 
Please use \\' to quote strings with spaces from a command line.   
- *dialog* - An array of hashes that are used to build the dialogs. 

The template engine can also be used for the config file. 
Although obviously, the variables section is ignored while parsing the config file at this stage.

````
--- # .config.yaml
name: 'Some Name'
version: 0.1
collate: 
  - file_zzz
  - file_aaa
  - file_cca
exclude: 
  - bbb.*
nocopy: 
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

If you want to use a more familiar syntax you can also parse a Has into a yaml when parsing the .config.yaml.erb template.
````
<%=
{
    'name' => 'Some Name'
    'version' => 0.1,
    'collate' => %w( file_zzz file_aaa file_cca ), 
    'collate' => %w( file_zzz file_aaa file_cca ),
    'exclude' => 'bbb.*',
    'nocopy' => 'file_cca',
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
Strings and numbers will result in text boxes, select_file and select_dir will provide file and folder selections, if the default value is an array a combobox will be displayed.  

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
exclude: []
nocopy: []
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

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sginzel/stempl. 
This project is intended to be a safe, welcoming space for collaboration, and contributors 
are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Stempl project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/sginzel/stempl/blob/master/CODE_OF_CONDUCT.md).
