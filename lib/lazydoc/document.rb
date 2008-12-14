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
  #   $3:: key
  #   $4:: end flag
  #
  ATTRIBUTE_REGEXP = /([A-Z][A-z]*(::[A-Z][A-z]*)*)?::([a-z_]+)(-?)/

  # A regexp matching constants from the ATTRIBUTE_REGEXP leader
  CONSTANT_REGEXP = /#.*?([A-Z][A-z]*(::[A-Z][A-z]*)*)?$/
  
  # A regexp matching a caller line, to extract the calling file
  # and line number.  After a match:
  #
  #   $1:: file
  #   $3:: line number (as a string, obviously)
  #
  # Note that line numbers in caller start at 1, not 0.
  CALLER_REGEXP = /^(([A-z]:)?[^:]+):(\d+)/
  
  # A Document tracks constant attributes and code comments for a particular
  # source file.  Documents may be assigned a default_const_name to be used
  # when a constant attribute does not specify a constant.
  #
  #   # KeyWithConst::key value a
  #   # ::key value b
  #
  #   doc = Document.new(__FILE__, 'DefaultConst')
  #   doc.resolve
  #   doc['KeyWithConst']['key'].value      # => 'value a'
  #   doc['DefaultConst']['key'].value      # => 'value b'
  #
  class Document
    class << self
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
      def scan(str, key) # :yields: const_name, key, value
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
  
    # An array of Comment objects identifying lines 
    # to be resolved
    attr_reader :comments
  
    # A nested hash of (const_name, (key, comment)) pairs tracking
    # the constant attributes assigned to a constant name.
    attr_reader :const_attrs
  
    # Flag indicating whether or not self has been resolved
    attr_accessor :resolved
    
    def initialize(source_file=nil, default_const_name='')
      self.source_file = source_file
      @default_const_name = default_const_name
      @const_attrs = {}
      @comments = []
      @resolved = false
    end
    
    # Returns the attributes for the specified const_name.
    def [](const_name)
      const_name = default_const_name unless const_name && !const_name.empty?
      const_attrs[const_name] ||= {}
    end
    
    # Resets self by clearing const_attrs, comments, and setting
    # resolved to false.  Generally NOT recommended as this 
    # clears any work you've done registering lines; to simply
    # allow resolve to re-scan a document, manually set
    # resolved to false.
    def reset
      # don't actually reset the values of const_attrs
      # as this may unlink Attributes classes from self
      const_attrs.values.each {|attrs| attrs.clear}
      comments.clear
      @resolved = false
      self
    end
  
    # Sets the source file for self.  Expands the source file path if necessary.
    def source_file=(source_file)
      @source_file = source_file == nil ? nil : File.expand_path(source_file)
    end
    
    # Sets the default_const_name for self. Any const_attrs assigned to
    # the previous default will be removed and merged with those already
    # assigned to the new default.
    def default_const_name=(const_name)
      current = self[@default_const_name]
      self[const_name].merge!(current)
      current.clear
      
      @default_const_name = const_name
    end
    
    # Register the specified line number to self.  Register
    # may take an integer or a regexp for late-evaluation.
    # See Comment#resolve for more details.
    # 
    # Returns a comment_class instance corresponding to the line.
    def register(line_number, comment_class=Comment)
      comment = comments.find {|c| c.class == comment_class && c.line_number == line_number }
    
      if comment == nil
        comment = comment_class.new(line_number, self)
        comments << comment
      end
    
      comment
    end
    
    # Registers a regexp matching the first definition of method_name.
    def register_method(method_name, comment_class=Method)
      register(Method.method_regexp(method_name), comment_class)
    end
    
    # Registers the next comment.
    #
    #   lazydoc = Document.new(__FILE__)
    #
    #   lazydoc.register___
    #   # this is the comment
    #   # that is registered
    #   def method(a,b,c)
    #   end
    #
    #   lazydoc.resolve
    #   m = lazydoc.comments[0]
    #   m.subject      # => "def method(a,b,c)"
    #   m.to_s         # => "this is the comment that is registered"
    #
    def register___(comment_class=Comment, caller_index=0)
      caller[caller_index] =~ CALLER_REGEXP
      block = lambda do |scanner, lines|
        n = $3.to_i
        n += 1 while lines[n] =~ /^\s*(#.*)?$/
        n
      end
      register(block, comment_class)
    end
      
    # Scans str for constant attributes and adds them to to self.  Code
    # comments are also resolved against str.  If no str is specified,
    # the contents of source_file are used instead.
    #
    # Resolve does nothing if resolved == true.  Returns true if str
    # was resolved, or false otherwise.
    def resolve(str=nil)
      return(false) if resolved
      @resolved = true
      
      str = File.read(source_file) if str == nil
      lines = Utils.split_lines(str)
      scanner = Utils.convert_to_scanner(str)
      
      unless comments.empty?
        comments.each do |comment|
          comment.parse_up(scanner, lines)
          
          n = comment.line_number
          comment.subject = n.kind_of?(Integer) ? lines[n] : nil
        end
      end
      
      Document.scan(scanner, '[a-z_]+') do |const_name, key, value|
        # get or initialize the comment that will be parsed
        comment = (self[const_name][key] ||= Subject.new(nil, self))
        
        # skip non-comment constant attributes
        next unless comment.kind_of?(Comment)
        
        # parse the comment
        comment.parse_down(scanner, lines) do |line|
          if line =~ ATTRIBUTE_REGEXP
            # rewind to capture the next attribute unless an end is specified.
            scanner.unscan unless $4 == '-' && $3 == key && $1.to_s == const_name
            true
          else false
          end
        end
        
        # set the subject
        comment.subject = value
      end
      
      true
    end
    
    # Returns a nested hash of (const_name, (key, comment)) pairs. Constants 
    # that have no attributes assigned to them are omitted.  A block may
    # be provided to collect values from the comments; each comment will
    # be yielded to the block and the return stored in it's place.
    def to_hash
      const_hash = {}
      const_attrs.each_pair do |const_name, attributes|
        next if attributes.empty?

        const_hash[const_name] = attr_hash = {}
        attributes.each_pair do |key, comment|
          attr_hash[key] = (block_given? ? yield(comment) : comment)
        end
      end
      const_hash
    end
  end
end
