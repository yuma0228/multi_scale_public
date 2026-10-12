# frozen_string_literal: true

require "yaml"

class PublicationConfig
  attr_reader :year, :lecture, :server_url

  def self.load(path)
    config = YAML.load_file(path)
    server_info = config.fetch(:server_info, {})

    new(
      year: config.fetch(:year),
      lecture: config.fetch(:lecture),
      server_url: server_info.fetch(:server_url)
    )
  end

  def initialize(year:, lecture:, server_url:)
    @year = year.to_s
    @lecture = lecture
    @server_url = server_url.sub(%r{/+\z}, "")
  end

  def public_base_url
    [server_url, year, lecture].join("/")
  end
end
