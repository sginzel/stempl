module Stempl
	module BinderInput
		def read(name, description = "Value for #{name}:")
			val = @binder.get_variable(name)
			if (val.nil?) then
				print description + " "
				val = STDIN.readline.strip
				@binder.register_variable(name, val)
			end
			@binder.get_variable(name)
		end
		
		def select_file(name, description = "Value for #{name}:")
			val = @binder.get_variable(name)
			if (val.nil?) then
				val = nil
				while val.nil? or !File.exist?(val)
					print description + "\n"
					val = STDIN.readline.strip
					if !File.exist?(val) then
						print "\n"
						print "File #{val} does not exist. Try again."
					end
				end
				@binder.register_variable(name, val)
			end
			@binder.get_variable(name)
		end
		
	end
end