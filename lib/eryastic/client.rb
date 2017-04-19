module Eryastic
  class Client

    def initialize
      raise 'AWS_PROFILE does not exist.' unless ENV['AWS_PROFILE']
      raise 'AWS_REGION does not exist.' unless ENV['AWS_REGION']
    end

    CLIENTS = {
      iam_client: Aws::IAM::Client,
      ess_client: Aws::ElasticsearchService::Client,
      s3_client: Aws::S3::Client
    }

    CLIENTS.each do |method_name, client|
      define_method method_name do
        eval "@#{method_name} ||= #{client}.new"
      end
    end

    def create_domain_action(config)
      begin
        res = ess_client.create_elasticsearch_domain(config)
        log.info('処理が成功しました.')
      rescue StandardError => e
        log.error('処理が失敗しました.' + e.to_s)
      end
    end

    def delete_domain_action(domain_name)
      begin
        res = ess_client.delete_elasticsearch_domain({ domain_name: domain_name })
        log.info('処理が成功しました.')
      rescue StandardError => e
        log.error('処理が失敗しました.' + e.to_s)
      end
    end

    def update_domain_action(config)
      config.delete('elasticsearch_version'.to_sym)
      begin
        res = ess_client.update_elasticsearch_domain_config(config)
        log.info('処理が成功しました.')
      rescue StandardError => e
        log.error('処理が失敗しました.' + e.to_s)
      end
    end

    def get_domain_endpoint_action(domain_name)
      res = ess_client.describe_elasticsearch_domains({ domain_names: [ domain_name ]})
      if res.domain_status_list.empty?
        log.warn('指定したドメインは存在しません.')
        exit 0
      else
        res.domain_status_list.last.endpoint
      end
    end

    def display_resources(header, rows)
      Terminal::Table.new :headings => header, :rows => rows
    end

    def display_domain_resources(config)
      resource_rows = []
      if config[:main]
        config.each { |key, value| value.to_a.each { |va| resource_rows << va } }
      else
        %w(elasticsearch_cluster_config ebs_options snapshot_options advanced_options).each do |key|
          if config[key.to_sym]
            config[key.to_sym].each do |k, v|
              config[k] = v
              config.delete(key.to_sym)
            end
          end
        end
        config.to_a.each do |va|
          if va.first == 'access_policies'.to_sym
            resource_rows << [ va.first, JSON.pretty_generate(JSON.parse(va.last)) ] unless va.last.empty?
          else
            resource_rows << va
          end
        end
      end
      header = [ 'key', 'value' ]
      display_resources(header, resource_rows)
    end

    def display_merged_domain_resources(current_config, update_config)
      update_config[:access_policies] = JSON.parse(update_config[:access_policies]).to_json
      resource_rows = []
      current_config.each do |key, value|
        if value.kind_of?(Hash)
          value.each do |k, v|
            update_value = update_config[key.to_sym][k.to_sym] if update_config[key.to_sym]
            if v == update_value
              resource_rows << [ k.to_s, v, update_value ]
            else
              resource_rows << [ k.to_s, v, hl.color(update_value.to_s, :red) ]
            end
          end
        else
          if key == 'access_policies'.to_sym
            current_policy = JSON.pretty_generate(JSON.parse(value)) unless value == ""
            update_policy = JSON.pretty_generate(JSON.parse(update_config[key.to_sym])) unless update_config[key.to_sym] == ""
            if current_policy == update_policy
              resource_rows << [ key.to_s, current_policy, update_policy ]
            else
              resource_rows << [ key.to_s, current_policy, hl.color(update_policy, :red) ]
            end
          else
            resource_rows << [ key.to_s, value, update_config[key.to_sym] ]
          end
        end
      end
      header = [ 'key', 'current', 'update' ]
      display_resources(header, resource_rows)
    end

    def display_snapshots(snapshots)
      resources = JSON.parse(snapshots)
      if resources['snapshots'].empty?
        log.warn('指定したリポジトリのスナップショットは存在しません.')
        exit 0
      end

      resource_rows = []
      resources['snapshots'].each do |sn|
        resource_rows << [ sn['snapshot'], sn['state'], sn['start_time'], sn['end_time'] ]
      end
      header = [ 'snapshot', 'state', 'start_time', 'end_time' ]
      display_resources(header, resource_rows)
    end

    def display_repositories(repositories)
      resource_rows = []
      repositories.each  do |repo|
        resource_rows << repo.split(' ')
      end
      header = [ 'repository', 'source' ]
      display_resources(header, resource_rows)
    end

    def display_domain_configs(config, config_file = nil)
      template = <<-'EOF'
[main]
domain_id = "<%= config[:domain_id] %>"
arn = "<%= config[:arn] %>"
domain_name = "<%= config[:domain_name] %>"
endpoint = "<%= config[:endpoint] %>"
elasticsearch_version = "<%= config[:elasticsearch_version] %>"
access_policies = '''
<%= JSON.pretty_generate(JSON.parse(config[:access_policies])) %>
'''

[elasticsearch_cluster_config]
instance_type = "<%= config[:elasticsearch_cluster_config][:instance_type] %>"
instance_count = <%= config[:elasticsearch_cluster_config][:instance_count] %>
dedicated_master_enabled = <%= config[:elasticsearch_cluster_config][:dedicated_master_enabled] %>
zone_awareness_enabled = <%= config[:elasticsearch_cluster_config][:zone_awareness_enabled] %>
<% if config[:elasticsearch_cluster_config][:dedicated_master_type] -%>
dedicated_master_type = <%= config[:elasticsearch_cluster_config][:dedicated_master_type] %>
<% end %>
<% if config[:elasticsearch_cluster_config][:dedicated_master_count] -%>
dedicated_master_count = <%= config[:elasticsearch_cluster_config][:dedicated_master_count] %>
<% end %>

[ebs_options]
ebs_enabled = <%= config[:ebs_options][:ebs_enabled] %>
<% if config[:ebs_options][:ebs_enabled] -%>
volume_type = "<%= config[:ebs_options][:volume_type] %>"
volume_size = <%= config[:ebs_options][:volume_size] %>
iops = <%= config[:ebs_options][:iops] %>
<% end %>

[snapshot_options]
automated_snapshot_start_hour = <%= config[:snapshot_options][:automated_snapshot_start_hour] %>

[advanced_options]
<% config[:advanced_options].each do |key, value| -%>
<%= key %> = <%= value %>
<% end %>
EOF
      puts ERB.new(template, nil, "-").result(binding)
      if config_file
        File.open(config_file, "w") do |file|
          file.puts ERB.new(template, nil, "-").result(binding)
        end
      end
    end
  end
end
