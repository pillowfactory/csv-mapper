require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "csv-mapper"
    gem.summary = %Q{CsvMapper is a small library intended to simplify the common steps involved with importing CSV files to a usable form in Ruby.}
    gem.description = %Q{CSV Mapper makes it easy to import data from CSV files directly to a collection of any type of Ruby object. The simplest way to create mappings is declare the names of the attributes in the order corresponding to the CSV file column order.}
    gem.email = "lpillow@gmail.com"
    gem.homepage = "http://github.com/pillowfactory/csv-mapper"
    gem.authors = ["Luke Pillow"]
    gem.add_development_dependency "rspec", ">= 1.2.9"
    gem.add_dependency "fastercsv"  
    gem.extra_rdoc_files << "History.txt"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :spec => :check_dependencies

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "csv-mapper #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
