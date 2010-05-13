require 'csv-mapper/attribute_map'

module CsvMapper
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
  
    # Each row of a CSV is parsed and mapped to a new instance of a Ruby class; Struct by default.
    # Use this method to change the what class each row is mapped to.  
    # The given class must respond to a parameter-less #new and all attribute mappings defined.
    # Providing a hash of defaults will ensure that each resulting object will have the providing name and attribute values 
    # unless overridden by a mapping
    def map_to(klass, defaults={})
      @map_to_klass = klass
    
      defaults.each do |name, value|
        self.add_attribute(name, -99).map lambda{|row, index| value}
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
      
      self.mapped_attributes.each do |attr_map|
        target.send("#{attr_map.name}=", attr_map.parse(csv_row))
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
      unless @map_to_klass
        attrs = mapped_attributes.collect {|attr_map| attr_map.name}
        @map_to_klass = Struct.new(nil, *attrs)
      end
      
      @map_to_klass
    end
  
    def cursor=(value) # :nodoc:
      @cursor=value
    end
  end
end
