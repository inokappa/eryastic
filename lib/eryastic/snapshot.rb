#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'json'
require 'net/http'
require 'uri'

def http_output(response)
  puts "code => #{response.code}"
  puts "msg  => #{response.message}"
  puts "body => #{response.body}"
end

def post_request(uri, body)
  uri  = URI.parse(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  req  = Net::HTTP::Post.new(uri.request_uri)
  req["Content-Type"] = "application/json"
  req.body = body
  http.request(req)
end

def put_request(uri)
  uri  = URI.parse(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  req  = Net::HTTP::Put.new(uri.request_uri)
  http.request(req)
end

def get_request(uri)
  uri  = URI.parse(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  req  = Net::HTTP::Get.new(uri.request_uri)
  http.request(req)
end

def read_tfstate
  json_data = open('/tmp/terraform/terraform.tfstate') do |io|
    JSON.load(io)
  end
  output = json_data['modules'][0]['outputs']
  return output
end

def regist_snapshot_dir
  state = read_tfstate
  template = <<EOS
{
  "settings": {
    "role_arn": "#{state['IAM Role']}",
    "region": "ap-northeast-1",
    "bucket": "#{state['S3 bucket']}"
  },
  "type": "s3"
}
EOS
  uri  = "https://" + ENV["ES_HOST"] + "/_snapshot/" + ENV["ES_SNAPSHOT"]
  res = post_request(uri, template)

  http_output(res)
end

def create_snapshot
  uri  = "https://" + ENV["ES_HOST"] + "/_snapshot/" + ENV["ES_SNAPSHOT"] + "/" +ENV["ES_SNAPSHOT_NAME_PREFIX"] + "_" + "#{Time.now.to_i}"
  res = put_request(uri)

  http_output(res)
end

def list_snapshot
  uri  = "https://" + ENV["ES_HOST"] + "/_snapshot/" + ENV["ES_SNAPSHOT"] + "/_all?pretty"
  res = get_request(uri)

  http_output(res)
end

case ARGV[0]
when "regist" then
  regist_snapshot_dir
when "create" then
  create_snapshot
when "list" then
  list_snapshot
end
