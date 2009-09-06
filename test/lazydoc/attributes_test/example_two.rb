# AttributesTest::Example::two value for two
class AttributesTest
  class Example
    lazy_attr :two
    
    # method two comment
    def method_two
    end
    
    const_attrs[:method_three] = register___
    # method three comment
    def method_three
    end
  end
end