require 'uri'
require 'fileutils'

class DbBackup::Exporters::Influxdb

  def initialize(options = {})
    inf_uri = URI.parse(options[:source])

    @inf_options = {
      user: inf_uri.user,
      password: inf_uri.password,
      port: inf_uri.port,
      host: inf_uri.host,
      database: inf_uri.path.sub(/^\//, '')
    }
  end

  # uses legacy format
  def backup
    @tmp_dir = Dir.mktmpdir

    connect_params = [
      "-host", "#{@inf_options[:host]}:#{@inf_options[:port] || 8088}"
    ]

    DbBackup.cmd(:influxd, ["backup"] + connect_params + [::File.join(@tmp_dir, 'meta')])
    DbBackup.cmd(:influxd, ["backup"] + connect_params + ["-database", @inf_options[:database], ::File.join(@tmp_dir, 'data')])

    DbBackup.logger.info "Generated backup"

    return @tmp_dir
  end

  def remove_tmp_files
    if @tmp_dir
      DbBackup.logger.debug "Removing #{@tmp_dir}"
      FileUtils.remove_entry_secure(@tmp_dir)
    end
  end

end