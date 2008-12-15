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
      @const_attrs ||= Document[to_s]
    end
    
    def registered_methods
      @registered_methods ||= {}
    end

    # Returns the Document for source_file
    def lazydoc(resolve=true)
      lazydoc = Lazydoc[source_file]
      lazydoc.resolve if resolve
      lazydoc
    end

    # Creates a lazy attribute accessor for the specified attribute.
    def lazy_attr(key)
      instance_eval %Q{
def #{key}
  comment = const_attrs['#{key}'] ||= Subject.new(nil, Lazydoc[source_file])
  comment.kind_of?(Comment) ? comment.resolve : comment
end

def #{key}=(comment)
  const_attrs['#{key}'] = comment
end}
    end
    
    def method_added(sym)
      ancestors.each do |parent|
        break unless parent.respond_to?(:registered_methods)
        
        if comment_class = parent.registered_methods[sym]
          const_attrs[sym] = Lazydoc.register_caller(comment_class, 3)
        end
      end
      
      super
    end
    
    def lazy_register(key, method_name=key, comment_class=Method)
      registered_methods[method_name.to_sym] = comment_class
      instance_eval %Q{
def #{key}
  comment = const_attrs[:#{method_name}]
  comment.kind_of?(Comment) ? comment.resolve : comment
end

def #{key}=(comment)
  const_attrs[:#{method_name}] = comment
end}
    end
    
    # Registers the next comment (by default as a Method).
    def register___(comment_class=Method)
      lazydoc(false).register___(comment_class, 1)
    end
  end
end
