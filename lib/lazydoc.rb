require 'lazydoc/document'

module Lazydoc
  module_function
  
  # An array of documents registered with Lazydoc.
  def registry
    @registry ||= []
  end
  
  # Returns the Document in registry for the specified source file.
  # If no such Document exists, one will be created for it.
  def [](source_file)
    source_file = File.expand_path(source_file.to_s)
    registry.find {|doc| doc.source_file == source_file } || register_file(source_file)
  end
  
  # Generates a Document the source_file and default_const_name and adds it to
  # registry, or returns the document already registered to source_file.  An
  # error is raised if you try to re-register a source_file with an inconsistent
  # default_const_name.
  def register_file(source_file, default_const_name=nil)
    source_file = File.expand_path(source_file.to_s)
    lazydoc = registry.find {|doc| doc.source_file == source_file }
    
    unless lazydoc
      lazydoc = Document.new(source_file)
      registry << lazydoc
    end
    
    lazydoc.default_const_name = default_const_name
    lazydoc
  end

  # Registers the line number to the document for source_file and
  # returns the corresponding comment.
  def register(source_file, line_number, comment_class=Comment)
    Lazydoc[source_file].register(line_number, comment_class)
  end
  
  # Registers the method at the specified index in the call stack to
  # the file where the method was called.  Using the default index of
  # 1, register_caller registers the caller of the method where 
  # register_caller is called (whew!).  For instance:
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