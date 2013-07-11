require "test/unit"
require "java_class_parser"
 
class TestJavaClassParser < Test::Unit::TestCase
 
  def test_simple
    @parser = JavaClassParser.new()
    java_class = @parser.parse("ChildClass.class")

    p java_class
    
  end
 
end
