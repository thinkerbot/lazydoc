$:.unshift File.expand_path('../lib', __FILE__)
require 'lazydoc/version'

Gem::Specification.new do |s|
  s.name = 'lazydoc'
  s.version = Lazydoc::VERSION
  s.author = 'Simon Chiang'
  s.email = 'simon.a.chiang@gmail.com'
  s.homepage = 'http://tap.rubyforge.org/lazydoc'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Lazily pull documentation out of source files.'
  s.require_path = 'lib'
  s.rubyforge_project = 'tap'
  s.has_rdoc = true
  s.rdoc_options.concat %w{--main README -S -N --title Lazydoc}

  # list extra rdoc files here.
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
    History
  }
  
  # list the files you want to include here. you can
  # check this manifest using 'rake :print_manifest'
  s.files = %W{
    lib/lazydoc.rb
    lib/lazydoc/arguments.rb
    lib/lazydoc/attributes.rb
    lib/lazydoc/comment.rb
    lib/lazydoc/document.rb
    lib/lazydoc/method.rb
    lib/lazydoc/subject.rb
    lib/lazydoc/trailer.rb
    lib/lazydoc/utils.rb
    lib/lazydoc/version.rb
  }
end