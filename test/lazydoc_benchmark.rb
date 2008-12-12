require 'test/unit'
require 'lazydoc'
require 'benchmark'

class LazydocBenchmark < Test::Unit::TestCase

  def test_scan_speed
    puts "test_scan_speed"
    Benchmark.bm(25) do |x|
      str = %Q{#              key value} * 100
      n = 1000
      x.report("#{n}x #{str.length} chars") do 
        n.times do 
          Lazydoc.scan(str,  'key') {|*args|}
        end
      end

      str = %Q{# Name::Space::key  value} * 100
      x.report("same but matching") do 
        n.times do 
          Lazydoc.scan(str,  'key') {|*args|}
        end
      end

      str = %Q{#           ::key  value} * 100
      x.report("just ::key syntax") do 
        n.times do 
          Lazydoc.scan(str,  'key') {|*args|}
        end
      end

      str = %Q{# Name::Space:: key value} * 100
      x.report("unmatching") do 
        n.times do 
          Lazydoc.scan(str,  'key') {|*args|}
        end
      end
    end
  end

  def test_parse_speed
    puts "test_parse_speed"
    Benchmark.bm(25) do |x|
      comment = %Q{
# comment spanning
# multiple lines
#   with indented
#   lines
#
# and a new
# spanning line

}

      str = %Q{              key value#{comment}} * 10
      n = 100
      x.report("#{n}x #{str.length} chars") do 
        n.times do 
          Lazydoc.parse(str) {|*args|}
        end
      end

      str = %Q{Name::Space::key  value#{comment}} * 10
      x.report("same but matching") do 
        n.times do 
          Lazydoc.parse(str) {|*args|}
        end
      end

      str = %Q{           ::key  value#{comment}} * 10
      x.report("just ::key syntax") do 
        n.times do 
          Lazydoc.parse(str) {|*args|}
        end
      end

      str = %Q{Name::Space:: key value#{comment}} * 10
      x.report("unmatching") do 
        n.times do 
          Lazydoc.parse(str) {|*args|}
        end
      end
    end
  end

end