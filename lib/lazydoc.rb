require 'lazydoc/version'
require 'lazydoc/document'

module Lazydoc
  module_function
  
  # An array of documents registered with Lazydoc.
  def registry
    @registry ||= []
  end
  
  # Returns the document registered to the source file, or nil if no such
  # document exists.
  def document(source_file)
    source_file = File.expand_path(source_file.to_s)
    registry.find {|doc| doc.source_file == source_file }
  end
  
  # Returns the document registered to the source file.  If no such document
  # exists, one will be created for it.
  def [](source_file)
    document(source_file) || register_file(source_file)
  end
  
  # Guesses the default constant name for the source file by camelizing the
  # shortest relative path from a matching $LOAD_PATH to the source file.
  # Returns nil if the source file is not relative to any load path.
  #
  # ==== Code Credit
  #
  # The camelize algorithm is taken from the ActiveSupport {Inflections}[http://api.rubyonrails.org/classes/ActiveSupport/CoreExtensions/String/Inflections.html]
  # module.  See the {Tap::Env::StringExt}[http://tap.rubyforge.org/rdoc/classes/Tap/Env/StringExt.html]
  # module (which uses the same) for a proper credit and license.
  #
  def guess_const_name(source_file)
    source_file = File.expand_path(source_file.to_s)
    
    load_paths = []
    $LOAD_PATH.each do |load_path|
      load_path = File.expand_path(load_path)
      if source_file.rindex(load_path, 0) == 0
        load_paths << load_path
      end
    end
    
    return nil if load_paths.empty?
    
    load_path = load_paths.sort_by {|load_path| load_path.length}.pop
    extname = File.extname(source_file)
    relative_path = source_file[(load_path.length + 1)..(-1 - extname.length)]
    relative_path.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
  end
  
  # Generates a document for the source_file and default_const_name and adds it to
  # registry, or returns the document already registered to the source file.  An
  # error is raised if you try to re-register a source_file with an inconsistent
  # default_const_name.
  def register_file(source_file, default_const_name=guess_const_name(source_file))
    unless lazydoc = document(source_file)
      lazydoc = Document.new(source_file)
      registry << lazydoc
    end
    
    lazydoc.default_const_name = default_const_name
    lazydoc
  end

  # Registers the line number to the document for source_file and returns the
  # new comment.
  def register(source_file, line_number, comment_class=Comment)
    Lazydoc[source_file].register(line_number, comment_class)
  end
  
  # Registers the method to the line where it was called.  To do so,
  # register_caller examines the specified index in the call stack
  # and extracts a file and line number.  For instance:
  #
  #   module Sample
  #     module_function
  #     def method
  #       Lazydoc.register_caller
  #     end
  #   end
  #
  #   # this is the line that gets registered
  #   c = Sample.method
  #
  #   c.resolve
  #   c.subject   # => "c = Sample.method"
  #   c.comment   # => "this is the line that gets registered"
  #
  def register_caller(comment_class=Comment, caller_index=1)
    caller[caller_index] =~ CALLER_REGEXP
    Lazydoc[$1].register($2.to_i - 1, comment_class)
  end
  
  # Parses the usage for a file (ie the first comment in the file 
  # following an optional bang line), wrapped to n cols.  For 
  # example, with this:
  #
  #   [hello_world.rb]
  #   #!/usr/bin/env ruby
  #   # This is your basic hello world
  #   # script:
  #   #
  #   #   % ruby hello_world.rb
  #
  #   puts 'hello world'
  #
  # You get this:
  #
  #   "\n" + Lazydoc.usage('hello_world.rb')  
  #   # => %Q{
  #   # This is your basic hello world script:
  #   #
  #   #   % ruby hello_world.rb}
  #
  def usage(path, cols=80)
    scanner = StringScanner.new(File.read(path))
    scanner.scan(/#!.*?\r?\n/)
    scanner.scan(/\s*#/m)
    Comment.new.parse_down(scanner, nil, false).wrap(cols, 2).strip
  end
end