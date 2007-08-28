require 'rexml/document'

class Flag
	
	attr_accessor :id
	attr_accessor :name
	attr_accessor :description
	attr_accessor	:status
	attr_accessor	:explicit
	attr_accessor :my_implicit_setters
	attr_accessor :architecture
	attr_accessor :repository

	attr_accessor :implicit_setter_cache


	def explicit_set?
		if self.explicit == true
			return true
		elsif self.explicit == false
			return false
		else
			raise
		end
	end
	
	
	def disabled?
		case self.status
			when 'enable'
				return false
			when 'disable'
				return true
			when 'default'
				return self.implicit_setter.disabled?
		end
	end
	
	
	def enabled?
		return false if self.disabled?
		return true
	end	
	
	#this function returns the setter object, which the status of 'self' defines
	def implicit_setter
			
		#only one setter
		if self.my_implicit_setters.kind_of? Flag
			if self.my_implicit_setters.explicit_set?
				return self.my_implicit_setters
			else
				
				return self.my_implicit_setters.implicit_setter
			end
		end
		
		#two setters
		if self.my_implicit_setters.kind_of? Array and self.my_implicit_setters.size == 2
			candidate = self.my_implicit_setters[0].oder(self.my_implicit_setters[1])
			if candidate.explicit_set?
				return candidate
			else
				return candidate.implicit_setter 
			end
		end
		
#		#three setters
#		if self.my_implicit_setters.kind_of? Array and self.my_implicit_setters.size == 3
#			candidate = self.my_implicit_setters[0].oder(self.my_implicit_setters[1])
#					
#			#candidate = candidate.oder(self.my_implicit_setters[2])
#					
#			if candidate.explicit_set?
#					return candidate
#			end
#					
#			if self.my_implicit_setters[2].explicit_set?
#					return self.my_implicit_setters[2]
#			end
#					
#			return self.my_implicit_setters[2].implicit_setter		
#		end		
		
		
		#four setters
		if self.my_implicit_setters.kind_of? Array and self.my_implicit_setters.size == 4	
			candidate = self.my_implicit_setters[0].oder(self.my_implicit_setters[1])
			
			
			candidate = candidate.oder(self.my_implicit_setters[2])
			
			if candidate.explicit_set?
				return candidate
			end
			
			if self.my_implicit_setters[3].explicit_set?
				return self.my_implicit_setters[3]
			end
			
			return self.my_implicit_setters[3].implicit_setter		
		end
		raise RuntimeError.new("[FLAG:] Could not find a valid implicit setter for #{self.inspect}. Maybe no such setter exists?")
	end
	
	
	#little 'or' alternative.  
	def oder(n)
		return self if n.nil?
		return self if self.explicit_set? and self.status == 'enable'
		return n if n.explicit_set? and n.status == 'enable' unless n.id == 'all::all'
		return self if self.explicit_set?
		return n if n.explicit_set?	
		return self
	end
	
	
	#set the flags which determine the status of 'self'. the order is very important!
	#'firstflag' will be tested and used rather than 'fourthflag'.
	def set_implicit_setters( firstflag, secondflag=nil, thirdflag=nil, fourthflag=nil)
		setters = nil
		if secondflag.nil?
			setters = firstflag
		elsif thirdflag.nil?
			setters = [firstflag, secondflag]
		elsif fourthflag.nil?
			setters = [firstflag, secondflag, thirdflag]
			#raise RuntimeError.new("[FLAG:] One, two or four parameters expected. \n #{self.inspect}")
		else
			setters = [firstflag, secondflag, thirdflag, fourthflag]
		end
		self.my_implicit_setters = setters		
	end

	
	def to_xml
		raise RuntimeError.new( "FlagError: No flag-status set. \n #{self.inspect}" ) if self.status.nil?
		xml_element = REXML::Element.new(self.status.to_s)
		xml_element.add_attribute REXML::Attribute.new('arch', self.architecture) unless self.architecture.nil?
		xml_element.add_attribute REXML::Attribute.new('repository', self.repository) unless self.repository.nil?
		return xml_element
	end		

	
	def toggle_status
		if self.id == 'all::all' and self.my_implicit_setters.nil?
		#the project default flag is toggled
			case self.status
				when 'enable'
					self.status = 'disable'
					self.explicit = true
			when 'disable'
				self.status = 'enable'
				self.explicit = true
			else
				raise RuntimeError.new("Unknown flag type #{self.status}")
			end	
		else
			case self.status
				when 'enable'
					self.status = 'disable'
					self.explicit = true
				when 'disable'
					self.status = 'default'
					self.explicit = false				
				when 'default'
					self.status = 'enable'
					self.explicit = true					
				else
					raise RuntimeError.new("Unknown flag type #{self.status}")
			end
		end
	end	
	
end

