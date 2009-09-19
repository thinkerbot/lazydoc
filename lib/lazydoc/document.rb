require 'lazydoc/comment'
require 'lazydoc/method'

module Lazydoc
  autoload(:Attributes, 'lazydoc/attributes')
  autoload(:Arguments, 'lazydoc/arguments')
  autoload(:Subject, 'lazydoc/subject')
  autoload(:Trailer, 'lazydoc/trailer')
  
  # A regexp matching an attribute start or end.  After a match:
  #
  #   $1:: const_name
  #   $2:: key
  #   $3:: end flag
  #
  ATTRIBUTE_REGEXP = /([A-Z][A-z]*(?:::[A-Z][A-z]*)*)?::([a-z_]+)(-?)/

  # A regexp matching constants from the ATTRIBUTE_REGEXP leader
  CONSTANT_REGEXP = /#.*?([A-Z][A-z]*(?:::[A-Z][A-z]*)*)?$/
  
  # A regexp matching a caller line, to extract the calling file
  # and line number.  After a match:
  #
  #   $1:: file
  #   $2:: line number (as a string, obviously)
  #
  # Note that line numbers in caller start at 1, not 0.
  CALLER_REGEXP = /^((?:[A-z]:)?[^:]+):(\d+)/
  
  # A Document resolves constant attributes and code comments for a particular
  # source file.  Documents may be assigned a default_const_name to be used 
  # when a constant attribute does not specify a constant.
  #
  #   # Const::Name::key value a
  #   # ::key value b
  #
  #   doc = Document.new(__FILE__, 'Default')
  #   doc.resolve
  #
  #   Document['Const::Name']['key'].value      # => 'value a'
  #   Document['Default']['key'].value          # => 'value b'
  #
  # As in the example, constant attibutes for all documents may be accessed
  # from Document[].
  class Document
    class << self
      
      # A nested hash of (const_name, (key, comment)) pairs tracking
      # the constant attributes assigned to a constant name.
      def const_attrs
        @const_attrs ||= {}
      end
      
      # Returns the hash of (key, comment) pairs for const_name stored
      # in const_attrs.  If no such hash exists, one will be created.
      def [](const_name)
        const_attrs[const_name] ||= {}
      end
      
      # Scans the string or StringScanner for attributes matching the key
      # (keys may be patterns; they are incorporated into a regexp).
      # Regions delimited by the stop and start keys <tt>:::-</tt> and 
      # <tt>:::+</tt> are skipped. Yields each (const_name, key, value) 
      # triplet to the block.
      #
      #   str = %Q{
      #   # Name::Space::key value
      #   # ::alt alt_value
      #   #
      #   # Ignored::Attribute::not_matched value
      #   # :::-
      #   # Also::Ignored::key value
      #   # :::+
      #   # Another::key another value
      #
      #   Ignored::key value
      #   }
      #
      #   results = []
      #   Document.scan(str, 'key|alt') do |const_name, key, value|
      #     results << [const_name, key, value]
      #   end
      #
      #   results    
      #   # => [
      #   # ['Name::Space', 'key', 'value'], 
      #   # ['', 'alt', 'alt_value'], 
      #   # ['Another', 'key', 'another value']]
      #
      # Returns the StringScanner used during scanning.
      def scan(str, key='[a-z_]+') # :yields: const_name, key, value
        scanner = case str
        when StringScanner then str
        when String then StringScanner.new(str)
        else raise TypeError, "can't convert #{str.class} into StringScanner or String"
        end
        
        regexp = /^(.*?)::(:-|#{key})/
        while !scanner.eos?
          break if scanner.skip_until(regexp) == nil

          if scanner[2] == ":-"
            scanner.skip_until(/:::\+/)
          else
            next unless scanner[1] =~ CONSTANT_REGEXP
            key = scanner[2]
            yield($1.to_s, key, scanner.matched.strip) if scanner.scan(/[ \r\t].*$|$/)
          end
        end

        scanner
      end
    end
    
    # The source file for self, used during resolve
    attr_reader :source_file
    
    # The default constant name used when no constant name
    # is specified for a constant attribute
    attr_reader :default_const_name
  
    # An array of Comment objects registered to self
    attr_reader :comments
  
    # Flag indicating whether or not self has been resolved
    attr_accessor :resolved
    
    def initialize(source_file=nil, default_const_name=nil)
      self.source_file = source_file
      @default_const_name = default_const_name
      @comments = []
      @resolved = false
    end
    
    # Returns the attributes for the specified const_name.  If an empty 
    # const_name ('') is specified, and a default_const_name is set,
    # the default_const_name will be used instead.
    #
    # Note this method will return ALL attributes associated with const_name,
    # not just attributes associated with self.
    def [](const_name)
      const_name = default_const_name if default_const_name && const_name == ''
      Document[const_name]
    end
  
    # Expands and sets the source file for self.
    def source_file=(source_file)
      @source_file = source_file == nil ? nil : File.expand_path(source_file)
    end
    
    # Sets the default_const_name.  Raises an error if default_const_name is
    # already set to a different value.
    def default_const_name=(input)
      @default_const_name = case @default_const_name
      when nil, input then input
      else raise ArgumentError, "default_const_name cannot be overridden #{source_file}: #{@default_const_name.inspect} != #{input.inspect}"
      end
    end
    
    # Registers the specified line number to self.  Register may take an
    # integer or a regexp for dynamic evaluation. See Comment#resolve for
    # more details.
    # 
    # Returns the newly registered comment.
    def register(line_number, comment_class=Comment)
      comment = comment_class.new(line_number, self)
      comments << comment
      comment
    end
    
    # Registers the next comment.
    #
    #   lazydoc = Document.new(__FILE__)
    #
    #   c = lazydoc.register___
    #   # this is the comment
    #   # that is registered
    #   def method(a,b,c)
    #   end
    #
    #   lazydoc.resolve
    #
    #   c.subject      # => "def method(a,b,c)"
    #   c.comment      # => "this is the comment that is registered"
    #
    def register___(comment_class=Comment, caller_index=0)
      caller[caller_index] =~ CALLER_REGEXP
      block = lambda do |scanner, lines|
        n = $2.to_i
        n += 1 while lines[n] =~ /^\s*(#.*)?$/
        n
      end
      register(block, comment_class)
    end
      
    # Scans str for constant attributes and adds them to Document.const_attrs.
    # Comments registered with self are also resolved against str.  If no str
    # is specified, the contents of source_file are used instead.
    #
    # Resolve does nothing if resolved == true, unless force is also specified.
    # Returns true if str was resolved, or false otherwise.
    def resolve(str=nil, force=false)
      return false if resolved && !force
      @resolved = true
      
      str = File.read(source_file) if str == nil
      lines = Utils.split_lines(str)
      scanner = Utils.convert_to_scanner(str)
      
      Document.scan(scanner) do |const_name, key, value|
        # get or initialize the comment that will be parsed
        comment = (self[const_name][key] ||= Subject.new(nil, self))
        
        # skip non-comment constant attributes
        next unless comment.kind_of?(Comment)
        
        # parse the comment
        comment.parse_down(scanner, lines) do |line|
          if line =~ ATTRIBUTE_REGEXP
            # rewind to capture the next attribute unless an end is specified.
            scanner.unscan unless $3 == '-' && $2 == key && $1.to_s == const_name
            true
          else false
          end
        end
        
        # set the subject
        comment.subject = value
      end
      
      # resolve registered comments
      comments.each do |comment|
        comment.parse_up(scanner, lines)
        
        n = comment.line_number
        comment.subject = n.kind_of?(Integer) ? lines[n] : nil
      end
      
      true
    end
    
    # Summarizes constant attributes registered to self by collecting them
    # into a nested hash of (const_name, (key, comment)) pairs.  A block 
    # may be provided to collect values from the comments; each comment is
    # yielded to the block and the return stored in it's place.
    def summarize
      const_hash = {}
      Document.const_attrs.each_pair do |const_name, attributes|
        next if attributes.empty?

        const_hash[const_name] = attr_hash = {}
        attributes.each_pair do |key, comment|
          next unless comment.document == self
          attr_hash[key] = (block_given? ? yield(comment) : comment)
        end
      end
      const_hash
    end
  end
end
