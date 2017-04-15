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
  end
end
