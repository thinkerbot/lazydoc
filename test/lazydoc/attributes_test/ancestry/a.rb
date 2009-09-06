class AttributesTest
  module Example
    # AttributesTest::Example::AncestryA::one value for A
    class AncestryA
      extend Lazydoc::Attributes
      lazy_attr :one
    end
  end
end