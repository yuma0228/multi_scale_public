# frozen_string_literal: true

require_relative "my_hello/version"
require "thor"

module MyHello
  class Error < StandardError; end

  class Greeting
    def initialize(name)
      @name = name
    end

    def call
      puts "Hello, #{@name}."
    end
  end

  def self.greeting(name)
    Greeting.new(name).call
  end

  class CLI < Thor
    desc "greeting", "Display a greeting"
    option :name, aliases: "-n", required: true, desc: "Name to greet"
    def greeting
      MyHello.greeting(options[:name])
    end
  end
end
