require 'stempl/version'
require 'erb'
require 'yaml'
require 'fileutils'
require 'stempl/binder'
require 'stempl/template'
require 'stempl/gui_form'
require 'stempl/default_conf'


module Stempl
	class Generator
		def initialize(opts, names = [], vars = nil)
			@opts               = opts
			@_names             = [(opts[:names] | [names].flatten)].flatten.uniq
			@_locals            = {}
			@_last_skel         = nil
			@_processed_missing = Hash.new(false)
			(vars || {}).each do |name, val|
				register_variable(name, val)
			end
			#parse_vars(vars)
			self
		end
		
		def write_skeleton(name = nil)
			if (name.nil?) then
				@_names.each do |name|
					write_skeleton(name)
				end
				return
			end
			## read input directory
			repo = @opts[:repository]
			if repo =~ /.*\.git$/ then
				template = Stempl::Template::Git.new(repo, name)
			else
				template = Stempl::Template::Local.new(repo, name)
			end
			
			puts "PROCESSING #{name} in #{repo}" if @opts.verbose? && !@opts.dry_run?
			
			files  = template.list_files.sort
			config = read_config(files, template)
			files.reject! {|f| File.basename(f) == '.config.yaml'}
			files.reject! {|f| File.basename(f) == '.config.yaml.erb'}
			
			# create folders and
			# return a hash that maps the input file location to the output file location
			inout = setup_structure(files, template, config)
			
			## get locals for this template
			variables = @_locals.dup
			if (!config['variables'].nil?)
				variables.merge!(config['variables'])
			end
			if (!config['dialog'].nil?)
				dialogs = config['dialog']
				dialogs = [dialogs] unless dialogs.is_a?(Array)
				dialogs.each do |dialog|
					form = Stempl::GuiForm::MyGtk3.new(dialog)
					variables.merge!(form.get)
				end
			end
			
			template_binding = Stempl::Binder.new(variables)
			## copy each file, parsing .erb files
			inout.each do |finpath, fout|
				if (File.exist? fout) then
					raise "#{fout} already exists. Use --force to overwrite." unless @opts.force?
				end
				puts "\t#{finpath} -> #{fout}" if @opts.verbose? && !@opts.dry_run?
				if (finpath =~ /\.erb$/) then
					fin    = File.new(finpath, 'r')
					buffer = parse_template(fin, template_binding)
					fin.close
					if (!@opts.dry_run?)
						File.open(fout, "w+") do |skel|
							skel.write(buffer)
						end
					else
						puts "[FILE] #{fout}"
						if @opts.verbose?
							puts buffer
							puts "[EOF] #{fout}"
						end
					end
				else
					if (!@opts.dry_run?)
						FileUtils.cp(finpath, fout)
					else
						puts "[FILE] CP #{finpath} -> #{fout}"
					end
				end
			end
			# now we have to make sure that the next stempl we process knows about the variables we just put in
			@_locals = template_binding.variables.dup
			# write a yaml file containing the variable values to the target directory
			config['variables'] = template_binding.variables
			config['dialog']    = []
			if (!@opts.dry_run?)
				File.write(stempl_conf, config.to_yaml)
			else
				puts "[WRITE_STEMPLCONF] #{stempl_conf}"
				puts config.to_yaml if (@opts.verbose?)
				puts "[EOF STEMPLCONF]" if (@opts.verbose?)
			end
			
		end
		
		def parse_template(fin, template_binding)
			buffer = nil
			begin
				buffer = build(fin, template_binding)
			end
			buffer
		end
		
		def register_variable(name, value)
			@_locals[name] = value
		end
		
		private
		def build(fin, template_binding)
			# b = binding
			b = template_binding.instance_eval {binding}
			# create and run templates, filling member data variables
			# ERB.new(fin.read.gsub(/^\s+/, ""), 0, "", "@_last_skel"	).result b
			ERB.new(fin.read, 0, nil, "@_last_skel")
				.result(b)
		end
		
		def parse_vars(vars)
			return nil if vars.nil?
			vars.flatten.each do |name_val|
				name, val = name_val.split(' ', 2)
				val.gsub!(/^['"](.*)['"]$/, "\\1")
				name.gsub!(/^[\-]+/, '')
				register_variable(name, val)
			end
		end
		
		def read_config(files, template)
			## Check if template exists
			config      = Stempl::DEFAULT_CONF.merge!({'name' => File.basename(template.directory)})
			config_file = nil
			if (File.exists?stempl_conf) then
				puts '[INFO] the target directory contains a previous stempl configuration.'
				puts "[QUESTION] Do you want to use #{stempl_conf}?(Y/n)"
				answer = STDIN.readline.strip
				if (answer.upcase == "Y") then
					puts "[INFO] using #{stempl_conf}"
					config_file = stempl_conf
				else
					puts '[INFO] not using previous configuration.'
				end
			end
			
			if config_file.nil?
				config_file = files.select {|f| f == File.join(template.directory, '.config.yaml')}.first
				config_file = files.select {|f| f == File.join(template.directory, '.config.yaml.erb')}.first if config_file.nil?
			end
			
			if ((!config_file.nil?) && (File.exist? config_file))
				if (config_file =~ /\.erb$/) then
					template_binding = Stempl::Binder.new(@_locals.dup)
					fin              = File.new(config_file, 'r')
					buffer           = parse_template(fin, template_binding)
					fin.close
					puts buffer
					config = YAML.load(buffer)
				else
					config = YAML.load_file(config_file)
				end
			end
			# let us make sure that the config is accessible by string and by symbols
			config.default_proc = proc do |hash, key|
				if key.is_a?(String) and hash.keys.include?(key.to_sym) then
					hash[key.to_sym]
				
				elsif key.is_a?(Symbol) and hash.keys.include?(key.to_s) then
					hash[key.to_s]
				else
					hash.default
				end
			end
			config
		end
		
		def target_dir
			File.expand_path @opts[:target]
		end
		
		def stempl_conf
			File.join(target_dir, '.stempl_config.yaml')
		end
		
		def setup_structure(files, template, config)
			inout      = {}
			
			if (!Dir.exist? template.directory) then
				puts "[INFO] #{template.directory} does not exist."
				puts "[INFO] Do you want to create a new stempl at #{template.directory}?(Y/n)"
				answer = STDIN.readline.strip
				if (answer.upcase == "Y" or answer == "") then
					puts "Create stempl #{template.directory}"
					if (!@opts.dry_run?)
						FileUtils.mkpath template.directory
						File.write(File.join(template.directory, '.config.yaml'), Stempl::DEFAULT_CONF.merge!({'name' => File.basename(template.directory)}).to_yaml)
					else
						puts "[MKDIR-stempl] #{template.directory}"
						puts "[DEFAULT_CONF] #{File.join(template.directory, '.config.yaml')}"
						puts Stempl::DEFAULT_CONF.merge!({'name' => File.basename(template.directory)}).to_yaml
						puts "[END OF DEFAULT_CONF]"
					end
				else
					puts 'Doing nothing.'
				end
				exit
			end
			
			if (!Dir.exist? target_dir) then
				if (!@opts.dry_run?)
					FileUtils.mkpath target_dir
				else
					puts "[MKDIR-target] #{target_dir}"
				end
			end
			
			# sort according to collation. But make sure directories are always in front
			collation = (config['collate'] || []).dup
			collation = [collation] unless collation.is_a?(Array)
			collation.map! {|f| File.expand_path(f, template.directory)}
			if (@opts.verbose?) then
				puts "[CONFIG]"
				p config
			end
			directories = files.select {|f| File.directory? f}
			files       = files - directories
			# sort files by collation
			sorter      = Proc.new {|x, y| (collation.index(x) || collation.size) <=> (collation.index(y) || collation.size)}
			files       = files.sort {|x, y| sorter.call(x, y)}
			directories = directories.sort {|x, y| sorter.call(x, y)}
			
			directories.each do |dir|
				if (!@opts.dry_run?)
					FileUtils.mkpath dir.gsub(template.directory, target_dir)
				else
					puts "[MKDIR] #{dir.gsub(template.directory, target_dir)}"
				end
			end
			files.each do |fin|
				next if File.basename(fin).to_s[0] == '.'
				inout[fin] = fin.gsub(template.directory, target_dir).gsub(/\.erb$/, '')
			end
			inout
		end
	end
end
