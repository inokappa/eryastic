# coding: utf-8
require 'thor'
require 'aws-sdk'
require 'date'
require 'time'
require 'terminal-table'
require 'logger'
require 'erb'
require 'tomlrb'

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

    # desc 'snapshot', 'Elasticsearch の Snapshot を操作する.'
    # def snapshot
    #   unless options[:before_datetime] then
    #     puts '削除対象の日時がセットされていません. (--before-datetime 2017/04/01)'
    #     exit 1
    #   end
    #   Eryastic = Eryastic::Snapshot.new
    #   Eryastic.prepare_snapshot()
    #   Eryastic.create_snapshot()
    #   Eryastic.list_snapshot()
    #   Eryastic.delete_snapshot()
    # end
  end
end
