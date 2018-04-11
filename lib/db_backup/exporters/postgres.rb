require 'uri'

class DbBackup::Exporters::Postgres

  def initialize(options = {})
    pg_uri = URI.parse(options[:source])

    @pg_options = {
      user: pg_uri.user,
      password: pg_uri.password,
      port: pg_uri.port,
      host: pg_uri.host,
      database: pg_uri.path.sub(/^\//, '')
    }

    if @pg_options[:database] =~ /\//
      @pg_options[:database], @pg_options[:schema] = @pg_options[:database].split("/")
    else
      @pg_options[:schema] = "public"
    end

    @env_vars = {
      "PGPASSWORD" => @pg_options[:password]
    }.freeze
  end

  def backup
    @tmp_dir = Dir.mktmpdir

    args = [
      "-h", @pg_options[:host],
      "-U", @pg_options[:user],
      "-p", @pg_options[:port],
      "-d", @pg_options[:database],
      "-Fc", # binary format
      "--compress=7",
      "--file=#{@tmp_dir}/dump.sql.gz"
    ]

    res =  DbBackup.cmd(:pg_dump, *args, @env_vars)

    size_mb = (File.size(File.join(@tmp_dir, "dump.sql.gz")) / 1024.0 / 1024.0).round(3)
    DbBackup.logger.info "Generated file #{size_mb} MiB"

    return @tmp_dir
  end

  def remove_tmp_files
    if @tmp_dir
      DbBackup.logger.debug "Removing #{@tmp_dir}"
      FileUtils.remove_entry_secure(@tmp_dir)
    end
  end

  # TODO
  # backup each table in separate files: structure & data
  # for faster/partial restore, some day in a future
  def backup_separate_tables
    @tmp_dir = Dir.mktmpdir

    args = [
      "-h", @pg_options[:host],
      "-U", @pg_options[:user],
      "-p", @pg_options[:port],
      "-d", @pg_options[:database],
      "-c", "SELECT table_name FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND table_schema = '#{@pg_options[:schema]}'"
    ]

    res = DbBackup.cmd(:psql, *args, @env_vars)
    tables = res[:stdout].split("\n")[2...-1].map(&:strip)
    p tables
  end

end