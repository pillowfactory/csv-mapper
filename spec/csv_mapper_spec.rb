require File.dirname(__FILE__) + '/spec_helper.rb'

# Time to add your specs!
# http://rspec.info/
describe CsvMapper do
    
  # it "find this spec in spec directory" do
  #   violated "Be sure to write your specs"
  # end

  before(:each) do
    @mapped_klass = Class.new { include CsvMapper }
    @mapped = @mapped_klass.new
  end

  it "should import a CSV IO" do
    io = StringIO.new 'foo, bar, 00, 01'
    (results = @mapped.import(io)).should be_kind_of Enumerable
    results.should have(1).things
  end
  
  it "should description" do
    
  end
  
  
  
end
