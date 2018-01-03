require 'fileutils'
require 'tmpdir'
require 'open-uri'
#' Purpose of this module is to have a unified way to read files from a provided location
#' Remote locations are downloaded into a temporary directory
module Stempl
	module Template
		
		class Base
			def initialize(location, name)
				@location = location
				@name = name
			end
			
			def list_files
				Dir[File.join(self.directory, '**/*')] + Dir[File.join(self.directory, '**/.*')]
			end
			
			def directory
				File.join(@location, @name)
			end
		
		end
		
		class Local < Base
			def directory
				File.expand_path(File.join(@location, @name))
			end
		end
		
		class Git < Base
			def initialize(location, name)
				super location, name
				# check git
				check_git
				@download_dir = nil
				setup_directory
				if !download_template then
					raise "Could not get repository from #{location}. Check #{@download_dir}"
				end
			end
			
			def setup_directory
				if (@download_dir.nil?)
					basename = @location.split('//', 2).last
					tmpdir = File.join(Dir.tmpdir, ".stempl", basename)
					if (!Dir.exist?tmpdir)
						FileUtils.mkpath tmpdir, :mode => 0700
					end
					@download_dir = tmpdir
				end
			end
			
			def directory
				File.join(@download_dir, @name)
			end
			
			def download_template
				init_git = ''
				pull_git = 'git pull origin master'
				local_copy = File.join(@download_dir, @name)
				if (Dir.exist?(File.join(@download_dir, '.git'))) then
					puts "A git repository exists at #{@download_dir}"
					if (!Dir.exist?(local_copy)) then
						puts "The template #{@name} does not exist yet"
						puts 'Do you want to do `git pull origin master` [Y/n]'
						answer = STDIN.readline.strip
						answer = 'y' if answer == ''
						while !answer =~ /^[YynN]$/ do
							answer = STDIN.readline.strip
						end
						if (answer.downcase == 'y') then
							pull_git = 'git reset --hard origin/master'
						else
							return false
						end
					end
				end
				if (!Dir.exist?(local_copy)) then
					init_git =
<<EOS
					git init
					git remote add origin -f #{@location}
EOS
				end
				
				cmd =
<<EOF
				cd #{@download_dir}
				#{init_git}
				git config core.sparsecheckout true
				echo "#{@name}/*" >> .git/info/sparse-checkout
				#{pull_git}
EOF
				result = system(cmd)
				if (result == false)
					raise "Something went wrong at GIT #{@location} #{@name}"
				end
				true
			end
			
			def check_git
				begin
					`git --version`
				rescue Errno::ENOENT => e
					raise "Git is not available in #{ENV[:PATH] || ENV[:path]}"
				end
			end
		end
	end
end