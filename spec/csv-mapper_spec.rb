require File.dirname(__FILE__) + '/spec_helper.rb'

describe CsvMapper do
    
  before(:each) do    
    @mapped_klass = Class.new { include CsvMapper }
    @mapped = @mapped_klass.new
  end

  it "should allow the creation of CSV mappings" do
    mapping = @mapped.map_csv do
      start_at_row 2      
    end
    
    mapping.should be_instance_of CsvMapper::RowMap
    mapping.start_at_row.should == 2
  end
  
  it "should import a CSV IO" do
    io = 'foo,bar,00,01'
    results = @mapped.import(io, :type => :io) do 
      first
      second
    end
    
    results.should be_kind_of Enumerable
    results.should have(1).things
    results[0].first.should == 'foo'
    results[0].second.should == 'bar'
  end
  
  it "should import a CSV File IO" do
    results = import(File.dirname(__FILE__) + '/test.csv') do
      start_at_row 1
      [first_name, last_name, age]
    end
    
    results.size.should be(3)
  end 
  
  it "should import non-comma delimited files" do
    piped_io = 'foo|bar|00|01'
    
    results = import(piped_io, :type => :io) do
      delimited_by '|'
      [first, second]
    end
    
    results.should have(1).things
    results[0].first.should == 'foo'
    results[0].second.should == 'bar'
  end
  
end
