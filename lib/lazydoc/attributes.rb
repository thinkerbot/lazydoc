module Lazydoc
  
  # Attributes adds methods to declare class-level accessors for constant
  # attributes associated with the class.
  #
  #   # ConstName::key value
  #   class ConstName
  #     extend Lazydoc::Attributes
  #     lazy_attr :key
  #   end
  #
  #   ConstName::key.subject                 # => 'value'
  #
  # Lazy attributes are inherited, but can be overridden.
  #
  #   class SubclassA < ConstName; end
  #   SubclassA::key.subject                 # => 'value'
  #
  #   # SubclassB::key overridden value
  #   class SubclassB < ConstName; end
  #   SubclassB::key.subject                 # => 'overridden value'
  #
  # You can use Attributes to register methods on modules, but currently the
  # inheritance is a bit wonky; the accessors are methods on the extended
  # class/module and so standard module inclusion will not pass them on.
  # To work around you need to extend and redefine the accessors.  Note,
  # however, that methods do not need to be re-registered.
  #
  #   module A
  #     extend Lazydoc::Attributes
  #     lazy_attr(:one, :method_one)
  #     lazy_register(:method_one)
  #   
  #     # documentation for method one
  #     def method_one; end
  #   end
  # 
  #   class B
  #     include A
  #     extend Lazydoc::Attributes
  #     lazy_attr(:one, :method_one)
  #   end
  # 
  #   class C < B
  #     # overriding documentation for method one
  #     def method_one; end
  #   end
  # 
  #   A::one.comment    # => "documentation for method one"
  #   B::one.comment    # => "documentation for method one"
  #   C::one.comment    # => "overriding documentation for method one"
  #   
  # ==== Keys and Register
  #
  # Constant attributes parsed from a source file will ALWAYS be stored in
  # const_attrs using a string (since the 'ConstName::key' syntax always
  # results in a string key).  A lazy_attr is basically shorthand for either
  # of these statements:
  #
  #   ConstName.const_attrs['key'].subject            # => 'value'
  #   Lazydoc::Document['ConstName']['key'].subject   # => 'value'
  #
  # By default a lazy_attr maps to the constant attribute with the same name
  # as the accessor, but this can be overridden by specifying the string key
  # for another attribute.
  #
  #   class ConstName
  #     lazy_attr :alt, 'key'
  #   end
  #
  #   ConstName::alt.subject                     # => 'value'
  #   ConstName.const_attrs['alt']               # => nil
  #
  # Comments specified by non-string keys may also be stored in const_attrs;
  # these will not conflict with constant attributes parsed from a source
  # file. For instance you could manually register a comment to a symbol key
  # using lazy_register:
  #
  #   class Sample
  #     extend Lazydoc::Attributes
  #
  #     lazy_register(:method_one)
  #
  #     # this is the method one comment
  #     def method_one
  #     end
  #   end
  #
  #   Sample.const_attrs[:method_one].comment    # => "this is the method one comment"
  # 
  # Manually-registered comments may then be paired with a lazy_attr.  As
  # before the key for the comment is provided in the definition.
  #
  #   class Paired
  #     extend Lazydoc::Attributes
  #
  #     lazy_attr(:one, :method_one)
  #     lazy_register(:method_one)
  #
  #     # this is the method one comment
  #     def method_one
  #     end
  #   end
  #
  #   Paired::one.comment   # => "this is the method one comment"
  #
  # ==== Troubleshooting
  #
  # Under most circumstances Attributes will register all the necessary files
  # to make constant attributes available.  These include:
  #
  # * the file where the class is extended
  # * the file where a subclass inherits from an extended class
  # * files that declare a lazy_attr
  #
  # Be sure to call register_lazydoc in files that are not covered by one of
  # these cases but nonetheless contain constant attributes that should be
  # available to a lazy_attr.
  module Attributes
    
    # Sets source_file as the file where Attributes first extends the class.
    def self.extended(base)
      caller[1] =~ CALLER_REGEXP
      unless base.instance_variable_defined?(:@lazydocs)
        base.instance_variable_set(:@lazydocs, [Lazydoc[$1]])
      end
      
      unless base.instance_variable_defined?(:@lazy_registry)
        base.instance_variable_set(:@lazy_registry, {})
      end
      
      super
    end
    
    # Returns the documents registered to the extending class.
    # 
    # By default lazydocs contains a Document for the file where Attributes
    # extends the class, or where a subclass first inherits from an extended
    # class (if you include Attributes, you must set lazydocs manually).
    #
    # Additional documents may be added by calling register_lazydoc.
    attr_reader :lazydocs
    
    # Returns an array of the methods whose documentation will be automatically
    # registered by Attributes.  Set as_registry to true to return a hash of
    # of (method_name, [comment_class, caller_index]) pairs where the 
    # registration arguments are the hash values.
    def registered_methods(as_registry=false)
      methods = {}
      ancestors.reverse.each do |ancestor|
        if ancestor.kind_of?(Attributes)
          methods.merge!(ancestor.lazy_registry)
        end
      end
      
      as_registry ? methods : methods.keys
    end
    
    # Returns the constant attributes resolved for the extended class.
    def const_attrs
      Document[to_s]
    end
    
    protected
    
    # A hash of (method_name, [comment_class, caller_index]) pairs indicating
    # methods to lazily register, and the inputs used to register the method.
    #
    # The lazy_registry only contains methods lazily registered within the
    # current class or module.  To return methods registered throughout the
    # inheritance hierarchy, use registered_methods(true)
    attr_reader :lazy_registry
    
    # Registers the calling file into lazydocs.  Registration occurs by
    # examining the call stack at the specified index.
    def register_lazydoc(caller_index=0)
      caller[caller_index] =~ CALLER_REGEXP
      lazydocs << Lazydoc[File.expand_path($1)]
      lazydocs.uniq!
      self
    end
    
    # Creates a method that reads and resolves the constant attribute specified
    # by key. The method has a signature like:
    #
    #   def method(resolve=true)
    #   end
    #
    # To return the constant attribute without resolving, call the method with
    # resolve == false. If writable is true, a corresponding writer is also
    # created.
    def lazy_attr(symbol, key=symbol.to_s, writable=true)
      unless key.kind_of?(String) || key.kind_of?(Symbol)
        raise "invalid lazy_attr key: #{key.inspect} (#{key.class})"
      end
      
      key = key.inspect
      instance_eval %Q{def #{symbol}(resolve=true); get_const_attr(#{key}, resolve); end}
      instance_eval(%Q{def #{symbol}=(comment); const_attrs[#{key}] = comment; end}) if writable
      
      register_lazydoc(1)
    end
    
    # Marks the method for lazy registration.  When the method is registered,
    # it will be stored in const_attrs by method_name.
    def lazy_register(method_name, comment_class=Method, caller_index=1)
      lazy_registry[method_name.to_sym] = [comment_class, caller_index]
    end
    
    # Manually registers the next comment into const_attrs.  Note a lazy_attr
    # will still need to be defined to access this comment as an attribute.
    def register___(key, comment_class=Method)
      caller[0] =~ CALLER_REGEXP
      source_file = File.expand_path($1)
      const_attrs[key] = Lazydoc[source_file].register___(comment_class, 1)
    end
    
    private
    
    # Inherits lazy_registry from parent to child.  Also registers the
    # source_file for the child as the file where the inheritance first
    # occurs.
    def inherited(child)
      unless child.instance_variable_defined?(:@lazydocs)
        caller.each do |call|
          next if call =~ /in `inherited'$/
          
          call =~ CALLER_REGEXP
          child.instance_variable_set(:@lazydocs, [Lazydoc[$1]])
          break
        end
      end
      
      unless child.instance_variable_defined?(:@lazy_registry)
        child.instance_variable_set(:@lazy_registry, {})
      end
      
      super
    end
    
    # Helper to traverse the inheritance hierarchy.  The logic of this method
    # is described in the dsl pattern: http://gist.github.com/181961
    def each_ancestor # :nodoc:
      yield(self)
      
      blank, *ancestors = self.ancestors
      ancestors.each do |ancestor|
        yield(ancestor) if ancestor.kind_of?(Attributes)
      end
      
      nil
    end
    
    # Lazily registers the added method if marked for lazy registration.
    def method_added(sym)
      current = nil
      each_ancestor do |ancestor|
        if ancestor.lazy_registry.has_key?(sym)
          current = ancestor
          break
        end
      end
    
      if current
        args = current.lazy_registry[sym]
        const_attrs[sym] ||= Lazydoc.register_caller(*args)
      end
    
      super
    end
  
    # helper to traverse up the inheritance hierarchy looking for the first
    # const_attr assigned to key.  the lazydocs for each class will be
    # resolved along the way, if specified.
    def get_const_attr(key, resolve) # :nodoc:
      each_ancestor do |ancestor|
        const_attrs = ancestor.const_attrs
      
        unless const_attrs.has_key?(key)
          next unless resolve
        
          ancestor.lazydocs.each {|doc| doc.resolve }
          next unless const_attrs.has_key?(key)
        end
      
        const_attr = const_attrs[key]
        if resolve && const_attr.kind_of?(Comment)
          const_attr.resolve
        end

        return const_attr
      end
    end
  end
end
