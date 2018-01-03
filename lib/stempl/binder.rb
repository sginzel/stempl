require 'ostruct'
require 'stempl/binder_input'

module Stempl
	class Binder
		def initialize(variables)
			@variables = variables
		end
		
		def register_variable(name, value)
			@variables[name] = value
		end
		
		def get_variable(name)
			@variables[name]
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
		
		def method_missing(meth, *args)
			if self[meth].nil? then
				read(meth, "Undefined variable (#{meth}) found:")
			else
				self[meth]
			end
		end
		
	end
	
end
