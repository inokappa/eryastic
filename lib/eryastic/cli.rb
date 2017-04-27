# coding: utf-8
require 'thor'
require 'aws-sdk'
require 'date'
require 'time'
require 'terminal-table'
require 'logger'
require 'erb'
require 'tomlrb'
require 'json'
require 'net/http'
require 'uri'

module Eryastic
  class CLI < Thor
    default_command :version

    desc 'version', 'version 情報を出力.'
    def version
      puts Eryastic::VERSION
    end

    desc 'domain', 'Amazon Elasticsearch Service ドメインを操作する.'
    option :create, type: :boolean, aliases: '-c', desc: 'Amazon Elasticsearch Service ドメインを作成する.'
    option :delete, type: :boolean, aliases: '-d', desc: 'Amazon Elasticsearch Service ドメインを削除する.'
    option :export, type: :boolean, aliases: '-e', desc: 'Amazon Elasticsearch Service ドメインの設定を export する.'
    option :list, type: :boolean, aliases: '-l', desc: 'Amazon Elasticsearch Service ドメインの一覧を取得する.'
    option :update, type: :boolean, aliases: '-u', desc: 'Amazon Elasticsearch Service ドメイン構成を更新する.'
    option :domain_name, type: :string, aliases: '-n', desc: 'Amazon Elasticsearch Service ドメイン名を指定する.'
    option :config_file, type: :string, aliases: '-f', desc: 'Amazon Elasticsearch Service 設定ファイルを指定する.'
    def domain
      unless options[:create] or options[:delete] or options[:export] or options[:list] or options[:update] then
        puts '--create | --delete | --export | --list | --update オプションがセットされていません.'
        exit 1
      end
      eryastic = Eryastic::Domain.new
      eryastic.create_domain(options[:domain_name], options[:config_file]) if options[:create]
      eryastic.delete_domain(options[:domain_name]) if options[:delete]
      eryastic.export_domain(options[:domain_name], options[:config_file]) if options[:export]
      eryastic.list_domain if options[:list]
      eryastic.update_domain(options[:domain_name], options[:config_file]) if options[:update]
    end

    desc 'snapshot', 'Elasticsearch の Snapshot を操作する.'
    option :prepare, type: :boolean, aliases: '-p', desc: 'Amazon Elasticsearch Service ドメインのスナップショットを作成する準備をする.'
    option :create, type: :boolean, aliases: '-c', desc: 'Amazon Elasticsearch Service ドメインのスナップショットを作成する.'
    option :delete, type: :boolean, aliases: '-c', desc: 'Amazon Elasticsearch Service ドメインのスナップショットを削除する.'
    option :list, type: :boolean, aliases: '-l', desc: 'Amazon Elasticsearch Service ドメインのスナップショット一覧を取得する.'
    option :list_repository, type: :boolean, aliases: '-y', desc: 'Amazon Elasticsearch Service ドメインのスナップリポジトリ一覧を取得する.'
    option :restore, type: :boolean, aliases: '-r', desc: 'Amazon Elasticsearch Service ドメインのスナップリポジトリ一覧を取得する.'
    option :bucket_name, type: :string, desc: 'Amazon Elasticsearch Service ドメインのスナップショットを保存する S3 Bucket 名を指定する.'
    option :domain_name, type: :string, desc: 'Amazon Elasticsearch Service ドメインのスナップショットを取得するドメイン名を指定する.'
    option :repository_name, type: :string, desc: 'Amazon Elasticsearch Service ドメインのスナップショットリポジトリ名を指定する.'
    option :snapshot_name, type: :string, desc: 'Amazon Elasticsearch Service ドメインのスナップショット名を指定する.'
    option :snapshot_date, type: :string, desc: 'Amazon Elasticsearch Service ドメインのスナップショットを取得する年月日を YYYY.MM.DD で指定する.'
    option :validate, type: :boolean, desc: 'Amazon Elasticsearch Service ドメインのスナップショットの検証を行う.'
    def snapshot
      unless options[:prepare] or options[:create] or options[:delete] \
        or options[:list] or options[:list_repository] or options[:restore] or options[:validate] then
        puts '--prepare | --create | --delete | --list | --list-repository | --restore | --validate オプションがセットされていません.'
        exit 1
      end
      eryastic = Eryastic::Snapshot.new
      eryastic.prepare_snapshot(options[:domain_name], options[:repository_name], options[:bucket_name]) if options[:prepare]
      eryastic.create_snapshot(options[:domain_name], options[:repository_name], options[:snapshot_name], options[:snapshot_date]) if options[:create]
      eryastic.delete_snapshot(options[:domain_name], options[:repository_name], options[:snapshot_name]) if options[:delete]
      eryastic.list_snapshot(options[:domain_name], options[:repository_name]) if options[:list]
      eryastic.list_repository(options[:domain_name]) if options[:list_repository]
      eryastic.restore_snapshot(options[:domain_name], options[:repository_name], options[:snapshot_name]) if options[:restore]
      eryastic.validate_snapshot(options[:domain_name], options[:repository_name], options[:snapshot_name]) if options[:validate]
    end
  end
end
