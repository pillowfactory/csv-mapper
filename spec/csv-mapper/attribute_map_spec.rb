require File.dirname(__FILE__) + '/../spec_helper.rb'

describe CsvMapper::AttributeMap do
  
  class TestContext
    def transform_it(row, index)
      :transform_it_success
    end
  end
    
  before(:each) do
    @row_attr = CsvMapper::AttributeMap.new('foo', 1, TestContext.new)
    @csv_row = ['first_name', 'last_name']
  end
  
  it "should map a destination attribute name" do
    @row_attr.name.should == 'foo'
  end

  it "should map a CSV column index" do
    @row_attr.index.should be(1)
  end
  
  it "should map a transformation between the CSV value and destination value and chain method calls" do
    @row_attr.map(:named_transform).should be(@row_attr)
  end
  
  it "should provide ability to set the index and chain method calls" do
    @row_attr.at(9).should be(@row_attr)
    @row_attr.index.should be(9)
  end
  
  it "should parse values" do
    @row_attr.parse(@csv_row).should == @csv_row[1]
  end

  it "should parse values using a mapped lambda transformers" do
    @row_attr.map( lambda{|row, index| :success } )
    @row_attr.parse(@csv_row).should == :success
  end

  it "should parse values using a mapped lambda transformer that only accepts the row" do
    @row_attr.map( lambda{|row| :success } )
    @row_attr.parse(@csv_row).should == :success
  end
  
  it "should parse values using a mapped block transformers" do
    @row_attr.map {|row, index| :success }
    @row_attr.parse(@csv_row).should == :success
  end

  it "should parse values using a mapped block transformer that only accepts the row" do
    @row_attr.map {|row, index| :success }
    @row_attr.parse(@csv_row).should == :success
  end
  
  it "should parse values using a named method on the context" do
    @row_attr.map(:transform_it).parse(@csv_row).should == :transform_it_success
  end
  
  it "should provide access to the raw value" do
    @row_attr.raw_value(@csv_row).should be(@csv_row[@row_attr.index])
  end
  
end
