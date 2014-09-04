require 'time'
require 'sinatra/base'
require 'sequel'

# Sinatra::SequelExtension was forked from (rtomayko's sinatra-sequel gem)[https://github.com/rtomayko/sinatra-sequel],
# which has not had any commits since 2013. Install this gem using 
# +sudo gem install sinatra-sequel_extension+ or (if using RVM) 
# +gem install sinatra-sequel_extension+. rtomayko's gem can be installed
# with +sudo gem install sinatra-sequel+. The following information pertains to 
# this gem only:
#
# Author::     Ryan Tomayko
# Maintainer:: Dana Scheider
# Copyright::  Copyright (c) 2009 Ryan Tomayko
# License::    Distributes under the MIT License
#
# This gem extends the Sinatra DSL to work with the Sequel ORM gem. Install
# the Sinatra and Sequel gems using +sudo gem install sinatra sequel+, or 
# +gem install sinatra sequel+ if using RVM. Alternatively, add the following
# to your app's Gemfile[http://bundler.io]:
#     gem 'sinatra'
#     gem 'sequel'
#     gem 'sequel-sinatra_extension', '>= 0.9'
# Install the gems using +bundle install+.
#
# Sinatra::SequelExtension can work with MySQL, PostgreSQL, and SQLite3 adapters.
# You will need to include the appropriate database gem in your Gemfile as well.

module Sinatra
  module SequelHelper
    def database
      options.database
    end
  end

  module SequelExtension
    def database=(url)
      @database = nil
      set :database_url, url
      database
    end

    def database
      @database ||=
        Sequel.connect(database_url, :encoding => 'utf-8')
    end

    def migration(name, &block)
      create_migrations_table
      return if database[migrations_table_name].filter(:name => name).count > 0
      migrations_log.puts "Running migration: #{name}"
      database.transaction do
        yield database
        database[migrations_table_name] << { :name => name, :ran_at => Time.now }
      end
    end

    Sequel::Database::ADAPTERS.each do |adapter|
      define_method("#{adapter}?") { @database.database_type == adapter }
    end

  protected

    def create_migrations_table
      database.create_table? migrations_table_name do
        primary_key :id
        String :name, :null => false, :index => true
        timestamp :ran_at
      end
    end

    def self.registered(app)
      app.set :database_url, lambda { ENV['DATABASE_URL'] || "sqlite://#{environment}.db" }
      app.set :migrations_table_name, :migrations
      app.set :migrations_log, lambda { STDOUT }
      app.helpers SequelHelper
    end
  end

  register SequelExtension
end
