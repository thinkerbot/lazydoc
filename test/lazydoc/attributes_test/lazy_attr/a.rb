# AttributesTest::Example::LazyAttr::one value for one
class AttributesTest
  module Example
    class LazyAttr
      extend Lazydoc::Attributes
      lazy_attr :one
    end
  end
end