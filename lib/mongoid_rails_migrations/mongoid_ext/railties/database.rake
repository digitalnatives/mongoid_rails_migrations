namespace :db do
  namespace :mongo do
    desc 'Drops all the collections for the database for the current Rails.env'
    task :drop => :environment do
      Mongoid.master.collections.each do |col|
        next if ['system.indexes', 'system.users'].include?(col.name)
        col.drop_indexes && col.drop
      end
    end

    desc 'Load the seed data from db/seeds.rb'
    task :seed => :environment do
      seed_file = Rails.application.root.join('db', 'seeds.rb')
      load(seed_file) if File.exist?(seed_file)
    end

    desc 'Create the database, and initialize with the seed data'
    task :setup => [ 'db:mongo:create', 'db:mongo:seed' ]

    desc 'Delete data and seed'
    task :reseed => [ 'db:mongo:drop', 'db:mongo:seed' ]

    desc 'Current database version'
    task :version => :environment do
      puts Mongoid::Migrator.current_version.to_s
    end

    desc "Migrate the database through scripts in db/migrate. Target specific version with VERSION=x. Turn off output with VERBOSE=false."
    task :migrate => :environment do
      verbose = ENV.has_key?('VERBOSE')
      version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil

      Mongoid::Migration.verbose = verbose
      Mongoid::Migrator.migrate(version)
    end

    namespace :migrate do
      desc  'Rollback the database one migration and re migrate up. If you want to rollback more than one step, define STEP=x. Target specific version with VERSION=x.'
      task :redo => :environment do
        if ENV["VERSION"]
          Rake::Task["db:mongo:migrate:down"].invoke
          Rake::Task["db:mongo:migrate:up"].invoke
        else
          Rake::Task["db:mongo:rollback"].invoke
          Rake::Task["db:mongo:migrate"].invoke
        end
      end

      desc 'Resets your database using your migrations for the current environment'
      # should db:create be changed to db:setup? It makes more sense wanting to seed
      task :reset => ["db:mongo:drop", "db:mongo:create", "db:mongo:migrate"]

      desc 'Runs the "up" for a given migration VERSION.'
      task :up => :environment do
        Mongoid::Migrator.up(required_version)
      end

      desc 'Runs the "down" for a given migration VERSION.'
      task :down => :environment do
        Mongoid::Migrator.down(required_version)
      end

      def required_version
        ENV.fetch('VERSION') { raise "VERSION is required" }
      end
    end

    desc 'Rolls the database back to the previous migration. Specify the number of steps with STEP=n'
    task :rollback => :environment do
      Mongoid::Migrator.rollback(ENV.fetch('STEP', 1).to_i)
    end

    namespace :schema do
      task :load # noop
    end

    namespace :test do
      task :prepare # Stub out for MongoDB
    end
  end
end
