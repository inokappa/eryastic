require 'rspec/core/rake_task'
require 'bundler/gem_tasks'

RSpec::Core::RakeTask.new('spec')
task :default => :spec

namespace :spec do
  targets = []
  Dir.glob('./spec/*').each do |file|
    target = File.basename(file)
    if target.include?('_spec.rb') then
      targets << File.basename(target, '_spec.rb')
    end
  end

  targets.each do |target|
    desc "#{target} のテストを実行する."
    RSpec::Core::RakeTask.new(target.to_sym) do |t|
      t.rspec_opts = ["--format documentation", "--format html", "--out ./result_html/#{target}_result.html"]
      t.pattern = "spec/#{target}_spec.rb"
    end
  end
end
