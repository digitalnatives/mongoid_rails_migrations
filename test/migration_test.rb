require File.expand_path('../helper.rb', __FILE__)

class Mongoid::Migration
  class <<self
    attr_accessor :message_count

    def puts(text="")
      self.message_count ||= 0
      self.message_count += 1
    end
  end
end

module Mongoid
  class TestCase < ActiveSupport::TestCase #:nodoc:
    self.test_order = :random

    FIRST_MIGRATION  = 20100513054656
    SECOND_MIGRATION = 20100513063902

    def described_class
      Mongoid::Migrator
    end

    def setup
      Mongoid::Migration.verbose = true
      # same as db:drop command in lib/mongoid_rails_migrations/mongoid_ext/railties/database.rake
      Mongoid.default_session.drop
      @old_migrations_path = described_class.migrations_path
      described_class.migrations_path = MIGRATIONS_ROOT + "/valid"
    end

    def teardown
      described_class.migrations_path = @old_migrations_path
    end

    def test_drop_works
      assert_equal 0, described_class.current_version, "db:drop should take us down to version 0"
    end

    def test_finds_migrations
      assert_equal 2, described_class.new(:up).migrations.size
      assert_equal 2, described_class.new(:up).pending_migrations.size
    end

    def test_migrator_current_version
      described_class.migrate(version = FIRST_MIGRATION)
      assert_equal version, described_class.current_version
    end

    def test_migrator
      assert_nil SurveySchema.first, "All SurveySchemas should be clear before migration run"
      described_class.up

      assert_equal SECOND_MIGRATION, described_class.current_version
      assert !SurveySchema.first.nil?

      described_class.down
      assert_equal 0, described_class.current_version

      assert SurveySchema.create(:label => 'Questionable Survey')
      assert_equal 1, SurveySchema.all.to_a.size
    end

    def test_migrator_two_up_and_one_down
      assert_nil SurveySchema.where(:label => 'Baseline Survey').first
      assert_equal 0, SurveySchema.all.to_a.size

      described_class.up(FIRST_MIGRATION)

      assert !SurveySchema.where(:label => 'Baseline Survey').first.nil?
      assert_equal 1, SurveySchema.all.to_a.size

      assert SurveySchema.where(:label => 'Improvement Plan Survey').first.nil?

      described_class.up(SECOND_MIGRATION)
      assert_equal SECOND_MIGRATION, described_class.current_version

      assert !SurveySchema.where(:label => 'Improvement Plan Survey').first.nil?
      assert_equal 2, SurveySchema.all.to_a.size

      described_class.down(FIRST_MIGRATION)

      assert_equal FIRST_MIGRATION, described_class.current_version

      assert SurveySchema.where(:label => 'Improvement Plan Survey').first.nil?
      assert !SurveySchema.where(:label => 'Baseline Survey').first.nil?
      assert_equal 1, SurveySchema.all.to_a.size
    end

    def test_finds_pending_migrations
      described_class.up(FIRST_MIGRATION)
      pending_migrations = described_class.new(:up).pending_migrations

      assert_equal 1, pending_migrations.size
      assert_equal pending_migrations[0].version, SECOND_MIGRATION
      assert_equal pending_migrations[0].name, 'AddImprovementPlanSurveySchema'
    end

    def test_migrator_rollback
      described_class.migrate
      assert_equal(SECOND_MIGRATION, described_class.current_version)

      described_class.rollback
      assert_equal(FIRST_MIGRATION, described_class.current_version)

      described_class.rollback
      assert_equal(0, described_class.current_version)
    end

    def test_migrator_forward
      described_class.migrate(FIRST_MIGRATION)
      assert_equal(FIRST_MIGRATION, described_class.current_version)

      described_class.forward(SECOND_MIGRATION)
      assert_equal(SECOND_MIGRATION, described_class.current_version)
    end

    def test_migrator_with_duplicate_names
      assert_raise(Mongoid::DuplicateMigrationNameError) do
        described_class.migrate(nil, MIGRATIONS_ROOT + '/duplicate/names/')
      end
    end

    def test_migrator_with_duplicate_versions
      assert_raise(Mongoid::DuplicateMigrationVersionError) do
        described_class.migrate(nil, MIGRATIONS_ROOT + '/duplicate/versions/')
      end
    end

    def test_migrator_with_missing_version_numbers
      assert_raise(Mongoid::UnknownMigrationVersionError) do
        described_class.migrate(500)
      end
    end

    def test_default_state_of_timestamped_migrations
      assert Mongoid.configure.timestamped_migrations, "Mongoid.configure.timestamped_migrations should default to true"
    end

    def test_timestamped_migrations_generates_non_sequential_next_number
      next_number = Mongoid::Generators::Base.next_migration_number(described_class.migrations_path)
      assert_not_equal "20100513063903", next_number
    end

    def test_turning_off_timestamped_migrations
      Mongoid.configure.timestamped_migrations = false
      next_number = Mongoid::Generators::Base.next_migration_number(described_class.migrations_path)
      assert_equal "20100513063903", next_number
      Mongoid.configure.timestamped_migrations = true
    end

  end
end
