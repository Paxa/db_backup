require 'uri'
require 'fileutils'

class DbBackup::Exporters::Mysql

  def initialize(options = {})
    my_url = URI.parse(options[:source])

    @my_options = {
      user: my_url.user,
      password: my_url.password,
      port: my_url.port,
      host: my_url.host,
      database: my_url.path.sub(/^\//, '')
    }
  end

  def get_tables
    output = run_sql(%{SELECT TABLE_NAME AS db FROM information_schema.TABLES WHERE TABLE_SCHEMA = "#{@my_options[:database]}";})
    output.split("\n").map(&:strip)
  end

  def base_cmd_options
    @base_cmd_options ||= begin
      args = [
        "-u", @my_options[:user],
        "--host=#{@my_options[:host]}"
      ]
      if @my_options[:password]
        args << "--password=#{@my_options[:password]}"
      end
      if @my_options[:port]
        args << "--port=#{@my_options[:port]}"
      end

      args
    end
  end

  def run_sql(sql)
    args = base_cmd_options + [
      "-Bse", sql
    ]
    res = DbBackup.cmd(:mysql, *args, @my_options[:database], {})
    res[:stdout]
  end

  def backup
    tables = get_tables

    @tmp_dir = Dir.mktmpdir
    FileUtils.mkdir_p("#{@tmp_dir}/structure")
    FileUtils.mkdir_p("#{@tmp_dir}/data")

    args = base_cmd_options + [
      "--compress",
      "--skip-comments",
      "--complete-insert",
      "--single-transaction",
      "--lock-tables=false"
    ]

    tables.each do |table|
      dump_args = args + [
        "--no-data",
        "--result-file=#{@tmp_dir}/structure/#{table}.sql"
      ]
      res = DbBackup.cmd(:mysqldump, *dump_args, @my_options[:database], table, {})
      unless res[:success]
        DbBackup.logger.error(res[:stdout] + "\n" + res[:error])
      end
    end

    data_file = "#{@tmp_dir}/data.sql.gz"
    dump_args = args + [
      "--no-create-info"
    ]
    if ENV["MYSQL_SKIP_TABLES_DATA"]
      skip_tables = ENV["MYSQL_SKIP_TABLES_DATA"].split(",")
      skip_tables.each do |table|
        dump_args << "--ignore-table=#{@my_options[:database]}.#{table}"
      end
    end
    res = DbBackup.cmd(:mysqldump, *dump_args, @my_options[:database], "| gzip -c > #{data_file}", {})
    unless res[:success]
      DbBackup.logger.error(res[:stdout] + "\n" + res[:error])
    end

    size_mb = (::File.size(data_file) / 1024.0 / 1024.0).round(3)
    DbBackup.logger.info "Generated file #{data_file} -- #{size_mb} MiB"

    return @tmp_dir
  end

  def remove_tmp_files
    if @tmp_dir
      DbBackup.logger.debug "Removing #{@tmp_dir}"
      FileUtils.remove_entry_secure(@tmp_dir)
    end
  end

end
