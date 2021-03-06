require 'test/unit'
require 'lazydoc'
require 'benchmark'

class LazydocBenchmark < Test::Unit::TestCase
  include Lazydoc
  
  def test_scan_speed
    puts "test_scan_speed"
    Benchmark.bm(25) do |x|
      str = %Q{#              key value} * 100
      n = 1000
      x.report("#{n}x #{str.length} chars") do 
        n.times do 
          Document.scan(str,  'key') {|*args|}
        end
      end

      str = %Q{# Name::Space::key  value} * 100
      x.report("same but matching") do 
        n.times do 
          Document.scan(str,  'key') {|*args|}
        end
      end

      str = %Q{#           ::key  value} * 100
      x.report("just ::key syntax") do 
        n.times do 
          Document.scan(str,  'key') {|*args|}
        end
      end

      str = %Q{# Name::Space:: key value} * 100
      x.report("unmatching") do 
        n.times do 
          Document.scan(str,  'key') {|*args|}
        end
      end
    end
  end

  def test_parse_speed
    puts "test_parse_speed"
    Benchmark.bm(25) do |x|
      str = %Q{
# comment spanning
# multiple lines
#   with indented
#   lines
#
# and a new
# spanning line

}
      n = 1000
      comment = Comment.new(7)
      x.report("1k parse_up") do 
        n.times do 
          comment.parse_up(str)
        end
      end

      attribute = Comment.new(0)
      x.report("1k parse_down") do 
        n.times do 
          attribute.parse_down(str)
        end
      end
    end
  end
  
  
  class RegisterMethodControl
  end
  
  class RegisterMethod
    extend Lazydoc::Attributes
    lazy_register :method_name
  end
  
  class RegisterMethodSubA < RegisterMethod
  end
  class RegisterMethodSubB < RegisterMethodSubA
  end
  class RegisterMethodSubC < RegisterMethodSubB
  end
  
  class NoRegisterMethod
    extend Lazydoc::Attributes
  end
  
  class NoRegisterMethodSubA < NoRegisterMethod
  end
  class NoRegisterMethodSubB < NoRegisterMethodSubA
  end
  class NoRegisterMethodSubC < NoRegisterMethodSubB
  end
  
  def test_register_methods_speed
    puts "test_register_methods_speed"
    Benchmark.bm(25) do |x|
      block = lambda {}
      n = 10000
      x.report("control") do 
        n.times do 
          RegisterMethodControl.send(:define_method, :method_name, &block)
        end
      end
    
      x.report("reg method") do 
        n.times do 
          RegisterMethod.send(:define_method, :method_name, &block)
        end
      end
      
      x.report("unreg method") do 
        n.times do 
          RegisterMethod.send(:define_method, :alt, &block)
        end
      end
      
      x.report("no reg method") do 
        n.times do 
          NoRegisterMethod.send(:define_method, :method_name, &block)
        end
      end
      
      x.report("reg method (subclass)") do 
        n.times do 
          RegisterMethodSubC.send(:define_method, :method_name, &block)
        end
      end
      
      x.report("unreg method (subclass)") do 
        n.times do 
          RegisterMethodSubC.send(:define_method, :alt, &block)
        end
      end
      
      x.report("no reg method (subclass)") do 
        n.times do 
          NoRegisterMethodSubC.send(:define_method, :method_name, &block)
        end
      end
    end
  end
  
  # LazydocBenchmark::AccessSpeed::a value
  class AccessSpeed
    extend Lazydoc::Attributes
    lazy_attr :a
  end
  
  class AccessSpeedSubclassA < AccessSpeed
  end
  class AccessSpeedSubclassB < AccessSpeed
  end
  # LazydocBenchmark::AccessSpeedSubclassC::b value
  class AccessSpeedSubclassC < AccessSpeed
    lazy_attr :b
  end
  
  def test_lazy_attr_access_speed
    puts "test_lazy_attr_access_speed"
    Benchmark.bm(25) do |x|
      n = 100000
      
      x.report("object_id") do 
        n.times do 
          AccessSpeed.object_id
        end
      end
      
      AccessSpeed::a
      x.report("AccessSpeed::a") do 
        n.times do 
          AccessSpeed::a
        end
      end
      
      AccessSpeedSubclassC::b
      x.report("AccessSpeedSubclassC::a") do 
        n.times do 
          AccessSpeedSubclassC::a
        end
      end
      
      x.report("AccessSpeedSubclassC::b") do 
        n.times do 
          AccessSpeedSubclassC::b
        end
      end
    end
  end
  
  def test_regexp_speed
    puts "test_regexp_speed"
    Benchmark.bm(25) do |x|
      n = 100000
      
      r = Lazydoc::CALLER_REGEXP
      str = caller[1]
      x.report("CALLER_REGEXP") do 
        n.times {r =~ str}
      end
      
      r = ATTRIBUTE_REGEXP
      str = "Nested::Const::key"
      x.report("ATTRIBUTE_REGEXP") do 
        n.times {r =~ str}
      end
      
      r = CONSTANT_REGEXP
      str = "#   Nested::Const::"
      x.report("CONSTANT_REGEXP") do 
        n.times {r =~ str}
      end
    end
  end
end