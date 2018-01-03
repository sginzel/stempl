require 'asket/version'
require 'erb'
require 'yaml'
require 'fileutils'
require 'asket/binder'
require 'asket/template'
require 'asket/gui_form'

module Asket
	class Generator
		def initialize(opts, names = [], vars = nil)
			@opts       = opts
			@_names     = [(opts[:names] | [names].flatten)].flatten.uniq
			@_locals = {}
			@_last_skel = nil
			@_processed_missing = Hash.new(false)
			parse_vars(vars)
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
			repo       = @opts[:repository]
			if repo =~ /.*\.git$/ then
				template = Asket::Template::Git.new(repo, name)
			else
				template = Asket::Template::Local.new(repo, name)
			end
			
			files = template.list_files.sort
			config = read_config(files, template)
			files.reject!{|f| File.basename(f) == '.config.yaml'}
			files.reject!{|f| File.basename(f) == '.config.yaml.erb'}
			
			# create folders and
			# return a hash that maps the input file location to the output file location
			inout = setup_structure(files, template, config)
			
			## get locals for this template
			variables = @_locals.dup
			if (!config['variables'].nil?)
				variables.merge!(config['variables'])
			end
			if (!config['form'].nil?)
				confs = config['form']
				confs = [confs] unless confs.is_a?(Array)
				confs.each do |conf|
					form = Asket::GuiForm::MyGtk3.new(conf)
					variables.merge!(form.get)
				end
			end
			
			template_binding = Asket::Binder.new(variables)
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
						FileUtils.cp(fin, fout)
					else
						puts "[FILE] CP #{finpath} -> #{fout}"
					end
				end
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
			b = template_binding.instance_eval{ binding }
			# create and run templates, filling member data variables
			# ERB.new(fin.read.gsub(/^\s+/, ""), 0, "", "@_last_skel"	).result b
			ERB.new(fin.read, 0, nil, "@_last_skel"	)
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
			puts "PROCESSING #{name} in #{repo}" if @opts.verbose? && !@opts.dry_run?
			config = {}
			config_file = files.select{|f| f == File.join(template.directory, '.config.yaml')}.first
			config_file = files.select{|f| f == File.join(template.directory, '.config.yaml.erb')}.first if config_file.nil?
			
			if ((!config_file.nil?) && (File.exist?config_file))
				if (config_file =~ /\.erb$/) then
					puts "READING YAML ERB"
					template_binding = Asket::Binder.new(@_locals.dup)
					fin    = File.new(config_file, 'r')
					buffer = parse_template(fin, template_binding)
					fin.close
					puts buffer
					config = YAML.load(buffer)
				else
					config = YAML.load_file(config_file)
				end
			end
			config
		end
		
		def setup_structure(files, template, config)
			inout = {}
			target_dir = File.expand_path @opts[:target]
			
			if (!Dir.exist?template.directory) then
				if (!@opts.dry_run?)
					FileUtils.mkpath template.directory
				else
					puts "[MKDIR] #{template.directory}"
				end
			end
			# sort according to collation. But make sure directories are always in front
			collation = (config['collate'] || [])
			collation = [collation] unless collation.is_a?(Array)
			collation.map!{|f| File.expand_path(f, template.directory)}
			if (@opts.verbose?) then
				puts "CONFIG"
				p config
			end
			directories = files.select{|f| File.directory?f }
			files = files - directories
			# cort files by collation
			sorter = Proc.new{|x,y|	(collation.index(x) || collation.size) <=> (collation.index(y) || collation.size) }
			files = files.sort{|x,y| sorter.call(x,y) }
			directories = directories.sort{|x,y| sorter.call(x,y) }
			
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
