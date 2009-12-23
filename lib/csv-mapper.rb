dir = File.dirname(__FILE__)
$LOAD_PATH.unshift dir unless $LOAD_PATH.include?(dir)

require 'rubygems'

# the following is slightly modified from Gregory Brown's
# solution on the Ruport Blaag:
# http://ruport.blogspot.com/2008/03/fastercsv-api-shim-for-19.html
if RUBY_VERSION > "1.9"
 require "csv"
 unless defined? FCSV
   class Object
     FasterCSV = CSV
     alias_method :FasterCSV, :CSV
   end
 end
else
 require "fastercsv"
end

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
# * +map_to+ - Override the default Struct target. Accepts a class and an optional hash of default attribute names and values.
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

  protected
  # Create a new RowMap instance from the definition in the given block and pass the csv_data.
  def map_csv_with_data(csv_data, &map_block) # :nodoc:
    CsvMapper::RowMap.new(self, csv_data, &map_block)
  end
  
  extend self
end

require 'csv-mapper/row_map'