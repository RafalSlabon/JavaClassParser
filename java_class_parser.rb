
class JavaClass
    attr_accessor :name
    attr_accessor :abstract
    attr_accessor :package
    attr_accessor :super_class
    attr_accessor :interfaces
    attr_accessor :fields

    def initialize
        @interfaces = Array.new
        @fields = Hash.new
    end
end

class Constant
    attr_accessor :tag
    attr_accessor :name_index
    attr_accessor :type_index
    attr_accessor :value
end

class FieldInfo
    attr_accessor :access_flags
    attr_accessor :name_index
    attr_accessor :descriptor_index
    attr_accessor :attributes_count
    attr_accessor :attributes
end

class AttributeInfo
    attr_accessor :attribute_name_index
    attr_accessor :attribute_length
    attr_accessor :info
end

class MethodInfo 
    attr_accessor :access_flags
    attr_accessor :name_index
    attr_accessor :descriptor_index
    attr_accessor :attributes_count
    attr_accessor :attributes
end

class JavaClassParser

    CONSTANT_UTF8 = 1
    CONSTANT_UNICODE = 2
    CONSTANT_INTEGER = 3
    CONSTANT_FLOAT = 4
    CONSTANT_LONG = 5
    CONSTANT_DOUBLE = 6
    CONSTANT_CLASS = 7
    CONSTANT_STRING = 8
    CONSTANT_FIELD = 9
    CONSTANT_METHOD = 10
    CONSTANT_INTERFACEMETHOD = 11
    CONSTANT_NAMEANDTYPE = 12
    CLASS_DESCRIPTOR = 'L'

    ACC_INTERFACE = 0x200
    ACC_ABSTRACT = 0x400

    def parse(filename)
        @java_class = JavaClass.new
        @java_class.package = :default

        @file = File.new(filename,"r")
        parse_magic
        parse_minor_version
        parse_major_version
        parse_constant_pool
        parse_access_flags
        parse_class_name_and_package
        parse_super_class
        parse_interfaces
        parse_fields
        parse_methods

        @java_class
    end

    def parse_magic
        magic = read_u4
        unless magic == 0xCAFEBABE
            raise "File '#{filename}' is not a java class file!"
        end
    end

    def parse_minor_version
        read_u2
    end

    def parse_major_version
        read_u2
    end

    def parse_constant_pool
        @constant_pool = Array.new
        constant_pool_count = read_u2
        for i in 1...constant_pool_count
            @constant_pool << parse_next_constant
        end
    end

    def parse_next_constant
        tag = read_u1
        c = Constant.new
        c.tag = tag

        case tag
        when CONSTANT_CLASS
            c.name_index = read_u2
        when CONSTANT_STRING
            c.name_index = read_u2
        when CONSTANT_FIELD
            c.name_index = read_u2
            c.type_index = read_u2
        when CONSTANT_METHOD
            c.name_index = read_u2
            c.type_index = read_u2
        when CONSTANT_INTERFACEMETHOD
            c.name_index = read_u2
            c.type_index = read_u2
        when CONSTANT_NAMEANDTYPE
            c.name_index = read_u2
            c.type_index = read_u2
        when CONSTANT_INTEGER
            c.value = read_int
        when CONSTANT_FLOAT
            c.value = read_float
        when CONSTANT_LONG
            c.value = read_long
        when CONSTANT_DOUBLE
            c.value = read_double
        when CONSTANT_UTF8
            c.value = read_utf8
        else 
            raise "Unknown constant: #{tag}"
        end

        c
    end

    def parse_access_flags
        access_flags = read_u2
        is_abstract = (access_flags & ACC_INTERFACE) != 0
        is_abstract |= (access_flags & ACC_ABSTRACT) != 0
        @java_class.abstract = is_abstract
    end

    def parse_class_name_and_package
        index = read_u2
        full_qualified_class_name = slashes_to_dots(@constant_pool[index].value)
        start_index = 0
        end_index = full_qualified_class_name.rindex(".")
        if(end_index && end_index > start_index)
            package = full_qualified_class_name[start_index...end_index]
            class_name = full_qualified_class_name[(end_index+1)..full_qualified_class_name.length]
            @java_class.package = package
            @java_class.name = class_name
        else
            @java_class.name = full_qualified_class_name
        end
    end

    def slashes_to_dots(string)
        string.gsub(/\//, '.')
    end

    def parse_super_class
        index = read_u2
        if in_range_of_constant_pool? index
            super_class = slashes_to_dots(@constant_pool[index].value)
            @java_class.super_class = super_class
        end
    end

    def parse_interfaces
        interface_table_count = read_u2
        for i in 0...interface_table_count
            index = read_u2
            if in_range_of_constant_pool? index
                interface = slashes_to_dots(@constant_pool[index].value)
                @java_class.interfaces << interface
            end
        end
    end

    def in_range_of_constant_pool?(index)
        index > 0 && index < @constant_pool.length
    end

    def parse_fields
        fields = Array.new
        field_table_count = read_u2
        for i in 0...field_table_count
            fields << parse_field
        end
        fields.each do |field|
            resolve_field_based_on_constant_pool(field)
        end
    end

    def parse_field
        field = FieldInfo.new
        field.access_flags = read_u2
        field.name_index = read_u2
        field.descriptor_index = read_u2
        field.attributes_count = read_u2
        field.attributes = Array.new
        for i in 0...field.attributes_count
            field.attributes << parse_attribute
        end
        field
    end

    def parse_attribute
        attribute = AttributeInfo.new
        attribute.attribute_name_index = read_u2
        attribute.attribute_length = read_u4
        attribute.info = Array.new
        for i in 0...attribute.attribute_length
            attribute.info << read_u1
        end
        attribute
    end

    def resolve_field_based_on_constant_pool(field)
        name_index = field.name_index - 1
        field_name = @constant_pool[name_index].value
        type_index = field.descriptor_index - 1
        field_type = @constant_pool[type_index].value
        field_type = field_type[1...field_type.length-1] # remove 'L' and ';' e.g. "Ljava/lang/Integer;"
        field_type = slashes_to_dots(field_type)
        @java_class.fields[field_name] = field_type
    end

    def parse_methods
        methods = Array.new
        methods_count = read_u2
        for i in 0...methods_count
            methods << parse_method
        end
    end

    def parse_method
        method = MethodInfo.new
        method.access_flags = read_u2
        method.name_index = read_u2
        method.descriptor_index= read_u2
        method.attributes_count = read_u2
        method.attributes = Array.new
        for i in 0...method.attributes_count
            method.attributes << parse_attribute
        end
        method
    end

    def read_u1
        @file.read(1).unpack("C")[0]
    end

    def read_u2
        @file.read(2).unpack("n")[0]
    end

    def read_u4
        @file.read(4).unpack("N")[0]
    end

    def read_int
        @file.read(4).unpack("l")[0]
    end

    def read_long
        @file.read(8).unpack("q")[0]
    end

    def read_float
        @file.read(4).unpack("F")[0]
    end

    def read_double
        @file.read(8).unpack("D")[0]
    end

    def read_utf8
        utf8_size = read_u2
        @file.read(utf8_size)
    end

end
