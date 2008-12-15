module Lazydoc
  
  # Method represents a code comment for a standard method definition.
  # Methods give access to the method name, the arguments, and the 
  # trailing comment, if present.
  #
  #   sample_method = %Q{
  #   # This is the comment body
  #   def method_name(a, b='default', &c) # trailing comment
  #   end
  #   }
  #
  #   m = Document.new.register(2, Method)
  #   m.resolve(sample_method)
  #   m.method_name          # => "method_name"
  #   m.arguments            # => ["a", "b='default'", "&c"]
  #   m.trailer              # => "trailing comment"
  #   m.to_s                 # => "This is the comment body"
  #
  class Method < Comment
    
    # Matches a standard method definition.  After the match:
    #
    #   $1:: the method name
    #   $2:: the argument string, which may be parsed by parse_args
    #
    METHOD_DEF = /^\s*def (\w+)(.*)$/
    
    # The resolved method name
    attr_reader :method_name
    
    # An array of the resolved arguments for the method
    attr_reader :arguments
    
    def initialize(*args)
      super
      @method_name = nil
      @arguments = []
    end
    
    # Overridden to parse and set the method_name, arguments, and 
    # trailer in addition to setting the subject.
    def subject=(value)
      unless value =~ METHOD_DEF
        raise ArgumentError, "not a method definition: #{value}"
      end
      
      @method_name = $1
      @arguments = scan_args($2)
  
      super
    end
  end
end
