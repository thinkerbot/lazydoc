require 'lazydoc/comment'
require 'lazydoc/method'

module Lazydoc
  autoload(:Arguments, 'lazydoc/arguments')
  autoload(:Subject, 'lazydoc/subject')
  autoload(:Trailer, 'lazydoc/trailer')
  
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
    
    # The source file for self, used during resolve
    attr_reader :source_file
  
    # An array of Comment objects identifying lines 
    # to be resolved
    attr_reader :comments
  
    # A nested hash of (const_name, (key, comment)) pairs tracking 
    # the constant attributes resolved for self.
    attr_reader :const_attrs
  
    # The default constant name used when no constant name
    # is specified for a constant attribute
    attr_reader :default_const_name
  
    # Flag indicating whether or not self has been resolved
    attr_accessor :resolved
  
    def initialize(source_file=nil, default_const_name='')
      self.source_file = source_file
      @default_const_name = default_const_name
      @comments = []
      @const_attrs = {}
      @resolved = false
      self.reset
    end
  
    # Resets self by clearing const_attrs, comments, and setting
    # resolved to false.  Generally NOT recommended as this 
    # clears any work you've done registering lines; to simply
    # allow resolve to re-scan a document, manually set
    # resolved to false.
    def reset
      @const_attrs.clear
      @comments.clear
      @resolved = false
      self
    end
  
    # Sets the source file for self.  Expands the source file path if necessary.
    def source_file=(source_file)
      @source_file = source_file == nil ? nil : File.expand_path(source_file)
    end
  
    # Sets the default_const_name for self.  Any const_attrs assigned to 
    # the previous default will be removed and merged with those already 
    # assigned to the new default.
    def default_const_name=(const_name)
      self[const_name].merge!(const_attrs.delete(@default_const_name) || {})
      @default_const_name = const_name
    end
  
    # Returns the attributes for the specified const_name.
    def [](const_name)
      const_attrs[const_name] ||= {}
    end
    
    # Returns an array of the const_names in self with at
    # least one attribute.
    def const_names
      names = []
      const_attrs.each_pair do |const_name, attrs|
        names << const_name unless attrs.empty?
      end
      names
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
      block = lambda do |lines|
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
    
      str = File.read(source_file) if str == nil
      Lazydoc.parse(str) do |const_name, key, comment|
        const_name = default_const_name if const_name.empty?
        self[const_name][key] = comment
      end
    
      unless comments.empty?
        lines = str.split(/\r?\n/)  
        comments.each do |comment|
          comment.resolve(lines)
        end
      end
    
      @resolved = true
    end
    
    # Returns a nested hash of (const_name, (key, comment)) pairs. Constants 
    # that have no attributes assigned to them are omitted.  A block may
    # be provided to collect values from the comments; each comment will
    # be yielded to the block and the return stored in it's place.
    def to_hash
      const_hash = {}
      const_attrs.each_pair do |const_name, attributes|
        next if attributes.empty?
      
        attr_hash = {}
        attributes.each_pair do |key, comment|
          attr_hash[key] = (block_given? ? yield(comment) : comment)
        end
        const_hash[const_name] = attr_hash
      end
      const_hash
    end
  end
end
