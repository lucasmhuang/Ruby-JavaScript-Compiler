class Tokenizer
    TOKEN_TYPES = [
        [:def, /\bdef\b/],
        [:end, /\bend\b/],
        [:identifier, /\b[a-zA-Z]+\b/],
        [:integer, /\b[0-9]+\b/],
        [:oparen, /\(/],
        [:cparen, /\)/],
        [:comma, /,/],
    ]

    def initialize(code)
        @code = code
    end

    def tokenize
        tokens = []
        while !@code.empty?
            tokens << tokenize_one_token
            @code = @code.strip
        end
        tokens
    end

    def tokenize_one_token
        TOKEN_TYPES.each do |type, re|
            re = /\A(#{re})/
            if @code =~ re
                value = $1
                @code = @code[value.length..-1]
                return Token.new(type, value)
            end
        end

        raise RuntimeError.new(
            "Couldn't match token on #{@code.inspect}")
    end
end

Token = Struct.new(:type, :value)

# parse_body -> parse_function_call ->  parse_function_args -> parse_body repeating cycle
class Parser
    def initialize(tokens)
        @tokens = tokens
    end

    def parse
        parse_def
    end

    def parse_def  
        consume(:def)
        name = consume(:identifier).value
        arg_names = parse_arg_names
        body = parse_body
        consume(:end)
        DefNode.new(name, arg_names, body)
    end

    def parse_arg_names
        arg_names = []

        consume(:oparen)
        if peek(:identifier)
            arg_names << consume(:identifier).value
            while peek(:comma)
                consume(:comma)
                arg_names << consume(:identifier).value
            end
        end
        consume(:cparen)
        
        arg_names
    end

    def parse_body
        if peek(:integer)
            parse_integer
        elsif peek(:identifier) && peek(:oparen, 1)
            parse_function_call
        else
            parse_variable_reference
        end
    end

    def parse_integer
        IntegerNode.new(consume(:integer).value.to_i)
    end
    
    def parse_function_call
        name = consume(:identifier).value
        function_args = parse_function_args
        FunctionCallNode.new(name, function_args)
    end

    def parse_function_args
        function_args = []
        consume(:oparen)

        if !peek(:cparen)
            function_args << parse_body
            while peek(:comma)
                consume(:comma)
                function_args << parse_body
            end
        end

        consume(:cparen)
        function_args
    end

    def parse_variable_reference
        VariableNode.new(consume(:identifier).value)
    end

    def consume(expected_type)
        token = @tokens.shift
        if token.type == expected_type
            token
        else
            raise RuntimeError.new(
                "Expected token type #{expected_type.inspect} but got #{token.type.inspect}")
        end       
    end

    def peek(expected_type, offset = 0)
        @tokens.fetch(offset).type == expected_type
    end
end

DefNode = Struct.new(:name, :arg_names, :body)
IntegerNode = Struct.new(:value)
FunctionCallNode = Struct.new(:name, :function_args)
VariableNode = Struct.new(:value)

#recursively crawls over recursive tree created in parser
class Generator
    def generate(node)
        case node
        when DefNode
            "function %s(%s) { return %s };" % [
                node.name, node.arg_names.join(","),
                generate(node.body),
            ]
        when FunctionCallNode
            "%s(%s)" % [
                node.name, node.function_args.map { |expr| generate(expr) }.join(","),
            ]
        when VariableNode
            node.value
        when IntegerNode
            node.value
        else
            raise RuntimeError.new(
                "Unexpected node type #{node.class}")
        end
    end
end

tokens = Tokenizer.new(File.read("test.src")).tokenize
tree = Parser.new(tokens).parse
generated = Generator.new.generate(tree)
RUNTIME = "function add(x,y) { return x + y };"
TEST = "console.log(f(1, 2));"
puts [RUNTIME, generated, TEST].join("\n")