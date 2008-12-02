$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'ostruct'

module CsvMapper
  VERSION = '0.0.1'

  Parser = 
    begin
      require 'fastercsv'
      FasterCSV
    rescue LoadError
      require 'csv'
      CSV
    end

  def map_csv(&map_block)
    (map = CsvMapper::RowMap.new(self)).instance_eval(&map_block)
    map
  end
  
  def import_csv(csv_path, mapping=nil, &map_block)
    map = mapping || map_csv(&map_block)
    
    results = []
    Parser.foreach(csv_path) do |row|
      results << map.parse(row)
    end
    
    results
  end
  
  def import_string(csv_string, mapping=nil, &map_block)
    map = mapping || map_csv(&map_block)
    
    results = []
    Parser.parse(csv_string) do |row|
      results << map.parse(row)
    end
    
    results
  end

  class RowMap
    #Start with a 'blank slate'
    instance_methods.each { |m| undef_method m unless m =~ /^__||instance_eval/ }
    
    attr_reader :mapped_attributes
    
    def initialize(context)
      @context = context
      @before_filters = []
      @after_filters = []
      @start_at_row = 0
      @mapped_attributes = []
    end
    
    def map_to(klass, defaults)
      @map_to_klass = klass
      
      defaults.each do |name, value|
        self.add_attribute(name, -99).map lambda{|row| value}
      end
    end
    
    def cursor
      @cursor ||= 0
    end
    
    def move_cursor(positions=1)
      self.cursor += positions
    end
    
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
    
    def _SKIP_
      self.move_cursor
    end
    
    def start_at_row(row_number=nil)
      @start_at_row = row_number if row_number
      @start_at_row
    end
    
    def before_row(*befores)
      self.add_filters(@before_filters, *befores)
    end
    
    def after_row(*afters)
      self.add_filters(@after_filters, *afters)
    end
          
    protected
    
    def method_missing(name, *args)
      
      if index = args[0]
        self.move_cursor(index - self.cursor)
      else
        index = self.cursor
        self.move_cursor
      end
      
      add_attribute(name, index)
    end
    
    def add_filters(to_hook, *filters)
      (to_hook << filters.collect do |filter|
        filter.is_a?(Symbol) ? lambda{|row, target| @context.send(filter, row, target)} : filter
      end).flatten!
    end
        
    def add_attribute(name, index)
      attr_mapping = CsvMapper::AttributeMap.new(name, index, @context)
      self.mapped_attributes << attr_mapping
      attr_mapping
    end
    
    def map_to_class
      @map_to_klass || OpenStruct
    end
    
    def cursor=(value)
      @cursor=value
    end
    
    
  end
  
  class AttributeMap
    attr_reader :name, :index
    
    def initialize(name, index, map_context)
      @name, @index, @map_context = name, index, map_context
    end
    
    def at(index)
      @index = index
      self
    end
    
    def map(transform)
      @transformer = transform
      self
    end
    
    def parse(csv_row)
      @transformer ? parse_transform(csv_row) : csv_row[self.index]
    end
    
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