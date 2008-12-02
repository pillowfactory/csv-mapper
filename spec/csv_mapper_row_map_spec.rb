require File.dirname(__FILE__) + '/spec_helper.rb'

# import_to SomeClass, :some => 'default', :values => 'orsomethinglikethat'
# start_at_row 1
# 
# before_row :prepare_row
# after_row :save_record, :then_do_something
# 
# foo; bar; _SKIP_; another;
# 
# woot.map lamda{|record| record[woot.index].to_i }
# bam.map :map_bam

# Time to add your specs!
# http://rspec.info/
describe CsvMapper::RowMap do
  
  class TestMapToClass
    attr_accessor :foo, :bar, :baz
  end
  
  class TestMapContext; end;
  
  before(:each) do
    @row_map = CsvMapper::RowMap.new(TestMapContext.new)
    @csv_row = ['first_name', 'last_name']
  end

  it "should parse a CSV row" do
    @row_map.parse(@csv_row).should_not be_nil
  end

  it "should map to a OpenStruct by default" do
    @row_map.parse(@csv_row).should be_instance_of OpenStruct
  end
  
  it "should parse a CSV row returning the mapped result" do
    @row_map.fname
    @row_map.lname
    
    result = @row_map.parse(@csv_row)
    result.fname.should eql @csv_row[0]
    result.lname.should eql @csv_row[1]
  end

  it "should map to a ruby class with optional default attribute values" do
    @row_map.map_to TestMapToClass, :baz => :default_baz
    
    @row_map.foo
    @row_map.bar
    
    (result = @row_map.parse(@csv_row)).should be_instance_of TestMapToClass
    result.foo.should eql @csv_row[0]
    result.bar.should eql @csv_row[1]
    result.baz.should eql :default_baz
  end
    
  it "should have a moveable cursor" do
    @row_map.cursor.should be 0
    @row_map.move_cursor
    @row_map.cursor.should be 1
    @row_map.move_cursor 3
    @row_map.cursor.should be 4
  end
  
  it "should skip indexes" do
    pre_cursor = @row_map.cursor
    @row_map._SKIP_
    @row_map.cursor.should be(pre_cursor + 1)
  end
  
  it "should maintain a collection of attribute mappings" do
    @row_map.attributes.should be_kind_of Enumerable
  end
  
  it "should lazy initialize attribute maps and move the cursor" do
    pre_cursor = @row_map.cursor
    (attr_map = @row_map.first_name).should be_instance_of CsvMapper::AttributeMap
    attr_map.index.should be pre_cursor
    @row_map.cursor.should be (pre_cursor + 1)
  end
  
  it "should lazy initialize attribute maps with optional cursor position" do
    pre_cursor = @row_map.cursor
    @row_map.last_name(1).index.should be 1
    @row_map.cursor.should be 1
  end
end