require 'ostruct'
require 'stempl/binder_input'

module Stempl
	class Binder
		attr_reader :variables, :repository, :target_dir
		attr_accessor :source, :target
		
		def initialize(variables, repository, target_dir)
			@variables = variables
			@source = nil
			@target = nil
			@repository = repository
			@target_dir = target_dir
		end
		
		def register_variable(name, value)
			@variables[name.to_s] = value
		end
		
		def get_variable(name)
			@variables[name.to_s]
		end
		
		def binding
			BinderStruct.new(@variables, self).instance_eval{ binding }
		end
	end
	
	class BinderStruct < OpenStruct
		
		include Stempl::BinderInput
		
		def initialize(variables, binder)
			super variables
			@binder = binder
		end
		
		def method_missing(meth, *args, &block)
			if !@binder.respond_to?(meth) then
				if self[meth].nil? then
					cli_read(meth, "Undefined variable (#{meth}) found:")
				else
					self[meth]
				end
			else
				@binder.send(meth, *args, &block)
			end
		end
		
	end
	
end
