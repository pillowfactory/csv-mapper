$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'ostruct'

module CsvMapper
  VERSION = '0.0.1'

  class RowMap
    #Start with a 'blank slate'
    instance_methods.each { |m| undef_method m unless m =~ /^__/ }
    
    attr_reader :attributes
    
    def initialize(context)
      @context = context
      @attributes = []
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
      self.attributes.inject(self.map_to_class.new) do |result, attr_map|
        result.send("#{attr_map.name}=".to_sym, attr_map.parse(csv_row))
        result
      end
    end
    
    def _SKIP_
      self.move_cursor
    end
    
    def method_missing(name, *args)
      
      if index = args[0]
        self.move_cursor(index - self.cursor)
      else
        index = self.cursor
        self.move_cursor
      end
      
      add_attribute(name, index)
    end
    
    def add_attribute(name, index)
      attr_mapping = CsvMapper::AttributeMap.new(name, index, nil)
      self.attributes << attr_mapping
      attr_mapping
    end
    
    def map_to_class
      @map_to_klass || OpenStruct
    end
    
    private
    
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