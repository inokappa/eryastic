module Eryastic
  module Helper
    def process_ok?
      while true
        puts "処理を続行しますか ? [y|n]:"
        response = STDIN.gets.chomp
        case response
        when /^[yY]/
          log.info('処理を続行します.')
          return true
        when /^[nN]/, /^$/
          log.warn('処理を中止します.')
          return false
        end
      end
    end

    def datetime_parse(datetime)
      if datetime.to_s.include?('-')
        Time.parse(datetime.to_s.tr('-', '/')).to_i
      else
        Time.parse(datetime).to_i
      end
    end

    def log
      Logger.new(STDOUT)
    end

    def hl
      require 'highline'
      HighLine.new
    end

    def config_parse(config_file)
      if File.exists?(config_file)
        config = Tomlrb.load_file(config_file, symbolize_keys: true)
        config[:domain_name] = config[:main][:domain_name]
        config[:elasticsearch_version] = config[:main][:elasticsearch_version]
        config[:access_policies] = config[:main][:access_policies]
        # config.delete(:advanced_options)
        config.delete(:main)
        config
      else
        puts '設定ファイルが存在していません. 設定ファイルのパスを確認してください.'
        exit 1
      end
    end

    def delete_spec_generate(domain_name)
      template = <<-'EOF'
describe elasticsearch("<%= domain_name %>") do
  it { should_not exist }
end
EOF
      File.open("./spec/" + "delete_spec.rb", "w") do |file|
        file.puts "require 'spec_helper'"
        file.puts ERB.new(template, nil, "-").result(binding).gsub(/^\n/, "")
      end
    end

    def create_spec_generate(config)
      template = <<-'EOF'
describe elasticsearch("<%= config[:domain_name].to_s %>") do
  it { should exist }
<% config.each do |key, value| %>
<% if key == 'access_policies'.to_sym %>
  it do
    should have_access_policies <<-policy
<%= JSON.pretty_generate(JSON.load(value)) %>
  policy
  end
<% end %>
<% if value.kind_of?(Hash) %>
<% value.each do |k, v| %>
<% if k == 'instance_type'.to_sym or k == 'volume_type'.to_sym %>
  its("<%= key.to_s + '.' + k.to_s %>") { should eq "<%= v %>" }
<% else %>
  its("<%= key.to_s + '.' + k.to_s %>") { should eq <%= v %> }
<% end %>
<% end %>
<% else %>
<% if key != 'access_policies'.to_sym %>
<% if key == 'domain_name'.to_sym or key == 'elasticsearch_version'.to_sym %>
  its("<%= key.to_sym %>") { should eq "<%= value %>" }
<% else %>
  its("<%= key.to_sym %>") { should eq <%= value %> }
<% end %>
<% end %>
<% end %>
<% end %>
end
EOF
      File.open("./spec/" + "deploy_spec.rb", "w") do |file|
        file.puts "require 'spec_helper'"
        file.puts ERB.new(template, nil, "-").result(binding).gsub(/^\n/, "")
      end
    end
  end
end
