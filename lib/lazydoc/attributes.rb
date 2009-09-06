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
  #   ConstName::key.subject           # => 'value'
  # 
  # ==== Keys and Register
  #
  # Note that constant attributes parsed from a source file are stored in
  # const_attrs, and will ALWAYS be keyed using a string (since the 
  # 'ConstName::key' syntax always results in a string key).
  #
  #   ConstName.const_attrs['key']     # => ConstName::key
  #
  # Comments specified by non-string keys may also be stored in const_attrs;
  # these will not and cannot be conflict with constant attributes.  Attributes
  # uses such comments to tie user-specified comments to a constant.  For
  # instance you could manually register a comment using register___:
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
  #   Sample.const_attrs[:method_one].comment   # => "this is the method one comment"
  # 
  # For easier access, you could define a lazy_attr that maps to the registered
  # comment.  A similar strategy pairs a lazy_register with a lazy_attr.  Note
  # that in both cases the keys (ex :method_one) provided to lazy_attr are
  # symbols and not strings.
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
  #   Paired.one.comment      # => "this is the manually-registered method one comment"
  #   Paired.two.comment      # => "this is the lazyily-registered method two comment"
  #
  # The manual registration methods provided by Attributes allows comments to
  # be registered from multiple source files.
  module Attributes
    
    # Returns the Documents registered to the extending class.
    # 
    # By default lazydocs contains a Document for the file where Attributes
    # extends the class (if you include Attributes, you must set lazydocs
    # manually).  Classes that inherit from the extended class will add a
    # lazydoc for the file where inheritance first occurs.
    #
    # ==== Note
    # 
    # Assigning lazydocs is useful but also a bit
    # arbitrary.  Comments for the extended class may be spread over many
    # files unrelated to source_file.  Typically however, as is the case
    # when defining the actual class, it's a good practice to define all
    # coments in the same file and that file is usually defined as
    # source_file.
    #
    attr_accessor :lazydocs
    
    # Sets source_file as the file where Attributes first extends the class.
    def self.extended(base)
      caller[1] =~ CALLER_REGEXP
      base.lazydocs ||= [Lazydoc[$1]]
      super
    end
    
    # Inherits registered_methods from parent to child.  Also registers the
    # source_file for the child as the file where the inheritance first occurs.
    def inherited(child)
      unless child.lazydocs
        caller.each do |call|
          next if call =~ /in `inherited'$/
          
          call =~ CALLER_REGEXP
          child.lazydocs = [Lazydoc[$1]]
          break
        end
      end
      
      super
    end
    
    # Lazily registers the added method if marked for lazy registration.
    def method_added(sym)
      current = self
      while current.kind_of?(Attributes)
        if args = current.registered_methods[sym]
          const_attrs[sym] ||= Lazydoc.register_caller(*args)
        end
        current = current.superclass
      end
      
      super
    end
    
    # Returns the constant attributes resolved for the extended class.
    def const_attrs
      Document[to_s]
    end
    
    def register_lazydoc(caller_index=0)
      self.lazydocs ||= []
      
      caller[caller_index] =~ CALLER_REGEXP
      lazydocs << Lazydoc[File.expand_path($1)]
      lazydocs.uniq!
      self
    end
    
    # A hash of (method_name, [comment_class, caller_index]) pairs indicating
    # methods to lazily register, and the inputs to Lazydoc.register_caller
    # used to register the method.
    def registered_methods
      @registered_methods ||= {}
    end
    
    # Creates a method that reads and resolves the constant attribute specified
    # by key. The method has a signature like:
    #
    #   def method(resolve=true)
    #   end
    #
    # To simply return the constant attribute without resolving, call the 
    # method with resolve == false. If writable is true, a corresponding
    # writer is also created.
    #
    # ==== String Keys
    #
    # A string key indicates the method is supposed to access a 'proper'
    # constant attribute, defined in the documentation with the standard
    # 'Const::key' syntax.  These lazy_attrs may be defined across multiple
    # files but it is expected that a given lazy_attr, attribute pair are
    # defined in the same file.  To link the lazy_attr to source_file, set
    # link_to_source_file.
    #
    # If you manually resolve the attribute before you access the method it
    # technically can be declared elsewhere, but this is not a recommended
    # practice.
    #
    # ==== Non-String Keys
    #
    # Non-string keys indicate the method maps to a manually-registered
    # comment that is not declared with the standard constant attribute
    # syntax. Registration methods provided by Attributes are register___,
    # and lazy_register.  These too may be defined in multiple files.
    #
    def lazy_attr(symbol, key=symbol.to_s, writable=true)
      key = case key
      when String, Symbol then key.inspect
      else raise "invalid class for a lazy_attr key: #{key.inspect} (#{key.class})"
      end
      
      register_lazydoc(1)
      
      instance_eval %Q{def #{symbol}(resolve=true); seek_const_attr(#{key}, resolve); end}
      instance_eval(%Q{def #{symbol}=(comment); const_attrs[#{key}] = comment; end}) if writable
    end
    
    # Marks the method for lazy registration.  When the method is registered,
    # it will be stored in const_attrs by method_name.
    def lazy_register(method_name, comment_class=Method, caller_index=1)
      registered_methods[method_name.to_sym] = [comment_class, caller_index]
    end
    
    # Registers the next comment (by default as a Method).
    def register___(comment_class=Method)
      caller[0] =~ CALLER_REGEXP
      source_file = File.expand_path($1)
      
      Lazydoc[source_file].register___(comment_class, 1)
    end
    
    private
    
    def seek_const_attr(key, resolve, klass=self) # :nodoc:
      klass.lazydocs.each {|doc| doc.resolve } if resolve
      
      if klass.const_attrs.has_key?(key)
        klass.const_attrs[key]
      else
        klass = klass.superclass
        klass.kind_of?(Attributes) ? seek_const_attr(key, resolve, klass) : nil
      end
    end
  end
end
