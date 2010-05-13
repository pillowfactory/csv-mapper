module CsvMapper
  # A CsvMapper::AttributeMap contains the instructions to parse a value from a CSV row and to know the
  # name of the attribute it is targeting.
  class AttributeMap
    attr_reader :name, :index
  
    # Creates a new instance using the provided attribute +name+, CSV row +index+, and evaluation +map_context+
    def initialize(name, index, map_context)
      @name, @index, @map_context = name, index, map_context
    end
  
    # Set the index that this map is targeting.
    #
    # Returns this AttributeMap for chainability
    def at(index)
      @index = index
      self
    end
  
    # Provide a lambda or the symbol name of a method on this map's evaluation context to be used when parsing
    # the value from a CSV row.  
    # Both the lambda or the method provided should accept a single +row+ parameter
    #
    # Returns this AttributeMap for chainability
    def map(transform=nil, &block_transform)
      @transformer = block_transform || transform
      self
    end
  
    # Given a CSV row, return the value at this AttributeMap's index using any provided map transforms (see map)
    def parse(csv_row)
      @transformer ? parse_transform(csv_row) : raw_value(csv_row)
    end
  
    # Access the raw value of the CSV row without any map transforms applied.
    def raw_value(csv_row)
      csv_row[self.index]
    end
  
    private
  
    def parse_transform(csv_row)
      if @transformer.is_a? Symbol
        transform_name = @transformer
        @transformer = lambda{|row, index| @map_context.send(transform_name, row, index) }
      end
    
      if @transformer.arity == 1
        @transformer.call(csv_row) 
      else
        @transformer.call(csv_row, @index)
      end
    end
end
end
