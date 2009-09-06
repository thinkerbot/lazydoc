# AttributesTest::Example::one value for one
# AttributesTest::Example::three value for three
class AttributesTest
  class Example
    extend Lazydoc::Attributes
    
    lazy_attr :one
    lazy_register(:method_two)

    const_attrs[:method_one] = register___
    # method one comment
    def method_one
    end
  end
end