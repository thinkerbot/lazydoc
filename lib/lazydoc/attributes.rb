module Lazydoc
  
  # Attributes adds methods to declare class-level accessors for constant
  # attributes.
  #
  #   # ConstName::key value
  #   class ConstName
  #     extend Lazydoc::Attributes
  #     lazy_attr :key
  #   end
  #
  #   ConstName.source_file            # =>  File.expand_path(__FILE__)
  #   ConstName::key.subject           # => 'value'
  # 
  # ==== Keys and Register
  #
  # Note that constant attributes parsed from a source file are stored in
  # const_attrs, and will ALWAYS be keyed using a string (since the 
  # 'ConstName::key' syntax specifies a string key).
  #
  #   ConstName.const_attrs['key']     # => ConstName::key
  #
  # 'Constant Attributes' specified by non-string keys are sometimes used to
  # tie comments to a constant that will NOT be resolved from the constant
  # attribute syntax.  For instance you could register a method like this:
  #
  #   class Sample
  #     extend Lazydoc::Attributes
  #
  #     const_attrs[:method_one] = register___
  #     # this is the method one comment
  #     def method_one
  #     end
  #   end
  #
  #   Sample.lazydoc.resolve
  #   Sample.const_attrs[:method_one].comment   # => "this is the method one comment"
  # 
  # For easier access, you could define a lazy_attr to access the registered
  # comment.  And in the simplest case, you pair a lazy_register with a
  # lazy_attr.
  #
  #   class Paired
  #     extend Lazydoc::Attributes
  #
  #     lazy_attr(:one, :method_one)
  #     lazy_attr(:two, :method_two)
  #     lazy_register(:method_two)
  #
  #     const_attrs[:method_one] = register___
  #     # this is the manually-registered method one comment
  #     def method_one
  #     end
  #
  #     # this is the lazyily-registered method two comment
  #     def method_two
  #     end
  #   end
  #
  #   Paired.lazydoc.resolve
  #   Paired.one.comment      # => "this is the manually-registered method one comment"
  #   Paired.two.comment      # => "this is the lazyily-registered method two comment"
  #
  module Attributes
    
    # The source file for the extended class.
    # 
    # By default source_file is set to the file where Attributes extends the class
    # (if you include Attributes, you must set source_file manually).  Classes that
    # inherit from the extended class will set source_file to the file where
    # inheritance first occurs.
    attr_accessor :source_file
    
    # Sets source_file as the file where Attributes first extends the class.
    def self.extended(base)
      caller[1] =~ CALLER_REGEXP
      base.source_file ||= File.expand_path($1)
      super
    end
    
    # Inherits registered_methods from parent to child.  Also registers the
    # source_file for the child as the file where the inheritance first occurs.
    def inherited(child)
      unless child.source_file
        caller.each do |call|
          next if call =~ /in `inherited'$/
          
          call =~ CALLER_REGEXP
          child.source_file = File.expand_path($1)
          break
        end
      end
      
      child.registered_methods.merge!(registered_methods)
      super
    end
    
    # Lazily registers the added method if marked for lazy registration.
    def method_added(sym)
      if args = registered_methods[sym]
        const_attrs[sym] ||= Lazydoc.register_caller(*args)
      end
      
      super
    end
    
    # Returns the constant attributes resolved for the extended class.
    def const_attrs
      Document[to_s]
    end

    # Returns the Document for source_file
    def lazydoc
      Lazydoc[source_file]
    end
    
    # A hash of (method_name, [comment_class, caller_index]) pairs indicating
    # methods to lazily register, and the inputs to Lazydoc.register_caller
    # used to register the method.
    def registered_methods
      @registered_methods ||= {}
    end
    
    # Creates a method that reads and resolves the constant attribute specified
    # by key, which should normally be a string (see above for more details).  
    # If writable is true, a corresponding writer is also created.
    def lazy_attr(symbol, key=symbol.to_s, writable=true)
      key = case key
      when String, Symbol, Numeric, true, false, nil then key.inspect
      else "YAML.load(\'#{YAML.dump(key)}\')"
      end
      
      instance_eval %Q{
def #{symbol}(resolve=true)
  comment = const_attrs[#{key}] ||= Subject.new(nil, lazydoc)
  resolve && comment.kind_of?(Comment) ? comment.resolve : comment
end}

      instance_eval(%Q{
def #{symbol}=(comment)
  const_attrs[#{key}] = comment
end}) if writable
    end
    
    # Marks the method for lazy registration.  When the method is registered,
    # it will be stored in const_attrs by method_name.
    def lazy_register(method_name, comment_class=Method, caller_index=1)
      registered_methods[method_name.to_sym] = [comment_class, caller_index]
    end
    
    # Registers the next comment (by default as a Method).
    def register___(comment_class=Method)
      lazydoc.register___(comment_class, 1)
    end
  end
end
