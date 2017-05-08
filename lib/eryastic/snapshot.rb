require 'faraday_middleware'
require 'faraday_middleware/aws_signers_v4'

module Eryastic
  class Snapshot < Client

    include Eryastic::Helper

    def prepare_snapshot(domain_name, repository_name, bucket_name = nil)
      iam_role_name = repository_name + '-role'
      iam_policy_name = repository_name + '-policy'
      ess_endpoint = get_domain_endpoint_action(domain_name)

      log.info('以下の内容でスナップショット取得先 S3 バケット、IAM Role を作成します.')
      header = [ 'ess_endpoint', 'iam_role_name', 'bucket_name' ]
      resource_rows = [[ ess_endpoint, iam_role_name, bucket_name ]]
      puts display_resources(header, resource_rows)

      if process_ok?
        exist, bucket_name = repository_not_exists?(repository_name, ess_endpoint)
        if exist
          log.info('リポジトリは存在していません.')
        else
          log.warn('リポジトリは存在しています.')
        end

        if s3_bucket_not_exists?(bucket_name)
          create_s3_bucket_action(bucket_name)
          log.info('スナップショットを保存する S3 Bucket ' + bucket_name + ' を作成しました.')
        else
          log.warn('スナップショットを保存する S3 Bucket は存在しています.')
        end

        if s3_bucket_not_exists?(bucket_name + '-state')
          create_s3_bucket_action(bucket_name + '-state')
          log.info('スナップショットの状態を保存する S3 Bucket ' + bucket_name + '-state を作成しました.')
        else
          log.warn('スナップショットの状態を保存する S3 Bucket は存在しています.')
        end

        if iam_role_not_exists?(iam_role_name)
          iam_res = create_iam_role_action(iam_role_name)
          create_iam_policy_action(iam_res.role.role_name, iam_policy_name, bucket_name)
          log.info('IAM Role ' + iam_role_name + ' 及び' + iam_policy_name + ' を作成しました.')
        else
          log.warn('IAM Role は存在しています.')
          iam_res = iam_role_get(iam_role_name)
        end
      else
        exit 0
      end

      log.info('以下の内容でリポジトリを作成します.')
      header = [ 'ess_endpoint', 'repository_name', 'iam_role_name', 'bucket_name' ]
      resource_rows = [[ ess_endpoint, repository_name, iam_res.role.role_name, bucket_name ]]
      puts display_resources(header, resource_rows)

      if process_ok?
        begin
          regist_snapshot_repo(ess_endpoint, repository_name, iam_res.role.arn, bucket_name)
        rescue StandardError => e
          log.error(e)
          exit 1
        end
      else
        exit 0
      end
    end

    def create_snapshot(domain_name, repository_name, snapshot_name, snapshot_date = nil)
      ess_endpoint = get_domain_endpoint_action(domain_name)
      exist, bucket_name = repository_not_exists?(repository_name, ess_endpoint)
      snapshot_name = snapshot_name + '_' + "#{Time.now.to_i}"
      uri  = 'https://' + ess_endpoint + '/_snapshot/' + repository_name + '/' + snapshot_name

      log.info('以下の内容でスナップショットを作成します.')
      if snapshot_date
        indices = list_indices(domain_name)
        snapshot_indices = indices.select { |index| index.include?(snapshot_date) }
        if snapshot_indices.empty?
          log.warn('スナップショット対象の index は存在しません.')
          snapshot_month = 'スナップショット対象の index は存在しません.'
        end
        snapshot_indices_str = snapshot_indices.join(',')
        body = {
            "indices": snapshot_indices_str,
            "ignore_unavailable": true,
            "include_global_state": false
        }
        header = [ 'ess_endpoint', 'repository_name', 'snapshot_name', 'snapshot_date' ]
        resource_rows = [[ ess_endpoint, repository_name, snapshot_name, snapshot_date ]]
      else
        header = [ 'ess_endpoint', 'repository_name', 'snapshot_name' ]
        resource_rows = [[ ess_endpoint, repository_name, snapshot_name ]]
      end

      puts display_resources(header, resource_rows)

      if process_ok?
        begin
          res = put_request(uri, body)
        rescue StandardError => e
          log.error(e)
          exit 1
        end
      else
        exit 0
      end

      if res.code == '200'
        log.info('スナップショットを作成しました. message = ' + res.body + ', snapshot_name = ' + snapshot_name)
        state_bucket = bucket_name + '-state'
        key = 'snapshots' + '/' + repository_name + '/' + snapshot_name
        object = snapshot_indices.join("\n")
        log.info('s3://' + state_bucket + '/' + key + ' に取得した index スナップショットの一覧を保存します.')
        put_s3_object_action(state_bucket, key, object)
      else
        log.error('スナップショットの取得に失敗しました. message = ' + res.body)
        exit 1
      end
    end

    def list_indices(domain_name)
      ess_endpoint = get_domain_endpoint_action(domain_name)
      uri  = 'https://' + ess_endpoint + '/_aliases?pretty'
      res = get_request(uri)
      indices = JSON.parse(res.body)
      indices.keys
    end

    def list_snapshot(domain_name, repository_name)
      ess_endpoint = get_domain_endpoint_action(domain_name)
      uri  = 'https://' + ess_endpoint + '/_snapshot/' + repository_name + '/_all?pretty'
      res = get_request(uri)
      puts display_snapshots(res.body)
    end

    def list_repository(domain_name)
      ess_endpoint = get_domain_endpoint_action(domain_name)
      uri  = 'https://' + ess_endpoint + '/_cat/repositories'
      res = get_request(uri)
      puts display_repositories(res.body.split(" \n"))
    end

    def delete_snapshot(domain_name, repository_name, snapshot_name)
      ess_endpoint = get_domain_endpoint_action(domain_name)
      uri  = 'https://' + ess_endpoint + '/_snapshot/' + repository_name + '/' + snapshot_name

      log.info('以下の内容でスナップショットを削除します.')
      header = [ 'ess_endpoint', 'repository_name', 'snapshot_name' ]
      resource_rows = [[ ess_endpoint, repository_name, snapshot_name ]]
      puts display_resources(header, resource_rows)

      if process_ok?
        begin
          res = delete_request(uri)
        rescue StandardError => e
          log.error(e)
          exit 1
        end
      else
        exit 0
      end

      if res.code == '200'
        log.info('スナップショットを削除しました. message = ' + res.body + ', snapshot_name = ' + snapshot_name)
        exit 0
      else
        log.error('スナップショットの削除に失敗しました. message = ' + res.code)
        exit 1
      end
    end

    def restore_snapshot(domain_name, repository_name, snapshot_name)
      ess_endpoint = get_domain_endpoint_action(domain_name)
      uri  = 'https://' + ess_endpoint + '/_snapshot/' + repository_name + '/' + snapshot_name + '/_restore'

      log.info('以下の内容でレストアを行います.')
      header = [ 'ess_endpoint', 'repository_name', 'snapshot_name' ]
      resource_rows = [[ ess_endpoint, repository_name, snapshot_name ]]
      puts display_resources(header, resource_rows)

      if process_ok?
        begin
          res = post_request(uri)
        rescue StandardError => e
          log.error(e)
          exit 1
        end
      else
        exit 0
      end

      if res.code == '200'
        log.info('スナップショットからのレストアを開始しました. message = ' + res.body + ', snapshot_name = ' + snapshot_name)
        exit 0
      else
        log.error('スナップショットからのレストアに失敗しました. message = ' + res.body)
        exit 1
      end
    end

    def validate_snapshot(domain_name, repository_name, snapshot_name)
      ess_endpoint = get_domain_endpoint_action(domain_name)
      uri  = 'https://' + ess_endpoint + '/_snapshot/' + repository_name + '/' + snapshot_name
      exist, snapshot_bucket_name = repository_not_exists?(repository_name, ess_endpoint)

      state_bucket_name = snapshot_bucket_name + '-state'
      key_name = 'snapshots/' + repository_name + '/' + snapshot_name
      snapshot_state = get_s3_object_action(state_bucket_name, key_name)

      log.info('以下の内容でスナップショットの検証を行います.')
      header = [ 'ess_endpoint', 'repository_name', 'snapshot_name' ]
      resource_rows = [[ ess_endpoint, repository_name, snapshot_name ]]
      puts display_resources(header, resource_rows)

      if process_ok?
        begin
          res = get_request(uri)
        rescue StandardError => e
          log.error(e)
          exit 1
        end
      else
        exit 0
      end

      begin
        remote_snapshot = JSON.parse(res.body)['snapshots'][0]['indices'].sort
      rescue StandardError => e
        log.error('処理が失敗しました. ' + e.to_s)
        exit 1
      end

      if remote_snapshot == snapshot_state.read.split("\n").sort
        log.info(hl.color('スナップショットは正常に取得されています.', :green))
      else
        log.warn(hl.color('スナップショットが正常に取得されていない可能性があります.', :yellow))
      end
    end

    private

    def repository_not_exists?(repository_name, ess_endpoint)
      uri  = 'https://' + ess_endpoint + '/_snapshot/' + repository_name
      res = get_request(uri)
      if res.code == '404'
        return true, nil
      else
        repository = JSON.parse(res.body)
        return false, repository[repository_name]['settings']['bucket']
      end
    end

    def s3_bucket_not_exists?(bucket_name)
      res = s3_client.list_buckets
      bucket_names = res.buckets.select { |bucket| bucket.name == bucket_name }
      if bucket_names.empty?
        true
      else
        false
      end
    end

    def create_s3_bucket_action(bucket_name)
      begin
        res = s3_client.create_bucket({
          bucket: bucket_name
        })
        res
      rescue StandardError => e
        log.error('処理が失敗しました. message = ' + e.to_s)
      end
    end

    def put_s3_object_action(bucket_name, key_name, object)
      begin
        res = s3_client.put_object({
          bucket: bucket_name,
          key: key_name,
          body: object
        })
        res
      rescue StandardError => e
        log.error('処理が失敗しました. message = ' + e.to_s)
      end
    end

    def get_s3_object_action(bucket_name, key_name)
      begin
        res = s3_client.get_object({
          bucket: bucket_name,
          key: key_name
        })
        res.body
      rescue StandardError => e
        log.error('処理が失敗しました. message = ' + e.to_s)
      end
    end

    def iam_role_not_exists?(role_name)
      res = iam_client.list_roles({ path_prefix: '/service-role/' })
      role_names = res.roles.select { |role| role.role_name == role_name }
      if role_names.empty?
        true
      else
        false
      end
    end

    def iam_role_get(role_name)
      begin
        res = iam_client.get_role({ role_name: role_name })
        res
      rescue StandardError => e
        log.error('処理が失敗しました. message = ' + e.to_s)
        exit 0
      end
    end

    def create_iam_role_action(role_name)
      policy_document = <<-"EOF"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "es.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
      begin
        res = iam_client.create_role({
          path: '/service-role/',
          role_name: role_name,
          assume_role_policy_document: policy_document
        })
        res
      rescue StandardError => e
        log.error('処理が失敗しました. message = ' + e.to_s)
      end
    end

    def create_iam_policy_action(role_name, policy_name, bucket_name)
      policy_document = <<-"EOF"
{
  "Version": "2012-10-17",
  "Statement":[
    {
      "Action":[
        "s3:ListBucket"
      ],
      "Effect":"Allow",
      "Resource":[
        "arn:aws:s3:::#{bucket_name}"
      ]
    },
    {
      "Action":[
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "iam:PassRole"
      ],
      "Effect":"Allow",
      "Resource":[
          "arn:aws:s3:::#{bucket_name}/*"
      ]
    }
  ]
}
EOF
      begin
        res = iam_client.put_role_policy({
          role_name: role_name,
          policy_name: policy_name,
          policy_document: policy_document
        })
        res
      rescue StandardError => e
        log.error('処理が失敗しました. message = ' + e.to_s)
      end
    end

    def http_output(response)
      puts "code => #{response.code}"
      puts "msg  => #{response.message}"
      puts "body => #{response.body}"
    end

    def post_request(uri)
      uri  = URI.parse(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 300
      req  = Net::HTTP::Post.new(uri.request_uri)
      http.request(req)
    end

    def put_request(uri, body = nil)
      uri  = URI.parse(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 300
      if body == nil
        req  = Net::HTTP::Put.new(uri.request_uri)
      else
        req  = Net::HTTP::Put.new(uri.request_uri, 'Content-Type' => 'application/json')
        req.body = body.to_json
      end
      http.request(req)
    end

    def get_request(uri)
      uri  = URI.parse(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 300
      req  = Net::HTTP::Get.new(uri.request_uri)
      http.request(req)
    end

    def delete_request(uri)
      uri  = URI.parse(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 300
      req  = Net::HTTP::Delete.new(uri.request_uri)
      http.request(req)
    end

    def read_tfstate
      json_data = open('/tmp/terraform/terraform.tfstate') do |io|
        JSON.load(io)
      end
      output = json_data['modules'][0]['outputs']
      return output
    end

    def regist_snapshot_repo(ess_endpoint, snapshot_name, iam_role_arn, s3_bucket_name)
      template = <<-"EOT"
{
"settings": {
  "role_arn": "#{iam_role_arn}",
  "region": "ap-northeast-1",
  "bucket": "#{s3_bucket_name}"
},
"type": "s3"
}
EOT
      uri  = "https://" + ess_endpoint
      conn = Faraday.new(url: uri) do |faraday|
        faraday.request :aws_signers_v4,
          credentials: Aws::SharedCredentials.new(profile_name: ENV['AWS_PROFILE']),
          service_name: 'es',
          region: ENV['AWS_REGION']

        faraday.adapter Faraday.default_adapter
      end

      res = conn.post do |req|
        req.headers['Content-Type'] = 'application/json'
        req.url "/_snapshot/" + snapshot_name
        req.body = template
      end

      if res.status == 200
        log.info('スナップショットレジストリを登録しました. message = ' + res.body)
        exit 0
      else
        log.error('スナップショットレジストリの登録に失敗しました. message = ' + res.body)
        exit 1
      end
    end
  end
end
