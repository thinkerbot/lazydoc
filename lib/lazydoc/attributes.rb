module Lazydoc
  
  # Attributes adds methods to declare class-level accessors for Lazydoc 
  # attributes.
  #
  #   # ConstName::key value
  #   class ConstName
  #     extend Lazydoc::Attributes
  #
  #     lazy_attr :key
  #   end
  #
  #   ConstName.source_file            # =>  __FILE__
  #   ConstName::key.subject           # => 'value'
  # 
  module Attributes

    # The source file for the extended class.  By default source_file
    # is set to the file where Attributes extends the class (if you 
    # include Attributes, you must set source_file manually).
    attr_accessor :source_file
    
    def self.extended(base) # :nodoc:
      caller[1] =~ CALLER_REGEXP
      base.source_file ||= $1
    end
    
    def const_attrs
      @const_attrs ||= {}
    end

    # Returns the Document for source_file
    def lazydoc(resolve=true)
      lazydoc = Lazydoc[source_file]
      lazydoc.resolve if resolve
      lazydoc
    end

    # Creates a lazy attribute accessor for the specified attribute.
    def lazy_attr(key, comment_class=Attribute, line_number=nil)
      instance_eval %Q{
def #{key}
  (const_attrs['#{key}'] ||= #{comment_class}.new(#{line_number.inspect}, Lazydoc[source_file])).resolve
end

def #{key}=(comment)
  const_attrs['#{key}'] = comment
end}
    end
    
    # Registers the next method.
    def register_method___(key, comment_class=Method)
      lazydoc(false).register___(comment_class, 1)
    end
  end
end
