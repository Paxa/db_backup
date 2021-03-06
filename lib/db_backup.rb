require_relative 'db_backup/version'
require_relative 'db_backup/cmd_utils'
require_relative 'db_backup/log_util'

require 'colorize'

module DbBackup
  extend DbBackup::CmdUtils

  module Exporters; end
  module Uploaders; end

  DEFAULT_DATE_FORMAT = "%FT%H-%M-%S%:z"

  def self.logger
    @logger ||= begin
      require 'logger'
      logger = Logger.new(STDOUT)
      logger.level = Logger::INFO

      logger.formatter = proc { |severity, datetime, progname, msg|
        res = "#{datetime.strftime("%T.%L")}: #{msg}\n"
        if severity == "WARN"
          puts res.colorize(:yellow)
        elsif severity == "ERROR"
          puts res.colorize(:red)
        elsif severity == "DEBUG"
          puts res.colorize(:light_black)
        else
          puts res
        end
      }

      logger
    end
  end

  def self.verbose_logger!
    self.logger.level = Logger::DEBUG
  end

  def self.verbose_logging?
    self.logger.level == Logger::DEBUG
  end

  def self.perform_backup(options)
    logger.debug "Args: #{LogUtil.hash(options)}"

    exporter = detect_source(options[:source], options)
    uploader = detect_target(options[:target], options)

    target_prefix = Time.now.strftime(options[:prefix])

    logger.info "Uploading to #{target_prefix}"

    backup_local_folder = exporter.backup
    uploader.sync(backup_local_folder, target_prefix)

    if options[:keep_num]
      logger.info "Cleaning old backups"
      remove_old_backups(options, uploader)
    end
  ensure
    #exporter && exporter.remove_tmp_files
  end

  def self.remove_old_backups(options, uploader = nil)
    if options[:keep_num].nil?
      raise "Missing argument --keep-num"
    end

    uploader ||= detect_target(options[:target], options)
    keep_num = options[:keep_num].to_i
    backups = uploader.ls.sort

    if backups.size > keep_num
      backups_to_delete = backups.first(backups.size - keep_num)
      logger.info("Deleting old backups #{backups_to_delete.join(", ")}")
      uploader.rm_dirs(backups_to_delete)
    end
  end

  def self.list_remote_objects(options)
    logger.debug "Args: #{LogUtil.hash(options)}"

    uploader = detect_target(options[:target], options)

    puts uploader.ls
  end

  def self.detect_source(value, options = {})
    value = value.to_s
    if value.start_with?("postgres://")
      return DbBackup::Exporters::Postgres.new(options.merge(source: value))
    elsif value.start_with?("influx://", "influxdb://")
      return DbBackup::Exporters::Influxdb.new(options.merge(source: value))
    elsif value.start_with?("mysql://")
      return DbBackup::Exporters::Mysql.new(options.merge(source: value))
    else
      raise ArgumentError, "Unknown source format, supported protocols: postgres, influx, mysql"
    end
  end

  def self.detect_target(value, options = {})
    value = value.to_s
    if value.start_with?("b2://")
      return DbBackup::Uploaders::B2.new(options.merge(target: value))
    elsif value.start_with?("http://", "https://")
      return DbBackup::Uploaders::WebDav.new(options.merge(target: value))
    elsif value.start_with?("file://")
      return DbBackup::Uploaders::LocalFile.new(options.merge(source: value))
    elsif value.start_with?("s3://")
      return DbBackup::Uploaders::S3.new(options.merge(source: value))
    else
      raise ArgumentError, "Unknown source format, supported protocols: b2, s3, file, https (webdav)"
    end
  end
end

require_relative './db_backup/uploaders/b2'
require_relative './db_backup/uploaders/s3'
require_relative './db_backup/uploaders/local_file'
require_relative './db_backup/uploaders/web_dav'
require_relative './db_backup/exporters/postgres'
require_relative './db_backup/exporters/influxdb'
require_relative './db_backup/exporters/mysql'
