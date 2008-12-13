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
      x.report("1k Comment") do 
        n.times do 
          comment.parse(str)
        end
      end

      attribute = Attribute.new
      x.report("1k Attribute") do 
        n.times do 
          attribute.parse(str)
        end
      end
    end
  end
end