Gem::Specification.new do |s|
  s.name = "lazydoc"
  s.version = "0.2.0"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org/lazydoc"
  s.platform = Gem::Platform::RUBY
  s.summary = "Lazily pull documentation out of source files."
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.has_rdoc = true
  s.add_development_dependency "tap", ">= 0.11.1"

  # list extra rdoc files here.
  s.extra_rdoc_files = %W{
    README
    MIT-LICENSE
  }
  
  # list the files you want to include here. you can
  # check this manifest using 'rake :print_manifest'
  s.files = %W{
    lib/lazydoc.rb
    lib/lazydoc/attributes.rb
    lib/lazydoc/comment.rb
    lib/lazydoc/document.rb
    lib/lazydoc/method.rb
  }
end