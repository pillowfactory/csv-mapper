$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'ostruct'
require 'fastercsv'

# This module provides the main interface for importing CSV files & data to mapped Ruby objects.
# = Usage
# Including CsvMapper will provide two methods:
# - +import+
# - +map_csv+
#
# See csv-mapper.rb[link:files/lib/csv-mapper_rb.html] for method docs.
#
# === Import From File
#   results = import('/path/to/file.csv') do
#     # declare mapping here
#   end
#
# === Import From String or IO
#   results = import(csv_data, :type => :io) do
#     # declare mapping here
#   end
#
# === Mapping
# Mappings are built inside blocks.  All three of CsvMapper's main API methods accept a block containing a mapping.
# Maps are defined by using +map_to+, +start_at_row+, +before_row+, and +after_row+ (methods on CsvMapper::RowMap) and
# by defining your own mapping attributes.
# A mapping block uses an internal cursor to keep track of the order the mapping attributes are declared and use that order to 
# know the corresponding CSV column index to associate with the attribute.
# 
# ===== The Basics
# * +map_to+ - Override the default OpenStruct target. Accepts a class and an optional hash of default attribute names and values.
# * +start_at_row+ - Specify what row to begin parsing at.  Use this to skip headers.
# * +before_row+ - Accepts an Array of method name symbols or lambdas to be invoked before parsing each row.
# * +after_row+ - Accepts an Array of method name symbols or lambdas to be invoked after parsing each row.
# * +delimited_by+ - Accepts a character to be used to delimit columns. Use this to specify pipe-delimited files.
# * <tt>\_SKIP_</tt> - Use as a placehold to skip a CSV column index.
# * +parser_options+ - Accepts a hash of FasterCSV options.  Can be anything FasterCSV::new()[http://fastercsv.rubyforge.org/classes/FasterCSV.html#M000018] understands
# 
# ===== Attribute Mappings
# Attribute mappings are created by using the name of the attribute to be mapped to.  
# The order in which attribute mappings are declared determines the index of the corresponding CSV row.  
# All mappings begin at the 0th index of the CSV row.
#   foo  # maps the 0th CSV row position value to the value of the 'foo' attribute on the target object.
#   bar  # maps the 1st row position to 'bar'
# This could also be a nice one liner for easy CSV format conversion
#   [foo, bar]  # creates the same attribute maps as above.
# The mapping index may be specifically declared in two additional ways:
#   foo(2)     # maps the 2nd CSV row position value to 'foo' and moves the cursor to 3
#   bar        # maps the 3rd CSV row position to 'bar' due to the current cursor position
#   baz.at(0)  # maps the 0th CSV row position to 'baz' but only increments the cursor 1 position to 4
# Each attribute mapping may be configured to parse the record using a lambda or a method name
#   foo.map lambda{|row| row[2].strip } # maps the 2nd row position value with leading and trailing whitespace removed to 'foo'.
#   bar.map :clean_bar  # maps the result of the clean_bar method to 'bar'. clean_bar must accept the row as a parameter.
# Attribute mapping declarations and "modifiers" may be chained
#   foo.at(4).map :some_transform
#
# === Create Reusable Mappings
# The +import+ method accepts an instance of RowMap as an optional mapping parameter.  
# The easiest way to create an instance of a RowMap is by using +map_csv+.
#   a_row_map = map_csv do 
#     # declare mapping here
#   end
# Then you can reuse the mapping
#   results = import(some_string, :type => :io, :map => a_row_map)
#   other_results = import('/path/to/file.csv', :map => a_row_map)
#
module CsvMapper
  VERSION = '0.0.3'

  # Create a new RowMap instance from the definition in the given block.
  def map_csv(&map_block)
    CsvMapper::RowMap.new(self, &map_block)
  end
  
  # Load CSV data and map the values according to the definition in the given block.
  # Accepts either a file path, String, or IO as +data+.  Defaults to file path.
  # 
  # The following +options+ may be used:
  # <tt>:type</tt>:: defaults to <tt>:file_path</tt>. Use <tt>:io</tt> to specify data as String or IO.
  # <tt>:map</tt>:: Specify an instance of a RowMap to take presidence over a given block defintion.
  #
  def import(data, options={}, &map_block)
    csv_data = options[:type] == :io ? data : File.new(data, 'r')

    config = { :type => :file_path,
               :map => map_csv_with_data(csv_data, &map_block) }.merge!(options)

    map = config[:map]
    
    results = []
    FasterCSV.new(csv_data, map.parser_options ).each_with_index do |row, i|
      results << map.parse(row) if i >= map.start_at_row && i <= map.stop_at_row
    end
    
    results
  end  

  # CsvMapper::RowMap provides a simple, DSL-like interface for constructing mappings.
  # A CsvMapper::RowMap provides the main functionality of the library. It will mostly be used indirectly through the CsvMapper API, 
  # but may be useful to use directly for the dynamic CSV mappings.
  class RowMap
    #Start with a 'blank slate'
    instance_methods.each { |m| undef_method m unless m =~ /^__||instance_eval/ }
    
    Infinity = 1.0/0
    attr_reader :mapped_attributes
    
    # Create a new instance with access to an evaluation context 
    def initialize(context, csv_data = nil, &map_block)
      @context = context
      @csv_data = csv_data
      @before_filters = []
      @after_filters = []
      @parser_options = {}
      @start_at_row = 0
      @stop_at_row = Infinity
      @delimited_by = FasterCSV::DEFAULT_OPTIONS[:col_sep]
      @mapped_attributes = []
      
      self.instance_eval(&map_block) if block_given?
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
    
    # Allow us to read the first line of a csv file to automatically generate the attribute names.
    # Spaces are replaced with underscores and non-word characters are removed.
    #
    # Keep in mind that there is potential for overlap in using this (i.e. you have a field named
    # files+ and one named files- and they both get named 'files').
    #
    # You can specify aliases to rename fields to prevent conflicts and/or improve readability and compatibility.
    #
    # i.e. read_attributes_from_file('files+' => 'files_plus', 'files-' => 'files_minus)
    def read_attributes_from_file aliases = {}
      attributes = FasterCSV.new(@csv_data, @parser_options).readline
      @start_at_row = [ @start_at_row, 1 ].max
      @csv_data.rewind
      attributes.each_with_index do |name, index|
        name.strip!
        use_name = aliases[name] || name.gsub(/\s+/, '_').gsub(/[\W]+/, '').downcase
        add_attribute use_name, index
      end
    end

    # Specify a hash of FasterCSV options to be used for CSV parsing
    #
    # Can be anything FasterCSV::new()[http://fastercsv.rubyforge.org/classes/FasterCSV.html#M000018] accepts
    def parser_options(opts=nil)
      @parser_options = opts if opts
      @parser_options.merge :col_sep => @delimited_by 
    end
    
    # Convenience method to 'move' the cursor skipping the current index.
    def _SKIP_
      self.move_cursor
    end
    
    # Specify the CSV column delimiter. Defaults to comma.
    def delimited_by(delimiter=nil)
      @delimited_by = delimiter if delimiter
      @delimited_by
    end
    
    # Declare what row to begin parsing the CSV.
    # This is useful for skipping headers and such.
    def start_at_row(row_number=nil)
      @start_at_row = row_number if row_number
      @start_at_row
    end
    
    # Declare the last row to be parsed in a CSV.
    def stop_at_row(row_number=nil)
      @stop_at_row = row_number if row_number
      @stop_at_row
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

  protected
  # Create a new RowMap instance from the definition in the given block and pass the csv_data.
  def map_csv_with_data(csv_data, &map_block) # :nodoc:
    CsvMapper::RowMap.new(self, csv_data, &map_block)
  end
end