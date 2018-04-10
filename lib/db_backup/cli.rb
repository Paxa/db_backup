require 'commander'

class DbBackup::CLI
  include Commander::Methods

  def default_args_from_env(defaults = {})
    args = defaults
    if ENV['BACKUP_SOURCE']
      args[:source] = ENV['BACKUP_SOURCE']
    end
    if ENV['BACKUP_TARGET']
      args[:target] = ENV['BACKUP_TARGET']
    end
    if ENV['BACKUP_PREFIX']
      args[:prefix] = ENV['BACKUP_PREFIX']
    end

    if ENV['BACKUP_VERBOSE']
      args[:verbose] = ["1", "true", "yes", "ya"].include?(ENV['BACKUP_VERBOSE'].downcase)
      if args[:verbose]
        DbBackup.verbose_logger!
      end
    end

    args
  end

  def run
    program :name, 'db_backup'
    program :version, DbBackup::VERSION
    program :description, 'Backup database or folders to cloud'
    program :help_formatter, :compact
    program :help_paging, false

    global_option('--verbose', 'Verbose logging (env var BACKUP_VERBOSE)') {
      $verbose = true
      DbBackup.verbose_logger!
    }

    command :backup do |c|
      c.syntax = 'db_backup backup [options]'
      c.summary = 'Perform backup'
      c.description = 'Create backup and upload it to storage'
      c.example 'postgres', 'db_backup backup --source postgres://user:pass@host/db --target b2://key:token@bucket/db_backups'
      c.example 'mysql', 'db_backup backup --source mysql://user:pass@host/db --target s3://key:token@bucket/db_backups'
      c.option '--source VAL', 'Backup source (env var BACKUP_SOURCE)'
      c.option '--target VAL', 'Upload target (env var BACKUP_TARGET)'
      c.option '--prefix [PATH]', 'Optional. Folder prefix, default is "%FT%T%:z" (support strftime format) (env var BACKUP_PREFIX)'
      c.action do |args, options|
        options.default(default_args_from_env(prefix: "%FT%T%:z"))
        DbBackup.perform_backup(options)
      end
    end

    command :ls do |c|
      c.syntax = 'db_backup ls [options]'
      c.summary = 'List files in storage'
      c.description = 'List files in storage'
      c.example 'description', 'command example'
      #c.option '--source VAL', 'Upload target. Can be b2://key:token@bucket/path'
      c.option '--target VAL', 'Upload target. Can be b2://key:token@bucket/path (env var BACKUP_SOURCE)'
      c.action do |args, options|
        options.default(default_args_from_env)
        DbBackup.list_remote_objects(options)
      end
    end

    #command :claen_old do |c|
    #  c.syntax = 'db_backup claen_old [options]'
    #  c.summary = ''
    #  c.description = ''
    #  c.example 'description', 'command example'
    #  c.option '--some-switch', 'Some switch that does something'
    #  c.action do |args, options|
    #    # Do something or c.when_called Db_backup::Commands::Claen_old
    #  end
    #end
    #
    #command :remove_all do |c|
    #  c.syntax = 'db_backup remove_all [options]'
    #  c.summary = ''
    #  c.description = ''
    #  c.example 'description', 'command example'
    #  c.option '--some-switch', 'Some switch that does something'
    #  c.action do |args, options|
    #    # Do something or c.when_called Db_backup::Commands::Remove_all
    #  end
    #end
    #
    #command :usage do |c|
    #  c.syntax = 'db_backup usage [options]'
    #  c.summary = ''
    #  c.description = ''
    #  c.example 'description', 'command example'
    #  c.option '--some-switch', 'Some switch that does something'
    #  c.action do |args, options|
    #    # Do something or c.when_called Db_backup::Commands::Usage
    #  end
    #end
    #
    #command :download do |c|
    #  c.syntax = 'db_backup download [options]'
    #  c.summary = ''
    #  c.description = ''
    #  c.example 'description', 'command example'
    #  c.option '--some-switch', 'Some switch that does something'
    #  c.action do |args, options|
    #    # Do something or c.when_called Db_backup::Commands::Download
    #  end
    #end

    run!
  end
end
