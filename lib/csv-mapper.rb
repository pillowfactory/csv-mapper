$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'ostruct'

module CsvMapper
  VERSION = '0.0.1'

  # Prefer FasterCSV over CSV 
  Parser =
    begin
      require 'fastercsv'
      FasterCSV
    rescue LoadError
      require 'csv'
      CSV
    end

  # Create a new RowMap instance from the definition in the given block.
  def map_csv(&map_block)
    (map = CsvMapper::RowMap.new(self)).instance_eval(&map_block)
    map
  end
  
  # Load a CSV file from the given csv_path and map the values according to the definition in the given block.
  # Using the optional row_map (create using map_csv) parameter will take presidence over a block definition.
  def import_csv(csv_path, row_map=nil, &map_block)
    map = row_map || map_csv(&map_block)
    
    results, i = [], 0
    Parser.foreach(csv_path) do |row|
      results << map.parse(row) if i >= map.start_at_row
      i += 1
    end
    
    results
  end
  
  # Load a CSV string representation from the given csv_string and map the values according to the definition in the given block.
  # Using the optional row_map (create using map_csv) parameter will take presidence over a block definition.
  def import_string(csv_string, row_map=nil, &map_block)
    map = row_map || map_csv(&map_block)
    
    results, i = [], 0
    Parser.parse(csv_string) do |row|
      results << map.parse(row) if i >= map.start_at_row
      i += 1
    end
    
    results
  end

  
  #
  # CsvMapper::RowMap provides a simple, DSL-like interface for constructing mappings.
  # A CsvMapper::RowMap provides the main functionality of the library. It will mostly be used indirectly through the CsvMapper API, 
  # but may be useful to use directly for the dynamic CSV mappings.
  class RowMap
    #Start with a 'blank slate'
    instance_methods.each { |m| undef_method m unless m =~ /^__||instance_eval/ }
    
    attr_reader :mapped_attributes
    
    # Create a new instance with access to an evaluation context 
    def initialize(context)
      @context = context
      @before_filters = []
      @after_filters = []
      @start_at_row = 0
      @mapped_attributes = []
    end
    
    # Each row of a CSV is parsed and mapped to a new instance of a Ruby class; OpenStruct by default.
    # Use this method to change the what class each row is mapped to.  
    # The given class must respond to a parameter-less #new and all attribute mappings defined.
    # Providing a hash of defaults will ensure that each resulting object will have the providing name and attribute values 
    # unless overridden by a mapping
    def map_to(klass, defaults={})
      @map_to_klass = klass
      
      defaults.each do |name, value|
        self.add_attribute(name, -99).map lambda{|row| value}
      end
    end
    
    # The current cursor location
    def cursor  # :nodoc:
      @cursor ||= 0
    end
    
    # Move the cursor relative to it's current position
    def move_cursor(positions=1) # :nodoc:
      self.cursor += positions
    end
    
    # Given a CSV row return an instance of an object defined by this mapping
    def parse(csv_row)
      target = self.map_to_class.new
      @before_filters.each {|filter| filter.call(csv_row, target) }
        
      self.mapped_attributes.inject(target) do |result, attr_map|
        result.send("#{attr_map.name}=".to_sym, attr_map.parse(csv_row))
        result
      end
      
      @after_filters.each {|filter| filter.call(csv_row, target) }
      
      return target
    end
    
    # Convenience method to 'move' the cursor skipping the current index.
    def _SKIP_
      self.move_cursor
    end
    
    # Declare what row to begin parsing the CSV.
    # This is useful for skipping headers and such.
    def start_at_row(row_number=nil)
      @start_at_row = row_number if row_number
      @start_at_row
    end
    
    # Declare method name symbols and/or lambdas to be executed before each row.
    # Each method or lambda must accept to parameters: +csv_row+, +target_object+
    # Methods names should refer to methods available within the RowMap's provided context
    def before_row(*befores)
      self.add_filters(@before_filters, *befores)
    end
    
    # Declare method name symbols and/or lambdas to be executed before each row.
    # Each method or lambda must accept to parameters: +csv_row+, +target_object+
    # Methods names should refer to methods available within the RowMap's provided context
    def after_row(*afters)
      self.add_filters(@after_filters, *afters)
    end
    
    # Add a new attribute to this map.  Mostly used internally, but is useful for dynamic map creation.
    # returns the newly created CsvMapper::AttributeMap
    def add_attribute(name, index=nil)
      attr_mapping = CsvMapper::AttributeMap.new(name.to_sym, index, @context)
      self.mapped_attributes << attr_mapping
      attr_mapping
    end      
    
    protected # :nodoc:
    
    # The Hacktastic "magic"
    # Used to dynamically create CsvMapper::AttributeMaps based on unknown method calls that 
    # should represent the names of mapped attributes.
    #
    # An optional first argument is used to move this maps cursor position and as the index of the
    # new AttributeMap
    def method_missing(name, *args) # :nodoc:
      
      if index = args[0]
        self.move_cursor(index - self.cursor)
      else
        index = self.cursor
        self.move_cursor
      end
      
      add_attribute(name, index)
    end
    
    def add_filters(to_hook, *filters) # :nodoc:
      (to_hook << filters.collect do |filter|
        filter.is_a?(Symbol) ? lambda{|row, target| @context.send(filter, row, target)} : filter
      end).flatten!
    end
            
    def map_to_class # :nodoc:
      @map_to_klass || OpenStruct
    end
    
    def cursor=(value) # :nodoc:
      @cursor=value
    end
    
    
  end
  
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
    def map(transform)
      @transformer = transform
      self
    end
    
    # Given a CSV row, return the value at this AttributeMap's index using any provided map transforms (see map)
    def parse(csv_row)
      @transformer ? parse_transform(csv_row) : csv_row[self.index]
    end
    
    # Access the raw value of the CSV row without any map transforms applied.
    def raw_value(csv_row)
      csv_row[self.index]
    end
    
    private
    
    def parse_transform(csv_row)
      if @transformer.is_a? Symbol
        transform_name = @transformer
        @transformer = lambda{|row| @map_context.send(transform_name, row) }
      end
      
      @transformer.call(csv_row)
    end
    
  end
end