module Eryastic
  class Domain < Client

    include Eryastic::Helper

    def create_domain(domain_name = nil, config_file)
      if config_file == nil
        puts '設定ファイルを指定してください.(--config-file=exmaple.toml)'
        exit 1
      end

      config_tmp = config_parse(config_file)
      %w(domain_id arn endpoint).each do |key|
        config_tmp.delete(key.to_sym) if key.to_sym
      end

      log.info('以下の構成で Elasticsearch ドメインを作成します.')
      config = Marshal.load(Marshal.dump(config_tmp))
      puts display_domain_resources(config_tmp)

      if process_ok?
        begin
          create_domain_action(config)
        rescue StandardError => e
          log.error(e)
          exit 1
        end
      else
        exit 0
      end
      create_spec_generate(config)
    end

    def delete_domain(domain_name = nil)
      if domain_name == nil
        puts 'ドメイン名を指定してください.(--domain-name=exmaple)'
        exit 1
      end
      res = ess_client.describe_elasticsearch_domains({ domain_names: [domain_name] })
      if res.domain_status_list.empty?
        log.warn('指定した Amazon Elasticsearch Service ドメインは削除済みです.')
        exit 0
      elsif res.domain_status_list.last.deleted
        log.warn('指定した Amazon Elasticsearch Service ドメインは削除中です.')
        exit 0
      end

      log.info('以下の Amazon Elasticsearch Service ドメインを削除します.')
      config = res.domain_status_list.last.to_h
      puts display_domain_resources(config)

      if process_ok?
        begin
          delete_domain_action(domain_name)
        rescue StandardError => e
          log.error(e)
          exit 1
        end
      else
        exit 0
      end
      delete_spec_generate(domain_name)
    end

    def export_domain(domain_name = nil, config_file = nil)
      if domain_name == nil
        puts 'ドメイン名を指定してください.(--domain-name=exmaple)'
        exit 1
      end
      res = ess_client.describe_elasticsearch_domains({ domain_names: [domain_name] })
      if res.domain_status_list.empty?
        log.warn('指定した Amazon Elasticsearch Service ドメインは存在しません.')
        exit 0
      end

      log.info('Amazon Elasticsearch Service ドメイン ' + domain_name + ' 設定を export します.')
      config = res.domain_status_list.last.to_h
      %w(created deleted processing).each do |key|
        config.delete(key.to_sym)
      end
      display_domain_configs(config, config_file)
    end

    def list_domain
      log.info('Amazon Elasticsearch Service ドメインの一覧を取得します.')
      res = ess_client.list_domain_names()
      if res.domain_names.empty?
        log.warn('Amazon Elasticsearch Service ドメインは存在しません.')
        exit 0
      end

      domain_names = []
      res.domain_names.each do |domain|
        domain_names << domain.domain_name
      end

      res = ess_client.describe_elasticsearch_domains({ domain_names: domain_names })
      domains = []
      res.domain_status_list.each do |domain|
        domains << [ domain.domain_name, domain.endpoint, domain.elasticsearch_version, domain.elasticsearch_cluster_config.instance_count, domain.created, domain.deleted, domain.processing ]
      end
      header = [ 'domain_name', 'endpoint', 'elasticsearch_version', 'nodes', 'created', 'deleted', 'processing' ]
      puts display_resources(header, domains)
    end

    def update_domain(domain_name = nil, config_file)
      if domain_name == nil or config_file == nil
        puts 'ドメイン名及び設定ファイルを指定してください.(--domain-name=example --config-file=exmaple.toml)'
        exit 1
      end

      update_config = config_parse(config_file)
      res = ess_client.describe_elasticsearch_domains({ domain_names: [domain_name] })
      log.info('以下の構成で Amazon Elasticsearch Service ドメインを更新します.')
      current_config = res.domain_status_list.last.to_h

      puts display_merged_domain_resources(current_config, update_config)
      if process_ok?
        begin
          update_domain_action(update_config)
        rescue StandardError => e
          log.error(e)
          exit 1
        end
      else
        exit 0
      end
      create_spec_generate(update_config)
    end
  end
end
